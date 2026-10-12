import { zodResolver } from "@hookform/resolvers/zod";
import { settingsFormSchema } from "../../utils/formSchemas";
import { useForm } from "react-hook-form";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import {
  PageHeader,
  QueryState,
  Submit,
  Failure,
} from "../../components/Shared";
import {
  Field,
  TranslatedFields,
  ImageField,
} from "../../components/FormFields";
export default function SettingsPage() {
  const { t } = useLocale(),
    query = useAdminQuery("settings");
  return (
    <>
      <PageHeader title={t("settings")} subtitle={t("settingsHelp")} />
      <QueryState query={query}>
        {(data) => <Editor key={data.updated_at} data={data} />}
      </QueryState>
    </>
  );
}
function Editor({ data }) {
  const { t } = useLocale(),
    { access } = useClinic();
  const form = useForm({
      resolver: zodResolver(settingsFormSchema),
      defaultValues: {
        name: data.name,
        description: data.description,
        address: data.address,
        phone: data.phone,
        email: data.email || "",
        website: data.website || null,
        timezone: data.timezone,
        logo_url: data.logo_url,
        image_url: data.image_url,
        working_hours: data.working_hours || {},
        booking: { slot_step_minutes: data.booking?.slot_step_minutes || 15 },
        active: data.active,
      },
    }),
    mutation = useAdminMutation("settings", "patch");
  return (
    <form
      className="panel stack-form"
      noValidate
      onSubmit={form.handleSubmit((v) => {
        if (access.role !== "SUPER_ADMIN") delete v.active;
        v.email = v.email || null;
        mutation.mutate(v);
      })}
    >
      {["name", "description", "address"].map((name) => (
        <TranslatedFields
          key={name}
          name={name}
          register={form.register}
          errors={form.formState.errors}
          area={name === "description"}
        />
      ))}
      <div className="form-grid">
        {["phone", "email", "website", "timezone"].map((name) => (
          <Field
            key={name}
            name={name}
            type={
              name === "email" ? "email" : name === "website" ? "url" : "text"
            }
            nullable={name === "website"}
            register={form.register}
            errors={form.formState.errors}
            required={name === "timezone" || name === "phone"}
          />
        ))}
        {["logo_url", "image_url"].map((name) => (
          <ImageField
            key={name}
            name={name}
            register={form.register}
            errors={form.formState.errors}
            setValue={form.setValue}
          />
        ))}
      </div>
      <fieldset>
        <legend>{t("working_hours")}</legend>
        <div className="form-grid">
          {[
            ...new Set([
              "weekdays",
              "saturday",
              "sunday",
              ...Object.keys(data.working_hours || {}),
            ]),
          ].map((k) => (
            <Field
              key={k}
              name={"working_hours." + k}
              label={k}
              register={form.register}
              errors={form.formState.errors}
            />
          ))}
        </div>
      </fieldset>
      <fieldset>
        <legend>{t("booking")}</legend>
        <Field
          label="slot_step_minutes"
          name="booking.slot_step_minutes"
          type="number"
          min={5}
          max={60}
          step={5}
          register={form.register}
          errors={form.formState.errors}
        />
      </fieldset>
      {access.role === "SUPER_ADMIN" && (
        <Field
          name="active"
          type="checkbox"
          register={form.register}
          errors={form.formState.errors}
        />
      )}{" "}
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
    </form>
  );
}
