# InspectKit

A zero-dependency, in-process network debugging tool for iOS apps. InspectKit intercepts HTTP/HTTPS traffic, stores request/response records, and surfaces them through a floating SwiftUI overlay — all without modifying your application's networking code.

## Features

- 🔍 **Real-time traffic inspection** — See all network requests as they happen
- 🎨 **SwiftUI overlay** — Floating bubble UI that doesn't interfere with your app
- 🔐 **Zero dependencies** — No external frameworks required
- 📋 **Detailed request/response data** — Headers, body, timing information, and more
- 🎯 **Easy integration** — One-line setup, works with URLSession, Alamofire, and custom networking
- 📤 **Export capabilities** — Share requests as cURL commands or JSON
- 🕐 **Metrics collection** — Detailed timing phases for performance analysis

## Minimum Requirements

- iOS 13.0+
- Swift 5.5+

## Installation

### Swift Package Manager

Add InspectKit to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/InspectKit.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Packages
2. Paste: `https://github.com/yourusername/InspectKit.git`
3. Select version and target

## Quick Start

### Basic Setup

```swift
import InspectKit

// In your AppDelegate or @main app struct:
func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
    // Configure InspectKit
    let config = InspectKitConfiguration(
        environmentName: "development",
        allowsExport: true
    )
    InspectKit.shared.configure(config)
    InspectKit.shared.start()
    
    return true
}
```

### With URLSession

```swift
// For shared session (global registration)
InspectKit.shared.start()

// For custom URLSession
let config = URLSessionConfiguration.default
config.installInspectKit()
let session = URLSession(configuration: config)
```

### With SwiftUI

The overlay automatically appears once started. Control visibility:

```swift
// Show/hide overlay
InspectKit.shared.toggleOverlay()

// Access dashboard directly
InspectKit.shared.showDashboard()
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed technical documentation.

## Publishing to SPM Registry

To make InspectKit available for other developers:

### 1. Create a GitHub Repository

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/yourusername/InspectKit.git
git branch -M main
git push -u origin main
```

### 2. Create a Release

```bash
git tag -a v1.0.0 -m "Initial release"
git push origin v1.0.0
```

### 3. Verify Package Resolution

Xcode automatically discovers packages from GitHub. Test in a new project:

```swift
// In Package.swift or Xcode "Add Packages"
.package(url: "https://github.com/yourusername/InspectKit.git", from: "1.0.0")
```

### 4. (Optional) Submit to Apple's Package Index

Visit [swiftpackageindex.com](https://swiftpackageindex.com) and submit your package URL for better discoverability.

## Usage Examples

### Capturing Requests

InspectKit automatically intercepts all requests made via URLSession once `start()` is called.

```swift
// Get current records
let records = InspectKit.shared.store.records

// Filter and analyze
let failedRequests = records.filter { $0.statusCode >= 400 }
```

### Exporting Data

```swift
// Export all requests as JSON
let jsonExport = InspectKit.shared.exporter.exportAsJSON(
    records: InspectKit.shared.store.records
)

// Export as cURL for debugging
let curlCommand = InspectKit.shared.exporter.exportAsCurl(record: request)
```

### Configuration Options

```swift
let config = InspectKitConfiguration(
    environmentName: "dev",           // Display name
    allowsExport: true,               // Enable export buttons
    redactHeaders: ["Authorization"], // Headers to hide
    maxRecords: 500                   // Ring buffer size
)
InspectKit.shared.configure(config)
```

## Limitations

- **Non-production** — InspectKit is designed for development/QA only. Do not ship with it enabled in production.
- **Memory** — Stores up to 500 records by default in a ring buffer
- **Not all network libraries** — Works best with URLSession-based networking (Alamofire compatible)

## License

MIT

## Contributing

Contributions are welcome! Please open issues and submit pull requests.
