import { eventObject as object } from './events'

function text(v: unknown): string { if (typeof v !== 'string') throw new Error('Invalid observation text'); return v }
function num(v: unknown): number { if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid observation number'); return v }
function integer(v: unknown): number { const n = num(v); if (!Number.isSafeInteger(n)) throw new Error('Invalid observation integer'); return n }
function flag(v: unknown): boolean {
  if (v !== true && v !== false && v !== 0 && v !== 1 && v !== '0' && v !== '1') throw new Error('Invalid observation flag')
  return v === true || v === 1 || v === '1'
}
function array<T>(v: unknown, decode: (v: unknown) => T): T[] { if (!Array.isArray(v)) throw new Error('Invalid observation list'); return v.map(decode) }
function identity(v: unknown) { const s = text(v); if (!/^production-[a-f0-9]{64}$/.test(s)) throw new Error('Invalid observation Production'); return s }
function hash(v: unknown) { const s = text(v); if (!/^[a-f0-9]{64}$/.test(s)) throw new Error('Invalid observation hash'); return s }
function reference(v: unknown) {
  if (typeof v === 'number' && Number.isSafeInteger(v) && v >= 0) return String(v)
  const s = text(v); if (!/^[0-9]{1,15}$/.test(s)) throw new Error('Invalid message reference'); return s
}
function counts(v: unknown) { return Object.fromEntries(Object.entries(object(v)).map(([k, n]) => [k, integer(n)])) }
function scoped<T extends { production_id: string }>(pid: string, items: T[]) {
  if (items.some(item => item.production_id !== pid)) throw new Error('Cross-Production observation response')
  return items
}
const captureStates = ['captured', 'unsupported', 'not_authorized', 'evidence_failed']
const reviewStates = [...captureStates.filter(s => s !== 'captured'), 'pending_observer', 'pending', 'not_sampled', 'not_sampled_duplicate', 'blocked_budget', 'running', 'completed', 'failed', 'interrupted']
function review(v: unknown) {
  const r = object(v), state = text(r.state)
  if (!reviewStates.includes(state) || r.execution !== 'not_executed') throw new Error('Invalid non-executing review state')
  return { production_id: r.production_id === undefined ? undefined : identity(r.production_id),
    id: r.id === undefined ? undefined : text(r.id), header_id: r.header_id === undefined ? undefined : reference(r.header_id),
    state, reason: r.reason === undefined ? '' : text(r.reason), error: r.error === undefined ? '' : text(r.error),
    reserved: integer(r.reserved_model_requests), attempted: integer(r.attempted_model_requests),
    observation_hash: r.observation_hash === undefined ? undefined : hash(r.observation_hash),
    report_id: r.report_id === undefined ? undefined : text(r.report_id),
    authorization_id: r.authorization_id === undefined ? '' : text(r.authorization_id), raw: r }
}
export function decodeObservation(v: unknown) {
  const r = object(v), h = object(r.header), c = object(r.capture), pid = identity(r.production_id), current = r.current_review === undefined ? undefined : review(r.current_review)
  if (!captureStates.includes(text(c.state)) || r.model_calls !== 0) throw new Error('Invalid local evidence capture')
  if (current && current.state !== 'pending_observer' && (current.production_id !== pid || current.id !== r.id || current.header_id !== reference(h.header_id) || current.observation_hash !== r.record_hash)) throw new Error('Review overlay observation mismatch')
  if (c.state === 'captured' ? c.facts === null : c.facts !== null) throw new Error('Capture facts/state mismatch')
  return { id: text(r.id), production_id: pid, header_id: reference(h.header_id), session: reference(h.session_id),
    source: text(h.source), target: text(h.target), body_class: text(h.body_class), body_id: reference(h.body_id),
    capture_state: text(c.state), reason: text(c.reason), facts: c.facts === null ? null : object(c.facts),
    outcome: text(r.outcome), delivery_evidence: text(r.delivery_evidence), record_hash: hash(r.record_hash),
    config_hash: hash(r.observed_config_hash), limits: array(r.limits, text), current, raw: r }
}
export function decodeEvidencePage(v: unknown) {
  const p = object(v), pid = identity(p.production_id), observer = object(p.observer)
  if (p.model_calls !== 0) throw new Error('Evidence read cannot infer')
  return { production_id: pid, items: scoped(pid, array(p.items, decodeObservation)), next_before: integer(p.next_before),
    counts: counts(p.capture_counts), observer: { last_scan: num(observer.last_scan), error: text(observer.error),
      batch_full: flag(observer.batch_full), unattributed: integer(observer.unattributed_headers),
      retention_loss_detection: text(observer.retention_loss_detection), retention: text(observer.retention) }, history: text(p.history) }
}
export function decodeEdges(v: unknown) {
  const p = object(v)
  if (p.model_calls !== 0) throw new Error('Edge read cannot infer')
  const next = text(p.next_after)
  if (next) hash(next)
  return { production_id: identity(p.production_id), next_after: next, scope: text(p.scope), items: array(p.items, value => {
    const e = object(value)
    if (e.basis !== 'actual_message_header') throw new Error('Inferred topology is not an observed edge')
    return { id: hash(e.id), source: text(e.source), target: text(e.target) }
  }) }
}
export function decodeReviewPlan(v: unknown) {
  const p = object(v), b = object(p.bounds)
  if (p.model_calls !== 0 || p.runtime !== 'production-review-v1' || b.requests_per_review !== 2) throw new Error('Invalid non-authorizing review plan')
  return { production_id: identity(p.production_id), config_hash: hash(p.config_hash), contract_hash: hash(p.contract_hash),
    now: num(p.now), max_reviews: integer(b.max_reviews), expiry_seconds: integer(b.expiry_seconds),
    sampling: text(p.sampling), scope: text(p.scope), agents: array(p.eligible_agents, value => {
      const a = object(value)
      return { id: text(a.id), revision: integer(a.revision), config_hash: hash(a.config_hash), model: text(a.model), status: text(a.status) }
    }) }
}
export type ReviewPlan = ReturnType<typeof decodeReviewPlan>
export function decodeDemoPremises(v: unknown) {
  const p = object(v)
  const keys = ['session_id', 'recipient', 'relationship', 'purpose', 'permission_basis', 'permission_details', 'authorization_status', 'safeguards', 'exceptions', 'confirmed']
  const mapped = 'recipient_mapping' in p || 'data_scope' in p
  if (mapped) keys.push('recipient_mapping', 'data_scope')
  if (Object.keys(p).length !== keys.length || keys.some(k => !(k in p)) || p.confirmed !== true ||
    !/^[1-9][0-9]{0,14}$/.test(text(p.session_id))) throw new Error('Confirm demo premises for an exact source session')
  function bounded(field: string, limit: number) {
    const value = text(p[field])
    if (!value.trim() || Array.from(value).length > limit) throw new Error(`Complete demo ${field}; use "unknown" if not known`)
    return value
  }
  function choice(field: string, choices: string[]) {
    const value = text(p[field])
    if (!choices.includes(value)) throw new Error(`Invalid demo ${field}`)
    return value
  }
  return { session_id: text(p.session_id), recipient: bounded('recipient', 200),
    relationship: choice('relationship', ['same_covered_entity', 'another_provider', 'business_associate', 'external', 'unknown']),
    purpose: bounded('purpose', 600), permission_basis: choice('permission_basis', ['treatment', 'healthcare_operations', 'individual_authorization', 'other', 'unknown']),
    permission_details: bounded('permission_details', 1000),
    authorization_status: choice('authorization_status', ['present', 'absent', 'not_relied_upon', 'unknown']),
    safeguards: bounded('safeguards', 600), exceptions: bounded('exceptions', 600), confirmed: true as const,
    ...(mapped ? { recipient_mapping: bounded('recipient_mapping', 600), data_scope: bounded('data_scope', 600) } : {}) }
}
export function decodeGrant(v: unknown) {
  const g = object(v), d = object(g.definition), pid = identity(g.production_id)
  if (d.production_id !== pid || d.authorization_id !== g.authorization_id || d.acknowledge_cost !== true || d.acknowledge_synthetic_data_export !== true ||
    integer(d.max_model_requests) !== 2 * integer(d.max_reviews)) throw new Error('Invalid Production budget grant')
  return { production_id: pid, id: text(g.authorization_id), enabled: flag(g.enabled), used: integer(g.used_reviews),
    max_reviews: integer(d.max_reviews), requests: integer(d.max_model_requests), expires: num(d.expires_at),
    every_n: integer(d.every_n), include_existing: flag(d.include_existing), agent: text(d.agent_id), revision: integer(d.source_revision),
    config_hash: hash(d.config_hash), actor: text(g.actor),
    premises: d.demo_premises === undefined ? undefined : decodeDemoPremises(d.demo_premises),
    confirmed_at: d.demo_premises === undefined ? undefined : num(g.authorized_at), raw: g }
}
export function decodeReviewPage(v: unknown) {
  const p = object(v), pid = identity(p.production_id), items = array(p.items, review)
  if (items.some(r => r.production_id !== pid) || p.execution !== 'advisory_only_no_replay') throw new Error('Cross-Production review page')
  return { production_id: pid, items, counts: counts(p.counts), next_before: integer(p.next_before),
    grants: scoped(pid, array(p.authorizations, decodeGrant)), heartbeat: p.heartbeat === '' ? 0 : num(p.heartbeat),
    last_scan: p.last_scan === '' ? 0 : num(p.last_scan), error: text(p.error), worker_error: text(p.worker_error),
    cursor: integer(p.cursor), batch_full: flag(p.batch_full), paused: flag(p.paused), sampling: text(p.sampling_unit) }
}
export function buildReviewConsent(plan: ReviewPlan, input: { key: string; agent: string; every: number; reviews: number; minutes: number; existing: boolean; cost: boolean; synthetic: boolean; premises?: unknown }) {
  const a = plan.agents.find(a => a.id === input.agent)
  if (!a || !/^[A-Za-z0-9-]{1,40}$/.test(input.key) || !input.cost || !input.synthetic ||
    !Number.isSafeInteger(input.every) || input.every < 1 || input.every > 1000 ||
    !Number.isSafeInteger(input.reviews) || input.reviews < 1 || input.reviews > plan.max_reviews ||
    !Number.isSafeInteger(input.minutes) || input.minutes < 1 || input.minutes * 60 > plan.expiry_seconds) throw new Error('Explicit bounded review consent required')
  return { authorization_id: input.key, production_id: plan.production_id, config_hash: plan.config_hash,
    agent_id: a.id, source_revision: a.revision, agent_config_hash: a.config_hash, contract_hash: plan.contract_hash,
    every_n: input.every, max_reviews: input.reviews, max_model_requests: 2 * input.reviews,
    expires_at: Math.floor(plan.now) + input.minutes * 60, include_existing: input.existing,
    acknowledge_cost: true, acknowledge_synthetic_data_export: true,
    ...(input.premises === undefined ? {} : { demo_premises: decodeDemoPremises(input.premises) }) }
}
export function decodeInspectionGrant(v: unknown) {
  const g = object(v)
  return { production_id: identity(g.production_id), enabled: flag(g.enabled) }
}
export function decodeContext(v: unknown) {
  const c = object(v)
  if (c.monitoring_prerequisite !== false || c.model_calls !== 0) throw new Error('Context cannot authorize monitoring')
  return { id: text(c.id), production_id: identity(c.production_id), key: text(c.flow_key), revision: integer(c.revision), digest: hash(c.digest),
    config: object(c.config), raw: c }
}
export function decodeContexts(v: unknown) {
  const p = object(v), pid = identity(p.production_id)
  if (p.discovered_flows !== false || p.monitoring_prerequisite !== false || p.record_kind !== 'optional_review_context') throw new Error('Context is not flow enrollment')
  return { production_id: pid, items: scoped(pid, array(p.items, decodeContext)), next_after: text(p.next_after) }
}
function businessEvidence(v: unknown, e: ReturnType<typeof decodeObservation>, packet: unknown) {
  const b = object(v), receipt = object(b.receipt), policy = object(b.policy), p = object(packet)
  const facts = array(p.facts, object), bindingFact = facts.find(f => f.id === 'evidence_binding')
  if (!bindingFact) throw new Error('Missing model-reviewed business evidence binding')
  const binding = object(JSON.parse(text(bindingFact.text)))
  if (b.adapter !== 'synthetic-quality-intake-v1' || b.production_id !== e.production_id ||
    b.observation_hash !== e.record_hash || b.config_hash !== e.config_hash ||
    binding.evidence_hash !== hash(b.evidence_hash) || binding.production_id !== e.production_id ||
    binding.observation_hash !== e.record_hash || binding.config_hash !== e.config_hash ||
    receipt.readback_match !== true || reference(receipt.message_id) !== e.body_id ||
    reference(receipt.session_id) !== e.session || hash(receipt.payload_hash) !== object(e.raw.capture).body_digest ||
    policy.synthetic !== true || policy.version !== b.adapter) throw new Error('Business receipt/observation binding mismatch')
  return { receiver: text(receipt.receiver), batch: text(receipt.batch_id), received: num(receipt.received_at),
    established: flag(b.recipient_established), scope: text(b.scope), policy: text(policy.purpose), raw: b }
}
export function decodeProductionReviewDetail(v: unknown) {
  const d = object(v), r = review(d.review), e = decodeObservation(d.evidence)
  if (r.production_id !== e.production_id || r.id !== e.id || r.header_id !== e.header_id || r.observation_hash !== e.record_hash) throw new Error('Review/evidence binding mismatch')
  const business = r.raw.business_evidence === undefined ? undefined : businessEvidence(r.raw.business_evidence, e, r.raw.packet)
  const approval = r.raw.demo_approval === undefined ? undefined : (() => {
    const a = object(r.raw.demo_approval), premises = decodeDemoPremises(a.premises), packet = object(r.raw.packet)
    const f = array(packet.facts, object).find(f => f.id === 'demo_approval')
    if (!f) throw new Error('Missing model-reviewed demo approval')
    const binding = object(JSON.parse(text(f.text)))
    if (a.provenance !== 'user_confirmed_demo_premises_not_independently_verified' || premises.session_id !== e.session ||
      a.authorization_id !== r.authorization_id || binding.authorization_id !== a.authorization_id ||
      binding.actor !== a.actor || binding.confirmed_at !== a.confirmed_at ||
      f.kind !== 'observation' || f.verification !== 'verified' || f.origin !== 'protected_demo_approval') throw new Error('Demo approval/session binding mismatch')
    hash(binding.approval_hash)
    const facts = array(packet.facts, object)
    function premiseFact(id: string) {
      const fact = facts.find(f => f.id === id)
      if (!fact) throw new Error('Missing model-reviewed demo premise')
      return text(fact.text)
    }
    const recipient = object(JSON.parse(premiseFact('demo_recipient'))), permission = object(JSON.parse(premiseFact('demo_permission')))
    const safeguards = object(JSON.parse(premiseFact('demo_safeguards')))
    if (recipient.recipient !== premises.recipient || recipient.relationship !== premises.relationship ||
      premiseFact('demo_purpose') !== premises.purpose || permission.basis !== premises.permission_basis ||
      permission.authorization_status !== premises.authorization_status || permission.details !== premises.permission_details ||
      safeguards.safeguards !== premises.safeguards || safeguards.exceptions !== premises.exceptions) throw new Error('Demo inputs differ from model-reviewed premises')
    if (premises.recipient_mapping !== undefined) {
      const mapping = object(JSON.parse(premiseFact('demo_message_scope')))
      if (mapping.session_id !== premises.session_id || mapping.recipient_mapping !== premises.recipient_mapping ||
        mapping.data_scope !== premises.data_scope) throw new Error('Demo message mapping differs from approved inputs')
    }
    return { premises, actor: text(a.actor), confirmed_at: num(a.confirmed_at) }
  })()
  if (d.report === null) {
    if (r.state === 'completed') throw new Error('Completed review requires report')
    return { review: r, evidence: e, report: null, sources: [], issues: [], missing: [], business, approval, assessment: undefined }
  }
  const report = object(d.report), auth = object(report.authorization), source = object(report.source)
  if (approval && JSON.stringify(report.packet) !== JSON.stringify(r.raw.packet)) throw new Error('Demo report packet differs from approved review')
  if (report.id !== r.report_id || report.version !== 'production-review-v1' ||
    auth.agent_id !== source.id || auth.source_revision !== source.revision ||
    auth.config_hash !== source.config_hash || auth.max_model_requests !== 2 ||
    !/^production-[a-f0-9]{64}$/.test(text(auth.request_key))) throw new Error('Review report identity mismatch')
  const sources = report.packages === undefined ? [] : array(report.packages, value => {
    const p = object(value)
    return array(p.evidence, value => {
      const h = object(value), meta = object(h.metadata)
      if (meta.retrieval_scope !== 'normative' || !flag(h.source_hash_verified) || !flag(h.section_text_complete)) throw new Error('Unverified or non-normative review source')
      return { question: text(p.question_id), id: text(h.id), text: text(h.text), metadata: meta,
        passages: array(h.passages, value => {
          const span = object(value)
          return { id: text(span.id), start: integer(span.start), end: integer(span.end), text: text(span.text) }
        }) }
    })
  }).flat()
  const result = r.state === 'completed' ? object(report.result) : undefined
  if (r.state === 'completed' && (report.state !== 'completed' || JSON.stringify(r.raw.result) !== JSON.stringify(result))) throw new Error('Review result/report mismatch')
  const issues = result ? array(result.issues, value => {
    const i = object(value)
    if (!['risk_signal', 'unresolved', 'no_signal_on_checked_issue'].includes(text(i.status))) throw new Error('Invalid finding status')
    return { question: text(i.question_id), status: text(i.status), explanation: text(i.explanation),
      citations: array(i.citations, value => {
        const c = object(value), s = sources.find(s => s.question === i.question_id && s.id === c.evidence_id)
        const start = integer(c.start), end = integer(c.end)
        const passage = s?.passages.find(p => p.id === c.passage_id)
        if (!s || !passage || passage.start !== start || passage.end !== end || passage.text !== c.quote ||
          end <= start || end > Array.from(s.text).length || Array.from(s.text).slice(start, end).join('') !== c.quote) throw new Error('Review citation span mismatch')
        return { id: text(c.evidence_id), passage: text(c.passage_id), quote: text(c.quote) }
      }) }
  }) : []
  const missing = result ? array(result.missing_information, text) : []
  let assessment: string | undefined
  if (result) {
    const summary = object(result.summary)
    if (!issues.length || result.human_review_required !== true || summary.execution !== 'not_executed' ||
      summary.recommended_action !== 'manual_review' || summary.risk_detected !== issues.some(i => i.status === 'risk_signal') ||
      summary.unresolved !== (missing.length > 0 || issues.some(i => i.status === 'unresolved'))) throw new Error('Review finding/aggregate mismatch')
    assessment = summary.risk_detected ? 'risk_identified' : summary.unresolved ? 'information_required' : 'no_signal_on_checked_issues'
    if (result.assessment !== assessment) throw new Error('Review assessment/aggregate mismatch')
  }
  return { review: r, evidence: e, report, sources, issues, missing, business, approval, assessment }
}
