import localFont from "next/font/local";

export const albertSans = localFont({
  src: "./fonts/albert-sans-var.woff2",
  variable: "--font-albert",
  weight: "100 900",
  display: "swap",
});

export const interDisplay = localFont({
  src: [
    { path: "./fonts/inter-display-400.woff2", weight: "400" },
    { path: "./fonts/inter-display-500.woff2", weight: "500" },
    { path: "./fonts/inter-display-600.woff2", weight: "600" },
    { path: "./fonts/inter-display-700.woff2", weight: "700" },
  ],
  variable: "--font-inter-display",
  display: "swap",
});
