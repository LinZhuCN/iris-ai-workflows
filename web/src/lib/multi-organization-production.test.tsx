import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it } from 'vitest'
import { DistributionProductionReviewLink, ProductionComponentCatalog, ProductionEventCard } from '../productions-page'
import { decodeProductionSnapshot, decodeProductionEvent, productionDistributionReviewLink } from './productions'

describe('organization-aware Production evidence handoff', () => {
  it('deep-links advisory audit events to the exact immutable run rather than the generic review adapter', () => {
    const event = decodeProductionEvent({ production_id: 'production-' + 'a'.repeat(64), source_key: 'review-unit',
      sequence: 1, category: 'risk_review', severity: 'warning', title: 'Research audit',
      evidence: { run_id: 'multi-unit-123', branch: 'research', report_id: 'report-unit', detail_page: '/demo' },
      created_at: 5863734680.5, state: 'open', revision: 1, actions: [] })
    const html = renderToStaticMarkup(<ProductionEventCard event={event} disabled action={async () => {}} />)
    expect(html).toContain('href="/demo?run=multi-unit-123"')
    expect(html).toContain('Inspect evidence / review')
    expect(html).not.toContain('href="/demo"')
    for (const patch of [{ run_id: undefined }, { run_id: '../outside' }, { run_id: 42 }, { detail_page: 'https://outside.invalid' }]) {
      expect(productionDistributionReviewLink({ ...event, evidence: { ...event.evidence, ...patch } })).toBeUndefined()
    }
    expect(productionDistributionReviewLink({ ...event, category: 'message_observed' })).toBeUndefined()
  })
  it('links to actual distribution receipts and audit without claiming generic M5 support', () => {
    const html = renderToStaticMarkup(<DistributionProductionReviewLink />)
    expect(html).toContain('href="/demo"')
    expect(html).toContain('SQL, REST and HL7 branch receipts')
    expect(html).toContain('pinned organization-policy revisions')
    expect(html).toContain('M5 payload-review adapter does not establish review coverage')
    expect(html).not.toContain('Authorize local synthetic inspection')
  })
  it('displays server-supplied Business Partner badges and leaves absent associations explicit', () => {
    const snapshot = decodeProductionSnapshot({
      id: 'production-' + 'a'.repeat(64), instance_id: 'local-iris', namespace: 'UNIT', production: 'Unit.Production',
      state: 1, running: true, config_hash: 'b'.repeat(64), observed_at: 100, nodes: [
        { name: 'Unit source', class: 'Unit.Service', enabled: true, pool_size: 1, business_partner: 'ActualUnitPartner' },
        { name: 'Unit process', class: 'Unit.Process', enabled: true, pool_size: 1 },
      ],
    })
    const html = renderToStaticMarkup(<ProductionComponentCatalog snapshot={snapshot} />)
    expect(html).toContain('Business Partner')
    expect(html).toContain('ActualUnitPartner')
    expect(html).toContain('status-info')
    expect(html).toContain('Not supplied')
    expect(html).not.toContain('DemoHospital')
    expect(html).toContain(snapshot.config_hash)
  })
})
