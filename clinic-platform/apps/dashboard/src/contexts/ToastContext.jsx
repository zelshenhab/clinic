import { createContext, useContext, useState, useRef, useEffect } from "react";
const Context = createContext();
export function ToastProvider({ children }) {
  const [items, setItems] = useState([]),
    timers = useRef([]);
  const toast = (message, type = "success") => {
    const id = crypto.randomUUID();
    setItems((v) => [...v.slice(-3), { id, message, type }]);
    timers.current.push(
      setTimeout(() => setItems((v) => v.filter((i) => i.id !== id)), 6000),
    );
  };
  useEffect(() => () => timers.current.forEach(clearTimeout), []);
  return (
    <Context.Provider value={toast}>
      {children}
      <div className="toasts" aria-live="polite">
        {items.map((i) => (
          <div key={i.id} className={`toast ${i.type}`}>
            {i.message}
            <button
              aria-label="×"
              onClick={() => setItems((v) => v.filter((x) => x.id !== i.id))}
            >
              ×
            </button>
          </div>
        ))}
      </div>
    </Context.Provider>
  );
}
export const useToast = () => useContext(Context);
