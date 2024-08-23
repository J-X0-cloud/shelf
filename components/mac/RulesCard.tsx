import type { CSSProperties } from "react";
import { Icon } from "@/components/ui/Icon";
import type { RuleSummary } from "@/types/shelf";

/** Compact list of running rules: source → destination shelf. */
export function RulesCard({ rules }: { rules: RuleSummary[] }) {
  return (
    <div className="rcard">
      <p className="rc-h">
        <Icon name="wand" size={16} /> Rules · running
      </p>
      {rules.map((rule) => (
        <div key={rule.source} className="rmini">
          <span className="rm-src">
            <Icon name={rule.icon} size={16} />
            {rule.source}
          </span>
          <span className="rm-ar">
            <Icon name="arrow" size={16} strokeWidth={2} />
          </span>
          <span className="rm-dst">
            <b style={{ "--d": rule.color } as CSSProperties} />
            {rule.shelf}
          </span>
        </div>
      ))}
    </div>
  );
}
