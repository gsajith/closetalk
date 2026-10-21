# LocalWhisper implementation plan

> Historical. Written before the rename to Offscript, under the working name LocalWhisper. The code has moved on since (for example, the recorder now uses AVCaptureSession). The README describes the app as it is.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menu bar Mac app that records while right Command is held and pastes a local Whisper transcript at the cursor on release.

**Architecture:** One SwiftPM package. `LocalWhisperCore` holds pure logic with unit tests: transcript cleanup, the hotkey state machine, spacing. The `LocalWhisper` executable holds the macOS glue: event tap, audio capture, WhisperKit, paste, menu bar. A shell script wraps the binary into a signed `.app` bundle.

**Tech stack:** Swift 6.3 toolchain (Swift 5 language mode to avoid strict-concurrency churn in AppKit glue), WhisperKit 1.1.1, AVAudioEngine, CGEventTap, NSStatusItem, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-21-localwhisper-design.md`

## Global constraints

- macOS 14+ deployment target, arm64 only.
- Model: WhisperKit variant `large-v3-v20240930_turbo`, downloaded to `~/Library/Application Support/LocalWhisper/models`. English, no language detection.
- No network use except the first-run model download.
- Bundle id `dev.gsajith.LocalWhisper`, `LSUIElement` true, `NSMicrophoneUsageDescription` set.
- Signing identity name `LocalWhisper Dev`, self-signed, login keychain.
- Only permission needed besides Microphone is Accessibility (use an active event tap, not listen-only, so Input Monitoring is not needed).
- Minimum hold: 200 ms. Spacing window: 60 s.

## Review focus

1. Our own synthetic Cmd+V reaching the event tap. Expected: ignored, so it neither cancels a recording nor resets spacing. Tag posted events with `eventSourceUserData = 0x4C57` and skip them in the tap. The check lives in the tap; manual check in Task 5.
2. Right Command released while a transcription is still running, then pressed again. Expected: the new recording works; the old result still inserts. Test in Task 2.
3. Clipboard changed by the user within the restore delay. Expected: do not overwrite their new content. Inserter checks `changeCount` before restoring. Manual check in Task 5.
4. Silence or a mumble. Expected: nothing inserted. Covered by `TranscriptCleaner` tests in Task 1.
5. Event tap disabled by the system (timeout or user input). Expected: tap re-enables itself on `tapDisabledByTimeout` / `tapDisabledByUserInput`. Manual check in Task 5.

---

### Task 1: Package scaffold and transcript cleanup

**Files:**
- Create: `Package.swift`, `.gitignore`, `Sources/LocalWhisperCore/TranscriptCleaner.swift`, `Tests/LocalWhisperCoreTests/TranscriptCleanerTests.swift`, `Sources/LocalWhisper/main.swift` (placeholder that prints and exits)

**Interfaces:**
- Produces: `public enum TranscriptCleaner { public static func clean(_ raw: String) -> String? }`. Returns nil when nothing should be inserted.

- [ ] **Step 1:** `git init`. `Package.swift`: tools 6.0, platforms `.macOS(.v14)`, dependency WhisperKit `from: "1.1.1"` (product `WhisperKit`, used only by the executable), `swiftLanguageModes: [.v5]`.
- [ ] **Step 2: Write failing tests** in `TranscriptCleanerTests`:

```swift
XCTAssertEqual(TranscriptCleaner.clean("Um, so the build is failing."), "So the build is failing.")
XCTAssertEqual(TranscriptCleaner.clean("Run the uh tests again"), "Run the tests again")
XCTAssertEqual(TranscriptCleaner.clean("  hello world  "), "hello world")
XCTAssertEqual(TranscriptCleaner.clean("Check the umbrella config"), "Check the umbrella config") // word boundary
XCTAssertNil(TranscriptCleaner.clean(""))
XCTAssertNil(TranscriptCleaner.clean("Um."))
XCTAssertNil(TranscriptCleaner.clean("[BLANK_AUDIO]"))
XCTAssertNil(TranscriptCleaner.clean(" Thank you."))
XCTAssertNil(TranscriptCleaner.clean("Thanks for watching!"))
XCTAssertNil(TranscriptCleaner.clean("(silence)"))
XCTAssertEqual(TranscriptCleaner.clean("[Music] fix the bug"), "fix the bug")
```

- [ ] **Step 3:** Run `swift test`. Expected: fails to compile (no `TranscriptCleaner`).
- [ ] **Step 4: Implement.** Order: strip `[...]` and `(...)` annotations; remove standalone fillers `um+|uh+|erm+|hmm+|mm+` (case-insensitive, word-bounded, with a following comma or period); collapse whitespace; remove space before punctuation; trim; if a leading filler was removed, uppercase the first letter. Return nil if the result is empty, only punctuation, or (lowercased, punctuation-trimmed) in the hallucination set `["thank you", "thanks for watching", "thank you for watching", "you", "bye"]`.
- [ ] **Step 5:** `swift test` passes. Commit `feat: transcript cleanup`.

### Task 2: Hotkey state machine and spacing

**Files:**
- Create: `Sources/LocalWhisperCore/HotkeyStateMachine.swift`, `Sources/LocalWhisperCore/SpacingPolicy.swift`, `Tests/LocalWhisperCoreTests/HotkeyStateMachineTests.swift`, `Tests/LocalWhisperCoreTests/SpacingPolicyTests.swift`

**Interfaces:**
- Produces:
  - `public enum HotkeyEvent { case rightCommandDown(TimeInterval), rightCommandUp(TimeInterval), otherInput }` (timestamps in seconds; `otherInput` = any key down or mouse down)
  - `public enum HotkeyAction: Equatable { case startRecording, finishRecording, cancelRecording }`
  - `public struct HotkeyStateMachine { public init(minimumHold: TimeInterval = 0.2); public mutating func handle(_ event: HotkeyEvent) -> HotkeyAction? }`
  - `public struct SpacingPolicy { public init(window: TimeInterval = 60); public mutating func prefix(at now: TimeInterval) -> String; public mutating func recordInsert(at now: TimeInterval); public mutating func reset() }`

- [ ] **Step 1: Write failing tests.**

```swift
// hold then release -> start, finish
var m = HotkeyStateMachine()
XCTAssertEqual(m.handle(.rightCommandDown(0)), .startRecording)
XCTAssertEqual(m.handle(.rightCommandUp(1.0)), .finishRecording)
// quick tap -> start, cancel
XCTAssertEqual(m.handle(.rightCommandDown(2)), .startRecording)
XCTAssertEqual(m.handle(.rightCommandUp(2.1)), .cancelRecording)
// shortcut: other input while held -> cancel, then release does nothing
XCTAssertEqual(m.handle(.rightCommandDown(3)), .startRecording)
XCTAssertEqual(m.handle(.otherInput), .cancelRecording)
XCTAssertNil(m.handle(.rightCommandUp(4)))
// other input while idle does nothing
XCTAssertNil(m.handle(.otherInput))
// repeated down while held (key repeat / duplicate flags) does not restart
XCTAssertEqual(m.handle(.rightCommandDown(5)), .startRecording)
XCTAssertNil(m.handle(.rightCommandDown(5.5)))
XCTAssertEqual(m.handle(.rightCommandUp(6)), .finishRecording)
// up while idle does nothing
XCTAssertNil(m.handle(.rightCommandUp(7)))
```

```swift
var s = SpacingPolicy()
XCTAssertEqual(s.prefix(at: 0), "")
s.recordInsert(at: 0)
XCTAssertEqual(s.prefix(at: 30), " ")
XCTAssertEqual(s.prefix(at: 61), "")
s.recordInsert(at: 100); s.reset()
XCTAssertEqual(s.prefix(at: 101), "")
```

- [ ] **Step 2:** `swift test` fails to compile.
- [ ] **Step 3:** Implement. The state machine has two states, `idle` and `held(since:)`. It has no knowledge of whether a transcription is in flight; that is the controller's concern, so a new press always starts a new recording.
- [ ] **Step 4:** `swift test` passes. Commit `feat: hotkey state machine and spacing`.

### Task 3: App bundle, signing, menu bar shell

**Files:**
- Create: `Resources/Info.plist`, `scripts/make-cert.sh`, `scripts/build-app.sh`, `Sources/LocalWhisper/main.swift` (replace placeholder), `Sources/LocalWhisper/AppDelegate.swift`, `Sources/LocalWhisper/MenuBarController.swift`

**Interfaces:**
- Produces: `enum AppState { case loadingModel(progress: Double?), idle, recording, transcribing, error(String) }` and `MenuBarController.update(_ state: AppState)`. Menu items: a disabled status line, "Accessibility permission…" (shown only when not trusted, opens the System Settings pane), "Launch at login" toggle via `SMAppService.mainApp`, "Quit".

- [ ] **Step 1:** `make-cert.sh`: idempotent. If `security find-identity -v -p codesigning` lacks `LocalWhisper Dev`, generate a self-signed cert with `openssl` (extendedKeyUsage `codeSigning`), import the p12 into the login keychain with `-T /usr/bin/codesign`, and trust it for code signing with `security add-trusted-cert -p codeSign`. Run it; confirm the identity appears.
- [ ] **Step 2:** `build-app.sh`: `swift build -c release`, assemble `build/LocalWhisper.app` (binary in `Contents/MacOS`, `Info.plist`, plus any SwiftPM resource bundles), `codesign --force --options runtime --sign "LocalWhisper Dev"` with an entitlements file granting `com.apple.security.device.audio-input`.
- [ ] **Step 3:** App delegate: accessory activation policy, status item using SF Symbols (`mic` idle, `mic.fill` red-tinted recording, `waveform` transcribing, `arrow.down.circle` loading, `exclamationmark.triangle` error). On launch, call `AXIsProcessTrustedWithOptions` with the prompt option and request microphone access.
- [ ] **Step 4:** Run `scripts/build-app.sh && open build/LocalWhisper.app`. Expected: menu bar icon appears, no Dock icon, `codesign -dv` shows `LocalWhisper Dev`. Commit `feat: app bundle and menu bar`.

### Task 4: Audio capture and transcription

**Files:**
- Create: `Sources/LocalWhisper/Recorder.swift`, `Sources/LocalWhisper/Transcriber.swift`

**Interfaces:**
- Produces:
  - `final class Recorder { func start() throws; func stop() -> [Float] }` returning 16 kHz mono Float samples. Uses `AVAudioEngine` input tap plus `AVAudioConverter`. Call `engine.prepare()` at launch so `start()` is fast. Mic is only open while recording (Claude's call: the always-on mic indicator is worse than a short start delay; verify the first word survives).
  - `actor Transcriber { func load(progress: @escaping (Double) -> Void) async throws; func transcribe(_ samples: [Float]) async throws -> String }`. `load` downloads `large-v3-v20240930_turbo` if absent, then builds `WhisperKit` with `prewarm: true, load: true`. `transcribe` uses `DecodingOptions(language: "en", detectLanguage: false, skipSpecialTokens: true, withoutTimestamps: true)` and joins result texts.
  - Debug entry: `LocalWhisper --transcribe <file>` loads the model, transcribes the file, prints the text and elapsed ms, exits.

- [ ] **Step 1:** Implement both, plus the `--transcribe` path in `main.swift`.
- [ ] **Step 2:** Verify: `say -o <scratchpad>/clip.wav --data-format=LEI16@16000 "Run the tests in the auth folder and fix any failures"`, then run the built binary with `--transcribe`. Expected: matching text, transcription time under 1000 ms after the model is loaded. Record the time.
- [ ] **Step 3:** Commit `feat: recorder and WhisperKit transcriber`.

### Task 5: Hotkey tap, paste, and wiring

**Files:**
- Create: `Sources/LocalWhisper/HotkeyMonitor.swift`, `Sources/LocalWhisper/Inserter.swift`, `Sources/LocalWhisper/DictationController.swift`

**Interfaces:**
- Consumes: everything above.
- Produces:
  - `HotkeyMonitor(onEvent: (HotkeyEvent) -> Void)`: active `CGEvent.tapCreate` at `.cgSessionEventTap` for `flagsChanged`, `keyDown`, left/right/other mouse down. Right Command is keycode 54; down/up is read from the device-dependent bit `0x10` in the raw flags. Passes every event through unchanged. Skips events whose `eventSourceUserData == 0x4C57`. Re-enables on tap-disabled events.
  - `enum Inserter { static func insert(_ text: String) }`: snapshot all pasteboard items and types, write the text plus `org.nspasteboard.TransientType`, post Cmd+V (keycode 9) tagged with `0x4C57`, restore the snapshot after 300 ms only if `changeCount` is still the one we set.
  - `DictationController` maps `HotkeyAction` to Recorder/Transcriber/Inserter, owns `SpacingPolicy`, calls `reset()` on `otherInput` and on `NSWorkspace.didActivateApplicationNotification`, and drives `MenuBarController`.
- [ ] **Step 1:** Implement and wire into `AppDelegate`.
- [ ] **Step 2:** Build, launch, grant Accessibility. Verify by hand in Terminal and VS Code: hold-speak-release inserts; right Cmd+C still copies without inserting; a tap does nothing; two dictations in a row are space-separated; a copied value is back on the clipboard afterward.
- [ ] **Step 3:** Commit `feat: push-to-talk dictation`.

### Task 6: README

- [ ] Write `README.md`: what it is, `scripts/make-cert.sh` then `scripts/build-app.sh`, copying to `/Applications`, the two permissions, first-run model download size and time, Secure Keyboard Entry note, and how to run tests. Commit `docs: readme`.
