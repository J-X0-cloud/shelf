import Link from "next/link";
import { Button } from "@/components/ui/Button";
import { copyright, footerBlurb, footerColumns } from "@/lib/data/site";
import { formatReleaseDate, latestRelease } from "@/lib/release";
import { Brand } from "./Brand";

export function Footer() {
  return (
    <footer className="foot">
      <div className="wrap foot-grid">
        <div className="foot-brand">
          <Brand />
          <p>{footerBlurb}</p>
          <Button href="#download" variant="ghost-light" size="sm" icon="down">
            Download free trial
          </Button>
        </div>
        {footerColumns.map((column) => (
          <div key={column.title}>
            <h4>{column.title}</h4>
            {column.links.map((link) =>
              link.href.startsWith("/") ? (
                <Link key={link.label} href={link.href}>
                  {link.label}
                </Link>
              ) : (
                <a key={link.label} href={link.href}>
                  {link.label}
                </a>
              ),
            )}
          </div>
        ))}
      </div>
      <div className="wrap foot-base">
        <span>{copyright}</span>
        <span className="foot-ver">
          Shelf {latestRelease.version} · {formatReleaseDate(latestRelease.date)}
        </span>
      </div>
    </footer>
  );
}
