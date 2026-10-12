import { defineConfig } from "vite";
import tailwindcss from "@tailwindcss/vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            {
              name: "react",
              test: /node_modules\/(react|react-dom|scheduler)\//,
            },
            {
              name: "forms",
              test: /node_modules\/(zod|react-hook-form|@hookform)\//,
            },
            { name: "supabase", test: /node_modules\/@supabase\// },
          ],
        },
      },
    },
  },
});
