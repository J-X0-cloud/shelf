import Link from "next/link";
import { Desktop } from "@/components/mac/Desktop";
import { Button } from "@/components/ui/Button";
import { Icon } from "@/components/ui/Icon";
import { personalPlan } from "@/lib/data/pricing";
import { systemRequirements } from "@/lib/data/site";
import { formatPrice } from "@/lib/format";
import { minorVersion, latestRelease } from "@/lib/release";

export function Hero() {
  return (
    <section className="hero">
      <div className="wrap hero-in">
        <Link className="pill" href="/changelog">
          <b>New</b> Shelf {minorVersion(latestRelease.version)} brings Rules to every Space{" "}
          <Icon name="arrow" size={14} strokeWidth={2} />
        </Link>
        <h1>
          A tidy Mac,
          <br />
          <span>one shelf at a time.</span>
        </h1>
        <p className="lede">
          Shelf lives in your menu bar and turns Dock and desktop clutter into neat, labeled shelves, grouped into
          Spaces for every client, project or mode of work.
        </p>
        <div className="hero-btns">
          <Button href="#download" size="lg" icon="down">
            Download free trial
          </Button>
          <Button href="/pricing" variant="line" size="lg">
            {formatPrice(personalPlan.price)} once · Buy Shelf
          </Button>
        </div>
        <p className="fine">
          {systemRequirements.trialDays}-day full trial · {systemRequirements.shortMacOS} · Apple silicon &amp; Intel
        </p>
      </div>
      <div className="wrap hero-mock">
        <Desktop />
      </div>
    </section>
  );
}
