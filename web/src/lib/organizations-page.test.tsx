import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ConfirmedOrganization, OrganizationProfileEditor, OrganizationsPage } from '../organizations-page'
import type { OrganizationProfile } from './multi-organization'
import { routeTime } from './governance'

const profile: OrganizationProfile = {
  id: 'research', name: 'Synthetic research center', partner: 'DemoResearch', type: 'research',
  parent_id: '', responsibilities: 'Statistical research', purpose: 'External statistics',
  relationship: 'external', allowed_fields: ['patient_code', 'birth_year'],
  prohibited_fields: ['name', 'mrn', 'birthDate'], requirements: 'Remove direct identifiers.',
}
const record = { id: 'research' as const, revision: 1, profile, confirmed_by: 'builder', confirmed_at: 100, hash: 'a'.repeat(64) }

vi.mock('../auth', () => ({ useAuth: () => ({ authorization: 'Basic unit-test-only' }) }))
afterEach(() => vi.restoreAllMocks())
describe('organization forms are drafts until saved', () => {
  it('includes all profile fields, stable identity, and separate receiving-policy lists', () => {
    const html = renderToStaticMarkup(<OrganizationProfileEditor initial={profile} record={record} canManage busy={false} onSave={vi.fn()} />)
    for (const field of ['id', 'name', 'partner', 'type', 'parent_id', 'relationship', 'responsibilities', 'purpose', 'requirements', 'allowed', 'prohibited']) {
      expect(html).toContain(`id="organization-${field}"`)
    }
    expect(html).toContain('confirmed revision 1')
    expect(html).toContain('comma separated')
    expect(html).toContain('They never save, send data or call a model')
    expect(html).not.toContain('type="checkbox"')
    expect(html.split('</button>').find(part => part.endsWith('>Save for demo'))).not.toContain('disabled=""')
  })
  it('disables reader and busy forms without granting consent', () => {
    for (const [canManage, busy] of [[false, false], [true, true]]) {
      const html = renderToStaticMarkup(<OrganizationProfileEditor initial={profile} canManage={canManage} busy={busy} onSave={vi.fn()} />)
      expect(html).toContain('<fieldset disabled="">')
      expect(html).not.toContain('checked=""')
    }
  })
  it('shows immutable confirmation metadata and expandable profile JSON', () => {
    const html = renderToStaticMarkup(<ConfirmedOrganization record={record} />)
    expect(html).toContain('Confirmed revision 1')
    expect(html).toContain(`Confirmed by builder at ${routeTime(100)}`)
    expect(html).toContain(record.hash)
    expect(html).toContain('<details>')
    expect(html).toContain('Business Partner: DemoResearch')
  })
  it('presents fractional IRIS-epoch confirmation times as readable UTC without changing the raw snapshot', () => {
    const confirmed_at = 5863734680.576677
    const html = renderToStaticMarkup(<ConfirmedOrganization record={{ ...record, confirmed_at }} />)
    expect(html).toContain(`Confirmed by builder at ${routeTime(confirmed_at)}`)
    expect(html).not.toContain(`Confirmed by builder at ${confirmed_at}`)
    expect(html).toContain('2026-10-24')
    expect(html).toContain(String(confirmed_at))
  })
  it('never saves, sends or calls a model during rendering', () => {
    const fetch = vi.spyOn(globalThis, 'fetch')
    const onSave = vi.fn()
    renderToStaticMarkup(<OrganizationProfileEditor initial={profile} canManage busy={false} onSave={onSave} />)
    const html = renderToStaticMarkup(<OrganizationsPage />)
    expect(html).toContain('Loading organization catalog')
    expect(html).not.toContain('provision</button>')
    expect(fetch).not.toHaveBeenCalled()
    expect(onSave).not.toHaveBeenCalled()
  })
})
