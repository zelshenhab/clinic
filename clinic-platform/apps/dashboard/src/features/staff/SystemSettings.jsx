import { useState } from "react";
import { zodResolver } from "@hookform/resolvers/zod";
import { systemFormSchema } from "../../utils/formSchemas";
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query";
import { useForm } from "react-hook-form";
import { api } from "../../services/api";
import { useLocale } from "../../contexts/LocaleContext";
import { useToast } from "../../contexts/ToastContext";
import { QueryState, Submit, Failure, Dialog } from "../../components/Shared";
import { Field } from "../../components/FormFields";
export default function SystemSettings() {
  const query = useQuery({
      queryKey: ["system-settings"],
      queryFn: () => api.get("/admin/system"),
    }),
    { t } = useLocale();
  return (
    <section className="panel">
      <h2>{t("systemSettings")}</h2>
      <QueryState query={query}>
        {(data) => <Editor key={data.updated_at} data={data} />}
      </QueryState>
    </section>
  );
}
function Editor({ data }) {
  const [pending, setPending] = useState(null);
  const { t } = useLocale(),
    client = useQueryClient(),
    toast = useToast(),
    form = useForm({
      resolver: zodResolver(systemFormSchema),
      defaultValues: data,
    }),
    mutation = useMutation({
      mutationFn: (input) => api.patch("/admin/system", input),
      onSuccess: () => {
        client.invalidateQueries({ queryKey: ["system-settings"] });
        client.invalidateQueries({ queryKey: ["clinic"] });
        toast(t("saved"));
        setPending(null);
      },
    });
  return (
    <form
      className="stack-form"
      noValidate
      onSubmit={form.handleSubmit((v) => setPending(v))}
    >
      <p className="muted">{t("systemSettingsHelp")}</p>
      <Field
        name="booking_horizon_days"
        type="number"
        min={7}
        max={180}
        register={form.register}
        errors={form.formState.errors}
      />
      <Field
        name="booking_enabled"
        type="checkbox"
        register={form.register}
        errors={form.formState.errors}
      />
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
      {pending && (
        <Dialog title={t("confirmAction")} onClose={() => setPending(null)}>
          <p>{t("systemSettingsHelp")}</p>
          {mutation.error && <Failure error={mutation.error} />}
          <button
            type="button"
            className="button"
            disabled={mutation.isPending}
            onClick={() => mutation.mutate(pending)}
          >
            {t("confirm")}
          </button>
        </Dialog>
      )}
    </form>
  );
}
