import { describe, expect, it } from "vitest";
import { enTetesSecurite } from "./en-tetes-securite";

function valeur(env: { NODE_ENV?: string }, cle: string): string | undefined {
  return enTetesSecurite(env).find((h) => h.key === cle)?.value;
}

describe("enTetesSecurite", () => {
  it("pose une CSP restrictive", () => {
    const csp = valeur({ NODE_ENV: "production" }, "Content-Security-Policy");
    for (const d of [
      "default-src 'self'",
      "script-src 'self' 'unsafe-inline'",
      "object-src 'none'",
      "frame-ancestors 'none'",
      "base-uri 'self'",
      "form-action 'self'",
    ]) {
      expect(csp).toContain(d);
    }
  });

  it("n'autorise unsafe-eval qu'en développement", () => {
    expect(
      valeur({ NODE_ENV: "production" }, "Content-Security-Policy"),
    ).not.toContain("unsafe-eval");
    expect(
      valeur({ NODE_ENV: "development" }, "Content-Security-Policy"),
    ).toContain("unsafe-eval");
  });

  it("pose les autres en-têtes", () => {
    const attendu: Record<string, string> = {
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "strict-origin-when-cross-origin",
      "Permissions-Policy": "camera=(), microphone=(), geolocation=()",
      "Cross-Origin-Opener-Policy": "same-origin",
      "Cross-Origin-Resource-Policy": "same-origin",
      "Strict-Transport-Security": "max-age=31536000; includeSubDomains",
    };
    for (const [cle, v] of Object.entries(attendu)) {
      expect(valeur({ NODE_ENV: "production" }, cle)).toBe(v);
    }
  });
});
