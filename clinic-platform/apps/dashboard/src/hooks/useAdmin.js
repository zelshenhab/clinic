import { adminQueryOptions } from "../services/queries";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api, adminPath } from "../services/api";
import { useClinic } from "../contexts/ClinicContext";
import { useLocale } from "../contexts/LocaleContext";
import { useToast } from "../contexts/ToastContext";
export function useAdminQuery(path, params = {}, enabled = true) {
  const { clinic, access } = useClinic();
  return useQuery({
    ...adminQueryOptions(clinic, access, path, params),
    enabled: Boolean(clinic) && enabled,
    refetchInterval: path === "queue" ? 30000 : false,
  });
}
export function useAdminMutation(path, method = "post", successKey = "saved") {
  const { clinic, access } = useClinic(),
    client = useQueryClient(),
    toast = useToast(),
    { t } = useLocale();
  return useMutation({
    mutationFn: (input) =>
      access?.role === "DOCTOR" &&
      /^appointments\/[^/]+(?:\/attendance)?$/.test(path)
        ? api.patch(
            "/doctor/" + path + (path.endsWith("/attendance") ? "" : "/status"),
            {
              ...input,
              clinic_id: clinic.id,
            },
          )
        : api[method](adminPath(clinic.id, path), input),
    retry: false,
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["clinic", clinic.id] });
      if (["staff", "settings"].includes(path.split("/")[0]))
        client.invalidateQueries({ queryKey: ["authorized-clinics"] });
      toast(t(successKey));
    },
    onError: (error) => toast(t(error.code) || t("unexpected"), "error"),
  });
}
