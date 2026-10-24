# Closetalk as a macOS app

Closetalk is a menu bar app (`LSUIElement`, activation policy `.accessory`). macOS treats such apps differently from regular ones, and each difference below cost a test round to rediscover.

## Focus and windows

- **Focus after a system prompt** returns to the last *regular* app, never to a menu bar app. A window that must stay in front through a microphone or Accessibility prompt runs the app as `.regular` while it's open (a Dock icon appears) and switches back to `.accessory` on close. See `SetupWindowController`.
- **Activation can be refused.** `NSApp.activate()` is cooperative: macOS may decline it when another app is active. `orderFrontRegardless()` still puts the window on top.
- **Spaces.** A window opens on the Space the app launched on unless it sets `collectionBehavior = [.moveToActiveSpace]`.

## Paste

Text fields paste through the Edit menu's ⌘V, and dictation pastes by posting ⌘V. A menu bar app has no menu bar, so it needs `NSApp.mainMenu` with an Edit menu for its own fields to receive dictation. The menu only shows while the app is `.regular`.

## Permissions

- **Accessibility prompt.** Creating the key-event tap without Accessibility makes macOS show its own prompt. `DictationController.startMonitor` checks `AXIsProcessTrusted()` first, so the prompt only appears when the setup window asks for it.
- **Changes in System Settings** send no notification. Poll `AVCaptureDevice.authorizationStatus(for: .audio)` and `AXIsProcessTrusted()` while it matters.
- **Permissions follow the bundle ID and signing certificate.** A dev build (`Closetalk Dev`) and a release build (Developer ID) of `dev.gsajith.Closetalk` share the bundle ID, so `tccutil` resets both.

## Testing the app by hand

1. Quit the installed Closetalk first. Two running copies both listen for the shortcut and paste twice.
2. `scripts/build-app.sh`, then `open build/Closetalk.app`.
3. To rerun first-launch setup: `tccutil reset Microphone dev.gsajith.Closetalk`, `tccutil reset Accessibility dev.gsajith.Closetalk`, and delete `~/Library/Application Support/Closetalk/models/*.compiled`. The model stays downloaded and Core ML's compile stays cached, so the model step finishes in seconds.
4. `swift scripts/windows.swift` lists Closetalk's windows with title, bounds and whether they're on screen, so you can confirm a window appeared without a screenshot.
5. Log lines: `/usr/bin/log show --last 5m --predicate 'subsystem == "dev.gsajith.Closetalk"' --style compact`. Use the full path; zsh has its own `log` builtin. Add a temporary `Logger` category to trace focus or timing, and remove it before merging.
