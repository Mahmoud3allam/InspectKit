# InspectKit — Integration Guide

A rich, in-app network inspector for iOS. Works with **SwiftUI**, **UIKit (AppDelegate)**, **UIKit (SceneDelegate)**, and mixed UIKit+SwiftUI apps.

Captures request/response traffic and `URLSessionTaskMetrics` from any networking stack built on `URLSession` — raw `URLSession`, Alamofire, Moya, custom clients.

> **Debug / lower environments only.** Do not ship to production builds.

---

## UIKit — AppDelegate

```swift
// AppDelegate.swift
import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        #if DEBUG
        InspectKit.shared.configure(
            InspectKitConfiguration(
                environmentName: "dev",
                maxStoredRequests: 500
            )
        )
        InspectKit.shared.start()

        // Floating draggable bubble — appears above all content.
        if let window {
            InspectKit.shared.installWindowOverlay(in: window)
        }
        #endif

        return true
    }
}
```

The floating bubble is passthrough — touches outside the bubble reach your normal UI. Tap the bubble to open the inspector dashboard as a full-screen modal.

---

## UIKit — SceneDelegate

```swift
// SceneDelegate.swift
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        #if DEBUG
        InspectKit.shared.configure(
            InspectKitConfiguration(environmentName: "staging")
        )
        InspectKit.shared.start()

        // Scene-based window overlay.
        InspectKit.shared.installWindowOverlay(in: windowScene)
        #endif
    }
}
```

---

## UIKit — Present from any UIViewController

If you prefer a debug menu over the floating bubble, disable the overlay in config and trigger the inspector manually.

```swift
// Any UIViewController
override func viewDidLoad() {
    super.viewDidLoad()
    let button = UIButton(type: .system)
    button.setTitle("Network Inspector", for: .normal)
    button.addTarget(self, action: #selector(openInspector), for: .touchUpInside)
    view.addSubview(button)
}

@objc func openInspector() {
    presentInspectKit()              // modal full-screen
}
```

Push onto an existing navigation stack:

```swift
navigationController?.pushInspectKit()
```

Create the view controller yourself for custom embedding:

```swift
let vc = UIViewController.networkInspectorViewController {
    // Called when inspector is dismissed
}
present(vc, animated: true)
```

---

## SwiftUI

```swift
// App entry point
@main
struct DemoApp: App {
    init() {
        #if DEBUG
        InspectKit.shared.configure(
            InspectKitConfiguration(environmentName: "dev")
        )
        InspectKit.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .networkInspectorOverlay()   // floating bubble
        }
    }
}
```

Or trigger the dashboard as a sheet:

```swift
struct DebugMenu: View {
    @State private var showInspector = false

    var body: some View {
        Button("Open Network Inspector") { showInspector = true }
            .networkInspectorSheet(isPresented: $showInspector)
    }
}
```

---

## Mixed UIKit + SwiftUI

The window overlay works regardless of whether your app uses `UIHostingController` for some screens. Install the overlay at the UIKit layer (AppDelegate/SceneDelegate) and it floats above everything.

```swift
// AppDelegate — installs bubble above all UIKit and SwiftUI content
if let window {
    InspectKit.shared.installWindowOverlay(in: window)
}
```

SwiftUI screens wrapped in `UIHostingController` don't need any additional setup.

---

## Monitored URLSession

Any session with a monitored configuration is captured.

```swift
// Minimal
let session = URLSession(configuration: .networkInspectorDefault())

// From an existing config
let config = URLSessionConfiguration.default
config.httpAdditionalHeaders = ["X-Client": "MyApp"]
config.installInspectKit()
let session = URLSession(configuration: config)
```

### Alamofire

```swift
import Alamofire

let config = URLSessionConfiguration.af.default
config.installInspectKit()
let af = Session(configuration: config)
```

### Moya

```swift
import Moya

let config = URLSessionConfiguration.default
config.installInspectKit()
let provider = MoyaProvider<API>(session: Session(configuration: config))
```

---

## Programmatic API

```swift
InspectKit.shared.clear()

// cURL for a single request
let curl = InspectKit.shared.curl(for: record)

// Export all captures to JSON Data
let data = try InspectKit.shared.exportSessionJSON()

// Write session export to disk and get the file URL (e.g. for UIActivityViewController)
let fileURL = try InspectKit.shared.exportSessionFile()

// Disable at runtime
InspectKit.shared.stop()
InspectKit.shared.removeWindowOverlay()
```

---

## Configuration reference

| Field | Default | Purpose |
|---|---|---|
| `isEnabled` | `true` | Master toggle — `false` is a complete no-op. |
| `environmentName` | `nil` | Badge label in UI and JSON exports. |
| `allowedHosts` | `[]` | If non-empty, only matching hosts are captured. |
| `ignoredHosts` | `[]` | Always overrides `allowedHosts`. |
| `maxStoredRequests` | `500` | Ring-buffer cap; oldest entries dropped first. |
| `maxCapturedBodyBytes` | `1 MB` | Per-request body cap; overflow is truncated. |
| `captureRequestBodies` | `true` | Set `false` to skip heavy upload bodies. |
| `captureResponseBodies` | `true` | Set `false` to skip heavy download bodies. |
| `captureMetrics` | `true` | Controls `URLSessionTaskMetrics` collection. |
| `persistToDisk` | `false` | Lightweight JSON snapshot to Caches directory. |
| `showsFloatingOverlay` | `true` | Hide the draggable bubble (useful if presenting manually). |
| `allowsExport` | `true` | Disables share/export buttons in UI. |
| `redactedHeaderKeys` | (see below) | Additional header keys to redact. |
| `redactedBodyKeys` | (see below) | Additional JSON/query body keys to redact. |
| `redactionPlaceholder` | `██ REDACTED ██` | Custom placeholder string. |

**Default redacted headers:** `Authorization`, `Cookie`, `Set-Cookie`, `x-api-key`, `api-key`, `proxy-authorization`, `x-auth-token`

**Default redacted body keys:** `token`, `access_token`, `refresh_token`, `password`, `secret`, `client_secret`, `api_key`, `apikey`

---

## Coverage

**Captured**
- Raw `URLSession` using a monitored configuration
- Alamofire `Session(configuration:)` with monitored configuration
- Moya / custom API clients built on `URLSession`
- Any third-party SDK that accepts a `URLSessionConfiguration`

**Not captured without extra work**
- `WKWebView` traffic
- `Network.framework` sockets
- gRPC / custom transports not using `URLSession`
- Third-party SDKs that create private `URLSession`s you don't control
- Background sessions unless specifically wired

---

## Extracting to a Swift Package

1. `swift package init --type library --name InspectKit`
2. Copy the `InspectKit/` directory into `Sources/InspectKit/`.
3. Set `.iOS(.v15)` as the minimum platform.
4. All public API is already `public` — no renaming required.
5. Add a test target covering `InspectKitRedactor`, `InspectKitExporter`, and `InspectKitStore`.
