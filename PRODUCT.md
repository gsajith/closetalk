# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

The app itself is a native macOS menu bar app (Swift, AppKit, `LSUIElement`). `web` covers the brand surfaces built as web code: the landing page and the README cover. The app icon and menu bar glyphs are macOS assets and follow Apple's conventions for those formats.

## Stack

Delegated within the user's frame: hosted on Vercel, built with React. Choice: Next.js with static export. It is Vercel's own framework, and a single marketing page needs no server. Revisit if the site grows docs or a changelog. The README cover stays a standalone HTML file (`assets/src/cover.html`) rendered to PNG.

## Users

Anyone who prompts AI agents from a Mac: Claude Code, Cursor, ChatGPT, terminal agents, chat apps. They write long, specific instructions many times a day, and speaking those instructions is faster than typing them. Developers are the first and largest group, but the brand must not assume the reader writes code.

Hardware floor: Apple Silicon (M1 or later), macOS 14 or later, about 3 GB free disk.

## Product Purpose

Closetalk is push-to-talk dictation. Hold your shortcut, talk, let go, and the text appears wherever the cursor is, about a second later. It exists as a free stand-in for paid dictation apps, built mostly for talking to coding agents. Success is a user who stops reaching for the keyboard to write prompts.

## Positioning

Free and fully local leads. Closetalk runs Whisper large-v3 turbo on the Mac's Neural Engine. There is no account, no subscription, and no server: audio, transcripts and clipboard contents never leave the machine. The app goes online only to download the model from Hugging Face on first launch and to check closetalk.dev for updates once a day.

Named competitors: Superwhisper and Wispr Flow.

Supporting differences, in order:
1. Keeps your exact words. Only "um" and "uh" are removed. No AI rewrite, so `foo()` and `args[0]` survive.
2. One key, nothing else. No window, no mode switch. People choose the key or combo in setup, other shortcuts that use that key still work, and a quick tap does nothing.

## Operating Context

- Lives in the menu bar only. No Dock icon, no main window.
- Interaction: hold the shortcut chosen in setup, hear a start chime, talk, release, hear a stop chime, text is pasted at the cursor. The clipboard is restored two seconds later, and password-manager copies are never put on it.
- Consecutive dictations land with a space between them. Typing or clicking elsewhere resets that.
- Menu bar states: downloading or loading the model, ready, recording, transcribing, needs attention. The menu holds a status line, the microphone picker, launch at login, Check for Updates, and quit.
- First launch: grant microphone and Accessibility permissions, then wait for a 1.5 GB model download and a one-time Neural Engine compile (about 11 minutes on an M1 Max).
- Distribution: a notarized DMG from GitHub Releases. Sparkle delivers updates from closetalk.dev/appcast.xml.

## Capabilities and Constraints

- Current assets: menu bar glyphs are SF Symbols (`MenuBarController.swift`). Chimes are the system sounds Tink (start) and Pop (stop). The app icon is `assets/icon.png`, rendered from `assets/src/icon.html`.
- Brand surfaces in scope: app icon, menu bar glyphs for all five states, README cover, landing page.
- Menu bar glyphs must read as template images at menu bar size and work in light mode, dark mode and on tinted menu bars.

## Brand Commitments

- Name: Closetalk. A close-talking mic sits right at your mouth, which matches the hold-and-speak gesture, and the voice stays close, which matches the local promise.
- Domain: closetalk.dev. closetalk.app belongs to an unrelated social app called Close Talk; closetalk.com is parked.
- Known connotation: "close talker" is a Seinfeld bit about someone who stands too close. Expect the joke; do not lean on it without deciding to.

Everything else is open: the README's first-person maker voice, the right ⌘ key as a symbol, and the cover's dark and amber look are current evidence, free to keep or replace.

## Evidence on Hand

- `README.md`: product description, install steps, first-launch steps, troubleshooting, privacy statement.
- `assets/cover.jpg`, rendered from `assets/src/cover.html`: current cover image.
- Measured facts usable in copy: text appears about a second after release; built-in mic goes live in under 100 ms; Bluetooth headsets take 0.75 to 1.5 s; model is a 1.5 GB download and about 3 GB on disk; first-launch compile took about 11 minutes on an M1 Max.
- License: MIT. Source: github.com/gsajith/closetalk.
- Competitor facts used in the landing page FAQ, checked 2026-10-23 on the vendors' own pages. Wispr Flow: "Transcription always happens in the cloud" (wisprflow.ai/privacy); free plan "2,000/week on desktop" (wisprflow.ai/pricing). Superwhisper (superwhisper.com): free includes "Unlimited use of Whisper models"; Pro adds "Unlimited use of Cloud and Local AI models", own API keys, translation and file transcription. Re-check before launch and whenever the FAQ changes.
- Absent, never fabricate: user counts, download numbers, GitHub stars, testimonials, press, accuracy benchmarks, comparison benchmarks against Superwhisper or Wispr Flow.

## Product Principles

1. Local is the promise. Nothing in the brand may suggest a cloud service, an account, a trial, or a paid tier.
2. Your words, unedited. Closetalk transcribes; it does not rewrite. The brand should never imply AI polishing of what the user said.
3. One key, then out of the way. The product has no window and no ritual beyond holding a key. The brand should be as quiet as the app.
4. Talk to agents, not just to code. The audience is anyone prompting AI. Developer details are welcome as examples, never as a gate.
