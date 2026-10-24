type Listener = (authorization: string) => void
const listeners = new Set<Listener>()
const requests = new Map<AbortController, string>()

export function demoLoginDefaults(hostname: string, enabled: boolean, username = '', password = '') {
  const local = ['localhost', '127.0.0.1', '[::1]', '::1'].includes(hostname)
  return enabled && local ? { username, password } : { username: '', password: '' }
}

export function trackAuthorizedRequest(authorization: string) {
  const controller = new AbortController()
  requests.set(controller, authorization)
  return { controller, release: () => { requests.delete(controller) } }
}

export function abortAuthorizedRequests(authorization: string) {
  for (const [controller, identity] of requests) {
    if (identity === authorization) { controller.abort(); requests.delete(controller) }
  }
}

export function basicAuthorization(username: string, password: string): string {
  if (!username.trim() || username.includes(':') || /[\r\n]/.test(username + password) || !password) {
    throw new Error('Enter a username without colons and a nonempty password.')
  }
  const bytes = new TextEncoder().encode(`${username}:${password}`)
  return `Basic ${btoa(Array.from(bytes, byte => String.fromCharCode(byte)).join(''))}`
}

export function onUnauthorized(listener: Listener): () => void {
  listeners.add(listener)
  return () => { listeners.delete(listener) }
}

export function notifyUnauthorized(authorization: string) {
  for (const listener of listeners) listener(authorization)
}
