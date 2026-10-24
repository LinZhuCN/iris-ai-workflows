import { describe, expect, it } from 'vitest'
import {
  bindDeclarationReport, canDecide, dateInput, decisionCommand, decodeDeclarationCatalog, decodeDeclarationHistory,
  decodeDeclarationRecord, decodeDeclarationReport, decodeDeclarations, decodeProposalResult, decodeReviewPlan,
  inputDate, irisNow, newProposal, saveCommand,
} from './declarations'

const hash = 'a'.repeat(64)
function record(state = 'draft', assessment: string | null = null) {
  const p = newProposal()
  p.title = 'Synthetic quality analysis'; p.owner = 'Quality team'
  p.data.resources = ['Patient']; p.data.fields = ['Patient.id']
  const result = assessment ? {
    assessment, basis: 'proposed_use_as_declared', risk_detected: assessment === 'risk_identified',
    unresolved: assessment === 'information_required', missing_information: assessment === 'information_required' ? ['Specify purpose'] : [],
    issues: [{ question_id: 'q1', status: assessment === 'risk_identified' ? 'risk_signal' : assessment === 'information_required' ? 'unresolved' : 'no_signal_on_checked_issue',
      fact_ids: ['purpose_text'], explanation: 'Synthetic example', citations: [{ evidence_id: 'section-1', passage_id: 'p0', quote: 'Law', start: 0, end: 3 }] }],
  } : null
  return {
    id: 'declaration-unit', declaration_id: 'unit', revision: 1, latest_revision: 1, digest: hash, parent_digest: '',
    proposal: p, state: state === 'draft' ? 'draft' : 'submitted', created_by: 'unit', created_at: irisNow(),
    context: { catalog_version: 'v1', catalog_hash: hash, organization: { organization_id: 'DEMO', role: 'covered-entity', synthetic: true },
      recipient: { id: 'internal', name: 'Internal', relationship: 'same-covered-entity', service_identity: 'receiver', executable: true } },
    review: { task: state === 'draft' ? null : {
      id: 'task-unit', record_hash: hash, record_id: 'declaration-unit', declaration_id: 'unit', revision: 1, mode: 'declaration',
      declaration_digest: hash, state, assessment, result, reserved_requests: state === 'blocked_budget' ? 0 : 2, attempted_requests: state === 'blocked_budget' ? 0 : 2,
    } },
    decision: null, capability: { state: 'supported', reason: 'Bounded recipe' },
    execution_state: 'not_approved', is_current_submission: state !== 'draft',
  }
}
function consent() {
  return { record_id: 'declaration-unit', digest: hash, task_id: 'task-unit', agent_id: 'agent-unit', source_revision: 3,
    config_hash: hash, input_hash: hash, contract_hash: hash, max_model_requests: 2, acknowledge_cost: false }
}
function funded() {
  const r = record('completed', 'no_risk_identified')
  return { ...r, review: { task: { ...r.review.task, runtime: { authorization: { ...consent(), acknowledge_cost: true },
    report_id: 'report-unit', message_id: '12', session_id: 9, error: '' } } } }
}
function report() {
  const c = consent()
  return { id: 'report-unit', version: 'declaration-review-v1', state: 'completed',
    authorization: { request_key: 'declaration-task-unit', agent_id: c.agent_id, source_revision: 3, config_hash: hash,
      input_hash: hash, contract_hash: hash, max_model_requests: 2, acknowledge_cost: true },
    source: { id: c.agent_id, revision: 3, model: 'deepseek-flash', table: 'Contest.HIPAAIndex7', index_version: 7, corpus: hash, config_hash: hash },
    phases: [{ phase: 'judge', state: 'returned', agent_session: '22', raw: '{}',
      sdk_stats: { total_prompt_tokens: 50, total_completion_tokens: 10, total_interactions: 1 } }],
    packages: [{ question_id: 'q1', evidence: [{ id: 'section-1', text: 'Law', source_hash_verified: true,
      metadata: { source_url: 'https://www.ecfr.gov/unit', source_locator: 'section 1', source_version: '2026', source_sha256: hash } }] }],
  }
}

describe('declaration workflow contracts', () => {
  it('starts a genuinely blank unapproved proposal, not a QI verdict', () => {
    const p = newProposal()
    expect(p.purpose.category).toBe('unspecified')
    expect(p.data.fields).toEqual([])
    expect(p.recipient_id).toBe('unspecified-recipient')
    expect(decodeDeclarationRecord(record()).review.task).toBeNull()
  })
  it('sends exact optimistic concurrency pins when saving a new version', () => {
    const previous = decodeDeclarationRecord(record()), p = previous.proposal
    expect(saveCommand('unit', p)).toMatchObject({ expected_revision: 0, expected_digest: '' })
    expect(saveCommand('unit', p, previous)).toMatchObject({ expected_revision: 1, expected_digest: hash })
    expect(() => saveCommand('different', p, previous)).toThrow()
    expect(() => saveCommand('unit', p, { ...previous, latest_revision: 2 })).toThrow()
  })
  it('rejects incompatible selected resource/field combinations and empty scope', () => {
    const p = record().proposal
    expect(() => saveCommand('unit', { ...p, data: { ...p.data, resources: [] } })).toThrow()
    expect(() => saveCommand('unit', { ...p, data: { ...p.data, fields: ['Encounter.id'] } })).toThrow()
  })
  it('validates fractional limits and validity boundaries', () => {
    const r = record()
    r.proposal.data.max_records = 1.5
    expect(() => decodeDeclarationRecord(r)).toThrow()
    const invalid = record(); invalid.proposal.validity.until = invalid.proposal.validity.from
    expect(() => decodeDeclarationRecord(invalid)).toThrow()
  })
  it.each(['no_risk_identified', 'risk_identified', 'information_required'])('keeps actual %s distinct', assessment => {
    const r = decodeDeclarationRecord(record('completed', assessment))
    expect(r.review.task?.assessment).toBe(assessment)
    expect(r.decision).toBeNull()
    expect(canDecide(r, 'approved')).toBe(assessment === 'no_risk_identified')
  })
  it.each(['draft', 'blocked_budget', 'queued', 'running', 'failed'])('never approves %s', state => {
    const r = decodeDeclarationRecord(record(state))
    expect(canDecide(r, 'approved')).toBe(false)
    expect(canDecide(r, 'returned')).toBe(state === 'failed')
    expect(canDecide(r, 'rejected')).toBe(state === 'failed')
  })
  it('prevents stale, expired, future and unsubmitted approvals', () => {
    const r = decodeDeclarationRecord(record('completed', 'no_risk_identified'))
    for (const changed of [{ ...r, latest_revision: 2 }, { ...r, is_current_submission: false },
      { ...r, proposal: { ...r.proposal, validity: { from: 1, until: 2 } } },
      { ...r, proposal: { ...r.proposal, validity: { from: irisNow() + 30, until: irisNow() + 60 } } }]) {
      expect(canDecide(changed, 'approved')).toBe(false)
    }
  })
  it('records a reason against the precise terminal task hash, never a label alone', () => {
    const r = decodeDeclarationRecord(record('completed', 'no_risk_identified'))
    expect(decisionCommand(r, 'approved', 'Accept scoped use')).toEqual({
      record_id: r.id, digest: hash, task_id: 'task-unit', task_hash: hash, action: 'approved', reason: 'Accept scoped use',
    })
    expect(() => decisionCommand(r, 'approved', ' ')).toThrow()
    expect(() => decisionCommand(r, 'approved', 'x'.repeat(1001))).toThrow()
  })
  it('rejects technical failures containing conclusions and mismatched task bindings', () => {
    expect(() => decodeDeclarationRecord(record('failed', 'no_risk_identified'))).toThrow()
    const r = record('completed', 'no_risk_identified')
    if (!r.review.task) throw new Error('Fixture requires task')
    r.review.task.declaration_digest = 'b'.repeat(64)
    expect(() => decodeDeclarationRecord(r)).toThrow()
  })
  it('rejects missing material questions and hidden gaps in a no-risk result', () => {
    const result = record('completed', 'no_risk_identified').review.task?.result
    expect(() => decodeProposalResult({ ...result, missing_information: ['Recipient?'] })).toThrow()
    expect(() => decodeProposalResult({ ...result, assessment: 'information_required', unresolved: true })).toThrow()
    expect(() => decodeProposalResult({ ...result, issues: [{ ...result?.issues[0], status: 'risk_signal' }] })).toThrow()
    expect(() => decodeProposalResult({ ...result, issues: [] })).toThrow()
  })
  it('cost planning never authorizes inference or changes the exact task cap', () => {
    const plan = { consent: consent(), source: { model: 'deepseek-flash' }, model_calls: 0 }
    expect(decodeReviewPlan(plan).consent.acknowledge_cost).toBe(false)
    expect(() => decodeReviewPlan({ ...plan, consent: { ...consent(), acknowledge_cost: true } })).toThrow()
    expect(() => decodeReviewPlan({ ...plan, consent: { ...consent(), max_model_requests: 3 } })).toThrow()
    expect(() => decodeReviewPlan({ ...plan, model_calls: 1 })).toThrow()
  })
  it('binds actual source, revision, report and canonical citations', () => {
    const r = decodeDeclarationRecord(funded()), p = decodeDeclarationReport(report())
    expect(bindDeclarationReport(r, p).phases[0].completion_tokens).toBe(10)
    expect(() => bindDeclarationReport(r, { ...p, id: 'other-report' })).toThrow()
    expect(() => bindDeclarationReport(r, { ...p, authorization: { ...p.authorization, input_hash: 'b'.repeat(64) } })).toThrow()
    expect(() => bindDeclarationReport(r, { ...p, source: { ...p.source, revision: 2 } })).toThrow()
    expect(() => bindDeclarationReport(r, { ...p, sources: [{ ...p.sources[0], text: 'Not the source' }] })).toThrow()
    expect(() => bindDeclarationReport(r, { ...p, sources: [{ ...p.sources[0], verified: false }] })).toThrow()
  })
  it('rejects funding attached to another revision', () => {
    const r = funded(); r.review.task.runtime.authorization.record_id = 'different'
    expect(() => decodeDeclarationRecord(r)).toThrow()
  })
  it('supports list/history pagination and read-only numeric permission flags', () => {
    expect(decodeDeclarations({ items: [record()], next_cursor: 'unit', can_write: 0, model_calls: 0 }).can_write).toBe(false)
    expect(decodeDeclarationHistory({ declaration_id: 'unit', items: [record()], has_older: true, older_before_revision: 2 }).has_older).toBe(true)
    expect(() => decodeDeclarations({ items: [], next_cursor: '', can_write: 1, model_calls: 1 })).toThrow()
  })
  it('requires a synthetic, non-inferencing catalog and keeps unsupported execution explicit', () => {
    const c = { schema: 1, version: 'v1', model_calls: 0, organization: record().context.organization,
      recipients: [record().context.recipient], recipes: [{ id: 'retained', description: 'Assessment only', executable: false }],
      purpose_categories: ['unspecified'], resources: [], fields: [], cohorts: [], identifiability: [], arrangement_statuses: [] }
    expect(decodeDeclarationCatalog(c).recipes[0].executable).toBe(false)
    expect(() => decodeDeclarationCatalog({ ...c, model_calls: 2 })).toThrow()
    expect(() => decodeDeclarationCatalog({ ...c, organization: { ...c.organization, synthetic: false } })).toThrow()
  })
  it('roundtrips local datetime inputs using the IRIS epoch', () => {
    const value = inputDate('2026-10-17T12:00')
    expect(dateInput(value)).toBe('2026-10-17T12:00')
    expect(() => inputDate('not a date')).toThrow()
  })
})
