import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "socle-web",
  description: "Socle Next.js avec les bonnes pratiques DevOps.",
};

export default function RootLayout({
  children,
}: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="fr">
      <body>{children}</body>
    </html>
  );
}
