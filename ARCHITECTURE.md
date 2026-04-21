# InspectKit — Technical Architecture

## What It Is

A zero-dependency iOS debug toolkit with two independent products:

| Product | Role |
|---|---|
| **InspectKit** | Read-only network inspector — captures every HTTP/HTTPS request and exposes it in a floating dashboard |
| **InspectKitMock** | Network mocker — intercepts selected requests and returns configurable fake responses, errors, or delays |

An internal target, **InspectKitCore**, holds all code shared between the two products. It is not exposed as a library product; consumers only see `InspectKit` and/or `InspectKitMock`.

Minimum deployment target: **iOS 13**.

---

## Package Layout

```
InspectKit (SPM package)
├── InspectKitCore      [internal — not a product]
│     Models, Redactor, CoreAutoCapture swizzle, MockHooks hook point,
│     Theme tokens (NIColor/NIFont), shared utilities
│
├── InspectKit          [product]
│     depends on InspectKitCore
│     @_exported import InspectKitCore   ← re-exports Core types
│     InspectKitURLProtocol (priority 100), InspectKitStore, UI
│
└── InspectKitMock      [product]
      depends on InspectKitCore
      InspectKitMockURLProtocol (priority 200), MockStore, UI
```

When only `InspectKit` is linked, the Mock layer is absent and `MockHooks.onHit` is `nil` — no overhead. When both are linked, Mock intercepts matching requests first; unmatched requests fall through to the Inspector layer and then to the real network.

---

## Module Dependency Graph

```
        ┌────────────────────┐
        │   InspectKitCore   │  (internal, not a product)
        │                    │
        │  NetworkModels     │
        │  Redactor          │
        │  CoreAutoCapture   │
        │  MockHooks         │
        │  Theme (NIColor…)  │
        │  Utilities         │
        └──────┬─────────────┘
               │ depends on
       ┌───────┴────────┐
       │                │
       ▼                ▼
┌─────────────┐  ┌──────────────────┐
│ InspectKit  │  │  InspectKitMock  │
│  (product)  │  │    (product)     │
└─────────────┘  └──────────────────┘
```

---

## Layer Diagram — Combined Mode

```
┌────────────────────────────────────────────────────────────────┐
│                          Your App                              │
│        URLSession / Alamofire / custom networking layer        │
└──────────────────────────────┬─────────────────────────────────┘
                               │  URLRequest
                               ▼
┌────────────────────────────────────────────────────────────────┐
│               URL Loading System (Foundation)                  │
│                                                                │
│  protocolClasses = [InspectKitMockURLProtocol (200),          │
│                     InspectKitURLProtocol     (100), ...]      │
│                                                                │
│  canInit() called in priority order ──────────────────────►   │
└──────────────────────────────┬─────────────────────────────────┘
                               │
              ┌────────────────┴──────────────────┐
              │                                   │
        rule matched?                       no rule match
              │                                   │
              ▼                                   ▼
┌─────────────────────────┐        ┌──────────────────────────┐
│ InspectKitMockURLProtocol│        │  InspectKitURLProtocol   │
│   priority 200           │        │  priority 100            │
│   Synthesises response   │        │  Forwards to real network│
│   (no outgoing task)     │        │  Streams response back   │
│          │               │        │          │               │
│   logHit()               │        │   inspectionID attached  │
│   MockHooks.onHit?() ────┼──────► │   store.insert(record)   │
│                          │   if   │                          │
└──────────────────────────┘  both  └──────────────────────────┘
                              active
```

---

## InspectKitCore — Shared Infrastructure

### CoreAutoCapture — Single Shared Swizzle

Both protocols need to inject themselves into `URLSessionConfiguration.protocolClasses`. Two competing swizzles would chain unpredictably. `CoreAutoCapture` installs **one** swizzle on the first `register` call and maintains a priority-sorted class list.

```swift
public enum CoreAutoCapture {
    public static func register(_ cls: AnyClass, priority: Int)
    public static func unregister(_ cls: AnyClass)
    static func injectedClasses() -> [AnyClass]   // sorted descending by priority
}
```

Registration priorities:

| Class | Priority |
|---|---|
| `InspectKitMockURLProtocol` | 200 |
| `InspectKitURLProtocol` | 100 |

The swizzled getter prepends `injectedClasses()` before any app-level classes already in the list, with deduplication. Mock (200) always precedes Inspector (100) so Mock's `canInit` is evaluated first.

### MockHooks — Cross-Framework Bridge

```swift
public enum MockHooks {
    public static var onHit: ((NetworkRequestRecord) -> Void)?
}
```

`InspectKit.start()` installs a closure that calls `store.insert(record)` with `isMocked = true`. `InspectKit.stop()` nils it. `InspectKitMock` calls this hook after a rule fires; if the Inspector is not linked or not running, the hook is `nil` and this is a no-op.

### NetworkRequestRecord — Shared Data Model

```
NetworkRequestRecord  (public struct, Codable, Sendable, Hashable)
 ├─ id: UUID
 ├─ sequence: Int
 ├─ state: NetworkRequestState   — inProgress | completed | failed | cancelled
 ├─ url / host / path / queryItems
 ├─ method: HTTPMethod
 ├─ requestHeaders / requestBody: CapturedBody
 ├─ statusCode
 ├─ responseHeaders / responseBody: CapturedBody
 ├─ error: CapturedError?
 ├─ startDate / endDate → durationMS (computed)
 ├─ metrics: CapturedMetrics?    — DNS/TLS/connect/response phases
 ├─ isMocked: Bool               — set true when delivered by Mock
 └─ mockRuleName: String?        — name of the matching MockRule
```

`isMocked` and `mockRuleName` default to `false`/`nil` so all existing Inspector code compiles unchanged.

---

## InspectKit — Network Inspector

### Request Lifecycle

```
startLoading()
  │
  ├─ beginInspection(request)
  │    ├─ Generate UUID (recordID)
  │    ├─ Task { @MainActor } → store.insert(pendingRecord)
  │    └─ Return UUID immediately (non-blocking)
  │
  ├─ Tag forwarded request: handled=true, recordID=uuid
  │    (URLProtocol.setProperty — survives NSURLRequest copy)
  │
  ├─ forwardingSession.dataTask(taggedRequest).resume()
  │    └─ forwardingSession has protocolClasses=[]
  │       so canInit() never fires for this inner request
  │
  └─ delegateProxy.register(self, for: task)

              [Network round-trip happens here]

delegateProxy callbacks:
  didReceive response  → forwardResponse()  → client?.urlProtocol(didReceive:)
  didReceive data      → forwardData()      → client?.urlProtocol(didLoad:)
  didComplete          → forwardCompletion()
  │                       ├─ client?.urlProtocolDidFinishLoading / didFailWithError
  │                       └─ Task { @MainActor } → InspectKit.finishRecord()
  │
  didFinishCollecting  → Task { @MainActor } → InspectKit.attachMetrics()
```

Anti-recursion: every outgoing request is tagged with `URLProtocol.setProperty`. `canInit` checks this tag first and returns `false` if present.

### InspectKitStore

`@MainActor ObservableObject`. Ring buffer of `maxStoredRequests` (default 500) records with O(1) lookup via `indexByID: [UUID: Int]`.

```
insert(record)                       mutate(id:_:)
  │                                    │
  ├─ apply pendingMutations[id]         ├─ id found: mutate in-place (O(1))
  ├─ records.insert(at: 0)             │
  ├─ rebuildIndex()                    └─ id NOT found: store in pendingMutations[id]
  ├─ trimIfNeeded()                       applied on next insert(id)
  └─ schedulePersist()
```

`pendingMutations` prevents silent data loss when a cached response delivers completion before the insert Task runs.

---

## InspectKitMock — Network Mocker

### Request Lifecycle

```
InspectKitMockURLProtocol.canInit(request)
  │
  ├─ isActive == false → return false (fall through)
  ├─ request already handled → return false
  └─ RuleMatcher.shared.firstMatch(for: request) != nil → return true
       └─ (thread-safe NSLock snapshot — no actor hop required)

startLoading()
  │
  ├─ rule = RuleMatcher.shared.firstMatch(for: request)
  │
  ├─ DispatchQueue.global.asyncAfter(deadline: .now() + rule.delay)
  │
  └─ deliver(rule:)
       │
       ├─ .ok(status, headers, body)
       │    ├─ resolve body (text/json/data/bundleFile)
       │    ├─ client?.urlProtocol(didReceive: HTTPURLResponse)
       │    ├─ client?.urlProtocol(didLoad: data)
       │    ├─ client?.urlProtocolDidFinishLoading()
       │    ├─ Task { @MainActor } → store.recordHit(hit)
       │    └─ MockHooks.onHit?(mockedRecord)   [if Inspector is running]
       │
       └─ .failure(domain, code, userInfo)
            ├─ client?.urlProtocol(didFailWithError: NSError)
            ├─ Task { @MainActor } → store.recordHit(hit)
            └─ MockHooks.onHit?(mockedRecord)
```

### RuleMatcher — Thread-Safety Bridge

URLProtocol's `canInit` and `startLoading` run on arbitrary threads. `MockStore` is `@MainActor`. Direct calls would require a hop and `await`, which URLProtocol's synchronous API cannot accommodate.

`RuleMatcher` is a `NSLock`-protected `@unchecked Sendable` singleton. `MockStore` pushes a snapshot on every mutation; URLProtocol reads from this snapshot without any actor hop.

```swift
final class RuleMatcher: @unchecked Sendable {
    static let shared = RuleMatcher()
    private let lock = NSLock()
    private var _rules: [MockRule] = []
    private var _scenarioRuleIDs: [UUID]? = nil
    var logToInspectKit: Bool = true

    func update(rules: [MockRule], scenarioRuleIDs: [UUID]?, logToInspectKit: Bool)
    func firstMatch(for request: URLRequest) -> MockRule?
}
```

When a scenario is active, only rules whose IDs appear in `scenarioRuleIDs` are considered, in scenario order. With no active scenario, all enabled rules are evaluated in creation order.

### MockStore

`@MainActor ObservableObject`. Source of truth for rules, scenarios, and the rolling 100-entry hit log. Every mutation saves to `UserDefaults` (JSON-encoded) and pushes a new snapshot to `RuleMatcher.shared`.

**Array mutation pattern:** All methods that modify individual elements use explicit full reassignment rather than subscript mutation (`rules[i] = x`). Subscript mutation goes through Swift's `_modify` accessor, which does not reliably fire `objectWillChange` on all Swift 5.5 targets. The safe form is:

```swift
var updated = rules
updated[idx] = newRule
rules = updated          // setter always fires objectWillChange
```

**Initialisation:** `pushToMatcher()` is not called from `init()` to prevent a static singleton re-entrancy trap — `MockStore` is created inside `InspectKitMock.shared`'s own init, so `shared` is not yet accessible. The initial push is deferred to `InspectKitMock.start()` via `store.initialPush(logToInspectKit:)`.

---

## Thread Safety Model

| Component | Actor / Queue |
|---|---|
| `InspectKit` | `@MainActor` |
| `InspectKitStore` | `@MainActor` |
| `InspectKitMock` | `@MainActor` |
| `MockStore` | `@MainActor` |
| `InspectKitURLProtocol` callbacks | URL loading system background thread |
| `InspectKitMockURLProtocol` callbacks | URL loading system background thread |
| `InspectKitSessionDelegateProxy` callbacks | URLSession delegate queue (background) |
| `InspectKitURLProtocol.isActive` | `NSLock`-protected static |
| `InspectKitMockURLProtocol.isActive` | `NSLock`-protected static |
| `CoreAutoCapture` class registry | `NSLock`-protected |
| `RuleMatcher` rule snapshot | `NSLock`-protected (`@unchecked Sendable`) |
| Background → MainActor mutations | `Task { @MainActor in }` |
| Mock response delivery delay | `DispatchQueue.global(qos: .userInitiated).asyncAfter` |

---

## UI Architecture

### InspectKit Dashboard

```
InspectKitWindowOverlay (PassthroughWindow — hitTest returns nil for transparent areas)
  └── InspectKitOverlay (52pt draggable Circle, live badge count)
        └── .sheet → InspectKitDashboardView
                        └── InspectKitRequestListView
                              └── InspectKitRequestDetailView
                                    ├── OverviewTab
                                    ├── RequestTab
                                    ├── ResponseTab
                                    ├── HeadersTab
                                    ├── TimelineView (URLSessionTaskMetrics phases)
                                    └── CurlPreviewView
```

Records with `isMocked == true` render a cyan **MOCKED** capsule badge in `InspectKitRequestListView`.

### InspectKitMock Dashboard

#### Presentation

**SwiftUI** — attach `.inspectKitMock()` to the root view; the modifier listens for a `NotificationCenter` trigger so `presentDashboard()` works from anywhere:

```swift
ContentView().inspectKitMock()
InspectKitMock.shared.presentDashboard()   // e.g. shake gesture
```

**UIKit** — call `presentDashboard(from:)` from any `UIViewController`; it wraps `MockDashboardView` in a `UIHostingController` and presents it full-screen:

```swift
InspectKitMock.shared.presentDashboard(from: self)
```

#### View Hierarchy

```
MockDashboardView
  ├─ Summary bar (total rules, enabled, hits, active scenario)
  ├─ MockRuleListView (enable toggle, method badge, hit count, delay indicator)
  │    └─ pencil button → MockRuleEditorView (via EditSession sheet)
  ├─ MockRuleEditorView (create / edit)
  │    ├─ Identity  — name, enabled toggle
  │    ├─ Match     — host / path (any|equals|contains|prefix|suffix|regex),
  │    │              method, body-contains
  │    ├─ Response  — OK (status stepper, headers, body: none/json/text)
  │    │              or Failure (domain, code)
  │    └─ Delay     — 0–10s slider
  ├─ ScenarioPickerView (create named groups, activate with one tap)
  └─ MockHitsLogView (rolling 100, reverse-chronological)
```

#### EditSession — Sheet Identity

SwiftUI's `sheet(item:)` uses the item's `Identifiable.id` to track identity. When a rule is edited and the sheet is re-opened for the same rule (same UUID), SwiftUI can reuse the existing view, leaving `@State` variables stale from the previous session.

`MockRuleListView` wraps each edit in a private `EditSession` struct whose `id` is a freshly generated `UUID` on every open:

```swift
private struct EditSession: Identifiable {
    let id = UUID()   // unique per presentation — forces fresh @State
    let rule: MockRule
}
```

`sheet(item: $editSession)` sees a new identity on every open and always creates a fresh `MockRuleEditorView` with correctly initialised `@State`.

All InspectKitMock UI files are wrapped in `#if canImport(UIKit)` for macOS SPM build compatibility. Multi-line body input uses a `UIViewRepresentable` wrapping `UITextView` (`TextEditor` is iOS 14+).

---

## Setup Sequence — Combined Mode

```
App launch
  │
  ├─ InspectKit.shared.configure(InspectKitConfiguration(environmentName: "dev"))
  │
  ├─ InspectKit.shared.start()
  │    ├─ InspectKitURLProtocol.isActive = true
  │    ├─ URLProtocol.registerClass(InspectKitURLProtocol.self)
  │    ├─ CoreAutoCapture.register(InspectKitURLProtocol.self, priority: 100)
  │    │    └─ installs shared URLSessionConfiguration swizzle on first call
  │    └─ MockHooks.onHit = { record in store.insert(record) }
  │
  ├─ InspectKitMock.shared.start()
  │    ├─ InspectKitMockURLProtocol.isActive = true
  │    ├─ URLProtocol.registerClass(InspectKitMockURLProtocol.self)
  │    ├─ CoreAutoCapture.register(InspectKitMockURLProtocol.self, priority: 200)
  │    └─ store.initialPush(logToInspectKit: true)
  │         └─ RuleMatcher.shared.update(...)
  │
  ├─ InspectKit.shared.installWindowOverlay(in: windowScene)
  │    └─ Creates PassthroughWindow → hosts InspectKitOverlay
  │
  └─ ContentView().inspectKitMock()
       └─ Attaches MockDashboardView sheet to SwiftUI root view
```

From this point:
- A request matching a mock rule → synthesised response → `MockHooks.onHit` → Inspector shows it with **MOCKED** pill.
- An unmatched request → Mock's `canInit` returns `false` → Inspector captures and forwards it normally.
- `URLSessionConfiguration.protocolClasses` getter (swizzled once by `CoreAutoCapture`) always returns `[MockURLProtocol(200), InspectKitURLProtocol(100), …original…]`.

---

## Redaction

Applied at display and export time, never at capture time (raw data is always stored). `InspectKitRedactor` walks header dictionaries and JSON bodies, replacing values whose keys match the configured set (case-insensitive) with `██ REDACTED ██`.

Default redacted header keys: `Authorization`, `Cookie`, `Set-Cookie`, `X-API-Key`, `X-Auth-Token`.  
Default redacted body keys: `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`.

---

## Export

Two formats available from `InspectKit`:

- **cURL** — reconstructs a `curl` command from the captured request; redaction applied before generation.
- **JSON session** — `JSONEncoder` (ISO 8601 dates, Base64 body data) written to the Caches directory and presented via `UIActivityViewController`.

---

## Known Limitations

- `URLSessionWebSocketTask` — not intercepted by either protocol.
- Background sessions (`URLSessionConfiguration.background(_:)`) — tasks not captured.
- SSL pinning in the app's own `URLSessionDelegate` — unaffected by InspectKit; uses system trust chain.
- `InspectKitMock` — does not mock WebSocket, SSE, or background sessions.
