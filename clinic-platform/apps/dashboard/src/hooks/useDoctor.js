import { doctorQueryOptions } from "../services/queries";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "../services/api";
import { useClinic } from "../contexts/ClinicContext";
import { useLocale } from "../contexts/LocaleContext";
import { useToast } from "../contexts/ToastContext";
export function useDoctorQuery(path, params = {}, enabled = true) {
  const { clinic, access } = useClinic();
  return useQuery({
    ...doctorQueryOptions(clinic, access, path, params),
    enabled: !!clinic && enabled,
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
