import type { ReactNode } from "react";

/** Generic app glyphs for Dock and shelf tiles. */
const glyphs = {
  mail: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8">
      <rect x="3.5" y="6" width="17" height="12" rx="2" />
      <path d="m4.5 7.5 7.5 5.5 7.5-5.5" />
    </svg>
  ),
  note: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#6d5a2c" strokeWidth="1.8" strokeLinecap="round">
      <path d="M7 9h10M7 13h10M7 17h6" />
    </svg>
  ),
  cal: (
    <svg viewBox="0 0 24 24">
      <text
        x="12"
        y="17.5"
        textAnchor="middle"
        fontSize="12"
        fontWeight="700"
        fill="#1B1916"
        fontFamily="var(--fd), sans-serif"
      >
        24
      </text>
      <rect x="3" y="3" width="18" height="4" rx="1" fill="#E4572E" />
    </svg>
  ),
  term: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#9fe0b5" strokeWidth="1.9" strokeLinecap="round">
      <path d="m6 8 4 4-4 4M12 16h6" />
    </svg>
  ),
  pen: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8" strokeLinejoin="round">
      <path d="M12 3 5 12l7 9 7-9Z" />
      <circle cx="12" cy="12" r="1.8" />
    </svg>
  ),
  chat: (
    <svg viewBox="0 0 24 24" fill="#fff">
      <path d="M12 4c4.7 0 8.5 3 8.5 6.8s-3.8 6.8-8.5 6.8c-.9 0-1.8-.1-2.6-.3L5 19.5l1-3.4c-1.6-1.3-2.5-3.1-2.5-5.3C3.5 7 7.3 4 12 4Z" />
    </svg>
  ),
  music: (
    <svg viewBox="0 0 24 24" fill="#fff">
      <path d="M9 17.5V6.5l10-2v11" />
      <circle cx="7" cy="17.5" r="2.5" />
      <circle cx="17" cy="15.5" r="2.5" />
      <path d="M9 6.5 19 4.5v3L9 9.5Z" />
    </svg>
  ),
  globe: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.6">
      <circle cx="12" cy="12" r="8" />
      <path d="M4 12h16M12 4c2.5 2.3 3.5 5 3.5 8s-1 5.7-3.5 8c-2.5-2.3-3.5-5-3.5-8s1-5.7 3.5-8Z" />
    </svg>
  ),
  photo: (
    <svg viewBox="0 0 24 24">
      <circle cx="12" cy="8" r="3.4" fill="#F5B83D" />
      <circle cx="8" cy="14" r="3.4" fill="#E4572E" opacity=".85" />
      <circle cx="16" cy="14" r="3.4" fill="#5E9C7E" opacity=".85" />
    </svg>
  ),
  files: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8">
      <path d="M4 7.5A1.5 1.5 0 0 1 5.5 6H10l2 2h6.5A1.5 1.5 0 0 1 20 9.5v8a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 4 17.5Z" />
    </svg>
  ),
  set: (
    <svg viewBox="0 0 24 24" fill="none" stroke="#fff" strokeWidth="1.8">
      <circle cx="12" cy="12" r="3" />
      <path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1" />
    </svg>
  ),
} satisfies Record<string, ReactNode>;

export type AppGlyphName = keyof typeof glyphs;

export function AppGlyph({ name }: { name: AppGlyphName }) {
  return glyphs[name];
}
