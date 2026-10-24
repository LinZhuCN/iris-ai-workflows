import { describe, expect, it } from 'vitest'
import { decodeDeclarationRecord, irisNow, newProposal } from './declarations'
import { decodeExecution, decodeExecutionPlan, decodeExecutions, eligibleExecution, executionCommand, validBatch } from './declaration-execution'

const digest = 'a'.repeat(64)
function record() {
  const proposal = newProposal()
  return {
    id: 'declaration-unit', declaration_id: 'unit', revision: 1, latest_revision: 1, digest, parent_digest: '', proposal,
    state: 'submitted', created_by: 'unit', created_at: irisNow(), is_current_submission: true,
    context: { catalog_version: 'v1', catalog_hash: digest, organization: { organization_id: 'DEMO', role: 'covered-entity', synthetic: true },
      recipient: { id: 'internal', name: 'Internal', relationship: 'same-covered-entity', service_identity: 'receiver', executable: true } },
    review: { task: { id: 'task-unit', record_id: 'declaration-unit', declaration_id: 'unit', revision: 1, mode: 'declaration',
      declaration_digest: digest, record_hash: digest, state: 'completed', assessment: 'no_risk_identified', reserved_requests: 2, attempted_requests: 2,
      result: { assessment: 'no_risk_identified', basis: 'proposed_use_as_declared', risk_detected: false, unresolved: false, missing_information: [],
        issues: [{ question_id: 'q1', status: 'no_signal_on_checked_issue', fact_ids: ['purpose_text'], explanation: 'Synthetic test', citations: [] }] } } },
    decision: { record_id: 'declaration-unit', digest, task_id: 'task-unit', task_hash: digest, action: 'approved', reason: 'Synthetic approval', decided_by: 'unit', decided_at: irisNow(), record_hash: digest },
    capability: { state: 'supported', reason: 'Bounded internal recipe' }, execution_state: 'ready',
  }
}
function plan() {
  return { model_calls: 0, recipe_id: 'year-and-encounter-v1', max_records: 4, recipient: 'local-analysis-receiver',
    binding: { namespace: 'UTILIZATION', production: 'Contest.Utilization.Production', source: 'FHIRSource', sender: 'AnalysisReceiver', config_hash: digest },
    consent: { record_id: 'declaration-unit', digest, decision_hash: digest, task_id: 'task-unit', task_hash: digest,
      config_hash: digest, batch_id: 'unit-batch', acknowledge_delivery: false } }
}
function delivered() {
  return { id: 'declaration-run-unit', grant_hash: digest, state: 'delivered', error: '', model_calls: 0, monitoring_state: 'automatic_observer',
    grant: { consent: { ...plan().consent, acknowledge_delivery: true }, record: record(), batch_id: 'unit-batch', created_by: 'unit', created_at: irisNow() },
    receipt: { schema: 1, synthetic: true, model_calls: 0, outcome: 'delivered', receipt_hash: digest, source_hash: digest, output_hash: digest, config_hash: digest, scope_hash: digest,
      approval_id: 'declaration-run-unit', batch_id: 'unit-batch', message_id: '1', receiver_message_id: '2', session_id: 1, received_at: irisNow(),
      receiver_readback_match: true, transport: 'same-instance-BO-to-SQL', inspection: { resource_counts: { Patient: 2, Encounter: 2 }, field_paths: ['Patient.id'] },
      declaration_binding: { record_id: 'declaration-unit', revision: 1, declaration_digest: digest, decision_hash: digest, task_id: 'task-unit', task_hash: digest,
        recipe_id: record().proposal.handling.recipe_id, execution_id: 'declaration-run-unit', execution_hash: digest } } }
}
describe('exact approved declaration execution', () => {
  it('requires bounded caller-chosen batch IDs', () => {
    expect(validBatch('browser-quality-1')).toBe(true)
    for (const invalid of ['', '../other', 'space here', 'a'.repeat(65), '中文']) expect(validBatch(invalid)).toBe(false)
  })
  it('plans without granting delivery or inference', () => {
    expect(decodeExecutionPlan(plan()).consent.acknowledge_delivery).toBe(false)
    expect(() => decodeExecutionPlan({ ...plan(), model_calls: 1 })).toThrow()
    expect(() => decodeExecutionPlan({ ...plan(), consent: { ...plan().consent, acknowledge_delivery: true } })).toThrow()
    expect(() => decodeExecutionPlan({ ...plan(), recipient: 'external' })).toThrow()
  })
  it('requires explicit confirmation and matching decision/review/config pins', () => {
    const r = decodeDeclarationRecord(record()), p = decodeExecutionPlan(plan())
    expect(() => executionCommand(r, p, false)).toThrow()
    expect(executionCommand(r, p, true)).toMatchObject({ acknowledge_delivery: true, batch_id: 'unit-batch', decision_hash: digest })
    for (const field of ['record_id', 'digest', 'decision_hash', 'task_id', 'task_hash'] as const) {
      expect(() => executionCommand(r, { ...p, consent: { ...p.consent, [field]: 'changed' } }, true)).toThrow()
    }
  })
  it('gates draft, old, expired, unsupported, risky and unapproved execution', () => {
    const r = decodeDeclarationRecord(record())
    expect(eligibleExecution(r)).toBe(true)
    for (const changed of [{ ...r, execution_state: 'not_approved' }, { ...r, latest_revision: 2 },
      { ...r, is_current_submission: false }, { ...r, decision: null },
      { ...r, capability: { ...r.capability, state: 'unsupported' as const } },
      { ...r, proposal: { ...r.proposal, validity: { from: 1, until: 2 } } },
      { ...r, review: { task: null } }]) expect(eligibleExecution(changed)).toBe(false)
  })
  it('displays delivered only with a verified SQL receipt tied to the exact revision', () => {
    expect(decodeExecution(delivered()).receipt?.session_id).toBe(1)
    expect(() => decodeExecution({ ...delivered(), receipt: null })).toThrow()
    const base = delivered()
    for (const changed of [{ ...base.receipt, receiver_readback_match: false }, { ...base.receipt, scope_hash: 'b'.repeat(64) },
      { ...base.receipt, declaration_binding: { ...base.receipt.declaration_binding, record_id: 'other' } },
      { ...base.receipt, declaration_binding: { ...base.receipt.declaration_binding, decision_hash: 'b'.repeat(64) } }]) {
      expect(() => decodeExecution({ ...base, receipt: changed })).toThrow()
    }
  })
  it('never turns an uncertain result into delivery or completed after-send review', () => {
    const value = { ...delivered(), state: 'reconciliation_required', receipt: null, error: 'Inspect without replay' }
    expect(decodeExecution(value).state).toBe('reconciliation_required')
    expect(() => decodeExecution({ ...value, receipt: delivered().receipt })).toThrow()
    expect(() => decodeExecution({ ...delivered(), monitoring_state: 'completed' })).toThrow()
  })
  it('preserves historical grant and paginated execution linkage', () => {
    const value = { record_id: 'declaration-unit', items: [delivered()], next_cursor: 'declaration-run-unit', model_calls: 0 }
    expect(decodeExecutions(value).items[0].grant.record.id).toBe('declaration-unit')
    expect(decodeExecutions(value).next_cursor).toBe('declaration-run-unit')
    expect(() => decodeExecutions({ ...value, model_calls: 2 })).toThrow()
  })
})
