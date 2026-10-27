import { it, expect, vi } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { medicalRecords } from "../src/modules/medical_records/service.js";
const clinic = "12a30244-3000-4000-8000-000000000001",
  patient = "12a30244-3000-4000-8000-000000000002";
function fixture(rpcError?: { message: string; code?: string }) {
  const upload = vi.fn(async () => ({ error: null })),
    remove = vi.fn(async () => ({ error: null })),
    createSignedUrl = vi.fn(async () => ({
      data: { signedUrl: "https://example.invalid/signed" },
      error: null,
    })),
    rpc = vi.fn(async (name: string) =>
      rpcError
        ? { data: null, error: rpcError }
        : {
            data:
              name === "medical_record_file"
                ? {
                    storage_path: `${clinic}/${patient}/x.pdf`,
                    file_name: "Анализ.pdf",
                    mime_type: "application/pdf",
                  }
                : { id: "record" },
            error: null,
          },
    ),
    from = vi.fn(() => ({ upload, remove, createSignedUrl }));
  const db = { storage: { from }, rpc } as unknown as SupabaseClient;
  return { db, upload, remove, createSignedUrl, rpc, from };
}
const pdf = (mimetype = "application/pdf") =>
  ({
    buffer: Buffer.from("%PDF-1.7\n%fictional"),
    mimetype,
    originalname: Buffer.from("Анализ крови.pdf", "utf8").toString("latin1"),
    size: 19,
  }) as Express.Multer.File;
it("stores verified documents in the private bucket under a clinic/patient path", async () => {
  const f = fixture();
  await medicalRecords(f.db).upload(
    "actor",
    clinic,
    patient,
    false,
    { title: "Blood", kind: "lab_result" },
    pdf(),
  );
  expect(f.from).toHaveBeenCalledWith("medical-records");
  const [path, , options] = f.upload.mock.calls[0] as any;
  expect(path).toMatch(new RegExp(`^${clinic}/${patient}/[0-9a-f-]+\\.pdf$`));
  expect(options).toEqual({ contentType: "application/pdf", upsert: false });
  const args = (f.rpc.mock.calls[0] as any)[1];
  expect(args.p_input).toMatchObject({
    title: "Blood",
    kind: "lab_result",
    file_name: "Анализ крови.pdf",
    mime_type: "application/pdf",
    storage_path: path,
  });
});
it("rejects mismatched signatures and unknown fields before storage writes", async () => {
  const f = fixture(),
    records = medicalRecords(f.db);
  await expect(
    records.upload(
      "actor",
      clinic,
      patient,
      false,
      { title: "X", kind: "report" },
      pdf("image/png"),
    ),
  ).rejects.toMatchObject({ code: "DOCUMENT_INVALID" });
  await expect(
    records.upload(
      "actor",
      clinic,
      patient,
      false,
      { title: "X", kind: "report" },
      {
        ...pdf(),
        buffer: Buffer.from("<html>"),
      } as Express.Multer.File,
    ),
  ).rejects.toMatchObject({ code: "DOCUMENT_INVALID" });
  await expect(
    records.upload(
      "actor",
      clinic,
      patient,
      false,
      { title: "X", kind: "report", patient_id: "x" },
      pdf(),
    ),
  ).rejects.toThrow();
  expect(f.upload).not.toHaveBeenCalled();
});
it("removes the stored file when the database refuses the record", async () => {
  const f = fixture({ message: "FORBIDDEN" });
  await expect(
    medicalRecords(f.db).upload(
      "actor",
      clinic,
      patient,
      true,
      { title: "X", kind: "report" },
      pdf(),
    ),
  ).rejects.toMatchObject({ status: 403 });
  expect(f.remove).toHaveBeenCalledWith([(f.upload.mock.calls[0] as any)[0]]);
});
it("signs a one-minute download only after the database check", async () => {
  const f = fixture();
  const link = await medicalRecords(f.db).download(
    "patient",
    clinic,
    "record",
    "patient",
  );
  expect(f.rpc).toHaveBeenCalledWith("medical_record_file", {
    p_actor: "patient",
    p_clinic: clinic,
    p_id: "record",
    p_as: "patient",
  });
  expect(f.createSignedUrl).toHaveBeenCalledWith(
    `${clinic}/${patient}/x.pdf`,
    60,
    {
      download: "Анализ.pdf",
    },
  );
  expect(link).toMatchObject({
    url: "https://example.invalid/signed",
    expires_in: 60,
  });
});
