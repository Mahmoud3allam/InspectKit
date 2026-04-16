# Claude Code Prompt — Build Rich iOS Network Inspector

You are a senior iOS platform engineer.

Build a **rich in-app network monitoring / network inspector module** in **Swift** for an iOS app.  
This will initially live as app source files, but it must be designed so it can later be extracted into a reusable library / Swift Package.

Read and follow the requirements from `NETWORK_INSPECTOR_SPEC.md`.

## Primary Goal

Create a production-quality **debug/lower-environment network inspector** for iOS that captures and displays API traffic in real time inside the app.

This is **NOT** for production end users. It is for:
- developers
- QA
- internal testing
- lower environments

## Tech Constraints

- Language: Swift
- UI: Prefer **SwiftUI** for inspector screens, but UIKit bridging is acceptable where needed
- Networking interception: use `URLProtocol`
- Metrics collection: use `URLSessionTaskMetrics`
- Concurrency: modern Swift concurrency where appropriate, otherwise thread-safe primitives
- iOS target: keep code compatible with modern iOS versions typically used in active apps
- No third-party dependencies unless absolutely necessary
- Architecture must be modular and library-ready

## Deliverables

Generate actual source files, not pseudocode.

### Expected output structure

Create a folder structure like:

- `InspectKit/`
  - `Core/`
    - `InspectKit.swift`
    - `InspectKitConfiguration.swift`
    - `InspectKitStore.swift`
    - `InspectKitModels.swift`
    - `InspectKitRedactor.swift`
    - `InspectKitExporter.swift`
  - `Interception/`
    - `InspectKitURLProtocol.swift`
    - `InspectKitSessionDelegateProxy.swift`
    - `InspectKitRequestMarker.swift`
  - `UI/`
    - `InspectKitOverlay.swift`
    - `InspectKitDashboardView.swift`
    - `NetworkRequestListView.swift`
    - `NetworkRequestDetailView.swift`
    - `JSONViewer.swift`
    - `HeadersView.swift`
    - `TimelineView.swift`
    - `CurlPreviewView.swift`
  - `Utilities/`
    - `PrettyPrint.swift`
    - `ByteCountFormatter+Extensions.swift`
    - `DateFormatter+Extensions.swift`
  - `Integration/`
    - `URLSessionConfiguration+InspectKit.swift`
    - `View+InspectKit.swift`
  - `Demo/`
    - `InspectKitDemoAppIntegration.md`

If you think the structure should be improved, do so — but keep it clean and extractable.

## Functional Requirements

Implement all of the following:

### 1. Request/response capture
Capture:
- request id
- URL
- path
- query params
- HTTP method
- headers
- request body
- response status code
- response headers
- response body
- response error
- start time
- end time
- total duration
- body sizes
- whether request is still in progress

### 2. Metrics capture
Use `URLSessionTaskMetrics` to capture when available:
- redirect timings
- DNS lookup
- TCP connect
- TLS handshake
- request start/end
- response start/end
- total duration
- network protocol if available
- local/remote address info if available
- reused connection if available

### 3. Real-time dashboard UI
Create a rich in-app UI that includes:
- floating debug button or draggable overlay trigger
- live-updating request list
- status indicators
- search
- filtering by:
  - method
  - status code range
  - success/failure
  - endpoint text
- sorting by newest first
- clear logs button

### 4. Rich detail screen
Each request detail screen must show:
- overview summary
- request tab
- response tab
- headers tab
- metrics/timeline tab
- pretty JSON viewer when JSON is detected
- raw text fallback
- binary/file fallback metadata
- cURL preview/export text
- copy buttons

### 5. Redaction
Implement safe redaction by default for:
- Authorization
- Cookie
- Set-Cookie
- x-api-key
- api-key
- token
- access_token
- refresh_token
- password
- secret

Support custom redaction rules in config.

### 6. Performance / safety controls
Support config options for:
- enabled/disabled
- environment name
- only capture matching hosts
- ignored hosts
- max retained request count
- max body size to store
- whether to capture request bodies
- whether to capture response bodies
- whether to capture metrics
- whether to persist to disk
- whether to show overlay UI
- whether to allow export/share

### 7. Storage
Implement:
- in-memory ring-buffer style retention
- optional lightweight disk persistence
- thread-safe updates
- observable state for UI

### 8. Exporting
Support export as:
- cURL per request
- JSON session export of captured logs

### 9. Library-ready design
Design all APIs so later this can become:
- an internal framework
- or Swift Package

Avoid app-specific assumptions.

## Integration Requirements

Provide simple integration examples:

### A. Setup
A minimal setup such as:
- configure inspector on app launch
- enable in debug or lower environment only

### B. URLSession integration
Provide helpers so a developer can do something like:
- create a monitored `URLSessionConfiguration`
- attach protocol classes
- use monitored sessions easily

### C. SwiftUI integration
Provide a way to mount the overlay into root view.

## Important Implementation Rules

- Prevent infinite interception loops
- Mark already-inspected requests
- Avoid storing huge payloads
- Handle missing/invalid body data gracefully
- Pretty-print JSON safely
- Use clean separation of concerns
- Include comments where useful, but do not over-comment
- Avoid placeholder TODOs unless truly unavoidable
- Code should compile with minimal adjustments

## UI/UX Expectations

Make the inspector feel polished:
- compact but rich
- readable
- useful for QA and developers
- visually organized
- strong empty/loading states
- badges for method/status
- clear error rendering
- expandable sections for large payloads
- timeline presentation for metrics

## What to output

1. First, summarize the architecture briefly.
2. Then generate all source files with full contents.
3. Then provide a short integration guide.
4. Then provide a “next steps to extract as library” section.

Do not return vague advice.  
Do not return only partial snippets.  
Generate the full implementation files.