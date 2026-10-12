export class AppError extends Error {
  constructor(public status: number, public code: string, message: string, public details: Record<string,unknown> = {}) { super(message); }
}
export class AuthenticationError extends AppError { constructor() { super(401, 'UNAUTHORIZED', 'Your session is missing or expired'); } }
export class AuthorizationError extends AppError { constructor() { super(403, 'FORBIDDEN', 'You do not have access to this clinic'); } }
export class ResourceNotFoundError extends AppError { constructor() { super(404, 'NOT_FOUND', 'Resource not found'); } }
export class ConflictError extends AppError { constructor() { super(409, 'APPOINTMENT_SLOT_UNAVAILABLE', 'This appointment slot is no longer available'); } }
