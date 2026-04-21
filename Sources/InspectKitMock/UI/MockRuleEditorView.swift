#if canImport(UIKit)
import SwiftUI
import InspectKitCore

struct MockRuleEditorView: View {
    @ObservedObject var store: MockStore
    var onDismiss: (() -> Void)?

    // Editing an existing rule or creating new
    private let existingID: UUID?

    @State private var name: String
    @State private var isEnabled: Bool

    // Matcher fields
    @State private var matchHostMode: MatchMode = .any
    @State private var matchHostValue: String = ""
    @State private var matchPathMode: MatchMode = .any
    @State private var matchPathValue: String = ""
    @State private var matchMethod: String = "Any"
    @State private var bodyContains: String = ""

    // Response fields
    @State private var responseKind: ResponseKind = .ok
    @State private var statusCode: Int = 200
    @State private var responseHeadersRaw: String = ""
    @State private var bodyType: BodyType = .none
    @State private var bodyText: String = ""
    @State private var errorDomain: String = NSURLErrorDomain
    @State private var errorCode: Int = NSURLErrorTimedOut
    @State private var delay: Double = 0

    @State private var jsonError: String? = nil

    init(store: MockStore, rule: MockRule?, onDismiss: (() -> Void)?) {
        self.store = store
        self.onDismiss = onDismiss
        self.existingID = rule?.id

        let r = rule
        _name       = State(initialValue: r?.name ?? "New Rule")
        _isEnabled  = State(initialValue: r?.isEnabled ?? true)
        _delay      = State(initialValue: r?.delay ?? 0)

        if let matcher = r?.matcher {
            if let h = matcher.host {
                switch h {
                case .equals(let s):   _matchHostMode = State(initialValue: .equals);   _matchHostValue = State(initialValue: s)
                case .contains(let s): _matchHostMode = State(initialValue: .contains);  _matchHostValue = State(initialValue: s)
                case .prefix(let s):   _matchHostMode = State(initialValue: .prefix);    _matchHostValue = State(initialValue: s)
                case .suffix(let s):   _matchHostMode = State(initialValue: .suffix);    _matchHostValue = State(initialValue: s)
                case .regex(let s):    _matchHostMode = State(initialValue: .regex);     _matchHostValue = State(initialValue: s)
                }
            }
            if let p = matcher.path {
                switch p {
                case .equals(let s):   _matchPathMode = State(initialValue: .equals);   _matchPathValue = State(initialValue: s)
                case .contains(let s): _matchPathMode = State(initialValue: .contains);  _matchPathValue = State(initialValue: s)
                case .prefix(let s):   _matchPathMode = State(initialValue: .prefix);    _matchPathValue = State(initialValue: s)
                case .suffix(let s):   _matchPathMode = State(initialValue: .suffix);    _matchPathValue = State(initialValue: s)
                case .regex(let s):    _matchPathMode = State(initialValue: .regex);     _matchPathValue = State(initialValue: s)
                }
            }
            _matchMethod  = State(initialValue: matcher.method?.rawValue ?? "Any")
            _bodyContains = State(initialValue: matcher.bodyContains ?? "")
        }

        if let resp = r?.response {
            switch resp.kind {
            case let .ok(code, headers, body):
                _responseKind = State(initialValue: .ok)
                _statusCode   = State(initialValue: code)
                _responseHeadersRaw = State(initialValue: headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
                switch body {
                case .none:            _bodyType = State(initialValue: .none)
                case .text(let s):     _bodyType = State(initialValue: .text);  _bodyText = State(initialValue: s)
                case .json(let s):     _bodyType = State(initialValue: .json);  _bodyText = State(initialValue: s)
                case .data:            _bodyType = State(initialValue: .none)
                case .bundleFile:      _bodyType = State(initialValue: .none)
                }
            case let .failure(domain, code, _):
                _responseKind = State(initialValue: .failure)
                _errorDomain  = State(initialValue: domain)
                _errorCode    = State(initialValue: code)
            }
        }
    }

    var body: some View {
        NavigationView {
            Form {
                identitySection
                matchSection
                responseSection
                delaySection
                if let existingID {
                    Section {
                        Button(action: {
                            store.remove(id: existingID)
                            onDismiss?()
                        }) {
                            Text("Delete Rule").foregroundColor(NIColor.failure)
                        }
                    }
                }
            }
            .navigationBarTitle(existingID == nil ? "New Rule" : "Edit Rule", displayMode: .inline)
            .navigationBarItems(
                leading: Button("Cancel") { onDismiss?() },
                trailing: Button("Save") { save() }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Sections

    private var identitySection: some View {
        Section(header: Text("Identity")) {
            TextField("Rule name", text: $name)
            Toggle("Enabled", isOn: $isEnabled)
        }
    }

    private var matchSection: some View {
        Section(header: Text("Match")) {
            matchRow(label: "Host", mode: $matchHostMode, value: $matchHostValue)
            matchRow(label: "Path", mode: $matchPathMode, value: $matchPathValue)
            Picker("Method", selection: $matchMethod) {
                Text("Any").tag("Any")
                ForEach(["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"], id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            TextField("Body contains", text: $bodyContains)
        }
    }

    private var responseSection: some View {
        Section(header: Text("Response")) {
            Picker("Kind", selection: $responseKind) {
                Text("Success (OK)").tag(ResponseKind.ok)
                Text("Failure (Error)").tag(ResponseKind.failure)
            }
            .pickerStyle(.segmented)

            if responseKind == .ok {
                Stepper("Status: \(statusCode)", value: $statusCode, in: 100...599)
                TextField("Headers (Key: Value, one per line)", text: $responseHeadersRaw)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Picker("Body", selection: $bodyType) {
                    Text("None").tag(BodyType.none)
                    Text("JSON").tag(BodyType.json)
                    Text("Text").tag(BodyType.text)
                }
                if bodyType != .none {
                    if bodyType == .json {
                        TextEditorCompat(text: $bodyText, placeholder: "{ \"key\": \"value\" }",
                                         onTextChange: { validateJSON() })
                            .frame(minHeight: 100)
                        if let err = jsonError {
                            Text(err).font(.caption).foregroundColor(NIColor.failure)
                        }
                    } else {
                        TextEditorCompat(text: $bodyText, placeholder: "Response text…")
                            .frame(minHeight: 80)
                    }
                }
            } else {
                TextField("Error domain", text: $errorDomain)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                Stepper("Code: \(errorCode)", value: $errorCode, in: -9999...9999)
            }
        }
    }

    private var delaySection: some View {
        Section(header: Text("Delay: \(String(format: "%.1f", delay))s")) {
            Slider(value: $delay, in: 0...10, step: 0.1)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func matchRow(label: String, mode: Binding<MatchMode>, value: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Picker(label, selection: mode) {
                ForEach(MatchMode.allCases, id: \.self) { m in
                    Text(m.title).tag(m)
                }
            }
            if mode.wrappedValue != .any {
                TextField("Value", text: value)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }
        }
    }

    private func validateJSON() {
        guard bodyType == .json else { jsonError = nil; return }
        guard !bodyText.isEmpty else { jsonError = nil; return }
        if JSONSerialization.isValidJSONObject([bodyText]) {
            jsonError = nil
            return
        }
        if let data = bodyText.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil {
            jsonError = nil
        } else {
            jsonError = "Invalid JSON"
        }
    }

    private func save() {
        var matcher = RequestMatcher()
        if matchHostMode != .any, !matchHostValue.isEmpty {
            matcher.host = matchHostMode.stringMatch(matchHostValue)
        }
        if matchPathMode != .any, !matchPathValue.isEmpty {
            matcher.path = matchPathMode.stringMatch(matchPathValue)
        }
        matcher.method = matchMethod == "Any" ? nil : HTTPMethod(rawValue: matchMethod)
        if !bodyContains.isEmpty { matcher.bodyContains = bodyContains }

        let responseBody: MockResponse.Body
        switch bodyType {
        case .none: responseBody = .none
        case .json: responseBody = .json(bodyText)
        case .text: responseBody = .text(bodyText)
        }

        let headers = parseHeaders(responseHeadersRaw)

        let responseKindValue: MockResponse.Kind
        if responseKind == .ok {
            responseKindValue = .ok(statusCode: statusCode, headers: headers, body: responseBody)
        } else {
            responseKindValue = .failure(domain: errorDomain, code: errorCode, userInfo: [:])
        }

        var rule = MockRule(
            id: existingID ?? UUID(),
            name: name.isEmpty ? "Untitled" : name,
            isEnabled: isEnabled,
            matcher: matcher,
            response: MockResponse(kind: responseKindValue),
            delay: delay
        )
        if let existing = existingID,
           let old = store.rules.first(where: { $0.id == existing }) {
            rule.hitCount = old.hitCount
            rule.lastHitAt = old.lastHitAt
        }
        if existingID != nil { store.update(rule) } else { store.add(rule) }
        onDismiss?()
    }

    private func parseHeaders(_ raw: String) -> [String: String] {
        var dict: [String: String] = [:]
        for line in raw.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            dict[parts[0].trimmingCharacters(in: .whitespaces)] =
                parts[1].trimmingCharacters(in: .whitespaces)
        }
        return dict
    }
}

// MARK: - Local enums

private enum MatchMode: String, CaseIterable {
    case any, equals, contains, prefix, suffix, regex
    var title: String {
        switch self {
        case .any:      return "Any"
        case .equals:   return "Equals"
        case .contains: return "Contains"
        case .prefix:   return "Starts with"
        case .suffix:   return "Ends with"
        case .regex:    return "Regex"
        }
    }
    func stringMatch(_ value: String) -> RequestMatcher.StringMatch {
        switch self {
        case .any:      return .contains("")
        case .equals:   return .equals(value)
        case .contains: return .contains(value)
        case .prefix:   return .prefix(value)
        case .suffix:   return .suffix(value)
        case .regex:    return .regex(value)
        }
    }
}

private enum ResponseKind: Equatable { case ok, failure }
private enum BodyType: Equatable { case none, json, text }

// MARK: - iOS 13-compatible multiline text input (UITextView wrapper)

private struct TextEditorCompat: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    var onTextChange: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.autocorrectionType = .no
        tv.autocapitalizationType = .none
        tv.textColor = .white
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if tv.text != text { tv.text = text }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: TextEditorCompat
        init(_ parent: TextEditorCompat) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.onTextChange?()
        }
    }
}

#endif // canImport(UIKit)
