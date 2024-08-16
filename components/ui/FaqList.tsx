import type { Faq } from "@/types/content";

/** Native <details> accordions: keyboard accessible and working without JavaScript. */
export function FaqList({ faqs }: { faqs: Faq[] }) {
  return (
    <div className="faq-list">
      {faqs.map((faq) => (
        <details key={faq.question} className="faq">
          <summary>
            {faq.question}
            <span aria-hidden="true" />
          </summary>
          <p>{faq.answer}</p>
        </details>
      ))}
    </div>
  );
}
