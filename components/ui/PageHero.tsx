import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export interface PageHeroProps {
  eyebrow: string;
  title: string;
  lede: string;
  centered?: boolean;
  /** Extra content inside the text column (meta chips). */
  children?: ReactNode;
  /** Full-width content under the text (a product visual). */
  after?: ReactNode;
}

export function PageHero({ eyebrow, title, lede, centered, children, after }: PageHeroProps) {
  return (
    <section className={cn("phero", centered && "center")}>
      <div className="wrap">
        <p className="eyebrow">{eyebrow}</p>
        <h1>{title}</h1>
        <p className="lede">{lede}</p>
        {children}
      </div>
      {after}
    </section>
  );
}
