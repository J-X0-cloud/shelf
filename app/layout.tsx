import type { Metadata, Viewport } from "next";
import type { ReactNode } from "react";
import { Footer } from "@/components/layout/Footer";
import { Header } from "@/components/layout/Header";
import { albertSans, interDisplay } from "./fonts";
import "./globals.css";

const title = "Shelf — Menu-bar shelves and Spaces for a tidy Mac";
const description =
  "Shelf is a native macOS menu-bar app that organizes your Dock and desktop into shelves and Spaces. 14-day free trial, $19 once.";

export const metadata: Metadata = {
  metadataBase: new URL(process.env.NEXT_PUBLIC_SITE_URL ?? "https://shelfapp.com"),
  title: { default: title, template: "%s — Shelf for macOS" },
  description,
  openGraph: { title, description, type: "website" },
  icons: { icon: { url: "/shelf-icon.svg", type: "image/svg+xml" } },
  alternates: { types: { "application/rss+xml": "/appcast.xml" } },
};

export const viewport: Viewport = {
  themeColor: "#F7F3EC",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en" className={`${albertSans.variable} ${interDisplay.variable}`}>
      <body>
        <a className="skip" href="#main">
          Skip to content
        </a>
        <Header />
        <main id="main">{children}</main>
        <Footer />
      </body>
    </html>
  );
}
