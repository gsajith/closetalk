import type { Metadata } from "next";
import { REPO_URL } from "../site";

export const metadata: Metadata = {
  title: "Privacy: Closetalk",
  description: "What Closetalk and closetalk.dev do with your data: nothing leaves your Mac.",
  alternates: { canonical: "/privacy" },
};

// Adapted from the README's Privacy section. Update both together.
export default function Privacy() {
  return (
    <main className="prose-page">
      <h1 className="inked">Privacy</h1>
      <h2>The app</h2>
      <p>
        Closetalk goes online for one thing: downloading the speech model and its tokenizer from Hugging Face the first
        time you launch it. After that it works offline.
      </p>
      <p>
        Audio, transcripts and clipboard contents stay on your Mac. Audio is held in memory only while you&apos;re
        dictating and is never written to disk. Closetalk has no account, no telemetry and no server.
      </p>
      <p>
        Closetalk puts your clipboard back two seconds after it pastes. If what you had copied was a password from a
        password manager, Closetalk leaves it off rather than putting it back.
      </p>
      <h2>This website</h2>
      <p>
        closetalk.dev has no analytics, no cookies and no tracking scripts. Fonts and images are served from this site,
        so your browser doesn&apos;t contact anyone else to load the page. Downloads come from GitHub, which counts them.
      </p>
      <p>
        You can check all of this yourself: the app and this site are open source on{" "}
        <a href={REPO_URL}>GitHub</a>.
      </p>
    </main>
  );
}
