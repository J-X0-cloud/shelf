import type { CompareRow, LicenseTier, Plan } from "@/types/pricing";

function Value({ value }: { value: string | boolean }) {
  if (value === true) return <span aria-label="Included">✓</span>;
  if (value === false) return <span aria-label="Not included">—</span>;
  return <>{value}</>;
}

export function CompareTable({ plans, rows }: { plans: Plan[]; rows: CompareRow[] }) {
  const tiers: LicenseTier[] = plans.map((p) => p.id);
  return (
    <div className="tbl-wrap">
      <table className="cmp">
        <thead>
          <tr>
            <th scope="col">
              <span className="sr-only">Feature</span>
            </th>
            {plans.map((plan) => (
              <th key={plan.id} scope="col">
                {plan.name}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {rows.map((row) => (
            <tr key={row.feature}>
              <td>{row.feature}</td>
              {tiers.map((tier) => (
                <td key={tier}>
                  <Value value={row.values[tier]} />
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
