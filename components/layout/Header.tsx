"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useRef } from "react";
import { Button } from "@/components/ui/Button";
import { Icon } from "@/components/ui/Icon";
import { primaryNav } from "@/lib/data/site";
import { personalPlan } from "@/lib/data/pricing";
import { formatPrice } from "@/lib/format";
import { Brand } from "./Brand";

function NavLinks({ pathname }: { pathname: string }) {
  return (
    <>
      {primaryNav.map((link) => (
        <Link key={link.href} href={link.href} aria-current={pathname === link.href ? "page" : undefined}>
          {link.label}
        </Link>
      ))}
    </>
  );
}

export function Header() {
  const pathname = usePathname();
  const menu = useRef<HTMLDetailsElement>(null);

  // Close the mobile menu after client-side navigation.
  useEffect(() => {
    if (menu.current) menu.current.open = false;
  }, [pathname]);

  return (
    <header className="nav">
      <div className="wrap nav-in">
        <Brand />
        <nav className="nav-links" aria-label="Main">
          <NavLinks pathname={pathname} />
        </nav>
        <div className="nav-cta">
          <a className="btn btn-sm btn-dark" href="#download">
            <Icon name="down" size={16} strokeWidth={2} />
            <span>Download</span>
          </a>
          <details className="mnav" ref={menu}>
            <summary aria-label="Open menu">
              <span />
              <span />
            </summary>
            <div className="mnav-panel">
              <NavLinks pathname={pathname} />
              <Button href="/pricing">Buy Shelf — {formatPrice(personalPlan.price)}</Button>
            </div>
          </details>
        </div>
      </div>
    </header>
  );
}
