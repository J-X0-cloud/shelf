import type { CSSProperties } from "react";
import type { ShelfItem } from "@/types/shelf";
import { AppGlyph } from "./AppGlyph";

/** One item on a shelf: document, folder, image thumbnail or app. */
export function Tile({ item }: { item: ShelfItem }) {
  let icon;
  switch (item.kind) {
    case "file":
      icon = (
        <div className="fi" style={{ "--c": item.color } as CSSProperties}>
          <i>{item.badge}</i>
        </div>
      );
      break;
    case "folder":
      icon = <div className="fo" style={{ "--c": item.color ?? "#7FA7D9" } as CSSProperties} />;
      break;
    case "image":
      icon = <div className="im" style={{ backgroundPosition: item.focus }} />;
      break;
    case "app":
      icon = (
        <div className="ap" style={{ background: item.background }}>
          <AppGlyph name={item.glyph} />
        </div>
      );
      break;
  }

  return (
    <div className="tile">
      {icon}
      <span>{item.name}</span>
    </div>
  );
}
