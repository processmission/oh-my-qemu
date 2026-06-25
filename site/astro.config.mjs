import { defineConfig } from "astro/config";

const site = process.env.SITE_URL ?? "https://processmission.github.io";
const configuredBase = process.env.BASE_PATH ?? "/oh-my-qemu";
const base = configuredBase === "/" ? "/" : `${configuredBase.replace(/\/$/, "")}/`;

export default defineConfig({
  site,
  base,
  output: "static",
});
