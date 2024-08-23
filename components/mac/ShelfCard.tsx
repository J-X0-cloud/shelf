import { cn } from "@/lib/cn";
import type { ShelfPanel } from "@/types/shelf";
import { ShelfHeader } from "./ShelfHeader";
import { Tile } from "./Tile";

/** Glass shelf panel with a grid of tiles. */
export function ShelfCard({ shelf, className }: { shelf: ShelfPanel; className?: string }) {
  return (
    <div className={cn("shelf", className)}>
      <ShelfHeader title={shelf.title} color={shelf.color} count={shelf.items.length} />
      <div className="sh-g">
        {shelf.items.map((item) => (
          <Tile key={item.name} item={item} />
        ))}
      </div>
    </div>
  );
}
