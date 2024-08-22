import { releases } from "@/lib/data/changelog";
import type { Release } from "@/types/changelog";

const dateFormat = new Intl.DateTimeFormat("en-US", {
  month: "short",
  day: "numeric",
  year: "numeric",
  timeZone: "UTC",
});

export const latestRelease: Release = releases[0];

/** "2.4.1" → "2.4" for download buttons. */
export function minorVersion(version: string): string {
  return version.split(".").slice(0, 2).join(".");
}

/** "2026-09-22" → "Sep 22, 2026". */
export function formatReleaseDate(iso: string): string {
  return dateFormat.format(new Date(`${iso}T00:00:00Z`));
}

/** Anchor used on the changelog page, e.g. "v2-4-1". */
export function releaseAnchor(version: string): string {
  return `v${version.replaceAll(".", "-")}`;
}

/** Bytes → "11.4 MB" (decimal megabytes, as Finder reports them). */
export function formatSize(bytes: number): string {
  return `${(bytes / 1_000_000).toFixed(1)} MB`;
}

const downloadBase = process.env.NEXT_PUBLIC_DOWNLOAD_BASE_URL ?? "https://downloads.shelfapp.com";

export function downloadUrl(release: Release = latestRelease): string {
  return `${downloadBase}/Shelf-${release.version}.dmg`;
}

export const download = {
  label: `Download Shelf ${minorVersion(latestRelease.version)}`,
  href: downloadUrl(),
  size: latestRelease.size ? formatSize(latestRelease.size) : undefined,
};
