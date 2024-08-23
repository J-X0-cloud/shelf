import { FeatureCard } from "@/components/ui/FeatureCard";
import { principles } from "@/lib/data/home";

export function Principles() {
  return (
    <section className="band">
      <div className="wrap">
        <div className="pr4">
          {principles.map((p) => (
            <FeatureCard key={p.title} feature={p} variant="plain" />
          ))}
        </div>
      </div>
    </section>
  );
}
