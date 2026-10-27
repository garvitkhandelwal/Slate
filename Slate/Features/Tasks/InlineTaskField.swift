import SwiftUI

/// The focused add/edit field. It replaces `+ add` or task text in place with no border, fill, or modal wrapper.
struct InlineTaskField: View {
    @Binding var text: String
    let target: CaptureTarget
    let accessibilityIdentifier: String
    let onSubmit: () -> Void
    let onDismiss: () -> Void
    var focus: FocusState<CaptureTarget?>.Binding

    var body: some View {
        TextField(AccessibilityLabels.newTask, text: $text, prompt: Text(""))
            .font(SlateTypography.body)
            .foregroundStyle(SlateColors.ink)
            .textFieldStyle(.plain)
            #if os(iOS)
            .textInputAutocapitalization(.sentences)
            #endif
            .submitLabel(.done)
            .focused(focus, equals: target)
            .frame(maxWidth: .infinity, minHeight: SlateSpacing.minimumTarget, alignment: .leading)
            .accessibilityIdentifier(accessibilityIdentifier)
            .onSubmit(onSubmit)
            .onKeyPress(.escape) {
                onDismiss()
                return .handled
            }
    }
}
