import RescheduleRequest from "../doctor/RescheduleRequest";
import { useState } from "react";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useClinic } from "../../contexts/ClinicContext";
import { useLocale } from "../../contexts/LocaleContext";
import {
  Dialog,
  QueryState,
  Status,
  Failure,
  Submit,
} from "../../components/Shared";
import { clinicDate } from "../../utils/time";
import { allowed } from "../../utils/permissions";
import BookingForm from "./BookingForm";
export default function AppointmentDetail({ id, onClose }) {
  const query = useAdminQuery("appointments/" + id),
    { clinic, access } = useClinic(),
    { t, text, locale } = useLocale();
  const [action, setAction] = useState(null);
  const mutation = useAdminMutation("appointments/" + id, "patch");
  return (
    <Dialog title={t("appointments")} onClose={onClose}>
      <QueryState query={query}>
        {(record) => (
          <>
            <div className="detail-hero">
              <div>
                <small>{record.id}</small>
                <h2>{record.patient_name}</h2>
                <p>{record.patient_phone}</p>
              </div>
              <Status value={record.status} />
            </div>
            <div className="detail-grid">
              {[
                ["clinic", text(clinic.name)],
                [
                  "duration_minutes",
                  (Date.parse(record.ends_at) - Date.parse(record.starts_at)) /
                    60000,
                ],
                ["doctor", text(record.doctor_name)],
                ["specialty", text(record.specialty_name)],
                ["service", text(record.service_name)],
                ...(record.family_member_id
                  ? [["account_holder_name", record.account_holder_name]]
                  : []),
                [
                  "starts_at",
                  clinicDate(record.starts_at, clinic.timezone, locale),
                ],
                [
                  "ends_at",
                  clinicDate(record.ends_at, clinic.timezone, locale),
                ],
                [
                  "price_rub",
                  new Intl.NumberFormat(locale, {
                    style: "currency",
                    currency: "RUB",
                  }).format(record.price_rub),
                ],
                [
                  "created_at",
                  clinicDate(record.created_at, clinic.timezone, locale),
                ],
                [
                  "updated_at",
                  clinicDate(record.updated_at, clinic.timezone, locale),
                ],
              ].map(([key, value]) => (
                <div key={key}>
                  <small>{t(key)}</small>
                  <strong>{value}</strong>
                </div>
              ))}
            </div>
            {access.role === "DOCTOR" &&
              ["pending", "confirmed"].includes(record.status) &&
              Date.parse(record.starts_at) > Date.now() && (
                <button
                  className="button secondary"
                  onClick={() => setAction("request")}
                >
                  {t("requestReschedule")}
                </button>
              )}
            {action === "request" && (
              <RescheduleRequest
                record={record}
                onDone={() => setAction(null)}
              />
            )}
            <div className="action-row">
              {[
                ["confirmed", "confirm"],
                ["completed", "complete"],
                ["cancelled", "cancelAppointment"],
                ["no_show", "markNoShow"],
              ]
                .filter(
                  ([status]) =>
                    (record.status === "pending"
                      ? ["confirmed", "cancelled"]
                      : record.status === "confirmed"
                        ? ["completed", "cancelled", "no_show"]
                        : []
                    ).includes(status) &&
                    (access.role !== "DOCTOR" ||
                      ["completed", "no_show"].includes(status)) &&
                    (!["completed", "no_show"].includes(status) ||
                      Date.parse(record.starts_at) <= Date.now()),
                )
                .map(([status, label]) => (
                  <button
                    key={status}
                    className={`button ${status === "cancelled" ? "danger" : "secondary"}`}
                    onClick={() => setAction(status)}
                  >
                    {t(label)}
                  </button>
                ))}
              {allowed(access.role, "book") &&
                ["pending", "confirmed"].includes(record.status) && (
                  <button
                    className="button secondary"
                    onClick={() => setAction("reschedule")}
                  >
                    {t("reschedule")}
                  </button>
                )}
            </div>
            {action && action !== "reschedule" && action !== "request" && (
              <div className="confirmation">
                <strong>{t("confirmAction")}</strong>
                <p>
                  {t("confirmBody")} {t(action)}
                </p>
                <div className="action-row">
                  <button
                    className="button"
                    disabled={mutation.isPending}
                    onClick={() =>
                      mutation.mutate(
                        {
                          status: action,
                          expected_updated_at: record.updated_at,
                        },
                        { onSuccess: () => setAction(null) },
                      )
                    }
                  >
                    {t("confirm")}
                  </button>
                  <button
                    className="button secondary"
                    onClick={() => setAction(null)}
                  >
                    {t("cancel")}
                  </button>
                </div>
              </div>
            )}
            {action === "reschedule" && (
              <BookingForm existing={record} onDone={() => setAction(null)} />
            )}{" "}
            {mutation.error && (
              <Failure error={mutation.error} retry={query.refetch} />
            )}
            <h3>{t("history")}</h3>
            <ul className="timeline">
              {record.history.map((h) => (
                <li key={h.id}>
                  <Status value={h.status} />
                  <time>
                    {clinicDate(h.created_at, clinic.timezone, locale)}
                  </time>
                </li>
              ))}
            </ul>
            <h3>{t("audit")}</h3>
            <ul className="timeline">
              {record.audit.map((h, i) => (
                <li key={i}>
                  <span>
                    {t(h.action)}
                    {h.action === "appointment.rescheduled" &&
                      h.metadata?.before?.starts_at && (
                        <small className="audit-change">
                          {clinicDate(
                            h.metadata.before.starts_at,
                            clinic.timezone,
                            locale,
                          )}{" "}
                          →{" "}
                          {clinicDate(
                            h.metadata.after.starts_at,
                            clinic.timezone,
                            locale,
                          )}
                        </small>
                      )}
                  </span>
                  <time>
                    {clinicDate(h.created_at, clinic.timezone, locale)}
                  </time>
                </li>
              ))}
            </ul>
          </>
        )}
      </QueryState>
    </Dialog>
  );
}
