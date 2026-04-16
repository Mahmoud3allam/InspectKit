# InspectKit — Technical Architecture Overview

## What It Is

InspectKit is a zero-dependency, in-process network debugging tool for iOS apps. It intercepts HTTP/HTTPS traffic at the URL loading system layer, stores captured request/response records in memory, and surfaces them through a floating SwiftUI overlay — all without modifying any application networking code beyond the initial setup.

Minimum deployment target: **iOS 13**.

---

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│                      Your App                           │
│   Alamofire Session / URLSession / custom network layer │
└───────────────────────┬─────────────────────────────────┘
                        │  URLRequest
                        ▼
┌─────────────────────────────────────────────────────────┐
│              URL Loading System (Foundation)            │
│                                                         │
│  protocolClasses = [InspectKitURLProtocol, ...]   │
│                        │                               │
│            canInit() → startLoading()                  │
└───────────────────────┬─────────────────────────────────┘
                        │
          ┌─────────────▼──────────────┐
          │  InspectKitURLProtocol│  ← Interception layer
          │  (URLProtocol subclass)     │
          └──────┬──────────┬──────────┘
                 │          │
    Mark request │          │ Forward unmarked copy
    (handled=true│          │ to private forwardingSession
    recordID=uuid)│         │ (protocolClasses = [] — no re-entry)
                 │          ▼
                 │  ┌──────────────────────────────┐
                 │  │ InspectKitSessionDelegate│
                 │  │ Proxy (URLSessionDataDelegate) │
                 │  │                               │
                 │  │ didReceive response ──────────┼──► forwardResponse()
                 │  │ didReceive data ──────────────┼──► forwardData()
                 │  │ didCompleteWithError ─────────┼──► forwardCompletion()
                 │  │ didFinishCollecting metrics ──┼──► metricsHandler()
                 │  └──────────────────────────────┘
                 │
                 │ (MainActor Task)
                 ▼
┌─────────────────────────────────────────────────────────┐
│                  InspectKit (singleton)           │
│  @MainActor                                             │
│                                                         │
│  store.insert(record)       ← beginInspection()         │
│  flushBuffered(for: id)     ← drain any buffered data   │
│  store.mutate(finishRecord) ← response/error applied    │
│  store.mutate(attachMetrics)← timing phases applied     │
└───────────────────────┬─────────────────────────────────┘
                        │ @Published var records changes
                        ▼
┌─────────────────────────────────────────────────────────┐
│                InspectKitStore                    │
│  @MainActor  ObservableObject                           │
│                                                         │
│  records: [NetworkRequestRecord]   ← ring buffer (500)  │
│  indexByID: [UUID: Int]            ← O(1) lookup        │
│  pendingMutations buffer           ← race-condition safe│
└───────────────────────┬─────────────────────────────────┘
                        │ Combine @Published triggers SwiftUI
                        ▼
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                           │
│                                                         │
│  InspectKitWindowOverlay (PassthroughWindow)      │
│    └── InspectKitOverlay (floating bubble)        │
│          └── sheet → InspectKitDashboardView      │
│                        └── NetworkRequestListView       │
│                              └── NetworkRequestDetailView│
│                                    ├── OverviewTab      │
│                                    ├── RequestTab       │
│                                    ├── ResponseTab      │
│                                    ├── HeadersTab       │
│                                    ├── TimelineView     │
│                                    └── CurlPreviewView  │
└─────────────────────────────────────────────────────────┘
```

---

## Core Components

### 1. Interception — `InspectKitURLProtocol`

The entry point for all captured traffic. Subclasses `URLProtocol`, which lets it sit in the URL loading pipeline and handle any HTTP/HTTPS request before it hits the network.

**Registration — two paths:**

| Path | How | When to use |
|---|---|---|
| Global | `URLProtocol.registerClass(...)` called in `start()` | `URLSession.shared` and sessions whose config does not explicitly set `protocolClasses` |
| Per-session | `config.installInspectKit()` inserts the class at index 0 of `protocolClasses` | Alamofire `Session`, or any custom `URLSession` with its own config |

The `isActive` static flag (protected by `NSLock`) is checked in `canInit()` first. If `stop()` has been called, the protocol refuses every request immediately — even if it is still present in a session's `protocolClasses`.

**Request lifecycle inside the protocol:**

```
startLoading()
  │
  ├─ beginInspection(request)
  │    ├─ Generate UUID (recordID)
  │    ├─ Schedule Task { @MainActor } → store.insert(record)
  │    └─ Return UUID immediately (non-blocking)
  │
  ├─ Mark forwarded request: handled=true, recordID=uuid
  │    (URLProtocol.setProperty — survives NSURLRequest copy)
  │
  ├─ forwardingSession.dataTask(markedRequest).resume()
  │    └─ forwardingSession has protocolClasses=[]
  │       so canInit() will never fire for this inner request
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
  didFinishCollecting  → metricsHandler
                          └─ Task { @MainActor } → InspectKit.attachMetrics()
```

**Anti-recursion:** every outgoing request is tagged with `URLProtocol.setProperty(true, forKey: "com.networkinspector.handled")`. `canInit()` checks this tag first and returns `false` if present, ensuring the inner forwarding session never re-enters the protocol.

---

### 2. State Management — `InspectKitStore`

`@MainActor` `ObservableObject`. The single source of truth for all captured records.

```
insert(record)                        mutate(id:_:)
  │                                     │
  ├─ apply pendingMutations[id]         ├─ if id found: mutate in-place
  ├─ records.insert(at: 0)             │  (records[idx] = updated)
  ├─ rebuildIndex()                     │
  ├─ trimIfNeeded() — cap at 500        └─ if id NOT found:
  └─ schedulePersist()                     store in pendingMutations[id]
                                           applied on next insert(id)
```

**Why `pendingMutations`:** `finishRecord` and `attachMetrics` arrive via MainActor Tasks created on background threads. Although Task ordering on a serial actor is FIFO, a response served from cache can deliver its delegate callbacks before the insert Task has been enqueued. The buffer ensures the completion data is never silently dropped.

**Index:** `indexByID: [UUID: Int]` maps each record's UUID to its position in `records`. All `mutate` calls are O(1). The index is rebuilt entirely on every insert or trim — acceptable given the 500-record cap.

**Filtering:** `filtered(query:stateFilter:methodFilter:)` is a pure function over `records`. It is recomputed by SwiftUI on every store publish, so no separate filtered-list state is needed.

---

### 3. Data Model — `NetworkRequestRecord`

A value type (`struct`) that is `Codable`, `Sendable`, and `Hashable`. It carries the full lifecycle of one HTTP transaction:

```
NetworkRequestRecord
 ├─ id: UUID                  — correlates URLProtocol ↔ store ↔ UI
 ├─ sequence: Int             — monotonic counter for display order
 ├─ state: NetworkRequestState — inProgress | completed | failed | cancelled
 ├─ url / host / path / queryItems
 ├─ method: HTTPMethod
 ├─ requestHeaders / requestBody: CapturedBody
 ├─ statusCode
 ├─ responseHeaders / responseBody: CapturedBody
 ├─ error: CapturedError?
 ├─ startDate / endDate → durationMS (computed)
 └─ metrics: CapturedMetrics?  — DNS/TLS/connect/response phase timings
```

`CapturedBody` holds the raw `Data`, a text preview, byte count, content type, and a truncation flag. Body capture is gated by `captureRequestBodies` / `captureResponseBodies` flags in configuration and capped at `maxCapturedBodyBytes` (default 1 MB).

---

### 4. Redaction — `InspectKitRedactor`

Applied at display and export time, never at capture time (raw data is always stored). Walks header dictionaries and JSON bodies, replaces values whose keys match the redacted-key sets (case-insensitive) with `██ REDACTED ██`.

Default redacted header keys: `Authorization`, `Cookie`, `Set-Cookie`, `X-API-Key`, `X-Auth-Token`.  
Default redacted body keys: `token`, `access_token`, `refresh_token`, `password`, `secret`, `api_key`.

---

### 5. Configuration — `InspectKitConfiguration`

A plain `struct` (`Sendable`) passed to `InspectKit.configure(_:)` before `start()`. Key fields:

| Field | Default | Purpose |
|---|---|---|
| `isEnabled` | `true` | Master kill-switch |
| `allowedHosts` | `[]` (all) | Whitelist — if non-empty, only matching hosts are captured |
| `ignoredHosts` | `[]` | Blacklist — matching hosts are always skipped |
| `captureRequestBodies` | `true` | Store request body bytes |
| `captureResponseBodies` | `true` | Store response body bytes |
| `captureMetrics` | `true` | Store `URLSessionTaskMetrics` timing phases |
| `maxCapturedBodyBytes` | 1 MB | Truncation limit per body |
| `maxStoredRequests` | 500 | Ring buffer size |
| `persistToDisk` | `false` | JSON snapshot to Caches directory |

`shouldCapture(host:)` is evaluated on the MainActor inside `beginInspection` before the record is inserted. If it returns `false`, no record is created, but the request is still forwarded transparently.

---

### 6. UI Layer

**Window overlay:**  
`InspectKitWindowOverlay` creates a `PassthroughWindow` — a `UIWindow` subclass that overrides `hitTest(_:with:)` to return `nil` for touches on transparent areas. This allows the floating bubble to sit above the entire app without stealing touches from the app's own UI.

**Floating bubble (`InspectKitOverlay`):**  
A 52 pt draggable `Circle` rendered inside the passthrough window. Observes `store.activeCount` and `store.failureCount` to show a live indicator badge. Tapping presents the dashboard as a `.sheet`.

**Dashboard (`InspectKitDashboardView`):**  
`@ObservedObject var store`. Drives summary cards, search, segmented filter, and method-chip filter entirely from computed properties over `store.records` — no local copy. Re-renders automatically on every `@Published` change.

**Detail (`NetworkRequestDetailView`):**  
Custom tab bar (scrollable `HStack` of `Button`s) drives `@State var selectedTab`. Each tab is a separate `View` struct, rendered with `@ViewBuilder` switch. Tabs share a reference to the same `store` so live-updating requests (still in `.inProgress`) continue to update while the detail screen is open.

---

### 7. Export — `InspectKitExporter`

Two export formats:

- **cURL:** reconstructs a `curl` shell command from the captured request headers and body. Sensitive values are redacted before generation.
- **JSON session file:** encodes the full `[NetworkRequestRecord]` array with `JSONEncoder` (ISO 8601 dates, Base64 body data) and writes it to the Caches directory. Presented via `UIActivityViewController`.

---

### 8. Thread Safety Model

| Component | Actor / Queue |
|---|---|
| `InspectKit` | `@MainActor` |
| `InspectKitStore` | `@MainActor` |
| `InspectKitURLProtocol` (startLoading, stopLoading) | URL loading system background thread |
| `InspectKitSessionDelegateProxy` callbacks | Delegate queue (background) |
| `InspectKitURLProtocol.isActive` flag | `NSLock`-protected static |
| `delegateProxy.protocolsByTask` dictionary | `NSLock`-protected |
| All store/inspector mutations from background threads | Dispatched via `Task { @MainActor in }` |

The `forwardingSession` delegate queue is `nil` (system-managed). The `delegateProxy` uses an `NSLock` to protect its `[Int: InspectKitURLProtocol]` task registry, which is written from `startLoading` (URL loading thread) and read/written from delegate callbacks (delegate queue).

---

### 9. Alamofire / Custom Session Integration

`URLProtocol.registerClass` (called by `start()`) affects `URLSession.shared` and sessions whose configuration does not explicitly set `protocolClasses`. For Alamofire sessions or any session with a custom `URLSessionConfiguration`, the protocol class must be injected explicitly:

```swift
// In the network layer module (no import of InspectKit needed)
public var debugProtocolClasses: [AnyClass] = []

private lazy var session: Session = {
    let config = URLSessionConfiguration.default
    var classes = config.protocolClasses ?? []
    classes.insert(contentsOf: debugProtocolClasses, at: 0)
    config.protocolClasses = classes
    return Session(configuration: config, interceptor: MyInterceptor())
}()

// In the app target (imports both modules)
#if DEBUG
InspectKit.shared.start()
NetworkClient.shared.debugProtocolClasses = [InspectKit.urlProtocolClass]
#endif
```

The inspector sits **below** Alamofire's interceptor layer. Interceptors (auth adapters, retry logic, token refresh) run first and produce the final `URLRequest`. The inspector sees and records that final request, leaving Alamofire's behavior completely unaffected.

---

### 10. Setup Sequence

```
App launch
  │
  ├─ InspectKit.shared.configure(.init(environmentName: "dev"))
  │    └─ Creates new Store, Redactor, Exporter instances
  │
  ├─ InspectKit.shared.start()
  │    ├─ Sets InspectKitURLProtocol.isActive = true
  │    └─ URLProtocol.registerClass(InspectKitURLProtocol.self)
  │
  ├─ SessionManager.shared.debugProtocolClasses = [InspectKit.urlProtocolClass]
  │    └─ Stored; applied when the lazy Session is first accessed
  │
  ├─ InspectKit.shared.installWindowOverlay(in: window / scene)
  │    └─ Creates PassthroughWindow → hosts InspectKitOverlay
  │
  └─ App is ready. All HTTP/HTTPS requests through the monitored session
       are now captured, stored, and visible in the floating overlay.
```
