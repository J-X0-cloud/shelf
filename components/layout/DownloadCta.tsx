import Image from "next/image";
import { Button } from "@/components/ui/Button";
import { download } from "@/lib/release";
import { personalPlan } from "@/lib/data/pricing";
import { systemRequirements } from "@/lib/data/site";
import { formatPrice } from "@/lib/format";

/** Closing download section, shared by every page. `#download` anchors point here. */
export function DownloadCta() {
  return (
    <section className="cta" id="download">
      <div className="wrap cta-in">
        <Image src="/shelf-icon.svg" alt="" width={88} height={88} className="cta-ic" />
        <h2>Give every project its own shelf.</h2>
        <p>
          Try everything free for {systemRequirements.trialDays} days. No account, no email, no card. If Shelf earns a
          spot in your menu bar, it&apos;s {formatPrice(personalPlan.price)} once.
        </p>
        <div className="cta-btns">
          <Button href={download.href} size="lg" icon="down">
            {download.label}
          </Button>
          <Button href="/pricing" variant="ghost-light" size="lg">
            Buy a license
          </Button>
        </div>
        <p className="fine">
          {systemRequirements.macOS} · {systemRequirements.architectures} · {download.size}
        </p>
      </div>
    </section>
  );
}
