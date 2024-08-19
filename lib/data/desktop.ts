import type {
  DockApp,
  MenuAction,
  ReadingItem,
  Rule,
  RuleSummary,
  SettingsPane,
  ShelfPanel,
  SpaceSummary,
} from "@/types/shelf";

export const menuBar = {
  app: "Finder",
  menus: ["File", "Edit", "View", "Go", "Window", "Help"],
  clock: "Thu Sep 24  9:41 AM",
} as const;

export const inboxShelf: ShelfPanel = {
  title: "Inbox",
  color: "#E4572E",
  items: [
    { kind: "image", name: "Screenshot 09.41", focus: "20% 60%" },
    { kind: "file", name: "invoice-0932.pdf", badge: "PDF", color: "#E4572E" },
    { kind: "file", name: "Brief v3.docx", badge: "DOC", color: "#3F7BD0" },
    { kind: "folder", name: "Moodboard", color: "#E9B44C" },
    { kind: "file", name: "q3-numbers.csv", badge: "CSV", color: "#3E9A66" },
    { kind: "image", name: "hero-crop.png", focus: "70% 40%" },
    { kind: "file", name: "contract.pages", badge: "PGS", color: "#E89A3C" },
    { kind: "folder", name: "Exports" },
  ],
};

export const harborShelf: ShelfPanel = {
  title: "Harbor Coffee — Brand",
  color: "#5E9C7E",
  items: [
    { kind: "file", name: "logo-final.svg", badge: "SVG", color: "#8A5CD6" },
    { kind: "image", name: "cup-shoot-01.jpg", focus: "55% 75%" },
    { kind: "image", name: "cup-shoot-02.jpg", focus: "85% 55%" },
    { kind: "folder", name: "Type specimens", color: "#5E9C7E" },
    { kind: "file", name: "palette.ase", badge: "ASE", color: "#C7431D" },
    { kind: "app", name: "Brand board", background: "linear-gradient(#b48cf2,#6b45c9)", glyph: "pen" },
    { kind: "file", name: "menu-proof.pdf", badge: "PDF", color: "#E4572E" },
    { kind: "folder", name: "Signage", color: "#E9B44C" },
  ],
};

export const readingShelf = {
  title: "Reading",
  color: "#7FA7D9",
  items: [
    { color: "#E4572E", title: "Designing calm software", meta: "essay · 12 min" },
    { color: "#5E9C7E", title: "Q3 pricing notes", meta: "notes" },
    { color: "#7FA7D9", title: "Kerning, a field guide", meta: "bookmark" },
    { color: "#E9B44C", title: "Invoice template", meta: "link" },
  ] satisfies ReadingItem[],
};

export const spaces: SpaceSummary[] = [
  { name: "Studio", color: "#E4572E", shelfCount: 3, shortcut: "⌘1", active: true },
  { name: "Harbor Coffee rebrand", color: "#5E9C7E", shelfCount: 4, shortcut: "⌘2" },
  { name: "Admin & invoices", color: "#E9B44C", shelfCount: 2, shortcut: "⌘3" },
  { name: "Weekend projects", color: "#7FA7D9", shelfCount: 1, shortcut: "⌘4" },
];

export const popoverActions: MenuAction[] = [
  { label: "New shelf", keys: "⌥⌘N" },
  { label: "Stash selection", keys: "⇧⌘S" },
  { label: "Hide all shelves", keys: "⌥⌘H" },
];

export const dockApps: DockApp[] = [
  { name: "Files", background: "linear-gradient(#6aa7e6,#2f6fc0)", glyph: "files" },
  { name: "Mail", background: "linear-gradient(#5cb0f0,#2a79d6)", glyph: "mail" },
  { name: "Calendar", background: "#fffaf2", glyph: "cal" },
  { name: "Notes", background: "linear-gradient(#fbe7a6,#f3d272)", glyph: "note" },
  { name: "Messages", background: "linear-gradient(#72d08a,#2f9e55)", glyph: "chat" },
  { name: "Music", background: "linear-gradient(#ff8a6b,#e0412a)", glyph: "music" },
  { name: "Terminal", background: "linear-gradient(#3a3f47,#15181c)", glyph: "term" },
  { name: "Design", background: "linear-gradient(#b48cf2,#6b45c9)", glyph: "pen" },
  { name: "Browser", background: "linear-gradient(#4db6c6,#1f7c94)", glyph: "globe" },
  { name: "Photos", background: "#fffaf2", glyph: "photo" },
];

export const dockStackColors = ["#E9B44C", "#E4572E", "#7FA7D9"];
export const dockSettingsApp: DockApp = {
  name: "System Settings",
  background: "linear-gradient(#9aa3ad,#5f6771)",
  glyph: "set",
};

export const settingsPanes: SettingsPane[] = [
  { name: "General", color: "#8b939c" },
  { name: "Shelves", color: "#E4572E" },
  { name: "Spaces", color: "#5E9C7E" },
  { name: "Rules", color: "#8A5CD6" },
  { name: "Shortcuts", color: "#3F7BD0" },
  { name: "Appearance", color: "#E9B44C" },
  { name: "Displays", color: "#2f2b26" },
  { name: "License", color: "#C7431D" },
];

export const rules: Rule[] = [
  {
    source: "Downloads",
    condition: { kind: "extension", value: ".pdf" },
    shelf: "Paperwork",
    space: "Admin & invoices",
    color: "#E9B44C",
    enabled: true,
  },
  {
    source: "Desktop",
    condition: { kind: "screenshot" },
    shelf: "Inbox",
    space: "Studio",
    color: "#E4572E",
    enabled: true,
  },
  {
    source: "Downloads",
    condition: { kind: "nameContains", value: "harbor" },
    shelf: "Brand",
    space: "Harbor Coffee rebrand",
    color: "#5E9C7E",
    enabled: true,
  },
  {
    source: "Any shelf",
    condition: { kind: "untouched", days: 30 },
    shelf: "Archive",
    space: "Studio",
    color: "#7FA7D9",
    enabled: false,
  },
];

export const ruleSummaries: RuleSummary[] = [
  { icon: "stash", source: "Screenshots", shelf: "Inbox", color: "#E4572E" },
  { icon: "book", source: "*.pdf in Downloads", shelf: "Paperwork", color: "#E9B44C" },
  { icon: "link", source: "Links from Mail", shelf: "Reading", color: "#7FA7D9" },
  { icon: "sync", source: "Untouched 30 days", shelf: "Archive", color: "#8b939c" },
];
