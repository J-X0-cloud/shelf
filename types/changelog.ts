export type ChangeKind = "New" | "Improved" | "Fixed";

export interface Change {
  kind: ChangeKind;
  text: string;
}

export interface Release {
  version: string;
  /** ISO date (YYYY-MM-DD). */
  date: string;
  title?: string;
  summary?: string;
  changes: Change[];
  /** Download size in bytes of the notarized .dmg. */
  size?: number;
}
