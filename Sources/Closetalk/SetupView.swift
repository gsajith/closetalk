import ClosetalkCore
import SwiftUI

/// The first-launch window: a checklist sidebar, and one step at a time on the right.
struct SetupView: View {
    @Bindable var model: SetupModel
    let close: () -> Void

    /// The dictation shortcut as the menu names it: "right ⌘" by default.
    private var shortcut: String { DictationShortcutSettings.shortcut.name }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                pane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                Button { model.selected = step } label: {
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
        if model.progress.isDone(step) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                .background(Circle().fill(.white).padding(2))
        } else if step == .model, case .failed = model.progress.model {
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        } else if step == .model {
            ProgressView().controlSize(.mini)
        } else {
            Image(systemName: "circle").foregroundStyle(model.selected == step ? Color.white : .secondary)
        }
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
            if model.progress.microphoneAllowed {
                Done("Microphone is on.")
            } else if model.microphoneDenied {
                Button("Open System Settings", action: model.allowMicrophone).buttonStyle(.borderedProminent)
                Note("You turned this off earlier. Switch on Closetalk in the Microphone list.")
            } else {
                Button("Allow Microphone", action: model.allowMicrophone).buttonStyle(.borderedProminent)
            }
        }
    }

    private var accessibility: some View {
        StepPane(title: "Let Closetalk use \(shortcut)",
                 text: "macOS calls this Accessibility. Closetalk uses it to notice when you hold \(shortcut), and to paste what you said. Turn on Closetalk in the list.") {
            if model.progress.accessibilityAllowed {
                Done("Accessibility is on.")
            } else {
                Button("Open System Settings", action: model.openAccessibilitySettings).buttonStyle(.borderedProminent)
            }
        }
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
                Done("Ready.")
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
    var body: some View { Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
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
