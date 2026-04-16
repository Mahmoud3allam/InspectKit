# Integrating InspectKit with Custom Network Managers (Alamofire, etc.)

## The Challenge

Custom network managers like Alamofire's `SessionManager` typically create their `URLSession` with an explicitly set `protocolClasses` array. This shadows the global `URLProtocol.registerClass()` registration, so InspectKit isn't automatically included.

## Solutions

### Option 1: Inject into the Configuration (Recommended)

Modify your network layer to inject InspectKit's URLProtocol into the configuration **before** creating the session:

```swift
import Alamofire
import InspectKit

class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: Session
    
    private init() {
        var config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        // ... any other config ...
        
        // Install InspectKit last
        config.installInspectKit()
        
        // Create session with the modified config
        self.session = Session(configuration: config)
    }
}
```

### Option 2: Use InspectKit's Configuration Builder

```swift
import Alamofire
import InspectKit

class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: Session
    
    private init() {
        // Create a base config with your settings
        let baseConfig = URLSessionConfiguration.default
        baseConfig.timeoutIntervalForRequest = 30
        
        // Let InspectKit wrap it
        let monitoredConfig = InspectKit.shared.makeMonitoredConfiguration(base: baseConfig)
        
        self.session = Session(configuration: monitoredConfig)
    }
}
```

### Option 3: Manual Injection (for modules that can't import InspectKit)

If your network module **cannot import InspectKit**, inject the protocol class from the app target:

**App Target (imports both InspectKit and your network module):**

```swift
import YourNetworkModule
import InspectKit

func setupNetworking() {
    InspectKit.shared.start()
    
    // Pass InspectKit's protocol class to your network manager
    YourNetworkModule.setupNetworkInterception([InspectKit.urlProtocolClass])
}
```

**Network Module:**

```swift
public class SessionManager {
    static let shared = SessionManager()
    
    private var debugProtocolClasses: [AnyClass] = []
    private let session: URLSession
    
    private init() {
        self.session = SessionManager.makeSession()
    }
    
    static func setupNetworkInterception(_ classes: [AnyClass]) {
        shared.debugProtocolClasses = classes
    }
    
    private static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        
        var classes = config.protocolClasses ?? []
        // Insert debug classes first so they don't interfere with other logic
        classes.insert(contentsOf: shared.debugProtocolClasses, at: 0)
        config.protocolClasses = classes
        
        return URLSession(configuration: config)
    }
}
```

## Best Practices

1. **Call `InspectKit.shared.start()` as early as possible** — before any network sessions are created
2. **Inject InspectKit into the config before session creation** — don't try to modify existing sessions
3. **For modules without InspectKit access** — accept protocol classes as an array parameter
4. **Test that requests appear in the dashboard** — verify the integration works in your app

## Common Issues

| Issue | Solution |
|---|---|
| Requests don't appear | Make sure `InspectKit.shared.start()` was called BEFORE the session was created |
| "Module not found" errors | Ensure InspectKit is imported in files that use it |
| Crashes on config modification | Don't try to modify `protocolClasses` after session creation — must be before |
| Other URLProtocols are ignored | Place InspectKit LAST in the protocol classes array, not first |

## Why Not Automatic?

Automatically intercepting all URLSession instances without any code changes would require swizzling Foundation internals, which is:
- **Fragile** — implementation details change between iOS versions
- **Unreliable** — Objective-C runtime behavior varies
- **Hard to debug** — silent failures if swizzling fails
- **Against Apple's guidelines** — method swizzling can break in future OS releases

The manual injection approach is explicit, reliable, and gives you full control.
