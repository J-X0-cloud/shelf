import { Hero } from "@/components/home/Hero";
import { Ideas } from "@/components/home/Ideas";
import { Keys } from "@/components/home/Keys";
import { PriceTeaser } from "@/components/home/PriceTeaser";
import { Principles } from "@/components/home/Principles";
import { Testimonials } from "@/components/home/Testimonials";
import { Tour } from "@/components/home/Tour";
import { DownloadCta } from "@/components/layout/DownloadCta";
import { FaqSection } from "@/components/ui/FaqSection";
import Link from "next/link";
import { homeFaqs } from "@/lib/data/home";

export default function HomePage() {
  return (
    <>
      <Hero />
      <Ideas />
      <Tour />
      <Keys />
      <Principles />
      <Testimonials />
      <PriceTeaser />
      <FaqSection
        eyebrow="Questions"
        title="Good to know."
        faqs={homeFaqs}
        intro={
          <>
            Can&apos;t find it here? The <Link href="/support">help center</Link> covers setup, licenses and
            troubleshooting.
          </>
        }
      />
      <DownloadCta />
    </>
  );
}
