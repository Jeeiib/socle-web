export type HealthStatus = {
  status: "ok";
  version: string;
  env: string;
  time: string;
};

export function getHealth(
  env: NodeJS.ProcessEnv = process.env,
  now: Date = new Date(),
): HealthStatus {
  return {
    status: "ok",
    version: env.APP_VERSION || "dev",
    env: env.NODE_ENV || "development",
    time: now.toISOString(),
  };
}
