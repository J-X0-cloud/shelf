import type { ReactNode } from "react";
import { cn } from "@/lib/cn";

export interface SectionHeadProps {
  eyebrow: string;
  title: string;
  centered?: boolean;
  children?: ReactNode;
}

export function SectionHead({ eyebrow, title, centered, children }: SectionHeadProps) {
  return (
    <div className={cn("sec-h", centered && "center")}>
      <p className="eyebrow">{eyebrow}</p>
      <h2>{title}</h2>
      {children ? <p>{children}</p> : null}
    </div>
  );
}
