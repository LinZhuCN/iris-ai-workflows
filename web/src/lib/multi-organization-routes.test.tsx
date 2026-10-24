import type { ReactNode } from 'react'
import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { App } from '../app'

vi.mock('../auth', () => ({
  useAuth: () => ({ authorization: 'Basic unit-test-only' }),
  WorkspaceAuth: ({ children }: { children: (session: { username: string; authorization: string }, signOut: () => void) => ReactNode }) =>
    children({ username: 'builder', authorization: 'Basic unit-test-only' }, () => {}),
}))
vi.mock('../monitor-page', () => ({ LiveMonitorPage: ({ path }: { path: string }) => <div>Legacy monitor path: {path}</div> }))
afterEach(() => vi.unstubAllGlobals())
function render(path: string) {
  vi.stubGlobal('location', { pathname: path, search: '' })
  vi.stubGlobal('localStorage', { getItem: () => 'light' })
  return renderToStaticMarkup(<App />)
}
describe('multi-organization workspace routing', () => {
  it('adds Organizations to the workspace navigation and mounts its form page', () => {
    const html = render('/organizations')
    expect(html).toContain('href="/organizations"')
    expect(html).toContain('Loading organization catalog')
    expect(html).not.toContain('UI Preview')
  })
  it('makes distribution the main demo while preserving a visible legacy route', () => {
    const html = render('/demo')
    expect(html).toContain('FHIR distribution and advisory audit')
    expect(html).toContain('href="/demo/legacy"')
    expect(html).not.toContain('Legacy monitor path:')
  })
  it('passes the original /demo behavior to LiveMonitorPage on the legacy route', () => {
    const html = render('/demo/legacy')
    expect(html).toContain('Legacy monitor path: /demo')
    expect(html).not.toContain('FHIR distribution and advisory audit')
  })
})
