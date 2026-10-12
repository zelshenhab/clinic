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
    queryFn: ({ signal }) =>
      api.get(adminPath(clinic.id, path), { params, signal }),
    enabled: Boolean(clinic) && enabled,
    retry: (count, error) =>
      ![401, 403, 404, 400].includes(error.status) && count < 1,
  });
}
export function useAdminMutation(path, method = "post", successKey = "saved") {
  const { clinic } = useClinic(),
    client = useQueryClient(),
    toast = useToast(),
    { t } = useLocale();
  return useMutation({
    mutationFn: (input) => api[method](adminPath(clinic.id, path), input),
    retry: false,
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["clinic", clinic.id] });
      client.invalidateQueries({ queryKey: ["authorized-clinics"] });
      toast(t(successKey));
    },
    onError: (error) => toast(t(error.code) || t("unexpected"), "error"),
  });
}
