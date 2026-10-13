import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../services/api";
import { useClinic } from "../contexts/ClinicContext";
import { useLocale } from "../contexts/LocaleContext";
import { useToast } from "../contexts/ToastContext";
export function useDoctorQuery(path, params = {}, enabled = true) {
  const { clinic, access } = useClinic();
  return useQuery({
    queryKey: ["clinic", clinic?.id, "doctor", path, params, access?.doctor_id],
    queryFn: ({ signal }) =>
      api.get("/doctor/" + path, {
        params: { ...params, clinic_id: clinic.id },
        signal,
      }),
    enabled: !!clinic && enabled,
    retry: (count, error) =>
      ![400, 401, 403, 404].includes(error.status) && count < 1,
  });
}
export function useDoctorMutation(path, method = "post") {
  const { clinic } = useClinic(),
    client = useQueryClient(),
    { t } = useLocale(),
    toast = useToast();
  return useMutation({
    mutationFn: (input) =>
      api[method]("/doctor/" + path, { ...input, clinic_id: clinic.id }),
    retry: false,
    onSuccess: () => {
      client.invalidateQueries({ queryKey: ["clinic", clinic.id] });
      toast(t("saved"));
    },
    onError: (error) => toast(t(error.code), "error"),
  });
}
