import { NextResponse, type NextRequest } from "next/server";
import { z } from "zod";

const querySchema = z.object({
  plan: z.enum(["personal", "family", "team"]),
  seats: z.coerce.number().int().min(5).max(500).optional(),
});

const checkoutEnv: Record<z.infer<typeof querySchema>["plan"], string | undefined> = {
  personal: process.env.CHECKOUT_URL_PERSONAL,
  family: process.env.CHECKOUT_URL_FAMILY,
  team: process.env.CHECKOUT_URL_TEAM,
};

/** Sends the buyer to the hosted checkout for a plan. Team checkouts carry a seat count (5 minimum). */
export function GET(request: NextRequest) {
  const parsed = querySchema.safeParse(Object.fromEntries(request.nextUrl.searchParams));
  if (!parsed.success) {
    return NextResponse.json({ error: "Unknown plan" }, { status: 400 });
  }

  const base = checkoutEnv[parsed.data.plan];
  if (!base) {
    return NextResponse.redirect(new URL("/pricing", request.url));
  }

  const url = new URL(base);
  if (parsed.data.plan === "team") url.searchParams.set("quantity", String(parsed.data.seats ?? 5));
  return NextResponse.redirect(url, 303);
}
