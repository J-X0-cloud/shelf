import { NextResponse } from "next/server";
import { z } from "zod";
import { licenseService } from "@/lib/license";
import { mailer } from "@/lib/mailer";

const bodySchema = z.object({ email: z.string().email().max(254) });

/**
 * Settings → License → Recover. Always answers 202 so the endpoint can't be used to check
 * whether an address has bought Shelf; keys only ever go out by email.
 */
export async function POST(request: Request) {
  const parsed = bodySchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Enter a valid email address." }, { status: 400 });

  const licenses = await licenseService.recover(parsed.data.email);
  if (licenses.length > 0) {
    const lines = licenses.map((l) => `${l.tier[0].toUpperCase()}${l.tier.slice(1)}: ${l.key}`).join("\n");
    await mailer.send({
      to: parsed.data.email,
      subject: licenses.length === 1 ? "Your Shelf license key" : "Your Shelf license keys",
      text: `Here ${licenses.length === 1 ? "is the key" : "are the keys"} for this address:\n\n${lines}\n\nPaste a key into Settings → License on your Mac. Reply to this email if anything looks wrong.`,
    });
  }

  return NextResponse.json({ status: "sent-if-found" }, { status: 202 });
}
