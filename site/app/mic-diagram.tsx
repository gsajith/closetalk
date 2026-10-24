import { preload } from "react-dom";

// The hero diagram: the Riso mic with leader lines to four callouts. Coordinates live in one
// 1200x500 stage, so the SVG (mic, lines, pins) and the HTML callouts stay aligned at any width.
const STAGE = { w: 1200, h: 500 };
// mic-ink.webp (660x1027) is the Riso mic with the paper made transparent, cropped so the stand
// ends at the image's bottom edge, which is the stage's bottom edge. The Download plate below
// butts against it as the mic's base.
const MIC = { x: 442.5, y: 10, w: 315, h: 490 };

type Side = "left" | "right";
type Callout = {
  id: string;
  letter: string;
  side: Side;
  top: number; // callout top in stage units
  pin: [number, number]; // where the leader line touches the mic
  title: string;
  body: string;
};

// DOM order is reading order: left top, right top, left bottom, right bottom.
const CALLOUTS: Callout[] = [
  {
    id: "local",
    letter: "A",
    side: "left",
    top: 120,
    pin: [496, 197],
    title: "Runs on your Mac",
    body: "Nothing you say goes to a server, and it works offline.",
  },
  {
    id: "words",
    letter: "B",
    side: "right",
    top: 70,
    pin: [671, 169],
    title: "Your exact words",
    body: 'No AI rewrite. It drops "um" and "uh" and keeps everything else.',
  },
  {
    id: "key",
    letter: "C",
    side: "left",
    top: 330,
    pin: [579, 405],
    title: "Hold your shortcut",
    body: "Pick any key or combo in setup. Talk while you hold it, let go, and the text lands at your cursor.",
  },
  {
    id: "free",
    letter: "D",
    side: "right",
    top: 400,
    pin: [624, 469],
    title: "Free, no account",
    body: "No sign-up, no subscription, no word limit. The code is open source.",
  },
];

const ANCHOR_X: Record<Side, number> = { left: 360, right: 840 };
const ELBOW_X: Record<Side, number> = { left: 405, right: 795 };
const ANCHOR_DY = 22; // the line meets the callout at its title

export default function MicDiagram({ children }: { children: React.ReactNode }) {
  // The mic is the largest thing on the page, so fetch it before anything else.
  preload("/mic-ink.webp", { as: "image", fetchPriority: "high" });

  return (
    <div className="stage">
      <div className="diagram">
        <svg className="diagram-art" viewBox={`0 0 ${STAGE.w} ${STAGE.h}`} role="img" aria-label="A vintage studio microphone, printed in pink and blue ink">
          <image href="/mic-ink.webp" x={MIC.x} y={MIC.y} width={MIC.w} height={MIC.h} />
          {CALLOUTS.map((c) => {
            const ay = c.top + ANCHOR_DY;
            return (
              <g key={c.id} className="leader" data-for={c.id}>
                <polyline points={`${c.pin[0]},${c.pin[1]} ${ELBOW_X[c.side]},${ay} ${ANCHOR_X[c.side]},${ay}`} />
                <circle className="pin" cx={c.pin[0]} cy={c.pin[1]} r={9} />
                <circle className="pin-dot" cx={c.pin[0]} cy={c.pin[1]} r={3.5} />
                <text className="pin-letter" x={c.pin[0]} y={c.pin[1] - 18}>{c.letter}</text>
              </g>
            );
          })}
        </svg>
        <ul className="callouts">
          {CALLOUTS.map((c) => (
            <li
              key={c.id}
              className={`callout callout-${c.side}`}
              data-id={c.id}
              style={{ "--top": `${(c.top / STAGE.h) * 100}%` } as React.CSSProperties}
            >
              <h2 data-letter={c.letter}>{c.title}</h2>
              <p>{c.body}</p>
            </li>
          ))}
        </ul>
      </div>
      {/* The base plate: Download sits directly under the stand. */}
      {children}
    </div>
  );
}
