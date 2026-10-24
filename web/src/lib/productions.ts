import { eventObject } from './events'

const object = eventObject
function text(v: unknown): string { if (typeof v !== 'string') throw new Error('Invalid Production text'); return v }
function number(v: unknown): number { if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid Production number'); return v }
function boolean(v: unknown): boolean { if (v !== true && v !== false && v !== 0 && v !== 1) throw new Error('Invalid Production boolean'); return !!v }
function list<T>(v: unknown, decode: (v: unknown) => T): T[] { if (!Array.isArray(v)) throw new Error('Invalid Production list'); return v.map(decode) }
function id(v: unknown) { const s = text(v); if (!/^production-[a-f0-9]{64}$/.test(s)) throw new Error('Invalid Production identity'); return s }
function hash(v: unknown) { const s = text(v); if (!/^[a-f0-9]{64}$/.test(s)) throw new Error('Invalid configuration hash'); return s }

export function decodeProductionSnapshot(v: unknown) {
  const s = object(v)
  return { id: id(s.id), instance_id: text(s.instance_id), namespace: text(s.namespace), production: text(s.production),
    state: number(s.state), running: boolean(s.running), config_hash: hash(s.config_hash), observed_at: number(s.observed_at),
    nodes: list(s.nodes, v => {
      const n = object(v)
      return { name: text(n.name), class: text(n.class), enabled: boolean(n.enabled), pool_size: number(n.pool_size),
        ...(n.business_partner === undefined ? {} : { business_partner: text(n.business_partner) }) }
    }) }
}
export type ProductionSnapshot = ReturnType<typeof decodeProductionSnapshot>
export function decodeManagedProduction(v: unknown) {
  const r = object(v), baseline = decodeProductionSnapshot(r.baseline), current = decodeProductionSnapshot(r.current)
  if (r.model_calls !== 0 || baseline.id !== r.id || baseline.namespace !== r.namespace || baseline.production !== r.production) throw new Error('Managed Production snapshot mismatch')
  return { id: id(r.id), namespace: text(r.namespace), production: text(r.production), enabled: boolean(r.enabled), revision: number(r.revision),
    enrolled_by: text(r.enrolled_by), enrolled_at: number(r.enrolled_at), last_scan: number(r.last_scan), error: text(r.error),
    header_count: number(r.header_count), log_count: number(r.log_count), baseline, current }
}
export type ManagedProduction = ReturnType<typeof decodeManagedProduction>
export function decodeProductionDiscovery(v: unknown) {
  const d = object(v)
  if (d.model_calls !== 0) throw new Error('Production discovery cannot call a model')
  return { items: list(d.items, v => { const s = object(v); return { ...decodeProductionSnapshot(s), managed: boolean(s.managed) } }),
    errors: list(d.errors, v => { const e = object(v); return { namespace: text(e.namespace), error: text(e.error) } }) }
}
export function decodeProductionList(v: unknown) {
  const s = object(v)
  return { items: list(s.items, decodeManagedProduction), can_manage: boolean(s.can_manage), heartbeat: number(s.heartbeat), error: text(s.error) }
}
export function decodeProductionEvent(v: unknown) {
  const e = object(v), state = text(e.state)
  if (!['open', 'in_review', 'needs_information', 'resolved', 'ignored'].includes(state) ||
    !['info', 'warning', 'danger'].includes(text(e.severity))) throw new Error('Invalid Production event state')
  return { production_id: id(e.production_id), source_key: text(e.source_key), sequence: number(e.sequence), category: text(e.category),
    severity: text(e.severity), title: text(e.title), evidence: object(e.evidence), created_at: number(e.created_at), state,
    revision: number(e.revision), actions: list(e.actions, v => {
      const a = object(v)
      return { actor: text(a.actor), time: number(a.time), before: text(a.before), after: text(a.after), text: text(a.text) }
    }) }
}
export type ProductionEvent = ReturnType<typeof decodeProductionEvent>
export function productionDistributionReviewLink(event: ProductionEvent): string | undefined {
  const evidence = event.evidence
  return event.category === 'risk_review' && evidence.detail_page === '/demo'
    && typeof evidence.run_id === 'string' && /^[A-Za-z0-9-]{1,48}$/.test(evidence.run_id)
    ? `/demo?run=${encodeURIComponent(evidence.run_id)}` : undefined
}
export function decodeProductionEvents(v: unknown) {
  const p = object(v), production_id = id(p.production_id), items = list(p.items, decodeProductionEvent)
  if (items.some(e => e.production_id !== production_id)) throw new Error('Event belongs to another Production')
  return { production_id, items, next_before: number(p.next_before) }
}
export function decodeProductionDetail(v: unknown) {
  const d = object(v), record = decodeManagedProduction(d.record), events = decodeProductionEvents(d.events), risks = decodeProductionRisks(d.risks)
  if (events.production_id !== record.id || risks.production_id !== record.id) throw new Error('Production detail isolation mismatch')
  return { record, events, risks: risks.items, coverage: risks.coverage, next_risk_offset: risks.next_offset }
}
export function decodeProductionRisks(v: unknown) {
  const r = object(v), production_id = id(r.production_id)
  if (r.general_payload_assessment !== false || r.model_calls !== 0) throw new Error('Production risk coverage mismatch')
  const risks = list(r.items, v => {
    const item = object(v), link = text(item.link), category = text(item.category)
    const productionEvent = new RegExp(`^#production-event-${production_id}-review-[0-9]{1,15}$`).test(link)
    if (!['risk_identified', 'information_required', 'no_deviation_on_checked_use', 'coverage_gap', 'event', 'technical_failure'].includes(category) ||
      (!/^\/(declarations|governance|events\/event-[a-f0-9]{64})$/.test(link) && !productionEvent)) throw new Error('Invalid linked Production finding')
    if (item.result !== null && item.result !== '') object(item.result)
    return { id: text(item.id), source: text(item.source), state: text(item.state), category, batch_id: text(item.batch_id),
      record_id: text(item.record_id), event_state: text(item.event_state), result: item.result, link,
      event_before: productionEvent ? number(item.event_before) : undefined,
      title: item.title === undefined ? '' : text(item.title) }
  })
  return { production_id, items: risks, coverage: text(r.coverage), next_offset: number(r.next_offset) }
}
