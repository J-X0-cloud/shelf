import { formatReleaseDate, releaseAnchor } from "@/lib/release";
import type { Release } from "@/types/changelog";

export function ReleaseEntry({ release }: { release: Release }) {
  return (
    <article className="rel" id={releaseAnchor(release.version)}>
      <div className="rel-m">
        <span className="ver">{release.version}</span>
        <time dateTime={release.date}>{formatReleaseDate(release.date)}</time>
      </div>
      <div className="rel-b">
        {release.title ? <h2>{release.title}</h2> : null}
        {release.summary ? <p>{release.summary}</p> : null}
        <ul>
          {release.changes.map((change) => (
            <li key={change.text}>
              <span className={`tag tag-${change.kind.toLowerCase()}`}>{change.kind}</span>
              <span>{change.text}</span>
            </li>
          ))}
        </ul>
      </div>
    </article>
  );
}
