import { RulesCard } from "@/components/mac/RulesCard";
import { ShelfCard } from "@/components/mac/ShelfCard";
import { SpacesPopover } from "@/components/mac/SpacesPopover";
import { Stage } from "@/components/mac/Stage";
import { FeatureSplit } from "@/components/ui/FeatureSplit";
import { harborShelf, popoverActions, ruleSummaries, spaces } from "@/lib/data/desktop";
import { homeRows } from "@/lib/data/home";

/** Shelves, Spaces and Rules, each beside a standalone mock. */
export function Tour() {
  return (
    <section className="rows">
      <div className="wrap">
        <FeatureSplit
          row={homeRows.shelves}
          visual={
            <Stage backdrop="hills">
              <ShelfCard shelf={harborShelf} className="s-solo" />
            </Stage>
          }
        />
        <FeatureSplit
          row={homeRows.spaces}
          reverse
          visual={
            <Stage backdrop="dusk">
              <SpacesPopover spaces={spaces} actions={popoverActions} className="pop-solo" />
            </Stage>
          }
        />
        <FeatureSplit
          row={homeRows.rules}
          visual={
            <Stage backdrop="sage">
              <RulesCard rules={ruleSummaries} />
            </Stage>
          }
        />
      </div>
    </section>
  );
}
