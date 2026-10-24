import { describe, expect, it } from 'vitest'
import { decodeDeclarationMonitor, decodeMonitorPlan } from './declaration-monitor'

const hash = 'a'.repeat(64)
function item() {
  return { id: 'declaration-run-unit', state: 'blocked_budget', origin: 'automatic_after_send', heartbeat: 123,
    observer_error: '', error: '', result: null, reserved_requests: 0, attempted_requests: 0, authorized_requests: 0, evidence_hash: hash, receipt_hash: hash,
    event: { state: 'open', revision: 1, actions: [] },
    evidence: { record_id: 'declaration-unit', revision: 2, decision_hash: hash, task_hash: hash, batch_id: 'unit', limits: 'Future recipient conduct not observed' } }
}
function plan() {
  return { model: 'deepseek-flash', model_calls: 0, consent: { id: 'declaration-run-unit', evidence_hash: hash, receipt_hash: hash,
    agent_id: 'agent', source_revision: 1, config_hash: hash, contract_hash: hash, max_model_requests: 2, acknowledge_cost: false } }
}
function complete() {
  return { ...item(), state: 'completed', attempted_requests: 2, reserved_requests: 2, report_id: 'report',
    result: { summary: { risk_detected: false, unresolved: false, execution: 'not_executed', recommended_action: 'manual_review' }, missing_information: [],
      issues: [{ question_id: 'q1', status: 'no_signal_on_checked_issue', fact_ids: ['observed_output'], explanation: 'Matched the declared scope',
        applicability: 'applicable', condition_status: 'met', applicability_fact_ids: ['observed_output'], affirmative_fact_ids: ['observed_output'],
        exceptions: { status: 'resolved', explanation: 'Internal use within stated premise' },
        citations: [{ evidence_id: 'section', passage_id: 'p0', quote: 'Rule', start: 0, end: 4 }] }] },
    report: { id: 'report', version: 'staged-risk-v4', source: { model: 'deepseek-flash' }, authorization: { request_key: 'monitor-declaration-run-unit', contract_hash: hash },
      phases: [{ phase: 'judge', state: 'returned', agent_session: '1', raw: '{}' }],
      packages: [{ question_id: 'q1', evidence: [{ id: 'section', text: 'Rule', source_hash_verified: 1,
        metadata: { source_locator: '45 CFR', source_version: '2026' } }] }] } }
}
describe('automatic declaration after-send comparison', () => {
  it('distinguishes captured/unfunded from completed AI assessment', () => {
    expect(decodeDeclarationMonitor(item()).result).toBeNull()
    expect(decodeDeclarationMonitor(item()).state).toBe('blocked_budget')
    expect(() => decodeDeclarationMonitor({ ...item(), state: 'completed' })).toThrow()
    expect(() => decodeDeclarationMonitor({ ...item(), origin: 'browser_triggered' })).toThrow()
  })
  it('requires separate initially unchecked exact-receipt cost confirmation', () => {
    expect(decodeMonitorPlan(plan()).consent.acknowledge_cost).toBe(false)
    expect(() => decodeMonitorPlan({ ...plan(), model_calls: 1 })).toThrow()
    expect(() => decodeMonitorPlan({ ...plan(), consent: { ...plan().consent, acknowledge_cost: true } })).toThrow()
    expect(() => decodeMonitorPlan({ ...plan(), consent: { ...plan().consent, max_model_requests: 3 } })).toThrow()
  })
  it('validates actual report identity and materialized exact source citations', () => {
    expect(decodeDeclarationMonitor(complete()).result?.issues[0].citations[0].quote).toBe('Rule')
    const bad = complete(); bad.report.packages[0].evidence[0].text = 'Wrong'
    expect(() => decodeDeclarationMonitor(bad)).toThrow()
    const wrong = complete(); wrong.report.authorization.request_key = 'monitor-other'
    expect(() => decodeDeclarationMonitor(wrong)).toThrow()
  })
  it('preserves technical failures without manufacturing a privacy finding', () => {
    expect(decodeDeclarationMonitor({ ...item(), state: 'failed', error: 'Output failed' }).result).toBeNull()
    expect(() => decodeDeclarationMonitor({ ...complete(), state: 'failed' })).toThrow()
  })
  it('rejects inconsistent aggregate claims and executing review recommendations', () => {
    const value = complete(); value.result.summary.risk_detected = true
    expect(() => decodeDeclarationMonitor(value)).toThrow()
    const executing = complete(); executing.result.summary.execution = 'delivered'
    expect(() => decodeDeclarationMonitor(executing)).toThrow()
    const empty = complete(); empty.result.issues = []
    expect(() => decodeDeclarationMonitor(empty)).toThrow()
  })
  it('keeps human event resolution independent from funding and model completion', () => {
    const value = { ...item(), event: { state: 'resolved', revision: 3, actions: [
      { actor: 'reviewer', time: 10, before: 'open', after: 'in_review', text: 'Inspect' },
      { actor: 'reviewer', time: 11, before: 'in_review', after: 'resolved', text: 'Recorded gap' },
    ] } }
    expect(decodeDeclarationMonitor(value).state).toBe('blocked_budget')
    expect(decodeDeclarationMonitor(value).event.actions).toHaveLength(2)
  })
})
