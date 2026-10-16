// Share concurrent work only. Settled results (including authorization) are never cached.
const clients = new WeakMap<object, Map<string, Promise<unknown>>>();
export function inFlight<T>(
  client: object,
  key: string,
  task: () => Promise<T>,
): Promise<T> {
  let pending = clients.get(client);
  if (!pending) {
    pending = new Map();
    clients.set(client, pending);
  }
  const existing = pending.get(key);
  if (existing) return existing as Promise<T>;
  if (pending.size >= 256) return task();
  const promise = Promise.resolve().then(task);
  pending.set(key, promise);
  const remove = () => {
    if (pending.get(key) === promise) pending.delete(key);
  };
  void promise.then(remove, remove);
  return promise;
}
