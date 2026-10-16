import { createClient } from "@supabase/supabase-js";
const url = import.meta.env.VITE_SUPABASE_URL,
  key = import.meta.env.VITE_SUPABASE_ANON_KEY;
function safeKey(value) {
  if (!value || value.startsWith("sb_secret_")) return false;
  if (value.startsWith("sb_publishable_")) return true;
  try {
    return (
      JSON.parse(
        atob(value.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")),
      ).role === "anon"
    );
  } catch {
    return false;
  }
}
export const authStorageKey = url
  ? `sb-${new URL(url).hostname.split(".")[0]}-auth-token`
  : null;
export function clearStoredSession() {
  if (!authStorageKey) return;
  for (const suffix of ["", "-user", "-code-verifier"])
    localStorage.removeItem(authStorageKey + suffix);
}
// Bound logout transport without changing normal Auth/API request behavior.
export async function authFetch(input, init) {
  const address =
    typeof input === "string" ? input : input.url || String(input);
  if (!new URL(address).pathname.endsWith("/auth/v1/logout"))
    return fetch(input, init);
  const controller = new AbortController(),
    abort = () => controller.abort();
  const timer = setTimeout(abort, 4000);
  init?.signal?.addEventListener("abort", abort, { once: true });
  if (init?.signal?.aborted) abort();
  try {
    return await fetch(input, { ...init, signal: controller.signal });
  } finally {
    clearTimeout(timer);
    init?.signal?.removeEventListener("abort", abort);
  }
}
export const supabase =
  url && safeKey(key)
    ? createClient(url, key, {
        global: { fetch: authFetch },
        auth: {
          storageKey: authStorageKey,
          persistSession: true,
          autoRefreshToken: true,
          detectSessionInUrl: true,
        },
      })
    : null;
