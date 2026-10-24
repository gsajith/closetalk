import ClosetalkCore
import SwiftUI

/// The first-launch window: a checklist sidebar, and one step at a time on the right.
struct SetupView: View {
    @Bindable var model: SetupModel
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The saved dictation shortcut as the menu names it, like "fn" or "⌃⌥Space".
    private var shortcut: String { DictationShortcutSettings.shortcut?.name ?? "your dictation key" }

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
        case .shortcut: shortcutStep
        case .model: speechModel
        case .tryIt: tryIt
        }
    }

    private var microphone: some View {
        StepPane(title: "Let Closetalk hear you",
                 text: "It only listens while you're dictating. Nothing leaves your Mac.") {
            PermissionButton(model.microphoneDenied ? "Open System Settings" : "Allow Microphone",
                             doneTitle: "Microphone is on", state: permissionState(.microphone),
                             action: model.allowMicrophone)
            if model.microphoneDenied && !model.progress.microphoneAllowed && !model.waiting.contains(.microphone) {
                Note("Turn on Closetalk in the Microphone list.")
            }
        }
    }

    private var accessibility: some View {
        StepPane(title: "Let Closetalk listen to your keypresses",
                 text: "So it knows when to turn the mic on. Turn on Closetalk in the Accessibility list.") {
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

    private var shortcutStep: some View {
        StepPane(title: "Choose a key to hold while you talk",
                 text: "Pick one you don't type with, like fn or right ⌘.") {
            HStack(spacing: 10) {
                KeyField(text: keyFieldText, isListening: model.recordingShortcut)
                if model.recordingShortcut {
                    Button("Cancel", action: model.cancelRecordingShortcut)
                } else if model.progress.shortcutChosen {
                    Button("Change", action: model.recordShortcut)
                } else {
                    Button("Choose Key", action: model.recordShortcut).buttonStyle(.borderedProminent)
                }
            }
            if model.recordingShortcut && model.shortcutRefused {
                Text("Add ⌃, ⌥ or ⌘ so that key still types.").font(.callout).foregroundStyle(.red)
            } else if !model.recordingShortcut && model.showsDone(.shortcut) {
                Done("Hold \(shortcut) to talk.")
            }
        }
    }

    /// While listening, the field empties so the old key is visibly gone; Cancel brings it back.
    private var keyFieldText: String {
        if model.recordingShortcut { return model.heldKeys.isEmpty ? "Press a key…" : model.heldKeys }
        return DictationShortcutSettings.shortcut?.name ?? "None"
    }

    @ViewBuilder private var speechModel: some View {
        switch model.progress.model {
        case .downloading(let fraction):
            StepPane(title: "Downloading the speech model",
                     text: "A one-time download, about 1.5 GB.") {
                ProgressView(value: fraction)
                Note("\(Int(fraction * 100))% done")
                Note("You can close this window. It keeps going.")
            }
        case .compiling(let startedAt, true):
            StepPane(title: "Getting the speech model ready",
                     text: "This happens once and takes about 10 minutes.") {
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
                Note("You can close this window. It keeps going.")
            }
        case .compiling(_, false):
            StepPane(title: "Loading the speech model", text: "This takes a few seconds.") {
                ProgressView().controlSize(.small)
            }
        case .failed(let message):
            StepPane(title: "The speech model didn't load", text: message) {
                Note("Closetalk tries again every 30 seconds. If it keeps failing, check your internet.")
            }
        case .ready:
            StepPane(title: "The speech model is ready", text: "It runs on your Mac, so it works offline.") {
                if model.showsDone(.model) { Done("Ready.") }
            }
        }
    }

    private var tryIt: some View {
        VStack(alignment: .leading, spacing: 12) {
            (Text("Hold ") + Text(shortcut).bold() + Text(" and talk"))
                .font(.title2.weight(.semibold))
            Text("Say anything, then let go. It works the same in any app.")
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
        if state == .done {
            // Drawn rather than a tinted button: macOS greys out prominent buttons in a window that
            // isn't active, and the window often isn't when it comes back from System Settings.
            Label(doneTitle, systemImage: "checkmark")
                .symbolEffect(.bounce, value: state)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.green, in: .rect(cornerRadius: 6))
                .transition(.scale(scale: 0.85).combined(with: .opacity))
        } else {
            Button(state == .waiting ? "Waiting…" : title, action: action)
                .buttonStyle(.borderedProminent)
                .disabled(state == .waiting)
        }
    }
}

/// The dictation key, shown like a key cap. The event tap does the listening, so this only shows
/// what it hears.
private struct KeyField: View {
    let text: String
    let isListening: Bool

    var body: some View {
        Text(text)
            .font(.title3.weight(.semibold))
            .foregroundStyle(isListening ? .secondary : .primary)
            .frame(minWidth: 160, minHeight: 32)
            .padding(.horizontal, 10)
            .background(.background, in: .rect(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6)
                .strokeBorder(isListening ? Color.accentColor : .secondary.opacity(0.4), lineWidth: isListening ? 2 : 1))
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
        case .shortcut: "Dictation key"
        case .model: "Speech model"
        case .tryIt: "Try it"
        }
    }
}
