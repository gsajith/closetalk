import AppKit
import ClosetalkCore
import SwiftUI

/// What the island shows.
@MainActor
@Observable
final class IslandModel {
    enum Phase { case recording, transcribing }

    var phase = Phase.recording
    var levels = WaveformLevels()
    /// The live preview's latest words, nil until the first ones come in.
    var transcript: String?
    /// Drives the appear and disappear animation of the pill inside the panel.
    var isVisible = false
}

/// The small pill near the top of the screen while Closetalk listens: live bars while recording, a
/// pulsing dots while transcribing. Once the live preview has words, it widens to show them under the bars.
/// It must never take focus, because dictation pastes into whatever app is in front, so it's a
/// non-activating panel that ignores the mouse.
@MainActor
final class RecordingIsland {
    /// Room for the island at its largest. The panel is clear where the island doesn't draw.
    private static let size = NSSize(width: IslandLayout.wideWidth, height: IslandLayout.wideHeight)
    /// Gap between the menu bar (or notch) and the pill.
    private static let topGap: CGFloat = 8

    let model = IslandModel()
    private let panel: NSPanel
    private var hideWork: DispatchWorkItem?

    init() {
        panel = NSPanel(contentRect: NSRect(origin: .zero, size: Self.size),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false // The pill draws its own.
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = NSHostingView(rootView: IslandView(model: model))
    }

    func showRecording() {
        model.phase = .recording
        model.levels = WaveformLevels()
        model.transcript = nil
        show()
    }

    /// Keeps the preview's words up until the text lands.
    func showTranscribing() {
        model.phase = .transcribing
        show()
    }

    func hide() {
        guard model.isVisible else { return }
        model.isVisible = false
        // Let the pill animate out before the panel goes. The words go with it, so the next recording
        // fades in as the pill instead of shrinking from the wide panel.
        let work = DispatchWorkItem { [panel, model] in
            panel.orderOut(nil)
            model.transcript = nil
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func show() {
        hideWork?.cancel()
        if !model.isVisible {
            let screen = Self.screenBeingTypedOn() ?? NSScreen.main ?? NSScreen.screens[0]
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - Self.size.width / 2,
                                         y: screen.visibleFrame.maxY - Self.size.height - Self.topGap))
        }
        // Ordered in without activating Closetalk, so focus stays in the app being dictated into.
        panel.orderFrontRegardless()
        model.isVisible = true
    }

    /// The screen holding the front app's frontmost window, which is where the text will land. Window
    /// bounds from the window list don't need Screen Recording, unlike window titles.
    private static func screenBeingTypedOn() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]],
              let window = windows.first(where: {
                  ($0[kCGWindowOwnerPID as String] as? pid_t) == pid && ($0[kCGWindowLayer as String] as? Int) == 0
              }),
              let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
              let bounds = CGRect(dictionaryRepresentation: boundsDict),
              let primary = NSScreen.screens.first
        else { return screenWithMouse() }
        // The window list measures from the top of the primary screen, AppKit from its bottom.
        let flipped = CGRect(x: bounds.minX, y: primary.frame.maxY - bounds.maxY, width: bounds.width, height: bounds.height)
        let best = NSScreen.screens.max { $0.frame.intersection(flipped).area < $1.frame.intersection(flipped).area }
        if let best, best.frame.intersects(flipped) { return best }
        return screenWithMouse()
    }

    private static func screenWithMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) }
    }
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

private enum IslandLayout {
    static let pillWidth: CGFloat = 120
    static let pillHeight: CGFloat = 36
    static let wideWidth: CGFloat = 320
    static let textInset: CGFloat = 16
    static let fontSize: CGFloat = 13
    /// Two lines of preview text.
    static let textHeight = 2 * NSLayoutManager().defaultLineHeight(for: .systemFont(ofSize: fontSize))
    static let textBottomInset: CGFloat = 12
    static let wideHeight = pillHeight + textHeight + textBottomInset
}

private struct IslandView: View {
    let model: IslandModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let wide = model.transcript != nil
        // At pill height, a rounded rectangle with this radius is the pill, so widening is only a size change.
        let shape = RoundedRectangle(cornerRadius: IslandLayout.pillHeight / 2, style: .continuous)
        VStack(spacing: 0) {
            Group {
                switch model.phase {
                case .recording: Bars(levels: model.levels.values)
                case .transcribing: ThinkingDots(animated: !reduceMotion)
                }
            }
            .frame(height: IslandLayout.pillHeight)
            if let transcript = model.transcript {
                TranscriptLines(text: transcript)
                    .padding(.horizontal, IslandLayout.textInset)
                    .transition(.opacity)
            }
        }
        .frame(width: wide ? IslandLayout.wideWidth : IslandLayout.pillWidth,
               height: wide ? IslandLayout.wideHeight : IslandLayout.pillHeight, alignment: .top)
        .background {
            shape.fill(.black.opacity(0.85))
            shape.strokeBorder(.white.opacity(0.12))
        }
        .clipShape(shape)
        .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: wide)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
        .opacity(model.isVisible ? 1 : 0)
        .scaleEffect(model.isVisible || reduceMotion ? 1 : 0.8, anchor: .top)
        .animation(.snappy(duration: 0.2), value: model.isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
    }
}

/// Two lines of the live preview. Text that fits sits at the top; longer text keeps its newest words
/// on the bottom line and lets the older ones run off the top, fading out.
private struct TranscriptLines: View {
    let text: String

    var body: some View {
        ViewThatFits(in: .vertical) {
            lines.frame(maxHeight: .infinity, alignment: .topLeading)
            // A fixed height, unlike maxHeight, stays smaller than the text, so the clip has work to do.
            lines
                .frame(height: IslandLayout.textHeight, alignment: .bottomLeading)
                .clipped()
                .mask {
                    LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.4)],
                                   startPoint: .top, endPoint: .bottom)
                }
        }
        .frame(height: IslandLayout.textHeight)
    }

    private var lines: some View {
        Text(text)
            .font(.system(size: IslandLayout.fontSize))
            .foregroundStyle(.white.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Three dots pulsing in turn while the words are worked out. A system spinner draws dark grey on the
/// black pill, whatever the tint.
private struct ThinkingDots: View {
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(.white)
                        .frame(width: 6, height: 6)
                        .opacity(animated ? 0.35 + 0.65 * (sin(t * 6 - Double(i)) * 0.5 + 0.5) : 0.8)
                }
            }
        }
    }
}

/// One bar per recent chunk of audio, newest on the right.
private struct Bars: View {
    let levels: [Double]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(levels.indices, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: 3, height: 3 + levels[i] * 17)
            }
        }
        .animation(.linear(duration: 0.08), value: levels)
    }
}
