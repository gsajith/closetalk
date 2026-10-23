import type { Metadata } from "next";
import { Bricolage_Grotesque } from "next/font/google";
import Link from "next/link";
import "./globals.css";
import { DOWNLOAD_URL, REPO_URL } from "./site";

// next/font downloads the face at build time and serves it from this site, so visitors'
// browsers never contact Google. The page makes no third-party requests at all.
const bricolage = Bricolage_Grotesque({
  subsets: ["latin"],
  weight: ["500", "600", "800"],
  variable: "--font-bricolage",
});

export const metadata: Metadata = {
  metadataBase: new URL("https://closetalk.dev"),
  title: "Closetalk: push-to-talk dictation that runs on your Mac",
  description:
    "Hold right ⌘, say the prompt, let go. Closetalk types it wherever your cursor is. Free, no account, and nothing you say leaves your Mac.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={bricolage.variable}>
      <body>
        <header className="masthead">
          <Link href="/" className="wordmark" aria-label="Closetalk home">
            <span className="plate plate-pink" aria-hidden="true">Closetalk</span>
            <span className="plate plate-blue">Closetalk</span>
          </Link>
          <nav aria-label="Site">
            <Link href="/#questions">Questions</Link>
            <Link href="/privacy">Privacy</Link>
            <a href={REPO_URL}>GitHub</a>
            <a className="nav-download" href={DOWNLOAD_URL}>Download</a>
          </nav>
        </header>
        {children}
        <footer className="colophon">
          <p>Closetalk is made by Gautham Sajith and released under the MIT license.</p>
          <p>
            <Link href="/privacy">Privacy</Link>
            <a href={REPO_URL}>Source on GitHub</a>
          </p>
        </footer>
        {/* Ink grain for display type: roughens the edges and knocks specks out of the solids. */}
        <svg width="0" height="0" aria-hidden="true" style={{ position: "absolute" }}>
          <filter id="ink" x="-5%" y="-10%" width="110%" height="120%">
            <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves={2} seed={7} result="warp" />
            <feDisplacementMap in="SourceGraphic" in2="warp" scale={2} xChannelSelector="R" yChannelSelector="G" result="rough" />
            <feTurbulence type="fractalNoise" baseFrequency="1.1" numOctaves={1} seed={2} result="grain" />
            <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -3 2.6" result="mask" />
            <feComposite in="rough" in2="mask" operator="in" />
          </filter>
          {/* Ink for large floods: slow, uneven density like a Riso drum laying down ink, plus sparse
              specks. The type filter above turns into a woven pattern at this size. Density never drops
              below 92%, so text knocked out of the flood keeps at least 3:1 contrast. */}
          <filter id="flood" x="0" y="0" width="100%" height="100%">
            <feTurbulence type="fractalNoise" baseFrequency="0.006 0.018" numOctaves={3} seed={11} result="mottle" />
            <feColorMatrix in="mottle" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.25 0.92" result="density" />
            <feTurbulence type="fractalNoise" baseFrequency="0.33" numOctaves={2} seed={4} result="speck" />
            <feColorMatrix in="speck" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 -9 7.4" result="speckMask" />
            <feComposite in="density" in2="speckMask" operator="in" result="mask" />
            <feComposite in="SourceGraphic" in2="mask" operator="in" />
          </filter>
        </svg>
      </body>
    </html>
  );
}
