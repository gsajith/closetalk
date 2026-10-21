# LocalWhisper

Push-to-talk dictation for macOS that runs entirely on your Mac. Hold right Command, talk, let go, and the text is pasted at your cursor. Transcription uses Whisper large-v3 turbo through [WhisperKit](https://github.com/argmaxinc/WhisperKit) on the Neural Engine. Nothing is sent anywhere, and there's nothing to pay for.

## Build

```sh
scripts/make-cert.sh    # once: creates the "LocalWhisper Dev" signing certificate in your login keychain
scripts/build-app.sh    # builds and signs build/LocalWhisper.app
cp -R build/LocalWhisper.app /Applications/
open /Applications/LocalWhisper.app
```

Requires Xcode (for the Swift toolchain) on an Apple Silicon Mac running macOS 14 or later.

## First run

1. Grant **Microphone** when asked.
2. Grant **Accessibility**: System Settings > Privacy & Security > Accessibility, turn on LocalWhisper. The app needs it to see right Command and to send Cmd+V. It picks the permission up within a couple of seconds, with no restart.
3. Wait for the model. The first launch downloads about 1.5 GB to `~/Library/Application Support/LocalWhisper/models` and then compiles it for the Neural Engine, which can take a few minutes. Later launches load from disk with no network.

The menu bar icon shows the state: a down arrow while loading, a mic when ready, a red mic while recording, a waveform while transcribing, and a warning triangle when something needs attention (open the menu to see what).

## Use

- Hold right Command, speak, release. The text is pasted where your cursor is.
- A quick tap does nothing. Right Command shortcuts like Cmd+C still work and record nothing.
- Back-to-back dictations get a space between them. Typing, clicking or switching apps resets that.
- Your clipboard is restored right after the paste.
- Filler words ("um", "uh") are removed. Nothing else about the transcript is rewritten.

## Troubleshooting

- **Nothing happens in a terminal.** Turn off Secure Keyboard Entry (Terminal or iTerm menu). It blocks apps from seeing keystrokes.
- **Accessibility shows as on but the menu still asks for it.** You may have granted an older build signed differently. Remove LocalWhisper from the Accessibility list with the minus button, then add it again. Builds signed with `LocalWhisper Dev` keep the grant across rebuilds.

## Development

```sh
swift test                                                    # unit tests for cleanup, hotkey logic, spacing
.build/release/LocalWhisper --transcribe path/to/audio.wav    # transcribe a file and print timings
```

Code layout:

- `Sources/LocalWhisperCore`: pure logic with tests. Transcript cleanup, the push-to-talk state machine, spacing between dictations.
- `Sources/LocalWhisper`: the app. Event tap, microphone capture, WhisperKit, paste, menu bar.
