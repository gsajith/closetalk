import ClosetalkCore
import SwiftUI

/// The first-launch window: a checklist sidebar, and one step at a time on the right.
struct SetupView: View {
    @Bindable var model: SetupModel
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The dictation shortcut as the menu names it: "right ⌘" by default.
    private var shortcut: String { DictationShortcutSettings.shortcut.name }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                pane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .id(model.selected)
                    .transition(paneTransition)
                    .clipped()
                footer
            }
            .padding(24)
        }
        .frame(width: 640, height: 420)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SetupStep.allCases, id: \.self) { step in
                Button { model.go(to: step) } label: {
                    HStack(spacing: 8) {
                        status(step).frame(width: 16, height: 16)
                        Text(step.title)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundStyle(model.selected == step ? Color.white : .primary)
                    .background(model.selected == step ? Color.accentColor : .clear, in: .rect(cornerRadius: 6))
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!model.progress.isAvailable(step))
                .opacity(model.progress.isAvailable(step) ? 1 : 0.5)
            }
            Spacer()
        }
        .padding(10)
        .frame(width: 180)
        .background(.background.secondary)
    }

    @ViewBuilder private func status(_ step: SetupStep) -> some View {
        let done = model.showsDone(step)
        if !done, step == .model, case .failed = model.progress.model {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        } else if !done, step == .model {
            ProgressView().controlSize(.mini)
        } else {
            // One image for both states, so the circle morphs into the check and bounces.
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? Color.green : model.selected == step ? Color.white : .secondary)
                .background { if done { Circle().fill(.white).padding(2) } }
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: done)
        }
    }

    /// Forward slides in from the right, back from the left. Reduce Motion cross-fades instead.
    private var paneTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let forward = model.movingForward
        return .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity))
    }

    // MARK: Steps

    @ViewBuilder private var pane: some View {
        switch model.selected {
        case .microphone: microphone
        case .accessibility: accessibility
        case .model: speechModel
        case .tryIt: tryIt
        }
    }

    private var microphone: some View {
        StepPane(title: "Let Closetalk hear you",
                 text: "Closetalk listens only while you hold \(shortcut). Audio stays on this Mac and is never saved.") {
            PermissionButton(model.microphoneDenied ? "Open System Settings" : "Allow Microphone",
                             doneTitle: "Microphone is on", state: permissionState(.microphone),
                             action: model.allowMicrophone)
            if model.microphoneDenied && !model.progress.microphoneAllowed && !model.waiting.contains(.microphone) {
                Note("You turned this off earlier. Switch on Closetalk in the Microphone list.")
            }
        }
    }

    private var accessibility: some View {
        StepPane(title: "Let Closetalk use \(shortcut)",
                 text: "macOS calls this Accessibility. Closetalk uses it to notice when you hold \(shortcut), and to paste what you said. Turn on Closetalk in the list.") {
            PermissionButton("Open System Settings", doneTitle: "Accessibility is on",
                             state: permissionState(.accessibility), action: model.openAccessibilitySettings)
        }
    }

    /// Granted but not checked off yet still reads Waiting…, so the green check lands with the sidebar's.
    private func permissionState(_ step: SetupStep) -> PermissionButton.State {
        if model.showsDone(step) { return .done }
        if model.waiting.contains(step) || model.progress.isDone(step) { return .waiting }
        return .ready
    }

    @ViewBuilder private var speechModel: some View {
        switch model.progress.model {
        case .downloading(let fraction):
            StepPane(title: "Downloading the speech model",
                     text: "Closetalk runs Whisper on your Mac, so it downloads the model once: about 1.5 GB.") {
                ProgressView(value: fraction)
                Note("\(Int(fraction * 100))% downloaded")
                Note("You can close this window. Closetalk keeps going in the menu bar.")
            }
        case .compiling(let startedAt, true):
            StepPane(title: "Getting the speech model ready",
                     text: "Downloaded. Now your Mac is compiling it for the Neural Engine. This happens once, and takes about 10 minutes.") {
                // Core ML reports no progress here, so the bar follows elapsed time.
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let elapsed = context.date.timeIntervalSince(startedAt)
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: CompileEstimate.fraction(elapsed: elapsed))
                        HStack {
                            Note(CompileEstimate.elapsedText(elapsed))
                            Spacer()
                            Note(CompileEstimate.remainingText(elapsed: elapsed))
                        }
                    }
                }
                Note("You can close this window. Closetalk keeps going in the menu bar.")
            }
        case .compiling(_, false):
            StepPane(title: "Loading the speech model", text: "This takes a few seconds.") {
                ProgressView().controlSize(.small)
            }
        case .failed(let message):
            StepPane(title: "The speech model didn't load", text: message) {
                Note("Closetalk tries again every 30 seconds. Check your internet connection if it keeps failing.")
            }
        case .ready:
            StepPane(title: "The speech model is ready", text: "It runs on this Mac, and it's yours to keep.") {
                if model.showsDone(.model) { Done("Ready.") }
            }
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("Hold ") + Text(shortcut).bold() + Text(" and talk"))
                .font(.title2.weight(.semibold))
            Text("Say anything, then let go. Your words land here, the same way they will in any app.")
                .foregroundStyle(.secondary)
            PracticeField(text: $model.practiceText)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            if model.selected != .microphone {
                Button("Back", action: model.goBack)
            }
            Spacer()
            if model.selected == .tryIt {
                Button("Done", action: close).buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            } else {
                Button("Continue", action: model.goToNext)
                    .disabled(model.progress.nextUnfinished(after: model.selected) == nil)
            }
        }
    }
}

/// Header art, title, explanation, then the step's controls.
private struct StepPane<Content: View>: View {
    let title: String
    let text: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let mic = NSImage(named: "SetupMic") {
                Image(nsImage: mic).resizable().scaledToFit().frame(height: 80)
            }
            Text(title).font(.title2.weight(.semibold))
            Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            content
        }
    }
}

private struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View { Text(text).font(.callout).foregroundStyle(.secondary) }
}

private struct Done: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            .transition(.scale(scale: 0.6, anchor: .leading).combined(with: .opacity))
    }
}

/// A permission step's button: blue to ask, grey "Waiting…" while the person is in the system prompt
/// or System Settings, then green with a check once the permission is on.
private struct PermissionButton: View {
    enum State { case ready, waiting, done }

    let title: String
    let doneTitle: String
    let state: State
    let action: () -> Void

    init(_ title: String, doneTitle: String, state: State, action: @escaping () -> Void) {
        self.title = title
        self.doneTitle = doneTitle
        self.state = state
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            switch state {
            case .ready: Text(title)
            case .waiting: Text("Waiting…")
            case .done: Label(doneTitle, systemImage: "checkmark").symbolEffect(.bounce, value: state)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(state == .done ? .green : nil)
        .disabled(state == .waiting)
        // Done stays green rather than greyed out, but there's nothing left to click.
        .allowsHitTesting(state == .ready)
    }
}

/// Focused on appear, so a dictation pastes straight into it.
private struct PracticeField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .focused($focused)
            .frame(height: 54) // about three lines
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(.background, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(focused ? Color.accentColor : .secondary.opacity(0.4)))
            .onAppear { focused = true }
    }
}

extension SetupStep {
    var title: String {
        switch self {
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        case .model: "Speech model"
        case .tryIt: "Try it"
        }
    }
}
