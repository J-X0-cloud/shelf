import type { CSSProperties } from "react";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/cn";
import type { Rule, RuleCondition, SettingsPane } from "@/types/shelf";

function Condition({ condition }: { condition: RuleCondition }) {
  switch (condition.kind) {
    case "extension":
      return (
        <>
          name ends with <code>{condition.value}</code>
        </>
      );
    case "nameContains":
      return (
        <>
          name contains <code>{condition.value}</code>
        </>
      );
    case "screenshot":
      return <>is a screenshot</>;
    case "untouched":
      return <>untouched for {condition.days} days</>;
  }
}

function Switch({ on }: { on: boolean }) {
  return (
    <span className={cn("tg", on && "tg-on")} role="switch" aria-checked={on}>
      <i />
    </span>
  );
}

export interface SettingsWindowProps {
  panes: SettingsPane[];
  activePane: string;
  rules: Rule[];
}

/** The Settings window, open on the Rules pane. Mirrors `RulesSettings` in the macOS app. */
export function SettingsWindow({ panes, activePane, rules }: SettingsWindowProps) {
  return (
    <div className="win" role="img" aria-label={`Shelf settings, ${activePane} pane`}>
      <div className="win-bar">
        <span className="tl">
          <i />
          <i />
          <i />
        </span>
        <strong>{activePane}</strong>
      </div>
      <div className="win-in">
        <ul className="win-side">
          {panes.map((pane) => (
            <li key={pane.name} className={cn(pane.name === activePane && "on")}>
              <i style={{ background: pane.color }} />
              {pane.name}
            </li>
          ))}
        </ul>
        <div className="win-main">
          <div className="wm-h">
            <div>
              <h5>Rules</h5>
              <p>Shelf watches the folders you choose and files new items onto the right shelf.</p>
            </div>
            <span className="wm-btn">
              <Icon name="plus" size={12} strokeWidth={2.4} /> Add rule
            </span>
          </div>
          <div className="wm-opt">
            <span>Run rules automatically</span>
            <Switch on />
          </div>
          {rules.map((rule) => (
            <div key={`${rule.source}-${rule.shelf}`} className="rule">
              <div className="rl-t">
                <Switch on={rule.enabled} />
              </div>
              <div className="rl-b">
                <p>
                  <span className="chip">
                    When a file in <b>{rule.source}</b>
                  </span>{" "}
                  <span className="chip">
                    <Condition condition={rule.condition} />
                  </span>
                </p>
                <p className="rl-to">
                  → put it on <b style={{ "--d": rule.color } as CSSProperties} />
                  <strong>{rule.shelf}</strong> <em>in {rule.space}</em>
                </p>
              </div>
            </div>
          ))}
          <p className="wm-foot">Rules run on this Mac only. Nothing is uploaded.</p>
        </div>
      </div>
    </div>
  );
}
