import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";

const blog = defineCollection({
  loader: glob({ base: "./src/content/blog", pattern: "**/*.{md,mdx}" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    author: z.string().default("Oh My QEMU maintainers"),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

const docs = defineCollection({
  loader: glob({ base: "./src/content/docs", pattern: "**/*.{md,mdx}" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    order: z.number().int().nonnegative(),
    updatedDate: z.coerce.date().optional(),
    category: z.string().default("Guide"),
  }),
});

export const collections = { blog, docs };
