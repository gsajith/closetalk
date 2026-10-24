---
name: Closetalk
description: Push-to-talk dictation that runs on your Mac, printed as a two-ink Riso job on uncoated paper.
colors:
  paper: "#f2eadf"
  paper-light: "#f8f3eb"
  pink: "#ed269d"
  blue: "#1c81c3"
  purple: "#4a147d"
  purple-2: "#5f3f80"
  purple-deep: "#3b0f66"
typography:
  display:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(38px, 4.3vw, 62px)"
    fontWeight: 800
    lineHeight: 1.02
    letterSpacing: "-0.035em"
  headline:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(32px, 4.2vw, 54px)"
    fontWeight: 800
    lineHeight: 1.04
    letterSpacing: "-0.035em"
  wordmark:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "34px"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.04em"
  title:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "clamp(17px, 1.9cqw, 23px)"
    fontWeight: 800
    lineHeight: 1.15
    letterSpacing: "-0.02em"
  question:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "21px"
    fontWeight: 700
    letterSpacing: "-0.01em"
  lede:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "19px"
    fontWeight: 500
    lineHeight: 1.55
  body:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "18px"
    fontWeight: 500
    lineHeight: 1.55
  small:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "15px"
    fontWeight: 500
    lineHeight: 1.55
  label:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "14px"
    fontWeight: 700
    letterSpacing: "0.06em"
  button:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "21px"
    fontWeight: 800
    letterSpacing: "-0.01em"
  numeral:
    fontFamily: "Bricolage Grotesque, Helvetica Neue, Arial, sans-serif"
    fontSize: "72px"
    fontWeight: 800
    lineHeight: 0.9
rounded:
  plate: "4px"
  tab: "6px"
spacing:
  gutter: "20px"
  stack: "22px"
  column-gap: "56px"
  section: "104px"
  section-narrow: "80px"
components:
  button-download:
    backgroundColor: "{colors.blue}"
    textColor: "{colors.paper-light}"
    typography: "{typography.button}"
    rounded: "{rounded.plate}"
    padding: "18px 34px"
  button-nav-download:
    backgroundColor: "{colors.purple}"
    textColor: "{colors.paper-light}"
    rounded: "{rounded.tab}"
    padding: "7px 14px"
  button-nav-download-hover:
    backgroundColor: "{colors.purple-deep}"
  flood-plate:
    backgroundColor: "{colors.blue}"
    textColor: "{colors.paper-light}"
    padding: "48px 40px"
  fact-sheet:
    textColor: "{colors.purple}"
    padding: "14px 26px"
  question-row:
    textColor: "{colors.purple}"
    typography: "{typography.question}"
    padding: "22px 48px 22px 0"
---

# Design System: Closetalk

## Overview

**Creative North Star: "The two-ink Riso job"**

Every Closetalk surface is a sheet that came off a Risograph. There is one paper, uncoated and warm with visible fiber, and two inks: fluorescent pink and blue. Wherever the two overprint they make a deep purple, and that purple carries the reading text. Nothing on the page claims to be a screen. Type has a slightly rough edge, solids carry specks of paper showing through, flat plates sit a fraction of a degree crooked, and the two plates of a wordmark or heading land a few pixels out of register.

The landing page, the app icon and the README cover all print this same job. The hero is a labeled product diagram: the Riso mic in the middle, thin blue leader lines running from round pins on the mic to short callouts at its sides. That diagram language (leader, pin, callout) belongs to the world and may return on future surfaces. The page is light and generous: a single centered column, large heavy Grotesque headlines, plain paragraphs, and long breaks between sections.

The page stays print in every system theme. It declares `color-scheme: light` and never inverts.

**Key Characteristics:**
- One paper ground, two inks, purple only where they overprint.
- Ink is simulated with the `#ink` filter (rough edge, paper specks) on type and small solids, and the `#flood` filter (uneven drum density) on large fills.
- Pink and blue plates combine with `mix-blend-mode: multiply`, never with opacity.
- Misregistration of 3px left and 2px down is the signature gesture.
- Hand-fed sheets: tint and flood plates rotate by about half a degree.
- Bricolage Grotesque for everything, at 500, 600 and 800.

## Colors

Paper plus two fluorescent Riso inks; every other color is the result of those inks overprinting or thinning.

### Primary
- **Fluorescent Pink** (pink): the accent ink. It prints as the offset plate of the wordmark, section headings and Download button, the step numerals, the FAQ plus marks, the caret, and every hover or "hot" state (a callout's leader line and title turn pink while hovered, or while the visitor holds right ⌘).

### Secondary
- **Riso Blue** (blue): the structural ink. It draws leader lines, pins, link underlines, focus rings, FAQ rules, the dotted colophon rule, the halftone tint behind the fact sheet, and the flood plate behind the demo. It is the registered plate in every two-plate print.

### Tertiary
- **Overprint Purple** (purple): pink over blue. All body and heading text not printed in two plates sets in this color. It also fills the compact nav Download tab and the scrollbar thumb.
- **Deep Overprint** (purple-deep): a heavier pass of the same purple, used only as the hover state for purple fills and question titles.

### Neutral
- **Uncoated Paper** (paper): the page ground, under the `paper.jpg` fiber plate tiled at 1300px. The icon body fills with it too.
- **Bright Paper** (paper-light): paper where ink is knocked out. Knockout labels on the Download button and flood plate, pin centers, and the halo stroke behind pin letters use it.
- **Thin Purple** (purple-2): secondary text at about 6:1 on paper. Ledes, callout bodies, step bodies, FAQ answers, requirements, captions and the colophon use it.

### Named Rules
**The Two Inks Rule.** Only pink and blue are inks. Purple exists because they overprint, so a new hue never enters. A third ink would break the print.

**The Multiply Rule.** Ink on paper always composites with `mix-blend-mode: multiply`. Layered plates darken where they meet, the way real ink does. Opacity fades and normal blending are off-world.

**The Knockout Rule.** Text on a solid ink plate is paper showing through (paper-light), never white and never a third color.

## Typography

**Display Font:** Bricolage Grotesque (with Helvetica Neue, Arial, sans-serif), self-hosted through `next/font` at weights 500, 600 and 800.
**Body Font:** Bricolage Grotesque, same stack.

**Character:** One quirky grotesque does all the work. At 800 with tight negative tracking it reads as poster type pulled from a drum. At 500 it stays plain and readable for the arguments and answers.

### Hierarchy
- **Display** (800, clamp 38px to 62px, line-height 1.02, -0.035em): the hero headline only, capped at 22ch, printed through `#ink`.
- **Headline** (800, clamp 32px to 54px, line-height 1.04, -0.035em): section headings, printed in two plates with the text plate in purple, which reads better than blue at display size.
- **Wordmark** (800, 34px, line-height 1, -0.04em): the masthead "Closetalk", always two plates. The cover scales it to 118px with a proportionally larger offset.
- **Title** (800, clamp 17px to 23px in container units, line-height 1.15, -0.02em): diagram callout titles. Prose pages use a fixed 24px variant for subheads.
- **Question** (700, 21px, -0.01em): FAQ summaries.
- **Lede** (500, 19px): the line under the display, in Thin Purple, max 62ch. Argument paragraphs run a step larger at 20px, max 46ch.
- **Body** (500, 18px, line-height 1.55): default text. Prose pages cap at 68ch.
- **Small** (500, 15px): requirements, captions, colophon.
- **Label** (700, 14px, 0.06em, uppercase): terms in the fact sheet only, in Overprint Purple.
- **Button** (800, 21px, -0.01em): the printed Download button.
- **Numeral** (800, 72px, line-height 0.9): step counters in pink ink.

### Named Rules
**The Heavy Print Rule.** Headings and anything printed in ink set at 800. Weight 700 is for fact terms, questions and flood text, 600 for navigation and fact values, 500 for reading text. Nothing goes lighter than 500.

**The Self-Hosted Rule.** The face ships from the site's own origin. No runtime request reaches a font CDN.

## Layout

A centered single column. The masthead, hero and colophon run to 1240px; content sections run to 1080px; prose pages run to 68ch. Side gutters are 20px or the safe-area inset, whichever is larger.

The hero centers its text. The mic diagram lives on a fixed 1200 by 500 stage so the SVG art and the HTML callouts share one coordinate system. The stage also scales with viewport height, so headline, callouts and Download share the first screen. The Download button sits directly under the mic's stand as its base.

Sections open with 104px of space above (80px below 900px). The argument section is a two-column grid (1fr and 1.05fr, 56px gap); the steps are three equal columns (36px gap). Both collapse to one column at 900px. On narrow screens the diagram drops its leader lines, the pins gain pink letters A to D, and the callouts reflow beneath the mic carrying matching letters. At 520px the nav keeps only GitHub and Download, and fact rows stack.

## Elevation & Depth

The web surfaces have no shadows. Depth comes from print physics: plates multiplied over each other, a pink plate offset under a blue one, tint and flood plates rotated a fraction of a degree, and the paper texture under everything. The app icon is the one exception. It carries the soft drop shadow from Apple's macOS icon grid (`0 10px 14px rgba(0, 0, 0, 0.3)`), a platform convention.

### Named Rules
**The Misregistration Rule.** A two-plate print offsets its pink plate 3px left and 2px down from the text plate (at 34px to 62px type; scale it with size, as the cover does at 118px with 5px and 4px). This is ink, not a shadow. Hover may pull the plates toward register (the Download button closes to 1px, then 0 on press; the wordmark drifts apart to 5px and 3px).

**The Crooked Sheet Rule.** Tint and flood plates sit slightly rotated, between -0.6deg and 0.5deg, like a hand-fed sheet. Type plates stay square.

## Shapes

Shapes are mostly square-cut plates. The Download plate and the focus ring round to 4px; the compact nav Download tab rounds to 6px. Rules are thin: 1.5px blue for FAQ dividers, 1.5px purple at 35% between facts, and a 2px dotted blue rule above the colophon. Pins are circles: a 9px-radius paper ring with a 2.5px blue stroke around a 3.5px blue dot. Leader lines are 1.75px blue polylines with one elbow and round joins. The app icon uses Apple's continuous-corner superellipse with a hairline purple edge at 12% opacity.

## Components

### Buttons
Printed, not rendered. The main action prints as ink.
- **Shape:** gently squared plate (4px).
- **Download (primary):** two full-size plates, pink and blue, multiplied through `#ink`, with the pink plate offset 3px left and 2px down. The label "Download for Mac" is knocked out to paper at 21px, 800, padding 18px 34px. Requirements print in Small under it.
- **Hover / Press:** hover pulls the pink plate to 1px off over 180ms on `cubic-bezier(0.2, 0.9, 0.3, 1)`; pressing lands it in register.
- **Nav Download (compact):** a solid purple tab (6px radius, 7px 14px padding) with a paper-light label. Hover deepens it to purple-deep.
- **Focus:** a 3px blue outline, 3px offset, 4px radius, shared by every focusable element.

### Links
Inherit their text color with a 2px blue underline offset 4px; hover turns the underline pink. Nav links hide the underline until hover.

### Navigation
The masthead puts the two-plate wordmark on the left and a row of 600-weight, 16px links on the right, ending in the compact Download tab. No bar, no background, no border: it prints straight onto the paper.

### Printed heading
Section headings and the wordmark carry their text once, in a `span`. The pink plate is a `::before` drawn from a `data-print` attribute with `content: attr(data-print) / ""`, so crawlers and screen readers read the text once. Both plates pass through `#ink` and multiply, so they wrap identically and overprint where they meet. Section headings set the text plate in purple; the wordmark keeps it blue.

### Diagram callout (signature)
The hero's leader-line diagram. Each callout pairs a Title and a body in Thin Purple, set to the left or right of the art at 30% width, right-aligned on the left side. A blue polyline runs from a pin on the art to the callout's title. Hovering a callout, or the matching real-world gesture, sets the line, pin and title to pink and thickens the line from 1.75px to 3px over 160ms.

### Fact sheet
A definition list on a fine, light blue halftone tint (0.75px dots on a 4px grid at 40% opacity, about 10% coverage, multiplied, through `#ink`), rotated -0.6deg. The screen stays that light so the type on it reads cleanly. Rows split into a Label term column (8.5em) and a 19px, 600 value, separated by thin purple rules. Below 520px the term stacks over the value.

### Flood plate
A solid blue rectangle printed through `#flood`, rotated 0.5deg, with text knocked out to paper at 22px to 30px, 700. Flood density never drops below 92%, so knocked-out text keeps at least 3:1 contrast. On the landing page it holds the demo stub, with a pink blinking caret.

### Question row
Native `details` rows between 1.5px blue rules. The summary sets in Question type with a pink plus mark made of two 18px by 3px bars; the vertical bar rotates flat over 200ms when the row opens. Answers sit in Thin Purple, max 68ch.

### Steps
A three-column ordered list. Each step opens with a 72px pink numeral printed through `#ink`, then a purple bold lead-in and Thin Purple body.

### Motion
Motion stays small and physical: plates sliding toward register, ink color shifting along a line, a plus mark rotating. Durations run 160ms to 200ms with ease-out curves. `prefers-reduced-motion` removes every transition and the caret blink.

## Do's and Don'ts

### Do:
- **Do** print headings, the wordmark and primary actions as two plates, pink offset 3px left and 2px down under the text plate (purple for headings, blue for the wordmark and Download), both multiplied.
- **Do** draw the pink plate of printed type from a data attribute, never as a second copy of the text in the HTML.
- **Do** set reading text in Overprint Purple (purple) and secondary text in Thin Purple (purple-2) on Uncoated Paper.
- **Do** run large ink fills through `#flood` and type or small solids through `#ink`, so solids show grain.
- **Do** knock text out of ink plates to Bright Paper (paper-light).
- **Do** use blue for structure (lines, rules, pins, focus) and pink for emphasis and live states.
- **Do** keep the page light in every system theme and serve fonts and images from the site's own origin.

### Don't:
- **Don't** introduce a third ink, a gradient, or a dark theme.
- **Don't** add box shadows or glows to web surfaces; depth comes from overprint and misregistration.
- **Don't** fade ink with opacity or stack plates with normal blending; use multiply.
- **Don't** set type lighter than 500 or swap in a second typeface.
- **Don't** rotate type plates; only tint and flood plates sit crooked.
