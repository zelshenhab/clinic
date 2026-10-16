import type { SupabaseClient } from "@supabase/supabase-js";
/** Durable, idempotent in-app reminders and waitlist offers; no external delivery. */
export function startPatientJobs(db: SupabaseClient, intervalMs = 60_000) {
  let running = false;
  let stopped = false;
  const run = async () => {
    if (running || stopped) return;
    running = true;
    try {
      const { error } = await db
        .rpc("process_patient_jobs")
        .abortSignal(AbortSignal.timeout(15_000));
      if (error)
        console.warn(
          "Patient notification jobs unavailable; check database migrations.",
        );
    } catch {
      console.warn(
        "Patient notification jobs unavailable; retrying next interval.",
      );
    } finally {
      running = false;
    }
  };
  void run();
  const timer = setInterval(() => void run(), intervalMs);
  timer.unref();
  return () => {
    stopped = true;
    clearInterval(timer);
  };
}
