import { bookingRoutes } from "./modules/appointments/routes.js";
import { adminRoutes } from "./modules/admin/routes.js";
import { createApp } from "./app.js";
import { loadConfig } from "./config/env.js";
import { database } from "./database/supabase.js";
import { clinicRepository } from "./modules/clinics/repository.js";
import { authenticate } from "./common/middleware/auth.js";
import { AppError } from "./common/errors/app-error.js";
import { patientRepository } from "./modules/patients/repository.js";
import { catalogRoutes } from "./modules/doctors/routes.js";
const config = loadConfig();
const db = database(config);
const server = createApp(
  config,
  clinicRepository(db),
  {
    auth: {
      user: (header) => authenticate(db, header),
      logout: async (token) => {
        const { error } = await db.auth.admin.signOut(token, "local");
        if (error)
          throw new AppError(503, "LOGOUT_FAILED", "Could not revoke session");
      },
    },
    patients: patientRepository(db),
  },
  catalogRoutes(db),
  adminRoutes(db),
  bookingRoutes(db),
).listen(config.PORT);
for (const signal of ["SIGTERM", "SIGINT"])
  process.on(signal, () => {
    server.close(() => process.exit(0));
    setTimeout(() => process.exit(1), 10000).unref();
  });
