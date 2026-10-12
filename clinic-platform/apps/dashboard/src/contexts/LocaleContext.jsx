import { createContext, useContext, useState, useEffect } from "react";
import { translations } from "../utils/translations";
const LocaleContext = createContext();
export function LocaleProvider({ children }) {
  const [locale, set] = useState(() =>
    localStorage.getItem("language") === "en" ? "en" : "ru",
  );
  useEffect(() => {
    document.documentElement.lang = locale;
  }, [locale]);
  function change(value) {
    set(value);
    localStorage.setItem("language", value);
    document.documentElement.lang = value;
  }
  const t = (key) =>
    translations[locale][key] ||
    translations.ru[key] ||
    (String(key).match(/^[A-Z_]+$/) ? translations[locale].unexpected : key);
  const text = (value) =>
    typeof value === "string" ? value : value?.[locale] || value?.ru || "";
  return (
    <LocaleContext.Provider value={{ locale, change, t, text }}>
      {children}
    </LocaleContext.Provider>
  );
}
export const useLocale = () => useContext(LocaleContext);
