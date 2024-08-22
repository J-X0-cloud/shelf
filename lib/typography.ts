/** Joins characters with U+2060 WORD JOINER so short key sequences never wrap mid-way. */
export function keepTogether(text: string): string {
  return [...text].join("⁠");
}

/** "⌘1–9", unbreakable. */
export const SPACE_KEYS = keepTogether("⌘1–9");
