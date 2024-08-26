import { buildAppcast } from "@/lib/appcast";
import { releases } from "@/lib/data/changelog";

export const dynamic = "force-static";

/** Sparkle update feed polled by the macOS app (SUFeedURL). */
export function GET() {
  const siteUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "https://shelfapp.com";
  return new Response(buildAppcast(releases, siteUrl), {
    headers: {
      "content-type": "application/rss+xml; charset=utf-8",
      "cache-control": "public, max-age=300, s-maxage=3600",
    },
  });
}
