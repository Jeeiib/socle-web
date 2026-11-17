import { describe, expect, it } from "vitest";
import { getHealth } from "./health";

describe("getHealth", () => {
  it("renvoie ok avec la version et l'environnement", () => {
    const h = getHealth(
      { APP_VERSION: "1.2.3", NODE_ENV: "production" } as NodeJS.ProcessEnv,
      new Date("2026-01-01T00:00:00Z"),
    );
    expect(h).toEqual({
      status: "ok",
      version: "1.2.3",
      env: "production",
      time: "2026-01-01T00:00:00.000Z",
    });
  });

  it("utilise dev quand APP_VERSION est absent", () => {
    expect(getHealth({} as NodeJS.ProcessEnv).version).toBe("dev");
    expect(getHealth({} as NodeJS.ProcessEnv).env).toBe("development");
  });
});
