export type LicenseTier = "personal" | "family" | "team";

export interface Plan {
  id: LicenseTier;
  name: string;
  /** USD, one-time. Team is priced per seat. */
  price: number;
  unit: string;
  description: string;
  features: string[];
  cta: string;
  highlighted?: boolean;
  /** Minimum seats for per-seat plans. */
  minSeats?: number;
}

export interface CompareRow {
  feature: string;
  values: Record<LicenseTier, string | boolean>;
}
