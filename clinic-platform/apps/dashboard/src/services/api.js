import axios from "axios";
import { supabase } from "./supabase";
export class ApiError extends Error {
  constructor(code, status, details = {}) {
    super(code);
    this.code = code;
    this.status = status;
    this.details = details;
  }
}
export const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || "http://localhost:3000/api/v1",
  timeout: 20000,
});
api.interceptors.request.use(async (config) => {
  if (config.url?.startsWith("/admin") || config.url?.startsWith("/doctor")) {
    const session = await supabase?.auth.getSession();
    const token = session?.data?.session?.access_token;
    if (!token) throw new ApiError("UNAUTHORIZED", 401);
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});
let refreshPromise;
api.interceptors.response.use(
  (response) => {
    if (response.data?.success !== true)
      throw new ApiError("INVALID_RESPONSE", 502);
    return response.data.data;
  },
  async (error) => {
    if (error instanceof ApiError) throw error;
    const config = error.config;
    if (
      error.response?.status === 401 &&
      config &&
      !config._refreshed &&
      supabase
    ) {
      config._refreshed = true;
      refreshPromise ??= supabase.auth
        .refreshSession()
        .finally(() => (refreshPromise = null));
      const { data, error: refreshError } = await refreshPromise;
      if (!refreshError && data.session) return api(config);
      await supabase.auth.signOut({ scope: "local" });
    }
    if (error.response?.status === 401 && config?._refreshed && supabase)
      await supabase.auth.signOut({ scope: "local" });
    if (axios.isCancel(error)) throw error;
    throw new ApiError(
      error.response?.data?.error?.code ||
        (error.code === "ECONNABORTED" ? "TIMEOUT" : "NETWORK_ERROR"),
      error.response?.status || 0,
      error.response?.data?.error?.details || {},
    );
  },
);
export async function fetchClinics({ signal }) {
  return api.get("/clinics", { signal });
}
export const adminPath = (clinic, path = "") =>
  `/admin/clinics/${clinic}${path ? "/" + path : ""}`;
