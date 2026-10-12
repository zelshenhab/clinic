import { useState, useEffect } from "react";
export function useDebounced(value, delay = 350) {
  const [debounced, set] = useState(value);
  useEffect(() => {
    const timer = setTimeout(() => set(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);
  return debounced;
}
