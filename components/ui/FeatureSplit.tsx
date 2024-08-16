import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import type { FeatureRow } from "@/types/content";
import { TickList } from "./TickList";

/** Text beside a product visual. `reverse` puts the visual on the left. */
export function FeatureSplit({ row, reverse, visual }: { row: FeatureRow; reverse?: boolean; visual: ReactNode }) {
  return (
    <div className={cn("row", reverse && "row-r")}>
      <div className="row-t">
        <p className="eyebrow">{row.eyebrow}</p>
        <h2>{row.title}</h2>
        <p>{row.body}</p>
        <TickList items={row.points} />
      </div>
      <div className="row-v">{visual}</div>
    </div>
  );
}
