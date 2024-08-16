import { Icon } from "./Icon";

export function TickList({ items }: { items: string[] }) {
  return (
    <ul className="ticks">
      {items.map((item) => (
        <li key={item}>
          <Icon name="check" size={18} strokeWidth={2.2} />
          <span>{item}</span>
        </li>
      ))}
    </ul>
  );
}
