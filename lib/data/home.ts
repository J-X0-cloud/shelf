import { SPACE_KEYS } from "@/lib/typography";
import type { Faq, Feature, FeatureRow, Testimonial } from "@/types/content";

export const ideas: Feature[] = [
  {
    icon: "shelves",
    title: "Shelves",
    body: "Floating panels that hold files, folders, apps and links. Pin them to an edge, stack them, or tuck them away until you hover.",
  },
  {
    icon: "spaces",
    title: "Spaces",
    body: `Group shelves by client, project or mode of work. Switch with ${SPACE_KEYS} and everything else steps out of the way.`,
  },
  {
    icon: "stash",
    title: "Stash",
    body: "Select a mess of files on the desktop, press ⇧⌘S, and it lands on a shelf, neatly, without moving the originals.",
  },
];

export const homeRows: Record<"shelves" | "spaces" | "rules", FeatureRow> = {
  shelves: {
    eyebrow: "Shelves",
    title: "Shelves that stay where you put them.",
    body: "Drag anything onto a shelf: a stack of exports, the folder you open twenty times a day, an app, a link. Shelves float above the desktop, snap to screen edges, and slide out of sight when you're in a full-screen app.",
    points: [
      "Quick Look on hover, drag out to share or attach",
      "Pin to any edge, or auto-hide until your pointer arrives",
      "Mix files, folders, apps and web links on one shelf",
    ],
  },
  spaces: {
    eyebrow: "Spaces",
    title: "A separate desk for every context.",
    body: "A Space is a saved arrangement of shelves. Keep one for each client, one for admin, one for the side project you only touch on Sundays. Switching takes a keystroke, and Shelf remembers which display every shelf belongs to.",
    points: [
      `Switch from the menu bar or with ${SPACE_KEYS}`,
      "Per-Space wallpaper tint and Dock stack",
      "Share a Space layout as a small .shelfspace file",
    ],
  },
  rules: {
    eyebrow: "Rules",
    title: "Rules that do the filing for you.",
    body: "Tell Shelf where things belong once. New screenshots head to Inbox, PDFs from Downloads go to Paperwork, anything untouched for a month moves to Archive. Rules run on your Mac, instantly and quietly.",
    points: [
      "Match by folder, file type, name or age",
      "Preview what a rule will catch before you turn it on",
      "Undo any automatic move from the menu bar",
    ],
  },
};

export const keyHighlights = [
  { keys: ["⌥", "Space"], label: "Open Shelf from anywhere" },
  { keys: ["⌘", "1–9"], label: "Jump to a Space" },
  { keys: ["⇧⌘", "S"], label: "Stash the selection" },
  { keys: ["⌥⌘", "H"], label: "Hide every shelf" },
];

export const principles: Feature[] = [
  {
    icon: "bolt",
    title: "Native and light",
    body: "Written in Swift and AppKit. Launches instantly and idles at near-zero CPU.",
  },
  {
    icon: "lock",
    title: "Private by design",
    body: "No account, no analytics, no cloud. Your shelves are a small file on your Mac.",
  },
  {
    icon: "dock",
    title: "Respects the Dock",
    body: "Shelf organizes around the Dock instead of replacing it. Nothing to undo.",
  },
  {
    icon: "display",
    title: "Every display",
    body: "Shelves follow displays across sleep, reconnects and clamshell mode.",
  },
];

export const testimonials: Testimonial[] = [
  {
    quote:
      "I used to screenshot my desktop before a client call so I could clean it and put it back after. Now I just switch Spaces.",
    name: "Priya N.",
    role: "Motion designer, Portland",
  },
  {
    quote: "It's the first organizer that doesn't try to replace the Dock. It just makes the Dock make sense again.",
    name: "Marcus T.",
    role: "Freelance iOS developer",
  },
  {
    quote: "The rules are the quiet hero. Invoices go to Admin, screenshots go to Inbox, and I never think about it.",
    name: "Elena R.",
    role: "Producer, Austin",
  },
];

export const homeFaqs: Faq[] = [
  {
    question: "Does Shelf replace the macOS Dock?",
    answer:
      "No. Shelf sits in your menu bar and works alongside the Dock. It can add a single Shelf stack to the Dock if you like, but your Dock, apps and settings stay exactly as they are.",
  },
  {
    question: "Are my files moved or copied?",
    answer:
      "Neither, by default. A shelf holds references, so the original file stays where it lives. You can opt into “Move to shelf folder” per shelf if you prefer a real folder on disk.",
  },
  {
    question: "Does it work with multiple displays?",
    answer:
      "Yes. Each Space remembers which display its shelves belong to and restores them when you reconnect, including after sleep and clamshell mode.",
  },
  {
    question: "Is there a subscription?",
    answer:
      "No. A Personal license is $19 once and covers every 2.x update. Major upgrades are discounted for existing owners and are never required.",
  },
  {
    question: "What does Shelf collect?",
    answer:
      "Nothing. There's no account and no analytics. Update checks send only the app version, and you can turn them off.",
  },
];
