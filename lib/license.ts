import { createHash, randomUUID } from "node:crypto";
import type { LicenseTier } from "@/types/pricing";

export interface License {
  key: string;
  email: string;
  tier: LicenseTier;
  /** Macs per person. */
  seatLimit: number;
  activations: string[];
}

export type ActivationResult =
  | { ok: true; license: Omit<License, "activations">; activationsUsed: number }
  | { ok: false; reason: "not-found" | "seat-limit" };

/** Storage for licenses. Swapped for the payment provider's API in production. */
export interface LicenseStore {
  findByKey(key: string): Promise<License | undefined>;
  findByEmail(email: string): Promise<License[]>;
  save(license: License): Promise<void>;
}

export class InMemoryLicenseStore implements LicenseStore {
  private readonly licenses = new Map<string, License>();

  constructor(seed: License[] = []) {
    seed.forEach((l) => this.licenses.set(l.key, l));
  }

  async findByKey(key: string) {
    return this.licenses.get(key);
  }

  async findByEmail(email: string) {
    return [...this.licenses.values()].filter((l) => l.email.toLowerCase() === email.toLowerCase());
  }

  async save(license: License) {
    this.licenses.set(license.key, license);
  }
}

/** Machine identifiers are hashed before storage; the raw hardware UUID never leaves the Mac unhashed. */
export function hashMachine(machineId: string): string {
  return createHash("sha256").update(machineId).digest("hex").slice(0, 16);
}

export function generateKey(): string {
  return `SHELF-${randomUUID().slice(0, 18).toUpperCase()}`;
}

export class LicenseService {
  constructor(private readonly store: LicenseStore) {}

  async activate(key: string, machineId: string): Promise<ActivationResult> {
    const license = await this.store.findByKey(key.trim().toUpperCase());
    if (!license) return { ok: false, reason: "not-found" };

    const machine = hashMachine(machineId);
    if (!license.activations.includes(machine)) {
      if (license.activations.length >= license.seatLimit) return { ok: false, reason: "seat-limit" };
      license.activations.push(machine);
      await this.store.save(license);
    }

    const { activations, ...rest } = license;
    return { ok: true, license: rest, activationsUsed: activations.length };
  }

  async deactivate(key: string, machineId: string): Promise<boolean> {
    const license = await this.store.findByKey(key.trim().toUpperCase());
    if (!license) return false;
    const machine = hashMachine(machineId);
    license.activations = license.activations.filter((m) => m !== machine);
    await this.store.save(license);
    return true;
  }

  /** Licenses bought with this address. Callers must only ever deliver the keys by email. */
  async recover(email: string): Promise<Pick<License, "key" | "tier">[]> {
    return (await this.store.findByEmail(email)).map(({ key, tier }) => ({ key, tier }));
  }
}

const demoStore = new InMemoryLicenseStore([
  {
    key: "SHELF-7F3A2C9E-41B8-4D",
    email: "priya@example.com",
    tier: "personal",
    seatLimit: 3,
    activations: [],
  },
]);

export const licenseService = new LicenseService(demoStore);
