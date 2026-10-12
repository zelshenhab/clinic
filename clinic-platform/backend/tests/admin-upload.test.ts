import { it, expect, vi } from "vitest";
import sharp from "sharp";
import type { SupabaseClient } from "@supabase/supabase-js";
import { uploadArtwork } from "../src/modules/admin/uploads.js";
function fixture() {
  const upload = vi.fn(async () => ({ error: null })),
    remove = vi.fn(async () => ({ error: null })),
    insert = vi.fn(async () => ({ error: null }));
  const bucket = {
      upload,
      remove,
      getPublicUrl: (path: string) => ({
        data: { publicUrl: "https://example.invalid/" + path },
      }),
    },
    db = {
      storage: { from: () => bucket },
      from: () => ({ insert }),
    } as unknown as SupabaseClient;
  return { db, upload, remove, insert };
}
it("decodes and re-encodes artwork, removes metadata and stores a clinic-scoped unique path", async () => {
  const { db, upload, insert } = fixture(),
    buffer = await sharp({
      create: { width: 2000, height: 100, channels: 3, background: "blue" },
    })
      .jpeg()
      .withMetadata()
      .toBuffer();
  const result = await uploadArtwork(db, "actor", "clinic", {
    buffer,
    mimetype: "image/jpeg",
  } as Express.Multer.File);
  const [path, content, options] = upload.mock.calls[0] as any;
  expect(path).toMatch(/^clinic\/[0-9a-f-]+\.webp$/);
  const metadata = await sharp(content).metadata();
  expect(metadata.format).toBe("webp");
  expect(metadata.width).toBe(1600);
  expect(metadata.exif).toBeUndefined();
  expect(options.upsert).toBe(false);
  expect(insert).toHaveBeenCalled();
  expect(result.url).toContain(path);
});
it("rejects malicious bytes and misleading MIME types before storage writes", async () => {
  const { db, upload } = fixture();
  await expect(
    uploadArtwork(db, "actor", "clinic", {
      buffer: Buffer.from("<script>bad</script>"),
      mimetype: "image/png",
    } as Express.Multer.File),
  ).rejects.toMatchObject({ code: "UPLOAD_INVALID" });
  const buffer = await sharp({
    create: { width: 10, height: 10, channels: 3, background: "blue" },
  })
    .png()
    .toBuffer();
  await expect(
    uploadArtwork(db, "actor", "clinic", {
      buffer,
      mimetype: "image/jpeg",
    } as Express.Multer.File),
  ).rejects.toMatchObject({ code: "UPLOAD_INVALID" });
  expect(upload).not.toHaveBeenCalled();
});
it("does not report success if audit persistence fails and removes the uploaded artifact", async () => {
  const { db, insert, remove } = fixture();
  insert.mockResolvedValueOnce({ error: Error("database") } as any);
  const buffer = await sharp({
    create: { width: 10, height: 10, channels: 3, background: "blue" },
  })
    .png()
    .toBuffer();
  await expect(
    uploadArtwork(db, "actor", "clinic", {
      buffer,
      mimetype: "image/png",
    } as Express.Multer.File),
  ).rejects.toMatchObject({ code: "DATABASE_UNAVAILABLE" });
  expect(remove).toHaveBeenCalledTimes(1);
});
