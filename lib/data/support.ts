import { SPACE_KEYS } from "@/lib/typography";
import type { Faq, InfoBlock } from "@/types/content";

export const gettingStarted = [
  {
    title: "Install",
    body: "Open the download, drag Shelf to Applications and launch it. The Shelf icon appears in your menu bar.",
  },
  {
    title: "Make a shelf",
    body: "Press ⌥⌘N or drag a file onto the menu bar icon. Name it, pick a color, and drop in whatever belongs there.",
  },
  {
    title: "Add a Space",
    body: `Open the menu, choose New Space, and move shelves into it. Switch between Spaces with ${SPACE_KEYS}.`,
  },
  {
    title: "Teach it a rule",
    body: "In Settings → Rules, pick a folder and a condition. Preview what it catches, then switch it on.",
  },
];

export const troubleshooting: Faq[] = [
  {
    question: "Shelf's global shortcut doesn't work.",
    answer:
      "Shelf needs Accessibility permission for global shortcuts. Open System Settings → Privacy & Security → Accessibility and make sure Shelf is on. If it already is, toggle it off and on again.",
  },
  {
    question: "A shelf disappeared after I unplugged my display.",
    answer:
      "Shelves wait for their display to come back. To bring one to your current screen, open the menu, hold ⌥ and choose Gather shelves here.",
  },
  {
    question: "How do I back up my layout?",
    answer:
      "Choose File → Export Layout in Settings. You get a small .shelfspace file you can keep anywhere or import on another Mac.",
  },
  {
    question: "Can Shelf sync between my Macs?",
    answer:
      "Not automatically. Shelf keeps everything local on purpose. Exporting and importing a layout takes a few seconds.",
  },
  {
    question: "How do I uninstall Shelf?",
    answer:
      "Quit Shelf from its menu, then drag it from Applications to the Trash. Your files are never touched, since shelves only hold references.",
  },
];

export const licenseHelp: InfoBlock[] = [
  {
    title: "Lost your license key?",
    body: "Enter your purchase email in Settings → License → Recover and we'll resend it right away.",
  },
  { title: "Refunds", body: "Within 30 days of purchase, for any reason. Reply to your receipt email." },
  {
    title: "Moving to a new Mac",
    body: "Export your layout, deactivate the license on the old Mac, then activate and import on the new one.",
  },
];
