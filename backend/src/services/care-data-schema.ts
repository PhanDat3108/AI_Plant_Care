import { z } from "zod";

const guide = z.string().min(1).max(3000).nullable();
const days = z.number().int().min(1).max(365).nullable();
export const careFieldsSchema = z.strictObject({
  watering_days: days,
  fertilizing_days: days,
  water_guide: guide,
  light_guide: guide,
  soil_guide: guide,
  temperature_guide: guide,
  fertilizer_guide: guide,
});
export type CareFields = z.infer<typeof careFieldsSchema>;
export const careDataSchema = careFieldsSchema.superRefine((care, ctx) => {
  for (const [field, value] of Object.entries(care)) {
    if (typeof value === "string" && !value.trim())
      ctx.addIssue({
        code: "custom",
        path: [field],
        message: "Hướng dẫn không được rỗng.",
      });
  }
  if (care.watering_days !== null && !care.water_guide?.trim())
    ctx.addIssue({
      code: "custom",
      path: ["water_guide"],
      message: "Chu kỳ tưới cần hướng dẫn và điều kiện áp dụng.",
    });
  if (care.fertilizing_days !== null && !care.fertilizer_guide?.trim())
    ctx.addIssue({
      code: "custom",
      path: ["fertilizer_guide"],
      message: "Chu kỳ bón phân cần hướng dẫn và điều kiện áp dụng.",
    });
});
export const careProposalSchema = z.strictObject({
  scientific_name: z.string().min(1).max(200),
  care: careDataSchema,
  assumptions: z.array(z.string().min(1).max(500)).max(8),
  source_ids: z.array(z.string().regex(/^source_[1-5]$/)).max(5),
});
export type CareProposal = z.infer<typeof careProposalSchema>;
export const referencesSchema = z
  .array(
    z.strictObject({
      title: z.string().trim().min(1).max(200),
      url: z.url({ protocol: /^https$/ }).max(2000),
      excerpt: z.string().trim().min(1).max(6000),
    }),
  )
  .max(5);
export type CareReference = z.infer<typeof referencesSchema>[number];
export const generationInputSchema = z.strictObject({
  force: z.boolean().default(false),
  sources: referencesSchema.optional(),
});
export const reviewInputSchema = z.discriminatedUnion("action", [
  z.strictObject({
    action: z.literal("approve"),
    generation_id: z.uuid(),
    note: z.string().trim().min(1).max(2000),
    care: careDataSchema.optional(),
  }),
  z.strictObject({
    action: z.literal("reject"),
    generation_id: z.uuid(),
    note: z.string().trim().min(1).max(2000),
  }),
]);
export type ReviewInput = z.infer<typeof reviewInputSchema>;
export function sameSpecies(a: string, b: string) {
  return (
    a.trim().replace(/\s+/g, " ").toLowerCase() ===
    b.trim().replace(/\s+/g, " ").toLowerCase()
  );
}
