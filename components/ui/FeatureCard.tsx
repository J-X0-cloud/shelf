import type { Feature } from "@/types/content";
import { Icon } from "./Icon";

/** Icon + title + body. `variant` picks the card style used by each grid. */
export function FeatureCard({ feature, variant = "f3" }: { feature: Feature; variant?: "f3" | "fg" | "plain" }) {
  const body = (
    <>
      <span className="f3-i">
        <Icon name={feature.icon} size={variant === "fg" ? 20 : 22} />
      </span>
      <h3>{feature.title}</h3>
      <p>{feature.body}</p>
    </>
  );
  return variant === "plain" ? <div>{body}</div> : <article className={variant}>{body}</article>;
}
