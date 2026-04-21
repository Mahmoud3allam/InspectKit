import Foundation

// InspectKitRedactor is defined in InspectKitCore.
// This extension adds the convenience initialiser that accepts InspectKitConfiguration,
// which lives only in the InspectKit target.
extension InspectKitRedactor {
    public init(config: InspectKitConfiguration) {
        self.init(
            redactedHeaderKeys: config.redactedHeaderKeys,
            redactedBodyKeys: config.redactedBodyKeys,
            placeholder: config.redactionPlaceholder
        )
    }
}
