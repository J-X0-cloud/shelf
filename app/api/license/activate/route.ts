import { NextResponse } from "next/server";
import { z } from "zod";
import { licenseService } from "@/lib/license";

const bodySchema = z.object({
  key: z.string().min(8).max(64),
  /** IOPlatformUUID from the Mac; hashed before storage. */
  machineId: z.string().uuid(),
  appVersion: z.string().regex(/^\d+\.\d+\.\d+$/),
});

/** Called by the macOS app from Settings → License. */
export async function POST(request: Request) {
  const parsed = bodySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) {
    return NextResponse.json({ error: "Invalid request", issues: parsed.error.flatten().fieldErrors }, { status: 400 });
  }

  const result = await licenseService.activate(parsed.data.key, parsed.data.machineId);
  if (!result.ok) {
    const status = result.reason === "not-found" ? 404 : 409;
    const message =
      result.reason === "not-found"
        ? "That license key wasn't recognised."
        : "This license is active on the maximum number of Macs. Deactivate one from Settings → License.";
    return NextResponse.json({ error: message, reason: result.reason }, { status });
  }

  return NextResponse.json({
    tier: result.license.tier,
    email: result.license.email,
    seatLimit: result.license.seatLimit,
    activationsUsed: result.activationsUsed,
  });
}

export async function DELETE(request: Request) {
  const parsed = bodySchema.pick({ key: true, machineId: true }).safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Invalid request" }, { status: 400 });
  const ok = await licenseService.deactivate(parsed.data.key, parsed.data.machineId);
  return ok ? new NextResponse(null, { status: 204 }) : NextResponse.json({ error: "Not found" }, { status: 404 });
}
