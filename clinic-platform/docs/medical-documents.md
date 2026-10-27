# Medical documents

Apply `supabase/migrations/202610260012_medical_documents.sql` once in the Supabase SQL Editor, after migration 011 (family members). It extends the existing unused `medical_records` table, creates the private `medical-records` Storage bucket and the access functions. Restart `npm run dev:api`, refresh the dashboard and rebuild Flutter.

## Where to use it

- **Dashboard → Patients → View** (administrator or receptionist) and **Doctor → My patients → patient**: the **Medical documents** section uploads a PDF, JPEG or PNG (up to 10 MB). Each upload has a title, type (doctor's report, lab results, imaging, prescription, other) and an optional appointment. Linking an appointment automatically attributes the document to that appointment's family member. The list opens a file through a one-minute signed link, and removal archives it.
- **Flutter → Profile → Medical documents**: the account holder sees their own documents and their family members' documents in the selected clinic. A person filter appears when family documents exist. Tapping a document requests a fresh signed link and hands it to the system viewer (PDF viewer/browser), where the patient can view, share or save it.
- Every upload creates a durable in-app notification ("New medical document"). Its action opens Medical documents.

## Access rules

- Clinic administrators and receptionists can upload, list, open and archive documents for any patient of their clinic.
- A doctor can do so only for patients who have an appointment with that doctor in the clinic, and can archive only documents they uploaded. Uploads by a doctor record that doctor.
- A patient can list and open only documents where they are the account holder (`patient_id`). This includes documents of their family members.
- Files are never public. The API signs a 60-second download after a database check on every request, and staff opens are written to `audit_logs`. Uploads are checked against the file signature (`%PDF-`, JPEG, PNG), stored as `clinic/patient/random-uuid.ext`, and removed again if the database refuses the record.
- No browser role can execute the new functions or read the table directly.

## Verification

104 backend tests (including SQL access, family attribution, notification and privilege checks on PGlite), 34 dashboard tests and 65 Flutter tests passed. Flutter analysis is clean and the dashboard builds. Hosted Storage signed URLs, the hosted migration and on-device viewing have not been verified.
