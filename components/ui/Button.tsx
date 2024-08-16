import Link from "next/link";
import type { ReactNode } from "react";
import { cn } from "@/lib/cn";
import { Icon, type IconName } from "./Icon";

export type ButtonVariant = "accent" | "dark" | "line" | "ghost-light";
export type ButtonSize = "sm" | "md" | "lg";

export interface ButtonProps {
  href: string;
  variant?: ButtonVariant;
  size?: ButtonSize;
  icon?: IconName;
  className?: string;
  children: ReactNode;
}

const iconSize: Record<ButtonSize, number> = { sm: 16, md: 16, lg: 18 };

/** Pill-shaped link button. Internal routes use next/link; anchors, mail and downloads use <a>. */
export function Button({ href, variant = "accent", size = "md", icon, className, children }: ButtonProps) {
  const classes = cn("btn", `btn-${variant}`, size !== "md" && `btn-${size}`, className);
  const content = (
    <>
      {icon ? <Icon name={icon} size={iconSize[size]} strokeWidth={2} /> : null}
      {children}
    </>
  );

  return href.startsWith("/") ? (
    <Link href={href} className={classes}>
      {content}
    </Link>
  ) : (
    <a href={href} className={classes}>
      {content}
    </a>
  );
}
