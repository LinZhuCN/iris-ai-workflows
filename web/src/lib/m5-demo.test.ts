import { describe, expect, it } from 'vitest'
import { decodeM5Run, decodeM5Status, m5AuditRecorded, m5CanReconcileAudit, m5Capture, m5PublishedAgents, m5Result, m5SavedAuditRequest, m5Scope } from './m5-demo'

const hash = 'a'.repeat(64), pid = `production-${hash}`
export function m5Profile(id: 'hospital' | 'research') {
  return { id, name: `Synthetic ${id}`, partner: `M5${id}`, type: id, parent_id: '',
    responsibilities: 'Synthetic responsibility', purpose: 'Synthetic research', relationship: 'external' as const,
    allowed_fields: ['patient_code'], prohibited_fields: ['name'], requirements: 'Remove direct identifiers' }
}
export function m5Record(id: 'hospital' | 'research') {
  return { id, revision: 1, profile: m5Profile(id), confirmed_by: 'builder', confirmed_at: 100, hash }
}
export function m5Run() {
  return { id: 'm5-demo-12345678-1234-1234-1234-123456789abc', state: 'sent', created_at: 100.25,
    profiles: { hospital: m5Record('hospital'), research: m5Record('research') },
    message_id: '42', session_id: '41', header_id: '', receipt: { received: true } }
}
export function m5Status() {
  return { ...m5Scope, production_id: pid, config_hash: hash, can_manage: true, enrolled: false,
    inspection_enabled: false, profiles: [], presets: [m5Profile('hospital'), m5Profile('research')], runs: [] }
}
function plan() {
  return { production_id: pid, config_hash: hash, contract_hash: hash, runtime: 'production-review-v1', now: 100,
    bounds: { max_reviews: 20, requests_per_review: 2, expiry_seconds: 3600 },
    eligible_agents: [{ id: 'agent-unit', revision: 1, config_hash: hash, model: 'unit-only', status: 'published' }],
    sampling: 'fixed session', scope: 'synthetic', model_calls: 0 }
}
describe('fixed M5 strict response decoding', () => {
  it('requires stored collector capture, not a receiver header or receipt, for audit eligibility', () => {
    const run = decodeM5Run({ ...m5Run(), header_id: '42' })
    expect(m5Capture(run).captured).toBe(false)
    for (const state of ['unsupported', 'not_authorized', 'evidence_failed', 'pending']) {
      expect(m5Capture(decodeM5Run({ ...run, evidence: { capture: { state, facts: null } } })).captured).toBe(false)
    }
    const evidence = { capture: { state: 'captured', facts: { date_precision: 'year' } },
      header: { source: 'Source', target: 'Research', session_id: '41' } }
    expect(m5Capture(decodeM5Run({ ...run, evidence }))).toMatchObject({
      captured: true, state: 'captured', facts: { date_precision: 'year' }, header: evidence.header,
    })
  })
  it('normalizes the live API empty-report sentinel so a captured unfunded run remains eligible', () => {
      const run = decodeM5Run({ ...m5Run(), header_id: '50', report: '',
        review: { state: 'not_authorized', authorization_id: '' },
        evidence: { id: 'observation-live-shape', record_hash: hash, observed_config_hash: hash,
          header: { header_id: '50', source: 'ProcessB', target: 'ReceiverB', session_id: 49 },
          capture: { state: 'captured', reason: 'Minimized local inspection', facts: {
            fields: { name: 1, mrn: 1, birthDate: 1 }, dates: { year_only: 0, full_date: 1, other: 0 },
          } } } })
      expect(run.report).toBeUndefined()
      expect(m5Capture(run).captured).toBe(true)
      expect(m5AuditRecorded(run)).toBe(false)
      expect(m5Result(run).label).toBe('Not assessed')
      expect(m5CanReconcileAudit(run)).toBe(true)
  })
  it('accepts a clean scoped start and frozen profiles without mutation', () => {
    const input = { ...m5Status(), profiles: [m5Record('hospital')], runs: [m5Run()], plan: plan() }
    const decoded = decodeM5Status(input)
    expect(decoded.runs[0].created_at).toBe(100.25)
    decoded.runs[0].profiles.research.profile.allowed_fields.push('new')
    expect(input.runs[0].profiles.research.profile.allowed_fields).toEqual(['patient_code'])
    expect(decodeM5Status(m5Status()).runs).toEqual([])
  })
  it.each([
    { namespace: 'DEMO' }, { production: 'Other.Production' }, { production_id: 'other' },
    { config_hash: 'stale' }, { can_manage: 'true' }, { enrolled: null }, { inspection_enabled: '1' },
    { profiles: [m5Record('hospital'), m5Record('hospital')] },
    { presets: [{ ...m5Profile('hospital'), id: 'clinic' }] },
    { profiles: [{ ...m5Record('hospital'), id: 'research' }] },
    { runs: [m5Run(), m5Run()] }, { runs: null }, { plan: null },
  ])('rejects malformed or cross-scope status %#', change => {
    expect(() => decodeM5Status({ ...m5Status(), ...change })).toThrow()
  })
  it('checks plan Production/configuration and non-authorizing contract', () => {
    for (const change of [{ production_id: `production-${'b'.repeat(64)}` }, { config_hash: 'b'.repeat(64) },
      { model_calls: 1 }, { bounds: { max_reviews: 1, requests_per_review: 3, expiry_seconds: 3600 } }]) {
      expect(() => decodeM5Status({ ...m5Status(), plan: { ...plan(), ...change } })).toThrow()
    }
  })
  it.each([
    { id: '../other' }, { state: '' }, { created_at: Infinity }, { created_at: -1 },
    { message_id: 42 }, { header_id: null }, { session_id: undefined }, { error: 1 },
    { profiles: { hospital: m5Record('research'), research: m5Record('research') } },
    { profiles: { ...m5Run().profiles, clinic: m5Record('hospital') } },
    { report: { usage: Infinity } }, { review: { raw: undefined } },
  ])('rejects invalid run evidence %#', change => {
    expect(() => decodeM5Run({ ...m5Run(), ...change })).toThrow()
  })
  it('distinguishes unfunded capture from authorized, pending, failed and completed reviews', () => {
    const run = decodeM5Run(m5Run())
    expect(m5AuditRecorded(run)).toBe(false)
    expect(m5AuditRecorded({ ...run, review: { state: 'not_authorized', authorization_id: '' } })).toBe(false)
    expect(m5AuditRecorded({ ...run, review: { state: 'pending', authorization_id: '' } })).toBe(false)
    expect(m5AuditRecorded({ ...run, review: { state: 'blocked_budget', authorization_id: '' } })).toBe(false)
    expect(m5AuditRecorded({ ...run, review: { state: 'blocked_budget', authorization_id: 'confirmed' } })).toBe(true)
    for (const state of ['pending', 'running', 'completed', 'failed', 'interrupted']) {
      expect(m5AuditRecorded({ ...run, review: { state, authorization_id: 'confirmed' } })).toBe(true)
      expect(m5Result({ ...run, review: { state }, report: null }).label).toBe('Not assessed')
    }
  })
  it('offers only published eligible reviewers, never drafts', () => {
    const decoded = decodeM5Status({ ...m5Status(), plan: { ...plan(), eligible_agents: [
      ...plan().eligible_agents, { ...plan().eligible_agents[0], id: 'draft-agent', status: 'draft' },
    ] } })
    expect(m5PublishedAgents(decoded.plan).map(agent => agent.id)).toEqual(['agent-unit'])
    expect(m5PublishedAgents(undefined)).toEqual([])
  })
  it('retains pre-grant authorization and permits only an exact single-use reconciliation', () => {
    const authorization = { authorization_id: 'immutable-consent', agent_id: 'agent-unit', source_revision: 3,
      config_hash: hash, agent_config_hash: hash, contract_hash: hash, acknowledge_cost: true }
    const run = decodeM5Run({ ...m5Run(), authorization, review: { state: 'not_authorized', authorization_id: '' },
      review_header_id: '39' })
    expect(run.review_header_id).toBe('39')
    expect(m5AuditRecorded(run)).toBe(true)
    expect(m5CanReconcileAudit(run)).toBe(true)
    expect(m5SavedAuditRequest(run)).toEqual({ ...authorization, run_id: run.id })
    expect(m5SavedAuditRequest(run)?.authorization_id).toBe(m5SavedAuditRequest(run)?.authorization_id)
    expect(m5CanReconcileAudit({ ...run, review: { state: 'pending', authorization_id: 'immutable-consent' } })).toBe(false)
    expect(m5CanReconcileAudit({ ...run, report: { state: 'failed' } })).toBe(false)
    expect(m5CanReconcileAudit({ ...run, review: { state: 'failed' } })).toBe(false)
    for (const change of [{ acknowledge_cost: false }, { source_revision: 0 }, { contract_hash: 'changed' },
      { authorization_id: '' }, { agent_id: null }]) {
      expect(m5SavedAuditRequest({ ...run, authorization: { ...authorization, ...change } })).toBeUndefined()
    }
  })
  it('explains only saved completed assessments and keeps unresolved questions visible', () => {
    const run = { ...decodeM5Run(m5Run()), review: { state: 'completed' },
      report: { state: 'completed', result: { assessment: 'risk_identified', summary: { unresolved: true },
        issues: [{ status: 'risk_signal', explanation: 'Identifier conflicts with frozen research policy.' }],
        missing_information: ['Confirm permission basis'] } } }
    expect(m5Result(run)).toMatchObject({ label: 'Potential risk identified', unresolved: true,
      reason: 'Identifier conflicts with frozen research policy.', missing: ['Confirm permission basis'] })
    expect(m5Result({ ...run, review: { state: 'failed' } }).label).toBe('Not assessed')
  })
})
