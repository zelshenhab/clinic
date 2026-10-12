import { useState } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { Plus, Search, Stethoscope } from "lucide-react";
import { Link } from "react-router-dom";
import { useAdminQuery, useAdminMutation } from "../../hooks/useAdmin";
import { useLocale } from "../../contexts/LocaleContext";
import { useClinic } from "../../contexts/ClinicContext";
import { useDebounced } from "../../hooks/useDebounced";
import {
  QueryState,
  DataTable,
  Pagination,
  PageHeader,
  Dialog,
  Failure,
  Submit,
  Status,
} from "../../components/Shared";
import {
  Field,
  TranslatedFields,
  CheckOptions,
  ImageField,
} from "../../components/FormFields";
import { catalogDefaults, catalogSchemas } from "../../utils/formSchemas";
import { dateInput, toInstant } from "../../utils/time";
export default function CatalogPage({ resource }) {
  const { t, text, locale } = useLocale(),
    { clinic } = useClinic();
  const [search, setSearch] = useState(""),
    [page, setPage] = useState(1),
    [edit, setEdit] = useState(null),
    [active, setActive] = useState(""),
    [confirm, setConfirm] = useState(null);
  const term = useDebounced(search),
    query = useAdminQuery(resource, {
      search: term,
      page,
      limit: 20,
      ...(active ? { active } : {}),
    });
  const mutation = useAdminMutation(resource + "/" + confirm?.id, "patch");
  const columns = [
    ...(resource === "doctors"
      ? [
          {
            key: "photo_url",
            render: (r) =>
              r.photo_url ? (
                <img
                  className="table-avatar"
                  src={r.photo_url}
                  alt={text(r.name)}
                />
              ) : (
                <span className="table-avatar fallback">
                  <Stethoscope size={19} />
                </span>
              ),
          },
        ]
      : []),
    {
      key: resource === "promotions" ? "title" : "name",
      render: (r) => <strong>{text(r.name || r.title)}</strong>,
    },
    ...(resource === "doctors"
      ? [
          { key: "experience_years" },
          { key: "clinic", render: () => text(clinic.name) },
          {
            key: "specialty_ids",
            render: (r) =>
              (r.specialties || []).map((s) => text(s.name)).join(", "),
          },
          { key: "starting_price_rub", label: "price_rub" },
        ]
      : resource === "services"
        ? [
            { key: "duration_minutes" },
            {
              key: "price_rub",
              render: (r) =>
                new Intl.NumberFormat(locale, {
                  style: "currency",
                  currency: "RUB",
                }).format(r.price_rub),
            },
          ]
        : resource === "promotions"
          ? [
              {
                key: "starts_at",
                render: (r) => dateInput(r.starts_at, clinic.timezone),
              },
              {
                key: "ends_at",
                render: (r) => dateInput(r.ends_at, clinic.timezone),
              },
            ]
          : [{ key: "icon" }, { key: "sort_order" }]),
    {
      key: "active",
      render: (r) => <Status value={r.active ? "active" : "inactive"} />,
    },
    {
      key: "actions",
      render: (r) => (
        <div className="table-actions">
          <button className="text-button" onClick={() => setEdit(r.id)}>
            {t("edit")}
          </button>
          <button className="text-button" onClick={() => setConfirm(r)}>
            {t(r.active ? "archive" : "activate")}
          </button>
          {resource === "doctors" && (
            <Link to={"/schedules?doctor=" + r.id}>{t("schedules")}</Link>
          )}
        </div>
      ),
    },
  ];
  return (
    <>
      <PageHeader
        title={t(resource)}
        subtitle={t("localizedContent")}
        actions={
          <button className="button" onClick={() => setEdit("new")}>
            <Plus size={18} />
            {t("create")}
          </button>
        }
      />
      <section className="panel">
        <div className="toolbar">
          <label className="search-input">
            <Search size={17} />
            <input
              value={search}
              placeholder={t("search")}
              aria-label={t("search")}
              onChange={(e) => {
                setSearch(e.target.value);
                setPage(1);
              }}
            />
          </label>
          <select
            aria-label={t("active")}
            value={active}
            onChange={(e) => {
              setActive(e.target.value);
              setPage(1);
            }}
          >
            <option value="">{t("all")}</option>
            <option value="true">{t("active")}</option>
            <option value="false">{t("inactive")}</option>
          </select>
        </div>
        <QueryState query={query}>
          {(data) => (
            <>
              <DataTable rows={data.items} columns={columns} />
              <Pagination value={data.pagination} onPage={setPage} />
            </>
          )}
        </QueryState>
      </section>
      {edit && (
        <Dialog
          title={t(edit === "new" ? "create" : "edit") + " · " + t(resource)}
          onClose={() => setEdit(null)}
        >
          <EditorLoader
            key={resource + edit}
            resource={resource}
            id={edit}
            onDone={() => setEdit(null)}
          />
        </Dialog>
      )}
      {confirm && (
        <Dialog title={t("confirmAction")} onClose={() => setConfirm(null)}>
          <p>{t(confirm.active ? "confirmDeactivation" : "confirmBody")}</p>
          <button
            className="button danger"
            disabled={mutation.isPending}
            onClick={() =>
              mutation.mutate(
                { active: !confirm.active },
                { onSuccess: () => setConfirm(null) },
              )
            }
          >
            {t("confirm")}
          </button>
          {mutation.error && <Failure error={mutation.error} />}
        </Dialog>
      )}
    </>
  );
}
function EditorLoader({ resource, id, onDone }) {
  const query = useAdminQuery(resource + "/" + id, {}, id !== "new");
  return id === "new" ? (
    <CatalogEditor resource={resource} onDone={onDone} />
  ) : (
    <QueryState query={query}>
      {(row) => <CatalogEditor resource={resource} row={row} onDone={onDone} />}
    </QueryState>
  );
}
function CatalogEditor({ resource, row, onDone }) {
  const { t, text } = useLocale(),
    { clinic, access } = useClinic(),
    options = useAdminQuery("catalog-options");
  const defaults = catalogDefaults(resource, row);
  if (resource === "promotions") {
    defaults.starts_at = defaults.starts_at
      ? dateInput(defaults.starts_at, clinic.timezone)
      : "";
    defaults.ends_at = defaults.ends_at
      ? dateInput(defaults.ends_at, clinic.timezone)
      : "";
  }
  const {
    register,
    handleSubmit,
    setValue,
    formState: { errors },
  } = useForm({
    defaultValues: defaults,
    resolver: zodResolver(catalogSchemas[resource]),
  });
  const mutation = useAdminMutation(
    resource + (row ? "/" + row.id : ""),
    row ? "patch" : "post",
  );
  return (
    <form
      noValidate
      className="stack-form"
      onSubmit={handleSubmit((input) => {
        const data = { ...input };
        if (!data.doctor_id) delete data.doctor_id;
        if (resource === "promotions") {
          data.starts_at = toInstant(data.starts_at, clinic.timezone);
          data.ends_at = toInstant(data.ends_at, clinic.timezone);
          if (!data.action_kind) data.action_kind = null;
        }
        mutation.mutate(data, { onSuccess: onDone });
      })}
    >
      <TranslatedFields
        name={resource === "promotions" ? "title" : "name"}
        register={register}
        errors={errors}
      />
      <TranslatedFields
        name="description"
        area
        register={register}
        errors={errors}
      />
      {resource === "doctors" && (
        <>
          {[
            "professional_title",
            "education",
            "qualifications",
            "biography",
          ].map((name) => (
            <TranslatedFields
              key={name}
              name={name}
              area
              register={register}
              errors={errors}
            />
          ))}
          <Field
            name="experience_years"
            type="number"
            register={register}
            errors={errors}
          />
          <fieldset>
            <legend>{t("languages")}</legend>
            {["ru", "en"].map((code) => (
              <label className="check-label" key={code}>
                <input
                  type="checkbox"
                  value={code}
                  {...register("languages")}
                />
                {t(code)}
              </label>
            ))}
          </fieldset>
          {!row && access.role === "SUPER_ADMIN" && (
            <Field name="doctor_id" register={register} errors={errors} />
          )}
          <ImageField
            name="photo_url"
            register={register}
            errors={errors}
            setValue={setValue}
          />
          <QueryState query={options}>
            {(o) => (
              <>
                <CheckOptions
                  name="specialty_ids"
                  items={o.specialties}
                  register={register}
                />
                <CheckOptions
                  name="service_ids"
                  items={o.services}
                  register={register}
                />
              </>
            )}
          </QueryState>
        </>
      )}
      {resource === "specialties" && (
        <Field
          name="icon"
          register={register}
          errors={errors}
          options={[
            "medical",
            "heart",
            "brain",
            "skin",
            "eye",
            "scan",
            "child",
            "tooth",
            "bone",
          ].map((v) => [v, t("icon_" + v)])}
        />
      )}{" "}
      {resource === "services" && (
        <>
          <QueryState query={options}>
            {(o) => (
              <Field
                name="specialty_id"
                label="specialty"
                register={register}
                errors={errors}
                options={[
                  ["", t("select")],
                  ...o.specialties.map((s) => [s.id, text(s.name)]),
                ]}
              />
            )}
          </QueryState>
          <div className="form-grid">
            <Field
              name="duration_minutes"
              type="number"
              register={register}
              errors={errors}
            />
            <Field
              name="price_rub"
              type="number"
              step="0.01"
              register={register}
              errors={errors}
            />
          </div>
          <Field name="category_key" register={register} errors={errors} />
          <TranslatedFields
            name="category"
            register={register}
            errors={errors}
          />
        </>
      )}
      {["services", "specialties"].includes(resource) && (
        <QueryState query={options}>
          {(o) => (
            <CheckOptions
              name="doctor_ids"
              items={o.doctors}
              register={register}
            />
          )}
        </QueryState>
      )}
      {resource === "promotions" && (
        <>
          <ImageField
            name="image_url"
            register={register}
            errors={errors}
            setValue={setValue}
          />
          <div className="form-grid">
            <Field
              name="starts_at"
              type="datetime-local"
              register={register}
              errors={errors}
            />
            <Field
              name="ends_at"
              type="datetime-local"
              register={register}
              errors={errors}
            />
          </div>
          <Field
            name="action_kind"
            register={register}
            errors={errors}
            options={[
              ["", t("none")],
              ...["doctors", "services", "specialties"].map((v) => [v, t(v)]),
            ]}
          />
        </>
      )}
      <div className="form-grid">
        <Field
          name="sort_order"
          type="number"
          register={register}
          errors={errors}
        />
        <Field
          name="active"
          type="checkbox"
          register={register}
          errors={errors}
        />
        {["doctors", "services"].includes(resource) && (
          <Field
            name="featured"
            type="checkbox"
            register={register}
            errors={errors}
          />
        )}
      </div>
      {mutation.error && <Failure error={mutation.error} />}
      <Submit busy={mutation.isPending} />
    </form>
  );
}
