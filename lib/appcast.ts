import type { Release } from "@/types/changelog";
import { downloadUrl } from "./release";

const escape = (text: string) =>
  text.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");

function notesHtml(release: Release): string {
  const items = release.changes.map((c) => `<li><strong>${c.kind}</strong> ${escape(c.text)}</li>`).join("");
  const intro = release.summary ? `<p>${escape(release.summary)}</p>` : "";
  return `${intro}<ul>${items}</ul>`;
}

/**
 * Builds the Sparkle appcast the macOS app polls for updates. Only releases with a known
 * download size are published; older builds stay in the changelog but not in the feed.
 */
export function buildAppcast(releases: Release[], siteUrl: string): string {
  const items = releases
    .filter((r) => r.size)
    .map(
      (r) => `    <item>
      <title>Shelf ${r.version}</title>
      <pubDate>${new Date(`${r.date}T16:00:00Z`).toUTCString()}</pubDate>
      <sparkle:version>${r.version}</sparkle:version>
      <sparkle:shortVersionString>${r.version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>${siteUrl}/changelog#v${r.version.replaceAll(".", "-")}</sparkle:releaseNotesLink>
      <description><![CDATA[${notesHtml(r)}]]></description>
      <enclosure url="${downloadUrl(r)}" length="${r.size}" type="application/octet-stream" />
    </item>`,
    )
    .join("\n");

  return `<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Shelf</title>
    <link>${siteUrl}/appcast.xml</link>
    <language>en</language>
${items}
  </channel>
</rss>
`;
}
