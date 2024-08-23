import { FeatureCard } from "@/components/ui/FeatureCard";
import { SectionHead } from "@/components/ui/SectionHead";
import { ideas } from "@/lib/data/home";

export function Ideas() {
  return (
    <section className="band">
      <div className="wrap">
        <SectionHead eyebrow="Three ideas, one small app" title="Your desktop, but sorted." centered>
          Shelf doesn&apos;t ask you to change how you work. It gives the files and apps you already juggle a place to
          live, and puts the right ones in front of you at the right time.
        </SectionHead>
        <div className="f3-grid">
          {ideas.map((idea) => (
            <FeatureCard key={idea.title} feature={idea} />
          ))}
        </div>
      </div>
    </section>
  );
}
