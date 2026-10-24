import { describe, expect, it } from 'vitest'
import { decodeManagedProduction, decodeProductionDetail, decodeProductionDiscovery, decodeProductionEvent, decodeProductionEvents, decodeProductionRisks, decodeProductionSnapshot } from './productions'

const id = 'production-' + 'a'.repeat(64), other = 'production-' + 'b'.repeat(64), hash = 'c'.repeat(64)
function snapshot() {
  return { id, instance_id: 'local-iris', namespace: 'UNIT', production: 'Unit.Production', state: 1, running: true,
    config_hash: hash, observed_at: 100, nodes: [{ name: 'Service', class: 'Unit.Service', enabled: 1, pool_size: 1 }] }
}
function record() {
  return { ...snapshot(), baseline: snapshot(), current: snapshot(), enabled: true, revision: 1, enrolled_by: 'builder', enrolled_at: 100,
    last_scan: 110, error: '', model_calls: 0, header_count: 2, log_count: 0 }
}
function event() {
  return { production_id: id, source_key: 'header-1', sequence: 1, category: 'message_observed', severity: 'info', title: 'Header observed',
    evidence: { header_id: 1, session_id: 1 }, created_at: 101, state: 'open', revision: 1, actions: [] }
}
function risks() {
  return { production_id: id, general_payload_assessment: false, model_calls: 0, coverage: 'Metadata only without adapter', next_offset: 0,
    items: [{ id: 'review', source: 'declaration_after_send', state: 'completed', category: 'risk_identified',
      batch_id: 'batch', record_id: 'record', event_state: 'open', result: { summary: { risk_detected: true } }, link: '/declarations' }] }
}
describe('independently managed Productions', () => {
  it('decodes actual component snapshots without assuming a fixed Production', () => {
    expect(decodeProductionSnapshot(snapshot()).production).toBe('Unit.Production')
    expect(decodeProductionSnapshot(snapshot()).nodes[0].enabled).toBe(true)
    expect(() => decodeProductionSnapshot({ ...snapshot(), config_hash: '' })).toThrow()
  })
  it('preserves actual optional Business Partner values without changing legacy snapshots or hashes', () => {
    const original = snapshot()
    expect(decodeProductionSnapshot(original).nodes[0]).not.toHaveProperty('business_partner')
    const withPartner = { ...original, nodes: [{ ...original.nodes[0], business_partner: 'ActualPartnerFromServer' }] }
    expect(decodeProductionSnapshot(withPartner).nodes[0].business_partner).toBe('ActualPartnerFromServer')
    expect(decodeProductionSnapshot(withPartner).config_hash).toBe(original.config_hash)
    expect(() => decodeProductionSnapshot({ ...original, nodes: [{ ...original.nodes[0], business_partner: 7 }] })).toThrow()
  })
  it('keeps discovery non-authorizing and includes namespace access errors', () => {
    const value = decodeProductionDiscovery({ items: [{ ...snapshot(), managed: false }], errors: [{ namespace: 'Private', error: 'Access denied' }], model_calls: 0 })
    expect(value.items[0].managed).toBe(false)
    expect(value.errors).toHaveLength(1)
    expect(() => decodeProductionDiscovery({ items: [], errors: [], model_calls: 1 })).toThrow()
  })
  it('rejects enrollment snapshots bound to another identity', () => {
    expect(decodeManagedProduction(record()).id).toBe(id)
    expect(() => decodeManagedProduction({ ...record(), baseline: { ...snapshot(), id: other } })).toThrow()
    expect(() => decodeManagedProduction({ ...record(), model_calls: 2 })).toThrow()
  })
  it('does not leak an event from another Production into a page', () => {
    expect(decodeProductionEvents({ production_id: id, items: [event()], next_before: 0 }).items).toHaveLength(1)
    expect(() => decodeProductionEvents({ production_id: other, items: [event()], next_before: 0 })).toThrow()
  })
  it('preserves event notes and rejects unknown execution-like transitions', () => {
    expect(decodeProductionEvent({ ...event(), state: 'in_review', revision: 2, actions: [
      { actor: 'reviewer', time: 102, before: 'open', after: 'in_review', text: 'Inspect metadata' },
    ] }).actions).toHaveLength(1)
    expect(() => decodeProductionEvent({ ...event(), state: 'delivered' })).toThrow()
  })
  it('keeps risk links local and metadata-only coverage explicit', () => {
    expect(decodeProductionRisks(risks()).items[0].category).toBe('risk_identified')
    expect(() => decodeProductionRisks({ ...risks(), general_payload_assessment: true })).toThrow()
    const value = risks(); value.items[0].link = 'https://outside.invalid'
    expect(() => decodeProductionRisks(value)).toThrow()
  })
  it('rejects a combined detail with events or risk links from a different Production', () => {
    const value = { record: record(), events: { production_id: id, items: [event()], next_before: 0 }, risks: risks() }
    expect(decodeProductionDetail(value).record.id).toBe(id)
    expect(() => decodeProductionDetail({ ...value, risks: { ...risks(), production_id: other } })).toThrow()
    expect(() => decodeProductionDetail({ ...value, events: { production_id: other, items: [], next_before: 0 } })).toThrow()
  })
  it('does not turn an empty risk page into a clean assessment', () => {
    const result = decodeProductionRisks({ ...risks(), items: [], next_offset: 25 })
    expect(result.items).toHaveLength(0)
    expect(result.coverage).toContain('Metadata only')
    expect(result.next_offset).toBe(25)
  })
  it('accepts sampled reviews only with an event anchor bound to the same Production', () => {
    const value = risks()
    value.items[0].source = 'production_observation'
    value.items[0].category = 'information_required'
    value.items[0].link = `#production-event-${id}-review-18`
    const withEvent = { ...value, items: [{ ...value.items[0], event_before: 40 }] }
    expect(decodeProductionRisks(withEvent).items[0].source).toBe('production_observation')
    expect(decodeProductionRisks(withEvent).items[0].event_before).toBe(40)
    expect(() => decodeProductionRisks({ ...withEvent, items: [{ ...withEvent.items[0], event_before: '40' }] })).toThrow()
    withEvent.items[0].link = `#production-event-${other}-review-18`
    expect(() => decodeProductionRisks(withEvent)).toThrow()
    withEvent.items[0].link = `#production-event-${id}-review-not-a-header`
    expect(() => decodeProductionRisks(withEvent)).toThrow()
  })
})
