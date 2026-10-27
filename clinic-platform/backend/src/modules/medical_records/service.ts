import multer from "multer";
import type { RequestHandler } from "express";
import { randomUUID } from "node:crypto";
import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { AppError } from "../../common/errors/app-error.js";
import { adminRepository } from "../admin/repository.js";
import { uuid } from "../admin/validation.js";
export const MEDICAL_BUCKET = "medical-records";
const parseUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024, files: 1, fields: 4, fieldSize: 1024 },
}).single("file");
const invalidDocument = () =>
  new AppError(400, "DOCUMENT_INVALID", "Select a PDF, JPEG or PNG file");
// Image uploads share UPLOAD_INVALID; documents report their own limits.
export const recordUpload: RequestHandler = (req, res, next) =>
  parseUpload(req, res, (error?: unknown) =>
    next(error instanceof multer.MulterError ? invalidDocument() : error),
  );
export const recordFields = z
  .object({
    title: z.string().trim().min(1).max(200),
    kind: z.enum(["report", "lab_result", "imaging", "prescription", "other"]),
    appointment_id: uuid.optional(),
    family_member_id: uuid.optional(),
  })
  .strict();
const signatures: [string, string, number[]][] = [
  ["application/pdf", "pdf", [0x25, 0x50, 0x44, 0x46, 0x2d]],
  ["image/jpeg", "jpg", [0xff, 0xd8, 0xff]],
  ["image/png", "png", [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]],
];
// The declared MIME type must match the file's own signature; nothing else is accepted.
export function detectDocument(file?: Express.Multer.File) {
  const match = file
    ? signatures.find(
        ([mime, , bytes]) =>
          mime === file.mimetype && bytes.every((b, i) => file.buffer[i] === b),
      )
    : undefined;
  if (!file || !match) throw invalidDocument();
  return { mime: match[0], ext: match[1] };
}
function safeName(name: string, ext: string) {
  const base = Buffer.from(name, "latin1")
    .toString("utf8")
    .replace(/[\\/\0-\x1f"]/g, "_")
    .trim()
    .slice(0, 180);
  return base || `document.${ext}`;
}
export function medicalRecords(db: SupabaseClient) {
  const repo = adminRepository(db),
    bucket = () => db.storage.from(MEDICAL_BUCKET);
  return {
    async upload(
      actor: string,
      clinic: string,
      patient: string,
      doctorOnly: boolean,
      body: unknown,
      file?: Express.Multer.File,
    ) {
      const fields = recordFields.parse(body),
        { mime, ext } = detectDocument(file),
        path = `${clinic}/${patient}/${randomUUID()}.${ext}`;
      const { error } = await bucket().upload(path, file!.buffer, {
        contentType: mime,
        upsert: false,
      });
      if (error)
        throw new AppError(503, "UPLOAD_FAILED", "Document upload unavailable");
      try {
        return await repo.rpc("medical_record_save", {
          p_actor: actor,
          p_clinic: clinic,
          p_patient: patient,
          p_doctor_only: doctorOnly,
          p_input: {
            ...fields,
            file_name: safeName(file!.originalname, ext),
            mime_type: mime,
            size_bytes: file!.size,
            storage_path: path,
          },
        });
      } catch (failure) {
        await bucket().remove([path]);
        throw failure;
      }
    },
    list: (
      actor: string,
      clinic: string,
      patient: string,
      doctorOnly: boolean,
    ) =>
      repo.rpc("medical_record_list", {
        p_actor: actor,
        p_clinic: clinic,
        p_patient: patient,
        p_doctor_only: doctorOnly,
      }),
    patientList: (actor: string, clinic: string) =>
      repo.rpc("patient_medical_records", { p_actor: actor, p_clinic: clinic }),
    remove: (actor: string, clinic: string, id: string, doctorOnly: boolean) =>
      repo.rpc("medical_record_delete", {
        p_actor: actor,
        p_clinic: clinic,
        p_id: id,
        p_doctor_only: doctorOnly,
      }),
    // Short-lived signed link; the database check runs on every request.
    async download(
      actor: string,
      clinic: string,
      id: string,
      as: "patient" | "staff" | "doctor",
    ) {
      const file = (await repo.rpc("medical_record_file", {
        p_actor: actor,
        p_clinic: clinic,
        p_id: id,
        p_as: as,
      })) as { storage_path: string; file_name: string; mime_type: string };
      const { data, error } = await bucket().createSignedUrl(
        file.storage_path,
        60,
        { download: file.file_name },
      );
      if (error || !data)
        throw new AppError(503, "DOWNLOAD_FAILED", "Document unavailable");
      return {
        url: data.signedUrl,
        expires_in: 60,
        file_name: file.file_name,
        mime_type: file.mime_type,
      };
    },
  };
}
