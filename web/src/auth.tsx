import { createContext, useContext, useEffect, useRef, useState } from 'react'
import type { ReactNode } from 'react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Panel } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeEvents } from './lib/events'
import { abortAuthorizedRequests, basicAuthorization, demoLoginDefaults, onUnauthorized } from './lib/auth'

type Session = { authorization: string; username: string }
const AuthContext = createContext<Session | null>(null)

export function useAuth() {
  const session = useContext(AuthContext)
  if (!session) throw new Error('A workspace sign-in is required')
  return session
}

export function WorkspaceAuth({ children }: { children: (session: Session, signOut: () => void) => ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [defaults] = useState(() => demoLoginDefaults(location.hostname, import.meta.env.DEV,
    import.meta.env.VITE_DEMO_USERNAME, import.meta.env.VITE_DEMO_PASSWORD))
  const [username, setUsername] = useState(defaults.username), [password, setPassword] = useState(defaults.password)
  const [error, setError] = useState(''), [busy, setBusy] = useState(false)
  const pending = useRef<AbortController | null>(null)
  useEffect(() => () => pending.current?.abort(), [])
  useEffect(() => onUnauthorized(authorization => {
    if (session?.authorization !== authorization) return
    abortAuthorizedRequests(authorization)
    pending.current?.abort(); setSession(null); setPassword(''); setBusy(false)
    setError('Your sign-in is no longer valid. Sign in again to continue.')
  }), [session])
  function signOut() {
    if (session) abortAuthorizedRequests(session.authorization)
    pending.current?.abort(); setSession(null); setUsername(defaults.username); setPassword(defaults.password); setError(''); setBusy(false)
  }
  if (session) return <AuthContext.Provider value={session}>{children(session, signOut)}</AuthContext.Provider>
  return <div className="monitor-page"><Panel title="Sign in to IRIS Workflows">
    <form className="knowledge-login" onSubmit={event => {
      event.preventDefault(); pending.current?.abort()
      const controller = new AbortController(); pending.current = controller
      setBusy(true); setError('')
      void (async () => {
        try {
          const authorization = basicAuthorization(username, password)
          const result = await apiRequest('/events', decodeEvents, controller.signal, { authorization })
          if (!controller.signal.aborted) { setSession({ authorization, username: result.user }); setPassword('') }
        } catch (e) {
          if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Workspace sign-in failed')
        } finally { if (!controller.signal.aborted) setBusy(false) }
      })()
    }}>
      <p>Sign in once for all workspace pages. Server permissions still control each action. Signing in never calls a model or sends business data.</p>
      <p className="subtle">{defaults.password
        ? 'Local demo credentials are prefilled for convenience. Click Sign in; no automatic login. Use this HTTP demo only on localhost.'
        : 'Credentials stay in memory, never browser storage. They are cleared on sign-out or a full browser refresh. Use this HTTP demo only on localhost.'}</p>
      {error && <div role="alert" className="callout">{error}</div>}
      <label className="field-label" htmlFor="workspace-user">Username</label>
      <Input id="workspace-user" autoComplete="username" required value={username} disabled={busy} onChange={e => setUsername(e.target.value)} />
      <label className="field-label" htmlFor="workspace-password">Password</label>
      <Input id="workspace-password" type="password" autoComplete="current-password" required value={password} disabled={busy} onChange={e => setPassword(e.target.value)} />
      <Button type="submit" disabled={busy}>{busy ? 'Signing in…' : 'Sign in'}</Button>
    </form>
  </Panel></div>
}
