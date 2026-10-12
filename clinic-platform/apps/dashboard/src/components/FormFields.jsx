import { useLocale } from "../contexts/LocaleContext";
import { useAdminMutation } from "../hooks/useAdmin";
import { useToast } from "../contexts/ToastContext";
export function Field({
  label,
  name,
  register,
  errors,
  type = "text",
  options,
  nullable = false,
  ...rest
}) {
  const { t } = useLocale();
  const error = name.split(".").reduce((v, k) => v?.[k], errors);
  return (
    <label>
      {t(label || name)}
      {options ? (
        <select aria-label={t(label || name)} {...register(name)} {...rest}>
          {options.map(([value, label]) => (
            <option key={value} value={value}>
              {label}
            </option>
          ))}
        </select>
      ) : type === "textarea" ? (
        <textarea rows={3} {...register(name)} {...rest} />
      ) : type === "checkbox" ? (
        <input type="checkbox" {...register(name)} {...rest} />
      ) : (
        <input
          type={type}
          {...register(name, {
            ...(type === "number"
              ? { valueAsNumber: true }
              : nullable
                ? { setValueAs: (v) => v || null }
                : {}),
          })}
          {...rest}
        />
      )}{" "}
      {error && <small className="field-error">{t("fieldInvalid")}</small>}
    </label>
  );
}
export function TranslatedFields({ name, register, errors, area = false }) {
  const { t } = useLocale();
  return (
    <fieldset>
      <legend>{t(name)}</legend>
      <div className="form-grid">
        {["ru", "en"].map((locale) => (
          <Field
            key={locale}
            label={locale}
            name={name + "." + locale}
            register={register}
            errors={errors}
            type={area ? "textarea" : "text"}
          />
        ))}
      </div>
    </fieldset>
  );
}
export function CheckOptions({ name, items, register }) {
  const { t, text } = useLocale();
  return (
    <fieldset>
      <legend>{t(name)}</legend>
      <div className="checkbox-grid">
        {items.map((item) => (
          <label className="check-label" key={item.id}>
            <input type="checkbox" value={item.id} {...register(name)} />
            {text(item.name)}
          </label>
        ))}
      </div>
    </fieldset>
  );
}
export function ImageField({ name, register, errors, setValue }) {
  const { t } = useLocale(),
    toast = useToast(),
    mutation = useAdminMutation("uploads", "post", "imageUploaded");
  return (
    <div>
      <Field
        name={name}
        register={register}
        errors={errors}
        type="url"
        nullable
      />
      <label className="upload-control">
        {t("upload")}
        <input
          type="file"
          accept="image/jpeg,image/png,image/webp"
          disabled={mutation.isPending}
          onChange={async (e) => {
            const file = e.target.files?.[0];
            if (!file) return;
            if (
              file.size > 5 * 1024 * 1024 ||
              !["image/jpeg", "image/png", "image/webp"].includes(file.type)
            ) {
              toast(t("UPLOAD_INVALID"), "error");
              return;
            }
            const data = new FormData();
            data.append("image", file);
            try {
              const uploaded = await mutation.mutateAsync(data);
              setValue(name, uploaded.url, {
                shouldValidate: true,
                shouldDirty: true,
              });
            } catch {
              /* useAdminMutation displays a localized upload error. */
            }
          }}
        />
      </label>
      <p className="fine-print">{t("imageHelp")}</p>
    </div>
  );
}
