import type { FooterColumn, NavLink } from "@/types/content";

export const supportEmail = "hello@shelfapp.com";

export const primaryNav: NavLink[] = [
  { href: "/features", label: "Features" },
  { href: "/pricing", label: "Pricing" },
  { href: "/changelog", label: "Changelog" },
  { href: "/support", label: "Support" },
];

export const footerBlurb =
  "The calm, native way to keep your Mac's Dock and desktop in order. Built in Swift for macOS 13 and later.";

export const footerColumns: FooterColumn[] = [
  {
    title: "Product",
    links: [
      { href: "/features", label: "Features" },
      { href: "/pricing", label: "Pricing" },
      { href: "/changelog", label: "Changelog" },
      { href: "#download", label: "Download" },
    ],
  },
  {
    title: "Help",
    links: [
      { href: "/support", label: "Getting started" },
      { href: "/support#faq", label: "FAQ" },
      { href: "/support#license", label: "Licenses & refunds" },
      { href: `mailto:${supportEmail}`, label: supportEmail },
    ],
  },
  {
    title: "Company",
    links: [
      { href: "#press", label: "Press kit" },
      { href: "#privacy", label: "Privacy" },
      { href: "#terms", label: "Terms" },
      { href: "#education", label: "Education pricing" },
    ],
  },
];

export const copyright = "© 2026 Shelf Software. Made carefully for the Mac.";

export const systemRequirements = {
  macOS: "macOS 13 Ventura or later",
  shortMacOS: "macOS 13 or later",
  architectures: "Universal app for Apple silicon and Intel",
  trialDays: 14,
  refundDays: 30,
} as const;
