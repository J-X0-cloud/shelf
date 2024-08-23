import {
  dockApps,
  dockSettingsApp,
  dockStackColors,
  harborShelf,
  inboxShelf,
  menuBar,
  popoverActions,
  readingShelf,
  spaces,
} from "@/lib/data/desktop";
import { Dock } from "./Dock";
import { MenuBar } from "./MenuBar";
import { ReadingShelf } from "./ReadingShelf";
import { ShelfCard } from "./ShelfCard";
import { SpacesPopover } from "./SpacesPopover";

/**
 * Full macOS desktop mock. Everything inside `.desk` is sized in em off a container-query
 * font size, so the scene scales as one piece from a wide monitor down to a phone.
 */
export function Desktop() {
  return (
    <div
      className="mock-wrap"
      role="img"
      aria-label="Shelf running on a Mac desktop with three shelves and the Spaces menu open"
    >
      <div className="desk">
        <MenuBar app={menuBar.app} menus={menuBar.menus} clock={menuBar.clock} />
        <ShelfCard shelf={inboxShelf} className="s-inbox" />
        <ShelfCard shelf={harborShelf} className="s-harbor" />
        <ReadingShelf title={readingShelf.title} color={readingShelf.color} items={readingShelf.items} />
        <SpacesPopover spaces={spaces} actions={popoverActions} className="pop-desk" />
        <Dock apps={dockApps} stackColors={dockStackColors} trailing={dockSettingsApp} />
      </div>
    </div>
  );
}
