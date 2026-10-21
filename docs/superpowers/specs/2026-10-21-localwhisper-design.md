# LocalWhisper design

## Intent

A free, fully local replacement for Superwhisper and Wispr Flow. Gautham holds right Command, says a sentence or two, lets go, and the text appears at the cursor in whatever app has focus. The main targets are a terminal, VS Code, and Claude Code running in either. No subscription, no network calls for transcription, no audio leaving the machine.

Success means it feels instant: for a short clip, text appears well under a second after releasing the key.

## Goals

- Push to talk on right Command. Hold to record, release to transcribe and insert.
- Insert into the focused app, including Terminal, iTerm-style terminals, and VS Code (Electron).
- Local transcription with a free Whisper model, accurate on technical words (file names, CLI tools, programming terms).
- Raw transcript, with standalone filler words ("um", "uh", "erm", "hmm") stripped by a simple word filter.
- Back-to-back dictations read naturally: each release produces its own insert, with a space separating it from the previous one.
- Menu bar app. The icon shows state: loading model, idle, recording, transcribing.

## Non-goals

- AI cleanup or rewriting of the transcript. It adds latency and can change meaning. Claude handles raw speech fine.
- Streaming or live partial text while speaking.
- Languages other than English.
- A settings window, custom hotkeys, transcript history, or App Store distribution.

## Anti-goals

Any of these makes it a failure even if it works:

- Noticeable lag after release for a short clip (more than about a second).
- Breaking normal right Command shortcuts. Right Cmd+C, Cmd+Tab and so on must behave as before and must not insert anything.
- Losing what was on the clipboard.
- Sending audio or text off the machine.

## Constraints

- Machine: Apple M1 Max, 64 GB RAM, macOS 26.6, Xcode 26.5, Swift 6.3. Homebrew and cmake are installed.
- Builds from this folder with a command-line script. Gautham should not need to open Xcode.
- Needs Microphone and Accessibility permissions. First launch should tell him which to grant.

## Decided

These were Gautham's calls:

- Right Command is the hotkey, push-to-talk style.
- Raw transcript plus the filler word filter, no AI cleanup.
- Clips are usually a sentence or two. He chains several in a row with pauses between them.
- A menu bar icon is fine. A Dock icon is optional; the builder's default is no Dock icon.

These are Claude's calls, made in conversation and not objected to:

- Native Swift app, menu bar only (`LSUIElement`).
- Text goes in by paste: save the current clipboard contents, put the transcript on the clipboard, post Cmd+V, then restore the saved contents shortly after. This is the reliable path into terminals and Electron apps. Typing characters as synthetic keystrokes is the fallback only if paste fails somewhere in testing.
- Use a large, accurate model (large-v3-turbo class) rather than a tiny one, because short clips keep latency low even with a bigger model. Load and warm it up at launch so the first dictation is fast.

## Behavior details

- **Hotkey.** Recording starts when right Command goes down alone. If any other key is pressed while it is held, treat it as a shortcut: stop recording, discard audio, insert nothing. Ignore holds shorter than roughly 200 ms so a quick tap does nothing. Left Command never triggers anything.
- **Empty results.** If the transcript is empty after filtering, or Whisper returns a known hallucination for silence (e.g. "Thank you.", "[BLANK_AUDIO]"), insert nothing.
- **Spacing.** Prefix a single space when the previous insert happened recently (the builder picks the window, around a minute). Trim leading and trailing whitespace from the transcript itself.
- **Mouse while held.** A click or drag while right Command is held counts as a shortcut (Cmd+click) and cancels, same as a key press. (Claude's call.)
- **Spacing reset.** Typing a key, clicking, or switching apps after an insert clears the "recent" state, so the next insert gets no leading space. (Claude's call.)
- **Clipboard detail.** Save and restore every pasteboard item and type, not only plain text. Mark the transcript as transient (`org.nspasteboard.TransientType`) so clipboard managers skip it. (Claude's call.)
- **Latency over accuracy.** If a model choice forces a tradeoff, latency wins. (Claude's call.)
- **Model download.** First launch downloads the model into Application Support and shows progress in the menu. Later launches load from disk with no network.

## Left to the builder

- Transcription engine. WhisperKit (Swift package, Core ML) and whisper.cpp (Metal) both fit. Pick on latency and simplicity of integration, and say which and why.
- Exact model variant, as long as it is large-v3-turbo class or better in accuracy and meets the latency goal.
- Microphone handling: start the audio engine on key down, or keep it warm. Keeping it warm avoids clipping the first word but keeps the macOS mic indicator on. Pick one and note the tradeoff. Whatever is chosen, the first word of a clip must not get cut off.
- How the hotkey is detected (event tap or global event monitor).
- Code signing. The machine has no signing identities, and ad-hoc signing makes macOS forget the Accessibility grant on every rebuild. Gautham approved creating a local self-signed code signing certificate in his login keychain. The build script signs with it so the permission grants survive rebuilds.
- Secure Keyboard Entry (in some terminals) can block event taps. If detection fails while a terminal has focus, check this first and document it.
- Launch at login, offered as a menu toggle, if it is cheap to add.
- Tests: focused unit tests for the filler filter, the hallucination filter, and the hotkey state logic (tap vs hold vs shortcut). Manual verification of paste in Terminal and VS Code.
