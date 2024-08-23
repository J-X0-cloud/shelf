import type { CSSProperties } from "react";

export function ShelfHeader({ title, color, count }: { title: string; color: string; count: number }) {
  return (
    <div className="sh-h">
      <b style={{ "--d": color } as CSSProperties} />
      <strong>{title}</strong>
      <em>{count}</em>
      <span className="sh-x" aria-hidden="true">
        •••
      </span>
    </div>
  );
}
