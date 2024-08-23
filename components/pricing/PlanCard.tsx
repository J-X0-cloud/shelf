import { cn } from "@/lib/cn";
import { formatPrice } from "@/lib/format";
import { TickList } from "@/components/ui/TickList";
import type { Plan } from "@/types/pricing";

export function PlanCard({ plan }: { plan: Plan }) {
  return (
    <article className={cn("plan", plan.highlighted && "plan-hi")}>
      {plan.highlighted ? <span className="badge">Most popular</span> : null}
      <h3>{plan.name}</h3>
      <p className="pl-d">{plan.description}</p>
      <div className="pl-p">
        <strong>{formatPrice(plan.price)}</strong>
        <em>{plan.unit}</em>
      </div>
      <TickList items={plan.features} />
      <a className={cn("btn", plan.highlighted ? "btn-accent" : "btn-dark")} href={`/api/checkout?plan=${plan.id}`}>
        {plan.cta}
      </a>
    </article>
  );
}
