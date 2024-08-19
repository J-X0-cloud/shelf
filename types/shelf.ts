import type { AppGlyphName } from "@/components/mac/AppGlyph";

/** Something that can sit on a shelf. Mirrors `ShelfItem.Kind` in the macOS app. */
export type ShelfItem =
  | { kind: "file"; name: string; /** Badge on the document icon, e.g. "PDF". */ badge: string; color: string }
  | { kind: "folder"; name: string; color?: string }
  | { kind: "image"; name: string; /** background-position of the thumbnail crop. */ focus: string }
  | { kind: "app"; name: string; background: string; glyph: AppGlyphName };

export interface ShelfPanel {
  title: string;
  color: string;
  items: ShelfItem[];
}

export interface ReadingItem {
  title: string;
  meta: string;
  color: string;
}

export interface SpaceSummary {
  name: string;
  color: string;
  shelfCount: number;
  shortcut: string;
  active?: boolean;
}

export interface MenuAction {
  label: string;
  keys: string;
}

export type RuleSource = "Downloads" | "Desktop" | "Any shelf";

export type RuleCondition =
  | { kind: "extension"; value: string }
  | { kind: "nameContains"; value: string }
  | { kind: "screenshot" }
  | { kind: "untouched"; days: number };

export interface Rule {
  source: RuleSource;
  condition: RuleCondition;
  shelf: string;
  space: string;
  color: string;
  enabled: boolean;
}

export interface RuleSummary {
  icon: "stash" | "book" | "link" | "sync";
  source: string;
  shelf: string;
  color: string;
}

export interface DockApp {
  name: string;
  background: string;
  glyph: AppGlyphName;
}

export interface SettingsPane {
  name: string;
  color: string;
}
