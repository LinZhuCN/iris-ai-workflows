import { describe, expect, it } from 'vitest'
import { buildReviewConsent, decodeContext, decodeContexts, decodeDemoPremises, decodeEdges, decodeEvidencePage, decodeGrant, decodeObservation, decodeProductionReviewDetail, decodeReviewPage, decodeReviewPlan } from './production-observation'

const pid = 'production-' + 'a'.repeat(64), other = 'production-' + 'b'.repeat(64), hash = 'c'.repeat(64)
function plan() {
  return { production_id: pid, config_hash: hash, contract_hash: hash, runtime: 'production-review-v1', now: 10000,
    bounds: { max_reviews: 20, requests_per_review: 2, max_model_requests: 40, expiry_seconds: 86400 },
    eligible_agents: [{ id: 'agent-test', revision: 3, config_hash: hash, model: 'test-model', status: 'published' }],
    sampling: 'unique session/body', scope: 'synthetic minimized facts', model_calls: 0 }
}
function consent() {
  return buildReviewConsent(decodeReviewPlan(plan()), { key: 'test-m4', agent: 'agent-test', every: 3, reviews: 2,
    minutes: 10, existing: false, cost: true, synthetic: true })
}
function review() {
  return { id: 'observation-test', production_id: pid, header_id: '18', observation_hash: hash, authorization_id: 'test-m4',
    state: 'unsupported', reserved_model_requests: 0, attempted_model_requests: 0, execution: 'not_executed' }
}
function observation() {
  return { id: 'observation-test', production_id: pid, header: { header_id: '18', session_id: 18, source: 'Source', target: 'Process',
    body_class: 'Registered.Request', body_id: '3' }, capture: { state: 'unsupported', reason: 'No adapter', facts: null },
    outcome: 'attempted', delivery_evidence: 'message_header_only', record_hash: hash, observed_config_hash: hash,
    model_calls: 0, limits: ['No receiver proof'], current_review: review() }
}
function grant() {
  return { authorization_id: 'test-m4', production_id: pid, definition: consent(), enabled: 0, used_reviews: 1, actor: 'Builder' }
}
function reviewPage() {
  return { production_id: pid, items: [review()], counts: { unsupported: 1 }, next_before: 0, authorizations: [grant()],
    heartbeat: 11000, last_scan: 11000, error: '', worker_error: '', cursor: 18, batch_full: 0, paused: 0,
    sampling_unit: 'session/body', execution: 'advisory_only_no_replay' }
}
function evidencePage() {
  return { production_id: pid, items: [observation()], next_before: 0, capture_counts: { unsupported: 1 }, model_calls: 0,
    observer: { last_scan: 11000, error: '', batch_full: '0', unattributed_headers: 2, retention_loss_detection: 'not_available', retention: 'no_automatic_purge' }, history: 'No backfill' }
}
function context() {
  return { id: 'flow-test', production_id: pid, flow_key: 'optional', revision: 1, digest: hash, config: { title: 'Optional purpose' },
    monitoring_prerequisite: false, model_calls: 0 }
}
function premises() {
  return { session_id: '18', recipient: 'Demo clinic', relationship: 'another_provider',
    purpose: 'Treating this patient', permission_basis: 'treatment', permission_details: 'Ordinary treatment data, no special restriction.',
    authorization_status: 'not_relied_upon', safeguards: 'Treating team access only.', exceptions: 'No special-category exception needed.', confirmed: true }
}
describe('Production evidence and review workspace contracts', () => {
  it('freezes confirmed session-scoped demo premises in exact review consent', () => {
    const input = { key: 'demo', agent: 'agent-test', every: 1, reviews: 1, minutes: 10, existing: false, cost: true, synthetic: true }
    const p = premises()
    const c = buildReviewConsent(decodeReviewPlan(plan()), { ...input, premises: p })
    expect(c.demo_premises).toEqual(p)
    p.purpose = 'Changed after preview'
    expect(c.demo_premises?.purpose).toBe('Treating this patient')
    for (const change of [{ confirmed: false }, { session_id: '' }, { session_id: '18;halt' }, { relationship: 'invented' },
      { recipient: '' }, { permission_details: 'x'.repeat(1001) }, { verdict: 'no_risk' }]) {
      expect(() => decodeDemoPremises({ ...premises(), ...change })).toThrow()
    }
  })
  it('permits explicit unknown demo inputs without inventing absent authorization', () => {
    const p = decodeDemoPremises({ ...premises(), relationship: 'unknown', permission_basis: 'unknown', authorization_status: 'unknown' })
    expect(p.authorization_status).toBe('unknown')
    const g = decodeGrant({ ...grant(), authorized_at: 100, definition: { ...consent(), demo_premises: p } })
    expect(g.premises?.relationship).toBe('unknown')
  })
  it('preserves explicit message-to-recipient mapping and data scope without rewriting legacy approvals', () => {
    expect(decodeDemoPremises(premises())).not.toHaveProperty('recipient_mapping')
    const p = { ...premises(), recipient_mapping: 'Process is internal; Receiver represents the clinic.',
      data_scope: 'All messages concern the specified synthetic treatment episode.' }
    expect(decodeDemoPremises(p)).toEqual(p)
    expect(() => decodeDemoPremises({ ...p, data_scope: '' })).toThrow()
    expect(() => decodeDemoPremises({ ...premises(), recipient_mapping: p.recipient_mapping })).toThrow()
  })
  it('shows approval provenance only when user inputs match the model packet and source session', () => {
    const p = premises()
    const a = { premises: p, actor: 'Demo approver', confirmed_at: 100, authorization_id: 'test-m4',
      provenance: 'user_confirmed_demo_premises_not_independently_verified' }
    const facts = [
      { id: 'demo_approval', kind: 'observation', verification: 'verified', origin: 'protected_demo_approval',
        text: JSON.stringify({ actor: a.actor, confirmed_at: a.confirmed_at, authorization_id: a.authorization_id, approval_hash: hash }) },
      { id: 'demo_recipient', text: JSON.stringify({ recipient: p.recipient, relationship: p.relationship }) },
      { id: 'demo_purpose', text: p.purpose },
      { id: 'demo_permission', text: JSON.stringify({ basis: p.permission_basis, authorization_status: p.authorization_status, details: p.permission_details }) },
      { id: 'demo_safeguards', text: JSON.stringify({ safeguards: p.safeguards, exceptions: p.exceptions }) },
    ]
    const detail = { review: { ...review(), state: 'failed', packet: { facts }, demo_approval: a }, evidence: observation(), report: null }
    expect(decodeProductionReviewDetail(detail).approval?.actor).toBe('Demo approver')
    for (const change of [{ actor: 'Someone else' }, { premises: { ...p, session_id: '19' } }, { premises: { ...p, purpose: 'Marketing' } }]) {
      expect(() => decodeProductionReviewDetail({ ...detail, review: { ...detail.review, demo_approval: { ...a, ...change } } })).toThrow()
    }
  })
  it('decodes real message references without treating numeric cursors as strings', () => {
    expect(decodeEvidencePage(evidencePage()).items[0].header_id).toBe('18')
    expect(decodeEvidencePage(evidencePage()).observer.batch_full).toBe(false)
    expect(() => decodeEvidencePage({ ...evidencePage(), next_before: '18' })).toThrow()
    expect(() => decodeEvidencePage({ ...evidencePage(), next_before: 1.5 })).toThrow()
  })
  it('rejects cross-Production evidence and overlay identities', () => {
    expect(() => decodeEvidencePage({ ...evidencePage(), production_id: other })).toThrow()
    const value = observation(); value.current_review.production_id = other
    expect(() => decodeObservation(value)).toThrow()
    value.current_review.production_id = pid; value.current_review.observation_hash = 'd'.repeat(64)
    expect(() => decodeObservation(value)).toThrow()
  })
  it('does not turn capture failures or unsupported bodies into clean facts', () => {
    expect(decodeObservation(observation()).facts).toBe(null)
    const value = observation()
    expect(() => decodeObservation({ ...value, capture: { state: 'captured', reason: '', facts: null } })).toThrow()
    expect(() => decodeObservation({ ...value, capture: { state: 'unsupported', reason: '', facts: {} } })).toThrow()
    expect(() => decodeObservation({ ...value, current_review: { ...review(), state: 'delivered' } })).toThrow()
  })
  it('requires actual edges and no inference when reading paths', () => {
    const value = { production_id: pid, model_calls: 0, next_after: '', scope: 'Actual headers only',
      items: [{ id: hash, source: 'Source', target: 'Target', basis: 'actual_message_header' }] }
    expect(decodeEdges(value).items).toHaveLength(1)
    expect(() => decodeEdges({ ...value, items: [{ ...value.items[0], basis: 'configured_topology' }] })).toThrow()
    expect(() => decodeEdges({ ...value, model_calls: 1 })).toThrow()
  })
  it('builds consent only from exact pinned plan with separate acknowledgements', () => {
    const c = consent()
    expect(c.max_model_requests).toBe(4)
    expect(c.expires_at).toBe(10600)
    expect(c.include_existing).toBe(false)
    expect(c.source_revision).toBe(3)
    expect(c.agent_config_hash).toBe(hash)
    const base = { key: 'test', agent: 'agent-test', every: 1, reviews: 1, minutes: 10, existing: false, cost: true, synthetic: true }
    for (const change of [{ cost: false }, { synthetic: false }, { reviews: 21 }, { reviews: 1.5 }, { every: 0 },
      { minutes: 1441 }, { key: '../bad' }, { agent: 'another' }]) {
      expect(() => buildReviewConsent(decodeReviewPlan(plan()), { ...base, ...change })).toThrow()
    }
    expect(() => decodeReviewPlan({ ...plan(), model_calls: 1 })).toThrow()
  })
  it('keeps spent, revoked and failed budget visible and isolated', () => {
    const g = decodeGrant(grant())
    expect(g.enabled).toBe(false); expect(g.used).toBe(1); expect(g.requests).toBe(4)
    expect(decodeReviewPage(reviewPage()).items[0].state).toBe('unsupported')
    expect(() => decodeReviewPage({ ...reviewPage(), production_id: other })).toThrow()
    expect(() => decodeGrant({ ...grant(), definition: { ...consent(), max_model_requests: 100 } })).toThrow()
    expect(() => decodeGrant({ ...grant(), definition: { ...consent(), production_id: other } })).toThrow()
    expect(() => decodeReviewPage({ ...reviewPage(), next_before: '18' })).toThrow()
  })
  it('preserves empty coverage as unknown instead of manufacturing a percentage or all-clear', () => {
    const p = decodeReviewPage({ ...reviewPage(), items: [], counts: {}, authorizations: [], heartbeat: '', last_scan: '' })
    expect(p.items).toHaveLength(0); expect(p.counts).toEqual({}); expect(p.heartbeat).toBe(0)
  })
  it('keeps contexts optional, immutable revisions rather than discovered routes', () => {
    const value = { production_id: pid, items: [context()], next_after: '', discovered_flows: false,
      monitoring_prerequisite: false, record_kind: 'optional_review_context' }
    expect(decodeContexts(value).items[0].revision).toBe(1)
    expect(() => decodeContexts({ ...value, production_id: other })).toThrow()
    expect(() => decodeContexts({ ...value, discovered_flows: true })).toThrow()
    expect(() => decodeContext({ ...context(), monitoring_prerequisite: true })).toThrow()
  })
  it('accepts failed/no-report dispositions but never a completed verdict without a bound report', () => {
    const detail = { review: review(), evidence: observation(), report: null }
    expect(decodeProductionReviewDetail(detail).issues).toHaveLength(0)
    expect(() => decodeProductionReviewDetail({ ...detail, review: { ...review(), state: 'completed' } })).toThrow()
    expect(() => decodeProductionReviewDetail({ ...detail, review: { ...review(), observation_hash: 'd'.repeat(64) } })).toThrow()
  })
  it('rejects a substituted business receipt instead of displaying it as verified intake', () => {
    const detail = { review: { ...review(), business_evidence: { adapter: 'synthetic-quality-intake-v1',
      production_id: other, observation_hash: hash, config_hash: hash } }, evidence: observation(), report: null }
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
  })
  it('shows bound SQL intake without turning an unknown relationship into business permission', () => {
    const business = { adapter: 'synthetic-quality-intake-v1', production_id: pid, observation_hash: hash,
      config_hash: hash, evidence_hash: hash, recipient_established: false, scope: 'Intake only, not later use',
      policy: { version: 'synthetic-quality-intake-v1', synthetic: true, purpose: 'Year-only local rule' },
      receipt: { receiver: 'ReceiverC', batch_id: 'm5-unit', received_at: 100, readback_match: true,
        message_id: '3', session_id: '18', payload_hash: hash } }
    const packet = { facts: [{ id: 'evidence_binding', text: JSON.stringify({ production_id: pid,
      observation_hash: hash, config_hash: hash, evidence_hash: hash }) }] }
    const evidence = { ...observation(), capture: { ...observation().capture, body_digest: hash } }
    const detail = { review: { ...review(), business_evidence: business, packet }, evidence, report: null }
    expect(decodeProductionReviewDetail(detail).business?.receiver).toBe('ReceiverC')
    expect(decodeProductionReviewDetail(detail).business?.established).toBe(false)
    expect(decodeProductionReviewDetail(detail).assessment).toBeUndefined()
    expect(() => decodeProductionReviewDetail({ ...detail, review: { ...detail.review, business_evidence: {
      ...business, receipt: { ...business.receipt, message_id: '999' } } } })).toThrow()
    expect(() => decodeProductionReviewDetail({ ...detail, review: { ...detail.review, packet: { facts: [] } } })).toThrow()
  })
  it('validates actual question-specific citation spans and rejects substituted results', () => {
    const result = { issues: [{ question_id: 'q1', status: 'unresolved', explanation: 'Actual purpose unknown',
      citations: [{ evidence_id: 'section-test', passage_id: 'p0', start: 0, end: 13, quote: 'A dated rule.' }] }], missing_information: ['Actual purpose?'],
    human_review_required: true, assessment: 'information_required', summary: { execution: 'not_executed', recommended_action: 'manual_review', risk_detected: false, unresolved: true } }
    const r = { ...review(), state: 'completed', report_id: 'report-test', result }
    const report = { id: 'report-test', state: 'completed', version: 'production-review-v1', authorization: {
      agent_id: 'agent-test', source_revision: 3, config_hash: hash, max_model_requests: 2, request_key: 'production-' + 'e'.repeat(64) },
    source: { id: 'agent-test', revision: 3, config_hash: hash }, result, packages: [{ question_id: 'q1', evidence: [{
      id: 'section-test', text: 'A dated rule.', metadata: { retrieval_scope: 'normative' }, source_hash_verified: true, section_text_complete: true,
      passages: [{ id: 'p0', start: 0, end: 13, text: 'A dated rule.' }],
    }] }] }
    const detail = { review: r, evidence: observation(), report }
    expect(decodeProductionReviewDetail(detail).issues[0].citations[0].quote).toBe('A dated rule.')
    expect(() => decodeProductionReviewDetail({ ...detail, report: { ...report, id: 'wrong-report' } })).toThrow()
    expect(() => decodeProductionReviewDetail({ ...detail, review: { ...r, result: {} } })).toThrow()
    report.packages[0].evidence[0].source_hash_verified = false
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
    report.packages[0].evidence[0].source_hash_verified = true
    report.packages[0].evidence[0].section_text_complete = false
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
    report.packages[0].evidence[0].section_text_complete = true
    result.issues[0].citations[0].passage_id = 'invented'
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
    result.issues[0].citations[0].passage_id = 'p0'
    result.issues[0].citations[0].end = 14
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
    result.issues[0].citations[0].end = 13
    result.issues[0].citations[0].quote = 'An invented quotation.'
    expect(() => decodeProductionReviewDetail(detail)).toThrow()
  })
})
