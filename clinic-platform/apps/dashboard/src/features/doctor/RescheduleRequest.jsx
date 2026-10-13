import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { useDoctorMutation } from "../../hooks/useDoctor";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import { Submit, Failure } from "../../components/Shared";
import { toInstant } from "../../utils/time";
const schema = z.object({
  starts_at: z.string().min(1),
  reason: z.string().trim().min(5).max(2000),
});
export default function RescheduleRequest({ record, onDone }) {
  const { t } = useLocale(),
    { clinic } = useClinic(),
    m = useDoctorMutation("schedule-change-requests"),
    f = useForm({ resolver: zodResolver(schema) });
  return (
    <form
      noValidate
      className="stack-form confirmation"
      onSubmit={f.handleSubmit((v) => {
        const starts_at = toInstant(v.starts_at, clinic.timezone);
        if (!starts_at) {
          f.setError("starts_at", { message: "fieldInvalid" });
          return;
        }
        m.mutate(
          {
            kind: "reschedule",
            reason: v.reason,
            payload: {
              appointment_id: record.id,
              expected_updated_at: record.updated_at,
              starts_at,
            },
          },
          { onSuccess: onDone },
        );
      })}
    >
      <h3>{t("requestReschedule")}</h3>
      <p>{t("approvalRequired")}</p>
      <label>
        {t("starts_at")}
        <input type="datetime-local" {...f.register("starts_at")} />
        {f.formState.errors.starts_at && (
          <small className="field-error">{t("fieldInvalid")}</small>
        )}
      </label>
      <label>
        {t("requestReason")}
        <textarea maxLength={2000} {...f.register("reason")} />
        {f.formState.errors.reason && (
          <small className="field-error">{t("fieldInvalid")}</small>
        )}
      </label>
      <Submit busy={m.isPending}>{t("submitRequest")}</Submit>
      {m.error && <Failure error={m.error} />}
    </form>
  );
}
