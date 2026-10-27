# Family profile and add to calendar

Apply `supabase/migrations/202610260011_family_members.sql` once in the Supabase SQL Editor, after migrations 001–010. Restart `npm run dev:api` and rebuild Flutter.

## Family profile

- **Flutter → Profile → My family**: a signed-in patient adds, edits and removes relatives (name, relationship, optional date of birth). Up to 10 active members per account. Relatives have no login of their own.
- **Booking confirmation**: when the account has family members, the confirmation dialog asks who the appointment is for (Myself or a member). The receipt and **My appointments** show "For: name".
- The appointment stays owned by the account holder (`patient_id`), so cancellation, rescheduling, policy, reminders and notifications work unchanged and reach the account holder. `appointments.family_member_id` records the attending person. A composite foreign key ties it to the same owner, and booking rejects archived or foreign members with `NOT_FOUND`.
- Removing a member archives it (`active=false`). Past and upcoming appointments keep their attribution, but the member can no longer be booked.
- **Dashboard**: `admin_appointments.patient_name` is now the attending person's name, so lists, calendar, queue and the doctor workspace show who is actually coming. Appointment details add **Booked by** with the account holder, and `patient_phone` remains the account holder's phone. Search matches either name. The doctor "patients" list still groups by account.
- Not included: waitlist entries for family members, and separate medical records per family member.

## Add to calendar

The booking receipt and each upcoming pending or confirmed appointment have **Add to calendar**. The button opens the system calendar editor (via `add_2_calendar`) prefilled with the doctor, service, clinic address and the clinic-timezone time, and the patient saves the event there. The app requests no calendar read permission. Android declares an `INSERT` intent query, and iOS declares the calendar usage descriptions. `add_2_calendar` is pinned to 3.0.1 because 3.1.1's Kotlin Gradle script does not compile with this Android toolchain.

## Verification

97 backend tests (including SQL ownership/archival/staff-name checks on PGlite), 32 dashboard tests and 62 Flutter tests passed. Flutter analysis is clean, and Android debug APK and iOS no-codesign builds succeed. Hosted migration execution and on-device calendar interaction have not been verified.
