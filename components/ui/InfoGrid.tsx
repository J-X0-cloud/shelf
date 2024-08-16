import type { InfoBlock } from "@/types/content";

/** Three-up band of short reference blocks (requirements, licensing help). */
export function InfoGrid({ id, blocks }: { id?: string; blocks: InfoBlock[] }) {
  return (
    <section className="band band-alt" id={id}>
      <div className="wrap req">
        {blocks.map((block) => (
          <div key={block.title}>
            <h3>{block.title}</h3>
            <p>{block.body}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
