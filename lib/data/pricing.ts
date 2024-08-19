import type { Faq } from "@/types/content";
import type { CompareRow, Plan } from "@/types/pricing";

export const plans: Plan[] = [
  {
    id: "personal",
    name: "Personal",
    price: 19,
    unit: "one-time",
    description: "For one person and their Macs.",
    features: ["Up to 3 Macs", "All 2.x updates", "Unlimited shelves, Spaces and Rules", "Email support"],
    cta: "Buy Personal",
  },
  {
    id: "family",
    name: "Family",
    price: 39,
    unit: "one-time",
    description: "Everyone at home gets their own license.",
    features: ["Up to 5 people", "3 Macs per person", "All 2.x updates", "Manage seats from one email"],
    cta: "Buy Family",
    highlighted: true,
  },
  {
    id: "team",
    name: "Team",
    price: 14,
    unit: "per seat, one-time",
    description: "For studios and small teams, 5 seats minimum.",
    features: ["Shared Space templates", "License keys by email or MDM", "Invoice and PO billing", "Priority support"],
    cta: "Buy Team",
    minSeats: 5,
  },
];

export const personalPlan = plans[0];

export const compareRows: CompareRow[] = [
  { feature: "Floating shelves and Spaces", values: { personal: true, family: true, team: true } },
  { feature: "Rules and Stash", values: { personal: true, family: true, team: true } },
  { feature: "Macs per person", values: { personal: "3", family: "3", team: "3" } },
  { feature: "People covered", values: { personal: "1", family: "5", team: "Per seat" } },
  { feature: "Shared Space templates", values: { personal: false, family: false, team: true } },
  { feature: "Deploy with MDM", values: { personal: false, family: false, team: true } },
  { feature: "Support", values: { personal: "Email", family: "Email", team: "Priority email" } },
];

export const priceTeaserPoints = ["Up to 3 Macs", "All 2.x updates included", "30-day refund, no questions"];

export const pricingFaqs: Faq[] = [
  {
    question: "What happens when the trial ends?",
    answer:
      "Your shelves stay visible but become read-only until you add a license. Nothing is deleted, and the trial includes every feature.",
  },
  {
    question: "Will I have to pay for Shelf 3?",
    answer:
      "Every 2.x release is free for license holders. When 3.0 arrives, existing owners get an upgrade price, and 2.x keeps working if you'd rather not upgrade.",
  },
  {
    question: "Can I move my license to a new Mac?",
    answer:
      "Yes. Deactivate from Settings → License on the old Mac, or free up a seat from the link in your receipt email.",
  },
  {
    question: "Do you offer refunds?",
    answer: "Within 30 days of purchase, for any reason. Reply to your receipt and we'll handle it.",
  },
  {
    question: "Is there education pricing?",
    answer: "Students and teachers get 50% off Personal. Email us from your school address for a code.",
  },
];
