import type { CSSProperties } from "react";
import type { ReadingItem } from "@/types/shelf";
import { ShelfHeader } from "./ShelfHeader";

export interface ReadingShelfProps {
  title: string;
  color: string;
  items: ReadingItem[];
}

/** List-style shelf for links and notes. */
export function ReadingShelf({ title, color, items }: ReadingShelfProps) {
  return (
    <div className="shelf shelf-list">
      <ShelfHeader title={title} color={color} count={items.length} />
      <ul>
        {items.map((item) => (
          <li key={item.title}>
            <b style={{ "--d": item.color } as CSSProperties} />
            <span>
              <strong>{item.title}</strong>
              <em>{item.meta}</em>
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
