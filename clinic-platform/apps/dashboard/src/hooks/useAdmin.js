import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, adminPath } from "../services/api";
import { useClinic } from "../contexts/ClinicContext";
import { useLocale } from "../contexts/LocaleContext";
import { useToast } from "../contexts/ToastContext";
export function useAdminQuery(path, params = {}, enabled = true) {
  const { clinic, access } = useClinic();
  return useQuery({
    queryKey: [
      "clinic",
      clinic?.id,
      path,
      params,
      access?.role,
      access?.doctor_id,
    ],
    queryFn: ({ signal }) => {
      if (access?.role === "DOCTOR") {
        const mapped =
          path === "filter-options"
            ? "options"
            : /^doctors\/[^/]+\/schedules$/.test(path)
              ? "schedule"
              : path;
        const { doctor_id, specialty_id, ...safe } = params;
        return api.get("/doctor/" + mapped, {
          params: { ...safe, clinic_id: clinic.id },
          signal,
        });
      }
      return api.get(adminPath(clinic.id, path), { params, signal });
    },
    enabled: Boolean(clinic) && enabled,
    retry: (count, error) =>
      ![401, 403, 404, 400].includes(error.status) && count < 1,
  });
}
export function useAdminMutation(path, method = "post", successKey = "saved") {
  const { clinic, access } = useClinic(),
    client = useQueryClient(),
    toast = useToast(),
    { t } = useLocale();
  return useMutation({
    mutationFn: (input) =>
      access?.role === "DOCTOR" && /^appointments\/[^/]+$/.test(path)
        ? api.patch("/doctor/" + path + "/status", {
            ...input,
            clinic_id: clinic.id,
          })
        : api[method](adminPath(clinic.id, path), input),
    retry: false,
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["clinic", clinic.id] });
      client.invalidateQueries({ queryKey: ["authorized-clinics"] });
      toast(t(successKey));
    },
    onError: (error) => toast(t(error.code) || t("unexpected"), "error"),
  });
}
