import type { IconName } from "@/components/ui/Icon";

export interface NavLink {
  href: string;
  label: string;
}

export interface FooterColumn {
  title: string;
  links: NavLink[];
}

export interface Feature {
  icon: IconName;
  title: string;
  body: string;
}

export interface FeatureRow {
  eyebrow: string;
  title: string;
  body: string;
  points: string[];
}

export interface Faq {
  question: string;
  answer: string;
}

export interface Testimonial {
  quote: string;
  name: string;
  role: string;
}

export interface Shortcut {
  action: string;
  keys: string[];
}

export interface InfoBlock {
  title: string;
  body: string;
}
