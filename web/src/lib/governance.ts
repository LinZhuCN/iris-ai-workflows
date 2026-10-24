import { eventObject } from './events'

export type RouteKind = 'aggregation' | 'utilization'
export type RouteScope = { resources: string[]; fields: string[]; patient_selection: string; max_records: number }
export type Declaration = {
  schema: 1; synthetic: true; route_id: string; revision: number; kind: RouteKind
  purpose_code: string; purpose_text: string; owner: string; service_identity: string; recipient: string; scope: RouteScope
}
export type RouteBinding = {
  instance_id: string; namespace: string; production: string; source: string; sender: string
  point: 'before_send'; config_hash: string; collector_version: string; policy_version: string
}
export type RouteRecord = {
  id: string; digest: string; record_hash: string; submitted_by: string; submitted_at: number; record_source: string
  core: { declaration: Declaration; binding: RouteBinding; valid_from: number; valid_until: number }
  approval: null | { approved_by: string; approved_at: number; scope_hash: string; record_source: string; scenario?: RouteScenario }
}
export type RouteScenario = {
  policy_id: string; policy_version: number; organization_id: string; recipient_relationship: string
  permitted_use: string; data_path: string; conditions: string
}
export type GovernanceState = { records: RouteRecord[]; next_cursor: string; user: string; can_write: boolean }
export type RouteTemplate = { declaration: Declaration; binding: RouteBinding; valid_from: number; valid_until: number }
export type EvidenceFact = { id: string; kind: string; verification: string; origin: string; text: string }
export type RouteEvidence = {
  evidence: {
    batch_id: string; route_kind: RouteKind; evidence_hash: string
    approved: { record_id: string; scenario?: RouteScenario }; observed: {
      inspection: { field_paths: string[]; resource_counts: Record<string, number> }
      identifier_counts: Record<string, number>; transport: string; observed_at: number
      configured_recipient: string; destination: Record<string, unknown>; runtime_binding: RouteBinding
      message_id: string; session_id: number; readback_basis: string
    }
    provenance: Record<string, string>; fact_evidence: Record<string, unknown>[]
    packet: { stage: 'after_send'; facts: EvidenceFact[] }; limitations: string
  }
  current_admission: { state: string; checked_at: number }
}
function text(v: unknown): string {
  if (typeof v !== 'string') throw new Error('Invalid governance text')
  return v
}
function number(v: unknown): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid governance number')
  return v
}
function integer(v: unknown): number {
  const n = number(v)
  if (!Number.isInteger(n)) throw new Error('Invalid governance integer')
  return n
}
function strings(v: unknown): string[] {
  if (!Array.isArray(v)) throw new Error('Invalid governance field list')
  return v.map(text)
}
function hash(v: unknown): string {
  const h = text(v)
  if (!/^[a-f0-9]{64}$/.test(h)) throw new Error('Invalid governance digest')
  return h
}
function kind(v: unknown): RouteKind {
  if (v !== 'aggregation' && v !== 'utilization') throw new Error('Invalid governance route kind')
  return v
}
function declaration(v: unknown): Declaration {
  const d = eventObject(v), s = eventObject(d.scope)
  if (d.schema !== 1 || d.synthetic !== true || integer(d.revision) < 1) throw new Error('Synthetic versioned declaration required')
  return { schema: 1, synthetic: true, route_id: text(d.route_id), revision: integer(d.revision), kind: kind(d.kind),
    purpose_code: text(d.purpose_code), purpose_text: text(d.purpose_text), owner: text(d.owner),
    service_identity: text(d.service_identity), recipient: text(d.recipient),
    scope: { resources: strings(s.resources), fields: strings(s.fields), patient_selection: text(s.patient_selection), max_records: integer(s.max_records) } }
}
function binding(v: unknown): RouteBinding {
  const b = eventObject(v)
  if (b.point !== 'before_send') throw new Error('Unexpected governance binding point')
  return { instance_id: text(b.instance_id), namespace: text(b.namespace), production: text(b.production),
    source: text(b.source), sender: text(b.sender), point: b.point, config_hash: hash(b.config_hash),
    collector_version: text(b.collector_version), policy_version: text(b.policy_version) }
}
export function decodeRouteScenario(value: unknown): RouteScenario {
  const s = eventObject(value)
  if (s.synthetic !== true || s.policy_id !== 'DEMO-INTERNAL-USE-1' || s.policy_version !== 1 ||
    s.organization_id !== 'DEMO-HOSPITAL' || s.recipient_relationship !== 'same-covered-entity' ||
    s.deidentification_required !== false || s.individual_authorization_required !== false ||
    s.data_path !== 'controlled-identifiable-data') throw new Error('Unexpected synthetic organization scenario')
  return { policy_id: s.policy_id, policy_version: s.policy_version, organization_id: s.organization_id,
    recipient_relationship: s.recipient_relationship, permitted_use: text(s.permitted_use),
    data_path: s.data_path, conditions: text(s.conditions) }
}
export function decodeRouteRecord(v: unknown): RouteRecord {
  const r = eventObject(v), c = eventObject(r.core)
  const approval = r.approval === '' ? null : eventObject(r.approval)
  if (r.record_source !== 'synthetic-demo-registry-v1' || (approval && (
    approval.route_record_id !== r.id || approval.scope_hash !== r.digest ||
    approval.record_source !== 'synthetic-demo-manual-approval-v1'
  ))) throw new Error('Unexpected synthetic approval provenance')
  const valid_from = number(c.valid_from), valid_until = number(c.valid_until)
  if (valid_until <= valid_from) throw new Error('Invalid declaration validity')
  return { id: text(r.id), digest: hash(r.digest), record_hash: hash(r.record_hash),
    submitted_by: text(r.submitted_by), submitted_at: number(r.submitted_at), record_source: r.record_source,
    core: { declaration: declaration(c.declaration), binding: binding(c.binding), valid_from, valid_until },
    approval: approval ? { approved_by: text(approval.approved_by), approved_at: number(approval.approved_at),
      scope_hash: hash(approval.scope_hash), record_source: text(approval.record_source),
      scenario: approval.scenario === undefined ? undefined : decodeRouteScenario(approval.scenario) } : null }
}
export function decodeGovernance(v: unknown): GovernanceState {
  const s = eventObject(v)
  if (!Array.isArray(s.records) || s.model_calls !== 0 || s.runtime_activation !== 'not_performed' ||
    (s.can_write !== true && s.can_write !== false && s.can_write !== 0 && s.can_write !== 1)) throw new Error('Unexpected governance operation/permission')
  return { records: s.records.map(decodeRouteRecord), next_cursor: text(s.next_cursor), user: text(s.user),
    can_write: s.can_write === true || s.can_write === 1 }
}
export function decodeRouteTemplate(v: unknown): RouteTemplate {
  const t = eventObject(v)
  if (t.runtime_activation !== 'not_performed') throw new Error('Template cannot activate a route')
  const d = declaration(t.declaration)
  if (d.kind !== 'utilization' || d.scope.max_records !== 4 || d.scope.fields.length !== 7) throw new Error('Unexpected exporter recipe')
  return { declaration: d, binding: binding(t.binding), valid_from: number(t.valid_from), valid_until: number(t.valid_until) }
}
function counts(v: unknown): Record<string, number> {
  return Object.fromEntries(Object.entries(eventObject(v)).map(([key, val]) => [key, integer(val)]))
}
export function decodeRouteEvidence(v: unknown): RouteEvidence {
  const result = eventObject(v), e = eventObject(result.evidence), o = eventObject(e.observed)
  const inspection = eventObject(o.inspection), approved = eventObject(e.approved), packet = eventObject(e.packet)
  const current = eventObject(result.current_admission), provenance = eventObject(e.provenance)
  const scenarioBased = e.adapter === 'route-evidence-v2'
  if (e.schema !== 1 || (!scenarioBased && e.adapter !== 'route-evidence-v1') || e.synthetic !== true || e.model_calls !== 0 ||
    e.execution !== 'not_executed' || packet.stage !== 'after_send' || packet.synthetic !== true ||
    approved.legal_authorization !== 'not_established' || approved.historical_scope_match !== true ||
    inspection.complete_hipaa_check !== false || !Array.isArray(packet.facts) || !Array.isArray(e.fact_evidence) ||
    ['source', 'bundle', 'payload', 'source_pins', 'readback_resources'].some(key => key in e)) throw new Error('Unexpected evidence scope or legal claim')
  const labels: Record<string, [string, string]> = {
    declared_purpose: ['claim', 'unverified'], declared_context: ['claim', 'unverified'],
    approved_scope: ['observation', 'verified'], observed_output: ['observation', 'verified'],
    delivery_evidence: ['observation', 'verified'], evidence_limits: ['missing_information', 'unknown'],
  }
  if (scenarioBased) {
    labels.organization_policy = ['local_policy', 'verified']
    labels.approved_scenario = ['observation', 'verified']
  }
  const expectedFacts = Object.keys(labels).length
  const facts = packet.facts.map((val: unknown): EvidenceFact => {
    const f = eventObject(val), id = text(f.id)
    if (!labels[id] || f.kind !== labels[id][0] || f.verification !== labels[id][1]) throw new Error('Claims must not be promoted to verified observations')
    return { id, kind: text(f.kind), verification: text(f.verification), origin: text(f.origin), text: text(f.text) }
  })
  if (facts.length !== expectedFacts || new Set(facts.map(f => f.id)).size !== expectedFacts) throw new Error('Missing or duplicated evidence fact')
  const refs = e.fact_evidence.map(eventObject)
  if (refs.length !== expectedFacts || new Set(refs.map(r => r.fact_id)).size !== expectedFacts || refs.some(r =>
    !labels[text(r.fact_id)] || r.receipt_hash !== provenance.receipt_hash || r.batch_id !== e.batch_id ||
    r.approval_id !== approved.record_id || r.route_kind !== e.route_kind)) throw new Error('Fact source reference mismatch')
  if (!['missing_route', 'missing_approval', 'scope_mismatch', 'binding_mismatch', 'not_yet_valid', 'expired', 'approved_scope'].includes(text(current.state))) throw new Error('Unknown current admission')
  return { evidence: { batch_id: text(e.batch_id), route_kind: kind(e.route_kind), evidence_hash: hash(e.evidence_hash),
    approved: { record_id: text(approved.record_id), scenario: scenarioBased ? decodeRouteScenario(approved.scenario) : undefined },
    observed: { inspection: { field_paths: strings(inspection.field_paths), resource_counts: counts(inspection.resource_counts) },
      identifier_counts: counts(o.identifier_counts), transport: text(o.transport), observed_at: number(o.observed_at),
      configured_recipient: text(o.configured_recipient), destination: eventObject(o.destination), runtime_binding: binding(o.runtime_binding),
      message_id: text(o.message_id), session_id: integer(o.session_id), readback_basis: text(o.readback_basis) },
    provenance: Object.fromEntries(['source_hash', 'output_hash', 'config_hash', 'scope_hash', 'receipt_hash'].map(k => [k, hash(provenance[k])])),
    fact_evidence: refs, packet: { stage: 'after_send', facts }, limitations: text(e.limitations) },
    current_admission: { state: text(current.state), checked_at: number(current.checked_at) } }
}
export function receiptInput(v: unknown, selected: RouteRecord): { batch: string; pin: string } {
  const saved = eventObject(v), receipt = eventObject(saved.receipt ?? saved)
  if (receipt.approval_id !== selected.id || receipt.scope_hash !== selected.digest || receipt.synthetic !== true ||
    receipt.outcome !== 'delivered' || !(selected.core.declaration.kind === 'aggregation' ? receipt.send_message_id : receipt.receiver_message_id)) {
    throw new Error('The original receipt must belong to the selected declaration revision')
  }
  const batch = text(receipt.batch_id)
  if (!/^[A-Za-z0-9-]{1,64}$/.test(batch)) throw new Error('Invalid receipt batch ID')
  return { batch, pin: hash(receipt.receipt_hash) }
}
export function routeTime(seconds: number): string {
  return new Date((seconds - 4070908800) * 1000).toISOString().replace('T', ' ').replace('.000Z', 'Z').replace('Z', ' UTC')
}
