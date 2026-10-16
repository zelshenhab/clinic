import { useState } from "react";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { QueryState, Failure, Submit } from "../../components/Shared";
export default function BookingPolicy() {
  const q = useAdminQuery("booking-policy");
  return (
    <QueryState query={q}>
      {(data) => <Editor key={JSON.stringify(data)} data={data} />}
    </QueryState>
  );
}
function Editor({ data }) {
  const { t } = useLocale(),
    mutation = useAdminMutation("booking-policy", "patch");
  const [values, setValues] = useState(data);
  return (
    <form
      className="panel stack-form"
      onSubmit={(e) => {
        e.preventDefault();
        mutation.mutate({
          cancellation_notice_minutes: Number(
            values.cancellation_notice_minutes,
          ),
          reschedule_notice_minutes: Number(values.reschedule_notice_minutes),
        });
      }}
    >
      <h2>{t("bookingPolicy")}</h2>
      <p>{t("bookingPolicyHelp")}</p>
      {["cancellation_notice_minutes", "reschedule_notice_minutes"].map(
        (key) => (
          <label key={key}>
            {t(key)}
            <input
              type="number"
              required
              min="0"
              max="10080"
              step="1"
              value={values[key]}
              onChange={(e) =>
                setValues((v) => ({ ...v, [key]: e.target.value }))
              }
            />
          </label>
        ),
      )}
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
    </form>
  );
}
