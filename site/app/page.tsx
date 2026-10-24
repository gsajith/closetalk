import type { Metadata } from "next";
import MicDiagram from "./mic-diagram";
import { DOWNLOAD_URL, REPO_URL, REQUIREMENTS } from "./site";

export const metadata: Metadata = { alternates: { canonical: "/" } };

// Structured data so search engines know this page is a free Mac app. Facts only: no ratings
// or reviews, because there aren't any yet.
const APP_JSON_LD = {
  "@context": "https://schema.org",
  "@type": "SoftwareApplication",
  name: "Closetalk",
  description:
    "Push-to-talk dictation for your Mac. Hold right Command, say the prompt, let go, and the text appears at your cursor. Runs on your Mac with no account.",
  url: "https://closetalk.dev/",
  applicationCategory: "UtilitiesApplication",
  operatingSystem: "macOS 14 or later",
  softwareRequirements: "Mac with Apple Silicon (M1 or later)",
  downloadUrl: DOWNLOAD_URL,
  image: "https://closetalk.dev/icon.png",
  license: "https://opensource.org/license/mit",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD" },
};

const FACTS: [string, string][] = [
  ["Model", "Whisper large-v3 turbo"],
  ["Where it runs", "Your Mac"],
  ["Network use", "A 1.5 GB model download on first launch, then a daily update check"],
  ["Account", "None"],
  ["Price", "Free, MIT licensed"],
];

// Selling points only. Setup and troubleshooting (first-launch wait, permissions, Secure Keyboard
// Entry) live in the README.
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
    "Which apps does it work in?",
    <>
      Anywhere you can type: Terminal, VS Code, Claude Code, ChatGPT, Slack, your browser.
    </>,
  ],
  [
    "Is it really free?",
    <>
      Yes. There&apos;s no paid tier and no account. The <a href={REPO_URL}>source is on GitHub</a> under the MIT
      license.
    </>,
  ],
];

// A section heading printed in two plates off register (see .print in globals.css). The pink
// plate is a pseudo-element drawn from data-print, so the text appears once in the HTML.
function PrintedHeading({ id, children }: { id: string; children: string }) {
  return (
    <h2 id={id} className="print" data-print={children}>
      <span>{children}</span>
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
      <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(APP_JSON_LD) }} />
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
