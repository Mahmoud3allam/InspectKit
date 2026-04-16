import SwiftUI
import UIKit

struct MethodBadge: View {
    let method: HTTPMethod
    var body: some View {
        Text(method.rawValue)
            .font(NIFont.badge)
            .foregroundColor(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(NIColor.method(method))
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

struct StatusBadge: View {
    let code: Int?
    let inProgress: Bool
    let failed: Bool

    var body: some View {
        HStack(spacing: 4) {
            if inProgress {
                // ProgressView is iOS 14+; NIActivityIndicator wraps UIActivityIndicatorView
                NIActivityIndicator()
                    .frame(width: 10, height: 10)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
            }
            Text(label)
                .font(NIFont.badge)
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }

    private var color: Color {
        if inProgress { return NIColor.pending }
        if failed { return NIColor.failure }
        return NIColor.statusColor(code)
    }

    private var label: String {
        if inProgress { return "…" }
        if let code { return "\(code)" }
        if failed { return "ERR" }
        return "—"
    }
}

struct EnvBadge: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(NIFont.badge)
            .foregroundColor(NIColor.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(NIColor.accent.opacity(0.6), lineWidth: 1)
            )
    }
}

struct CopyButton: View {
    let text: String
    var compact: Bool = false

    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            withAnimation(.easeInOut(duration: 0.15)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                withAnimation { copied = false }
            }
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
                .foregroundColor(copied ? NIColor.success : NIColor.textMuted)
                .padding(compact ? 4 : 6)
        }
        .buttonStyle(.plain)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(NIColor.textMuted)
            Text(value)
                .font(NIFont.title3Semibold)
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(NIColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
