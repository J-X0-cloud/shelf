import { Button } from "@/components/ui/Button";
import { TickList } from "@/components/ui/TickList";
import { personalPlan, priceTeaserPoints } from "@/lib/data/pricing";
import { formatPrice } from "@/lib/format";

export function PriceTeaser() {
  return (
    <section className="price-teaser">
      <div className="wrap pt-in">
        <div>
          <p className="eyebrow">Pricing</p>
          <h2>Buy it once. Keep it.</h2>
          <p>
            One license covers up to three of your Macs and every 2.x update. Family and team licenses are on the
            pricing page.
          </p>
        </div>
        <div className="pt-card">
          <div className="pt-top">
            <span>{personalPlan.name}</span>
            <strong>{formatPrice(personalPlan.price)}</strong>
            <em>{personalPlan.unit}</em>
          </div>
          <TickList items={priceTeaserPoints} />
          <Button href="/pricing">See all plans</Button>
        </div>
      </div>
    </section>
  );
}
