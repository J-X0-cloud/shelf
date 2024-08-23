import Link from "next/link";
import { Icon } from "@/components/ui/Icon";
import { SectionHead } from "@/components/ui/SectionHead";
import { keyHighlights } from "@/lib/data/home";

export function Keys() {
  return (
    <section className="keys">
      <div className="wrap keys-in">
        <div>
          <SectionHead eyebrow="Keyboard first" title="Your hands never leave the keys.">
            Every action in Shelf has a shortcut, and every shortcut can be changed. Most people learn the four below in
            the first afternoon.
          </SectionHead>
          <Link className="lnk" href="/features#shortcuts">
            All shortcuts <Icon name="arrow" size={16} strokeWidth={2} />
          </Link>
        </div>
        <div className="kb-grid">
          {keyHighlights.map((item) => (
            <div key={item.label} className="kb">
              <div className="kb-k">
                {item.keys.map((key) => (
                  <kbd key={key}>{key}</kbd>
                ))}
              </div>
              <p>{item.label}</p>
            </div>
          ))}
        </div>
      </div>
    </section>
  );
}
