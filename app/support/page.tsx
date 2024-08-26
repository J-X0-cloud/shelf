import type { Metadata } from "next";
import { DownloadCta } from "@/components/layout/DownloadCta";
import { ContactCard } from "@/components/support/ContactCard";
import { GettingStarted } from "@/components/support/GettingStarted";
import { FaqSection } from "@/components/ui/FaqSection";
import { InfoGrid } from "@/components/ui/InfoGrid";
import { PageHero } from "@/components/ui/PageHero";
import { gettingStarted, licenseHelp, troubleshooting } from "@/lib/data/support";

export const metadata: Metadata = {
  title: "Support",
  description: "Get started with Shelf, fix common issues, manage licenses and contact support.",
};

export default function SupportPage() {
  return (
    <>
      <PageHero
        eyebrow="Support"
        title="Help for a tidier Mac."
        lede="Setup takes about two minutes. If anything feels off, a real person reads every email, usually within one business day."
      />

      <section className="band">
        <div className="wrap sup-grid">
          <GettingStarted steps={gettingStarted} />
          <ContactCard />
        </div>
      </section>

      <FaqSection id="faq" eyebrow="Troubleshooting" title="Common questions." faqs={troubleshooting} />
      <InfoGrid id="license" blocks={licenseHelp} />
      <DownloadCta />
    </>
  );
}
