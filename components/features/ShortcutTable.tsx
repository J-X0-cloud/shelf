import type { Shortcut } from "@/types/content";

export function ShortcutTable({ shortcuts }: { shortcuts: Shortcut[] }) {
  return (
    <div className="tbl-wrap">
      <table className="sc">
        <thead>
          <tr>
            <th scope="col">Action</th>
            <th scope="col">Keys</th>
          </tr>
        </thead>
        <tbody>
          {shortcuts.map((shortcut) => (
            <tr key={shortcut.action}>
              <td>{shortcut.action}</td>
              <td>
                {shortcut.keys.map((key) => (
                  <kbd key={key}>{key}</kbd>
                ))}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
