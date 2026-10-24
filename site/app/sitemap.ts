import type { MetadataRoute } from "next";

export const dynamic = "force-static";

// Add new pages here so search engines find them.
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: "https://closetalk.dev/", changeFrequency: "monthly", priority: 1 },
    { url: "https://closetalk.dev/privacy", changeFrequency: "yearly", priority: 0.3 },
  ];
}
