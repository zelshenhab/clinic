import { zodResolver } from "@hookform/resolvers/zod";
import { staffFormSchema } from "../../utils/formSchemas";
import SystemSettings from "./SystemSettings";
import { useState } from "react";
import { useForm } from "react-hook-form";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import {
  PageHeader,
  QueryState,
  DataTable,
  Pagination,
  Dialog,
  Submit,
  Failure,
  Status,
} from "../../components/Shared";
import { Field } from "../../components/FormFields";
export default function StaffPage() {
  const { t } = useLocale(),
    [page, setPage] = useState(1),
    [editing, setEditing] = useState(null),
    query = useAdminQuery("staff", { page, limit: 20 });
  return (
    <>
      <PageHeader
        title={t("staff")}
        actions={
          <button className="button" onClick={() => setEditing({})}>
            {t("inviteStaff")}
          </button>
        }
      />
      <section className="panel">
        <QueryState query={query}>
          {(data) => (
            <>
              <DataTable
                rows={data.items}
                columns={[
                  { key: "user_id" },
                  { key: "role", render: (r) => t(r.role) },
                  { key: "doctor_id" },
                  {
                    key: "active",
                    render: (r) => (
                      <Status value={r.active ? "active" : "inactive"} />
                    ),
                  },
                  {
                    key: "actions",
                    render: (r) => (
                      <button
                        className="text-button"
                        onClick={() => setEditing(r)}
                      >
                        {t("edit")}
                      </button>
                    ),
                  },
                ]}
              />
              <Pagination value={data} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      <SystemSettings />
      {editing && (
        <Dialog title={t("inviteStaff")} onClose={() => setEditing(null)}>
          <StaffForm initial={editing} onDone={() => setEditing(null)} />
        </Dialog>
      )}
    </>
  );
}
function StaffForm({ initial, onDone }) {
  const { t, text } = useLocale(),
    options = useAdminQuery("catalog-options"),
    form = useForm({
      resolver: zodResolver(staffFormSchema),
      defaultValues: {
        user_id: initial.user_id || "",
        email: "",
        role: initial.role || "RECEPTIONIST",
        doctor_id: initial.doctor_id || "",
        active: initial.active ?? true,
      },
    }),
    role = form.watch("role"),
    mutation = useAdminMutation("staff");
  return (
    <form
      className="stack-form"
      noValidate
      onSubmit={form.handleSubmit((v) =>
        mutation.mutate(
          {
            ...v,
            role: initial.role || v.role,
            user_id: v.user_id || undefined,
            email: v.email || undefined,
            doctor_id:
              (initial.role || v.role) === "DOCTOR" ? v.doctor_id : null,
          },
          { onSuccess: onDone },
        ),
      )}
    >
      <p className="muted">{t("invitationHelp")}</p>
      <Field
        name="user_id"
        register={form.register}
        errors={form.formState.errors}
        readOnly={Boolean(initial.user_id)}
      />
      {!initial.user_id && (
        <Field
          name="email"
          type="email"
          register={form.register}
          errors={form.formState.errors}
        />
      )}
      <Field
        name="role"
        register={form.register}
        errors={form.formState.errors}
        disabled={Boolean(initial.user_id)}
        options={["CLINIC_ADMIN", "RECEPTIONIST", "DOCTOR"].map((r) => [
          r,
          t(r),
        ])}
      />
      {role === "DOCTOR" && (
        <QueryState query={options}>
          {(o) => (
            <Field
              label="doctor"
              name="doctor_id"
              register={form.register}
              errors={form.formState.errors}
              required
              options={[
                ["", t("select")],
                ...o.doctors.map((d) => [d.id, text(d.name)]),
              ]}
            />
          )}
        </QueryState>
      )}
      <Field
        name="active"
        type="checkbox"
        register={form.register}
        errors={form.formState.errors}
      />
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
    </form>
  );
}
