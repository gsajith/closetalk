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
        Closetalk goes online for two things: downloading the speech model from Hugging Face the first time you
        launch it, and checking closetalk.dev for updates once a day. The update check sends nothing about
        you or what you dictate. Dictation works offline.
      </p>
      <p>
        Audio, transcripts and clipboard contents stay on your Mac. Closetalk keeps audio in memory only while
        you&apos;re dictating and never writes it to disk. Closetalk has no account and no telemetry.
      </p>
      <h2>This website</h2>
      <p>
        closetalk.dev has no analytics, no cookies and no tracking scripts. Fonts and images are served from this site,
        so your browser doesn&apos;t contact anyone else to load the page. The app and its updates download from GitHub, which counts downloads.
      </p>
      <p>
        You can check all of this yourself: the app and this site are open source on{" "}
        <a href={REPO_URL}>GitHub</a>.
      </p>
    </main>
  );
}
