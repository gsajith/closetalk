# Closetalk image briefs

Prompts for an image model (written for Midjourney; they work in most models with the `--` flags removed). Product facts live in `PRODUCT.md`.

The directions come from the Crazy 8's rounds. Favorites, in order: Riso hand, Studio mic, Proximity rings.

## How to use these

- Generate the subject on a plain background, not a finished icon. Image models draw bad rounded squares. Mask the pick into Apple's macOS icon template afterwards (1024 px canvas, 824 px rounded square, from Apple Design Resources).
- Reject anything with letters, fake text or a logo in it. Text goes on later, set in real type.
- Judge every pick at 32 px as well as full size. That's the size in Finder lists and Spotlight.
- Menu bar glyphs don't come from here. They are 18 pt line drawings, and get drawn by hand to match the chosen icon.

## App icon prompts

### 1. Riso mic

From Riso hand and Studio mic.

```
Risograph print of a vintage broadcast dynamic microphone, three-quarter view, printed in two inks, fluorescent pink and medium blue, purple where the inks overlap, visible halftone dots, ink grain, slight plate misregistration, uncoated off-white paper texture, bold simple shapes, single centered object filling most of the frame, plain background --ar 1:1 --style raw --no text, letters, words, logo
```

### 2. Whisper hand

Riso hand, done properly by a model that can draw a hand.

```
Risograph print of a hand cupped beside a mouth, whispering a secret, side profile, simple bold shapes, two inks fluorescent pink and medium blue overprinting into purple, halftone texture, ink grain, misregistered plates, off-white uncoated paper, single centered subject, plain background --ar 1:1 --style raw --no text, letters, words, logo
```

### 3. Studio mic, rendered

Studio mic as a lit object, the way Apple's own icons are made.

```
macOS app icon style 3D render of a compact broadcast microphone seen close up, satin graphite body, fine steel mesh grille, small glowing red on-air light, soft studio key light from top left, subtle reflections, centered, plain soft gradient background --ar 1:1 --no text, letters, words, logo
```

### 4. Foam windscreen

From Studio mic. Soft and friendly instead of pro gear.

```
3D render of a handheld microphone with a soft foam windscreen in cobalt blue, visible foam pores, warm rim light, matte off-white handle, minimal pale background, tactile, centered, macOS app icon style --ar 1:1 --no text, letters, words, logo
```

### 5. Contained ripples

Proximity rings as a real object: ripples that stop at the rim, the way your voice stops at your Mac.

```
Top-down photograph of a small round glazed ceramic dish of water, a single drop making concentric ripples that fade before the rim, cobalt blue glaze, soft daylight, calm, minimal, centered --ar 1:1 --style raw --no text, letters, words, logo
```

## README cover prompts

Wide art with the left side kept empty for the wordmark and headline, which get set in HTML on top.

### Riso

```
Wide risograph poster, a vintage studio microphone on the right third, left two thirds empty off-white paper, two inks fluorescent pink and medium blue, halftone dots, ink grain, misregistered plates --ar 2:1 --style raw --no text, letters, words, logo
```

### Rendered studio

```
Moody studio photograph, a broadcast microphone in close-up on the right, a red on-air light glowing in soft background bokeh, graphite tones, left half dark and empty --ar 2:1 --no text, letters, words, logo
```

## Copy to set on top

Headline options, best first:

1. Talk to your agents like they're sitting next to you.
2. Free, because it runs on the chip you already paid for.
3. Your prompts got longer. Your typing didn't get faster.

Under the headline: Hold right ⌘, say the prompt, let go. Closetalk types it wherever your cursor is, about a second later. The Whisper model runs on your Mac, so nothing you say goes to a server.

Short lines for the cover or a listing:

- Dictation that never leaves the room.
- Say exactly what you mean. Get exactly what you said.
- No account, no subscription, no server.

## After you pick

Drop the chosen images into `assets/src/`. From there:

1. Mask the icon into the template and build `AppIcon.icns` with `iconutil`.
2. Draw the five menu bar glyphs to match it.
3. Rebuild the cover around the chosen art and headline.
