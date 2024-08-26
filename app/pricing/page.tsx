import type { Metadata } from "next";
import { DownloadCta } from "@/components/layout/DownloadCta";
import { CompareTable } from "@/components/pricing/CompareTable";
import { PlanCard } from "@/components/pricing/PlanCard";
import { FaqSection } from "@/components/ui/FaqSection";
import { PageHero } from "@/components/ui/PageHero";
import { SectionHead } from "@/components/ui/SectionHead";
import { compareRows, plans, pricingFaqs } from "@/lib/data/pricing";
import { supportEmail } from "@/lib/data/site";

export const metadata: Metadata = {
  title: "Pricing",
  description:
    "Shelf is $19 once for up to three Macs, with Family and Team licenses. 14-day free trial and 30-day refunds.",
};

export default function PricingPage() {
  return (
    <>
      <PageHero
        centered
        eyebrow="Pricing"
        title="Pay once. Tidy forever."
        lede="No subscription and no account. Try every feature free for 14 days, then pick the license that fits."
      />

      <section className="plans">
        <div className="wrap plan-grid">
          {plans.map((plan) => (
            <PlanCard key={plan.id} plan={plan} />
          ))}
        </div>
        <p className="wrap fine center">
          Prices in USD. Sales tax or VAT added at checkout where required. 30-day refunds on every plan.
        </p>
      </section>

      <section className="band">
        <div className="wrap">
          <SectionHead eyebrow="Compare" title="What's in each license." />
          <CompareTable plans={plans} rows={compareRows} />
        </div>
      </section>

      <FaqSection
        eyebrow="Licensing"
        title="Straight answers."
        faqs={pricingFaqs}
        intro={
          <>
            Questions about invoices or volume licensing? Write to <a href={`mailto:${supportEmail}`}>{supportEmail}</a>
            .
          </>
        }
      />
      <DownloadCta />
    </>
  );
}
