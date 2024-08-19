import type { Release } from "@/types/changelog";

/** Release notes, newest first. Also feeds the Sparkle appcast at /appcast.xml. */
export const releases: Release[] = [
  {
    version: "2.4.1",
    date: "2026-09-22",
    summary: "A small follow-up to 2.4 with fixes reported in the first week.",
    size: 11_402_388,
    changes: [
      {
        kind: "Fixed",
        text: "Rules that watch iCloud Drive folders no longer run twice when a file finishes downloading.",
      },
      { kind: "Fixed", text: "Shelves pinned to the right edge keep their position after changing display scaling." },
      { kind: "Improved", text: "Quick Look opens faster for large PDFs on Intel Macs." },
    ],
  },
  {
    version: "2.4.0",
    date: "2026-09-15",
    title: "Rules for every Space",
    summary:
      "Rules were global until now. In 2.4 each Space can have its own set, so a client Space can file that client's downloads without touching anything else.",
    size: 11_388_214,
    changes: [
      { kind: "New", text: "Per-Space Rules, with a global section for rules that should always run." },
      { kind: "New", text: "Rule preview shows the files a rule would catch before you turn it on." },
      { kind: "New", text: "Undo the last automatic move from the menu bar for up to ten minutes." },
      { kind: "Improved", text: "The Rules pane was redesigned with plain-language conditions." },
    ],
  },
  {
    version: "2.3.2",
    date: "2026-08-28",
    summary: "Stability release.",
    changes: [
      { kind: "Fixed", text: "A rare crash when dragging a folder alias onto a collapsed shelf." },
      { kind: "Fixed", text: "Dock stack showed the previous Space's items after waking from sleep." },
    ],
  },
  {
    version: "2.3.0",
    date: "2026-08-04",
    title: "Focus-aware Spaces",
    summary:
      "Spaces can now follow your Focus modes. Turn on Work and your Studio Space comes forward; switch to Personal and it steps aside.",
    changes: [
      { kind: "New", text: "Link any Space to one or more Focus modes." },
      { kind: "New", text: "Space colors tint the menu bar icon so you always know where you are." },
      { kind: "Improved", text: "Switching Spaces is smoother on 120 Hz displays." },
    ],
  },
  {
    version: "2.2.0",
    date: "2026-06-30",
    title: "Search everything",
    changes: [
      { kind: "New", text: "⌘K searches every shelf in every Space, including indexed file contents." },
      { kind: "New", text: "Web links on shelves show page titles and favicons, fetched once and stored locally." },
      { kind: "Fixed", text: "Sorting by date added now survives a relaunch." },
    ],
  },
  {
    version: "2.0.0",
    date: "2026-04-14",
    title: "Shelf 2",
    summary:
      "A rebuilt app with Spaces, a new settings window and support for multiple displays. Free for every 1.x license holder.",
    changes: [
      { kind: "New", text: "Spaces: saved sets of shelves you can switch between instantly." },
      { kind: "New", text: "Multi-display support that remembers which screen each shelf lives on." },
      { kind: "New", text: "Import and export layouts as .shelfspace files." },
      { kind: "Improved", text: "Rewritten in Swift with native materials; uses noticeably less memory than 1.x." },
    ],
  },
];
