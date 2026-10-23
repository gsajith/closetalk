import MicDiagram from "./mic-diagram";
import { DOWNLOAD_URL, REPO_URL, REQUIREMENTS } from "./site";

const FACTS: [string, string][] = [
  ["Model", "Whisper large-v3 turbo"],
  ["Where it runs", "Your Mac's Neural Engine"],
  ["Network use", "One 1.5 GB model download on first launch"],
  ["Account", "None"],
  ["Price", "Free, MIT licensed"],
];

const QUESTIONS: [string, React.ReactNode][] = [
  [
    "How is this different from Wispr Flow or Superwhisper?",
    <>
      Wispr Flow transcribes your voice in the cloud, and its free plan has a weekly word limit. Superwhisper&apos;s
      free plan includes Whisper models, and its paid plan adds cloud and local AI models. Closetalk runs a large
      Whisper model on your Mac and types exactly what you said, with no word limit and no paid plan.
    </>,
  ],
  [
    "Why does the first launch take so long?",
    <>
      Closetalk downloads the 1.5 GB model, then macOS compiles it for your Neural Engine. On an M1 Max that took about
      11 minutes. It happens once. After that, Closetalk is ready a few seconds after launch.
    </>,
  ],
  [
    "Which apps does it work in?",
    <>
      Anywhere you can type: Terminal, VS Code, Claude Code, ChatGPT, Slack, your browser. It pastes at your cursor
      and puts your clipboard back two seconds later.
    </>,
  ],
  [
    "What permissions does it need?",
    <>
      The microphone, so it can hear you, and Accessibility, so it can see the right ⌘ key and paste. Audio stays in
      memory while you dictate and is never written to disk.
    </>,
  ],
  [
    "Will my keyboard shortcuts still work?",
    <>Yes. Right ⌘C, ⌘Tab and the rest work as usual, and a quick tap does nothing.</>,
  ],
  [
    "Nothing happens when I hold right ⌘ in Terminal or iTerm.",
    <>
      Turn off Secure Keyboard Entry in that app&apos;s menu. While it&apos;s on, macOS hides keystrokes from every
      other app, Closetalk included.
    </>,
  ],
  [
    "Does it work on Intel Macs?",
    <>No. It needs a Mac with Apple Silicon (M1 or later) running macOS 14 or later.</>,
  ],
  [
    "Is it really free?",
    <>
      Yes. There&apos;s no paid tier. The <a href={REPO_URL}>source is on GitHub</a> under the MIT license.
    </>,
  ],
];

// A section heading printed in two plates off register (see .print in globals.css).
function PrintedHeading({ id, children }: { id: string; children: string }) {
  return (
    <h2 id={id} className="print">
      <span className="ink-pink" aria-hidden="true">{children}</span>
      <span className="ink-blue">{children}</span>
    </h2>
  );
}

function DownloadButton() {
  return (
    <a className="download" href={DOWNLOAD_URL}>
      Download for Mac
    </a>
  );
}

export default function Home() {
  return (
    <main>
      <section className="hero" aria-labelledby="headline">
        <h1 id="headline" className="inked">Talk to your agents like they&apos;re sitting next to you.</h1>
        <p className="lede">
          Closetalk is push-to-talk dictation for your Mac. It types what you say into Claude Code, ChatGPT, Slack, or
          anything else with a cursor.
        </p>
        <MicDiagram>
          <div className="base-plate">
            <DownloadButton />
            <p className="requirements">{REQUIREMENTS}</p>
          </div>
        </MicDiagram>
      </section>

      <section className="section why" aria-labelledby="why">
        <div className="why-copy">
          <PrintedHeading id="why">Free, because it runs on the chip you already paid for.</PrintedHeading>
          <p>
            Dictation apps that send your voice to a server have to pay for that server, so they charge monthly or cap
            your words. Closetalk runs OpenAI&apos;s Whisper model on your Mac&apos;s Neural Engine instead. There&apos;s
            no server to pay for, and nothing you say leaves the machine.
          </p>
        </div>
        <dl className="facts">
          {FACTS.map(([term, value]) => (
            <div key={term}>
              <dt>{term}</dt>
              <dd>{value}</dd>
            </div>
          ))}
        </dl>
      </section>

      <section className="section how" aria-labelledby="how">
        <PrintedHeading id="how">Hold, talk, let go.</PrintedHeading>
        <ol className="steps">
          <li>
            <strong>Hold right ⌘.</strong> A soft chime means the mic is live.
          </li>
          <li>
            <strong>Say the prompt.</strong> Talk the way you would to someone next to you.
          </li>
          <li>
            <strong>Let go.</strong> A second chime, and about a second later the text is at your cursor.
          </li>
        </ol>
        {/* Stub until Gautham records the 10 to 20 second demo clip. Swap the frame's contents for a <video>. */}
        <figure className="demo">
          <div className="demo-frame">
            <p className="demo-prompt">
              Rename the Export button to Download and move it next to Share<span className="caret" />
            </p>
          </div>
          <figcaption>Demo video coming soon.</figcaption>
        </figure>
      </section>

      <section className="section questions" id="questions" aria-labelledby="questions-title">
        <PrintedHeading id="questions-title">Questions</PrintedHeading>
        <div className="faq">
          {QUESTIONS.map(([q, a]) => (
            <details key={q}>
              <summary>{q}</summary>
              <p>{a}</p>
            </details>
          ))}
        </div>
      </section>

      <section className="section closer" aria-labelledby="closer">
        <PrintedHeading id="closer">Try it on your next prompt.</PrintedHeading>
        <DownloadButton />
        <p className="requirements">{REQUIREMENTS}</p>
      </section>
    </main>
  );
}
