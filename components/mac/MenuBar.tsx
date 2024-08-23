import { Icon, MenuBarGlyph } from "@/components/ui/Icon";

export interface MenuBarProps {
  app: string;
  menus: readonly string[];
  clock: string;
}

export function MenuBar({ app, menus, clock }: MenuBarProps) {
  return (
    <div className="mbar">
      <div className="mb-l">
        <span className="mb-dot" />
        <b>{app}</b>
        {menus.map((menu) => (
          <span key={menu}>{menu}</span>
        ))}
      </div>
      <div className="mb-r">
        <span className="mb-shelf">
          <MenuBarGlyph />
        </span>
        <span>
          <Icon name="search" size={13} strokeWidth={2.2} />
        </span>
        <span className="mb-wifi">
          <i />
          <i />
          <i />
        </span>
        <span className="mb-bat">
          <i />
        </span>
        <span>{clock}</span>
      </div>
    </div>
  );
}
