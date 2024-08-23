import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export type StageBackdrop = "hills" | "dusk" | "sage";

/** Wallpaper-like backdrop for a standalone mock. */
export function Stage({
  backdrop,
  className,
  children,
}: {
  backdrop: StageBackdrop;
  className?: string;
  children: ReactNode;
}) {
  return <div className={cn("stage", `stage-${backdrop}`, className)}>{children}</div>;
}
