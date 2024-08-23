import type { CSSProperties } from "react";
import type { DockApp } from "@/types/shelf";
import { AppGlyph } from "./AppGlyph";

export interface DockProps {
  apps: DockApp[];
  stackColors: string[];
  trailing: DockApp;
}

/** macOS Dock with the Shelf app, the current Space's Dock stack and a trailing app. */
export function Dock({ apps, stackColors, trailing }: DockProps) {
  return (
    <div className="dock">
      <div className="dk-grp">
        {apps.map((app) => (
          <i key={app.name} className="dk-a" style={{ background: app.background }} title={app.name}>
            <AppGlyph name={app.glyph} />
          </i>
        ))}
      </div>
      <span className="dk-sep" />
      <div className="dk-grp">
        <i className="dk-a dk-shelf" title="Shelf">
          {/* eslint-disable-next-line @next/next/no-img-element -- decorative SVG inside a scaled mock */}
          <img src="/shelf-icon.svg" alt="" />
          <b className="dk-dot" />
        </i>
        <i className="dk-stack" title="Shelf stack">
          {stackColors.map((color) => (
            <u key={color} style={{ "--c": color } as CSSProperties} />
          ))}
        </i>
        <i className="dk-a" style={{ background: trailing.background }} title={trailing.name}>
          <AppGlyph name={trailing.glyph} />
        </i>
      </div>
    </div>
  );
}
