# Coding standards

Read during code review. These are judgement calls no linter checks; formatting, types and tests are left to the build and CI.

## Claims trace to evidence

Every factual claim on the site, in the README or in app copy (timings, sizes, prices, privacy, what competitors do) matches a fact in `PRODUCT.md`, under Evidence on Hand or the sections above it. A new claim needs its fact, with a source and date, added to `PRODUCT.md` in the same change. Quotes, user counts and ratings stay off the page until real ones exist.

## Copy names the user's shortcut

The dictation shortcut is chosen in setup, and there's no default. User-facing copy calls it the dictation key, explains it before asking for it, and names the saved one with `DictationShortcutSettings.shortcut?.name`. Nothing in the app, docs or site presents right ⌘ as the default. It may appear as one example among others.

## Copies of one fact change together

Some facts live in more than one place, and a change to one updates the others in the same change:

- Privacy: the README's Privacy section and `site/app/privacy/page.tsx`.
- Requirements and first-launch timings: the README, `site/app/site.ts` and `PRODUCT.md`.
- The brand system: `DESIGN.md` and `.impeccable/design.json`, when the site's visual rules change.
