import { SPACE_KEYS } from "@/lib/typography";
import type { Feature, FeatureRow, InfoBlock, Shortcut } from "@/types/content";

export const featureGrid: Feature[] = [
  {
    icon: "shelves",
    title: "Floating shelves",
    body: "Resizable panels for files, folders, apps and links. Snap them to edges, stack them, or collapse them to a tab.",
  },
  {
    icon: "spaces",
    title: "Spaces",
    body: `Saved sets of shelves for each project. Switch from the menu bar or with ${SPACE_KEYS}.`,
  },
  {
    icon: "wand",
    title: "Rules",
    body: "Watch folders and file new items onto the right shelf by type, name, source or age.",
  },
  {
    icon: "stash",
    title: "Stash",
    body: "Sweep a selection off the desktop onto a shelf with ⇧⌘S. Originals stay put.",
  },
  {
    icon: "search",
    title: "Instant search",
    body: "⌘K searches every shelf in every Space, including file contents Spotlight has indexed.",
  },
  {
    icon: "eye",
    title: "Quick Look",
    body: "Hover to preview, press Space for full Quick Look, drag out to attach or share.",
  },
  { icon: "dock", title: "Dock stack", body: "An optional Dock stack that always shows the current Space's shelves." },
  {
    icon: "display",
    title: "Multi-display",
    body: "Shelves remember their display and return to it after sleep or reconnecting.",
  },
  {
    icon: "lock",
    title: "Local only",
    body: "No account and no analytics. Your layout is a plain file you can back up.",
  },
];

export const featureRows: Record<"spaces" | "native", FeatureRow> = {
  spaces: {
    eyebrow: "Spaces in practice",
    title: "Monday is client work. Friday is invoices.",
    body: "Build a Space for each part of your week. When you switch, shelves from other Spaces fade out, the Dock stack updates, and the menu bar icon takes on the Space's color so you always know where you are.",
    points: [
      "Up to 9 Spaces with keyboard shortcuts, unlimited from the menu",
      "Optional: switch Space automatically when a Focus mode turns on",
      "Export and import layouts to set up a new Mac in seconds",
    ],
  },
  native: {
    eyebrow: "Built for macOS",
    title: "Feels like it shipped with your Mac.",
    body: "Shelf uses native materials, follows your accent color and Light or Dark appearance, supports VoiceOver and full keyboard access, and respects Reduce Motion and Reduce Transparency.",
    points: [
      "Universal app for Apple silicon and Intel",
      "Launch at login, no helper apps or kernel extensions",
      "Signed and notarized, updates with a single click",
    ],
  },
};

export const shortcuts: Shortcut[] = [
  { action: "Open Shelf", keys: ["⌥", "Space"] },
  { action: "Search all shelves", keys: ["⌘", "K"] },
  { action: "Switch to Space 1–9", keys: ["⌘", "1–9"] },
  { action: "New shelf", keys: ["⌥", "⌘", "N"] },
  { action: "Stash selection", keys: ["⇧", "⌘", "S"] },
  { action: "Hide or show all shelves", keys: ["⌥", "⌘", "H"] },
  { action: "Quick Look item", keys: ["Space"] },
  { action: "Move shelf to next display", keys: ["⌃", "⌥", "→"] },
  { action: "Undo last rule action", keys: ["⌘", "Z"] },
  { action: "Settings", keys: ["⌘", ","] },
];

export const requirements: InfoBlock[] = [
  { title: "System requirements", body: "macOS 13 Ventura or later. Apple silicon or Intel. 25 MB of disk space." },
  {
    title: "Permissions",
    body: "Accessibility (for global shortcuts) and folder access for the folders you add to Rules. Shelf explains each one before macOS asks.",
  },
  { title: "Languages", body: "English, Spanish, French, German, Japanese and Korean." },
];
