import { Icon } from "@/components/ui/Icon";
import { SectionHead } from "@/components/ui/SectionHead";
import { testimonials } from "@/lib/data/home";

export function Testimonials() {
  return (
    <section className="quotes">
      <div className="wrap">
        <SectionHead eyebrow="From the beta" title="People who tidy for a living." centered />
        <div className="q-grid">
          {testimonials.map((t) => (
            <figure key={t.name} className="q">
              <div className="stars" aria-label="5 out of 5 stars">
                {Array.from({ length: 5 }, (_, i) => (
                  <Icon key={i} name="star" size={15} strokeWidth={0} />
                ))}
              </div>
              <blockquote>“{t.quote}”</blockquote>
              <figcaption>
                <span className="av">{t.name[0]}</span>
                <span>
                  <strong>{t.name}</strong>
                  <em>{t.role}</em>
                </span>
              </figcaption>
            </figure>
          ))}
        </div>
      </div>
    </section>
  );
}
