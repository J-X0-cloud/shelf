import type { Metadata } from "next";
import { FeatureGrid } from "@/components/features/FeatureGrid";
import { ShortcutTable } from "@/components/features/ShortcutTable";
import { DownloadCta } from "@/components/layout/DownloadCta";
import { SettingsWindow } from "@/components/mac/SettingsWindow";
import { ShelfCard } from "@/components/mac/ShelfCard";
import { SpacesPopover } from "@/components/mac/SpacesPopover";
import { Stage } from "@/components/mac/Stage";
import { FeatureSplit } from "@/components/ui/FeatureSplit";
import { InfoGrid } from "@/components/ui/InfoGrid";
import { PageHero } from "@/components/ui/PageHero";
import { SectionHead } from "@/components/ui/SectionHead";
import { inboxShelf, popoverActions, rules, settingsPanes, spaces } from "@/lib/data/desktop";
import { featureGrid, featureRows, requirements, shortcuts } from "@/lib/data/features";

export const metadata: Metadata = {
  title: "Features",
  description:
    "Floating shelves, Spaces, Rules, Stash, instant search and keyboard shortcuts. A tour of everything Shelf does on your Mac.",
};

export default function FeaturesPage() {
  return (
    <>
      <PageHero
        eyebrow="Features"
        title="Small app. Carefully finished."
        lede="Everything Shelf does fits in your menu bar and a single settings window. Here's the tour."
        after={
          <div className="wrap win-stage">
            <Stage backdrop="hills" className="stage-win">
              <SettingsWindow panes={settingsPanes} activePane="Rules" rules={rules} />
            </Stage>
          </div>
        }
      />

      <section className="band">
        <div className="wrap">
          <SectionHead eyebrow="At a glance" title="Nine things Shelf does well." />
          <FeatureGrid features={featureGrid} />
        </div>
      </section>

      <section className="rows">
        <div className="wrap">
          <FeatureSplit
            row={featureRows.spaces}
            visual={
              <Stage backdrop="dusk">
                <SpacesPopover spaces={spaces} actions={popoverActions} className="pop-solo" />
              </Stage>
            }
          />
          <FeatureSplit
            row={featureRows.native}
            reverse
            visual={
              <Stage backdrop="sage">
                <ShelfCard shelf={inboxShelf} className="s-solo" />
              </Stage>
            }
          />
        </div>
      </section>

      <section className="band" id="shortcuts">
        <div className="wrap sc-in">
          <SectionHead eyebrow="Shortcuts" title="Default shortcuts.">
            All of them can be changed in Settings → Shortcuts, and Shelf warns you about conflicts before you save.
          </SectionHead>
          <ShortcutTable shortcuts={shortcuts} />
        </div>
      </section>

      <InfoGrid blocks={requirements} />
      <DownloadCta />
    </>
  );
}
