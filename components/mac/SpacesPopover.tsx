import type { CSSProperties } from "react";
import { Icon } from "@/components/ui/Icon";
import { cn } from "@/lib/cn";
import type { MenuAction, SpaceSummary } from "@/types/shelf";

export interface SpacesPopoverProps {
  spaces: SpaceSummary[];
  actions: MenuAction[];
  className?: string;
}

/** The menu-bar popover: search, Spaces with shortcuts, and quick actions. */
export function SpacesPopover({ spaces, actions, className }: SpacesPopoverProps) {
  return (
    <div className={cn("pop", className)}>
      <div className="pop-s">
        <Icon name="search" size={14} strokeWidth={2} />
        <span>Search shelves and files</span>
        <kbd>⌘K</kbd>
      </div>
      <p className="pop-l">Spaces</p>
      <ul className="pop-list">
        {spaces.map((space) => (
          <li key={space.name} className={cn(space.active && "on")}>
            <b style={{ "--d": space.color } as CSSProperties} />
            <span>
              <strong>{space.name}</strong>
              <em>
                {space.shelfCount} {space.shelfCount === 1 ? "shelf" : "shelves"}
              </em>
            </span>
            <kbd>{space.shortcut}</kbd>
          </li>
        ))}
      </ul>
      <hr />
      <ul className="pop-act">
        {actions.map((action) => (
          <li key={action.label}>
            {action.label}
            <kbd>{action.keys}</kbd>
          </li>
        ))}
      </ul>
      <hr />
      <ul className="pop-act">
        <li>
          Settings…<kbd>⌘,</kbd>
        </li>
      </ul>
    </div>
  );
}
