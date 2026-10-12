import multer from "multer";
import sharp from "sharp";
import { randomUUID } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import { AppError } from "../../common/errors/app-error.js";
export const catalogUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 0 },
  fileFilter: (_req, file, done) =>
    done(
      null,
      ["image/png", "image/jpeg", "image/webp"].includes(file.mimetype),
    ),
}).single("image");
export async function uploadArtwork(
  db: SupabaseClient,
  actor: string,
  clinic: string,
  file?: Express.Multer.File,
) {
  if (!file)
    throw new AppError(
      400,
      "UPLOAD_INVALID",
      "Select a JPEG, PNG or WebP image",
    );
  let image: Buffer;
  try {
    const decoder = sharp(file.buffer, {
      limitInputPixels: 16_000_000,
      animated: false,
    });
    const metadata = await decoder.metadata();
    if (
      !["jpeg", "png", "webp"].includes(metadata.format ?? "") ||
      (metadata.pages ?? 1) > 1 ||
      `image/${metadata.format}` !== file.mimetype
    )
      throw new Error();
    image = await decoder
      .rotate()
      .resize(1600, 1600, { fit: "inside", withoutEnlargement: true })
      .webp({ quality: 85 })
      .toBuffer();
  } catch {
    throw new AppError(400, "UPLOAD_INVALID", "Invalid image");
  }
  const id = randomUUID(),
    path = `${clinic}/${id}.webp`;
  const { error } = await db.storage
    .from("clinic-catalog")
    .upload(path, image, { contentType: "image/webp", upsert: false });
  if (error)
    throw new AppError(503, "UPLOAD_FAILED", "Image upload unavailable");
  const { error: auditError } = await db.from("audit_logs").insert({
    clinic_id: clinic,
    actor_id: actor,
    action: "catalog.image_uploaded",
    resource_id: id,
  });
  if (auditError) {
    await db.storage.from("clinic-catalog").remove([path]);
    throw new AppError(
      503,
      "DATABASE_UNAVAILABLE",
      "Image upload could not be recorded",
    );
  }
  return {
    url: db.storage.from("clinic-catalog").getPublicUrl(path).data.publicUrl,
  };
}
