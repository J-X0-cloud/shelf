import type { Metadata } from "next";
import Link from "next/link";
import { ReleaseEntry } from "@/components/changelog/ReleaseEntry";
import { DownloadCta } from "@/components/layout/DownloadCta";
import { Icon } from "@/components/ui/Icon";
import { PageHero } from "@/components/ui/PageHero";
import { releases } from "@/lib/data/changelog";
import { latestRelease } from "@/lib/release";

export const metadata: Metadata = {
  title: "Changelog",
  description:
    "Release notes for Shelf, the macOS menu-bar organizer. Version 2.4 adds per-Space Rules, rule previews and undo.",
};

export default function ChangelogPage() {
  return (
    <>
      <PageHero
        eyebrow="Changelog"
        title="What's new in Shelf."
        lede="Shelf updates itself in the background and asks before installing. Here's everything that changed, newest first."
      >
        <div className="cl-meta">
          <span>
            <Icon name="sync" size={16} /> Current version <b>{latestRelease.version}</b>
          </span>
          <span>
            <Icon name="check" size={16} strokeWidth={2.2} /> Signed &amp; notarized
          </span>
        </div>
      </PageHero>

      <section className="cl">
        <div className="wrap cl-in">
          {releases.map((release) => (
            <ReleaseEntry key={release.version} release={release} />
          ))}
          <p className="fine">
            Looking for 1.x release notes? They&apos;re archived in the <Link href="/support">help center</Link>.
          </p>
        </div>
      </section>
      <DownloadCta />
    </>
  );
}
