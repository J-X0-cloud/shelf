import { FeatureCard } from "@/components/ui/FeatureCard";
import type { Feature } from "@/types/content";

export function FeatureGrid({ features }: { features: Feature[] }) {
  return (
    <div className="fg-grid">
      {features.map((feature) => (
        <FeatureCard key={feature.title} feature={feature} variant="fg" />
      ))}
    </div>
  );
}
