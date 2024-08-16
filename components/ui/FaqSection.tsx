import type { ReactNode } from "react";
import type { Faq } from "@/types/content";
import { FaqList } from "./FaqList";
import { SectionHead } from "./SectionHead";

export interface FaqSectionProps {
  id?: string;
  eyebrow: string;
  title: string;
  intro?: ReactNode;
  faqs: Faq[];
}

export function FaqSection({ id, eyebrow, title, intro, faqs }: FaqSectionProps) {
  return (
    <section className="faqs" id={id}>
      <div className="wrap faq-in">
        <SectionHead eyebrow={eyebrow} title={title}>
          {intro}
        </SectionHead>
        <FaqList faqs={faqs} />
      </div>
    </section>
  );
}
