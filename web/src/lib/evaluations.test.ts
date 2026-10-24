import { describe, expect, it } from 'vitest'
import { decodeEvaluation, decodeEvaluations } from './evaluations'

const config = {
  id: 'agent-1', revision: 3, status: 'published', name: 'Privacy', purpose: 'Synthetic review',
  retrieval_query: 'HIPAA', template: 'privacy_review', table: 'Contest.HIPAAIndex7',
  index_version: 7, corpus: 'corpus', model: 'deepseek-flash', config_hash: 'config-hash',
  max_iterations: 4, executor_version: 'privacy-v1',
}
const caseResult = { scenario: 'risk', expected: 'risk', state: 'completed', passed: true, tools: [],
  result: { assessment: 'risk', reason: 'Limited synthetic flags.', citations: ['evidence-0'] } }
const report = { id: 'evaluation-1', state: 'running', config, config_hash: 'config-hash',
  manifest_hash: 'manifest-hash', suite: 'privacy-synthetic-v1', cases: [], passed: false,
  max_model_requests: 48, reserved_model_requests: 4, limitations: 'Not legal certification.' }
describe('privacy evaluation evidence', () => {
  it('binds new report and case evidence to the versioned prompt', () => {
    const v2 = { ...report, config: { ...config, prompt_version: 'privacy-review-v2', prompt_hash: 'a'.repeat(64) },
      prompt_version: 'privacy-review-v2', prompt_hash: 'a'.repeat(64) }
    expect(decodeEvaluation(v2).prompt_version).toBe('privacy-review-v2')
    expect(() => decodeEvaluation({ ...v2, prompt_hash: 'changed' })).toThrow()
    expect(() => decodeEvaluation({ ...v2, cases: [caseResult] })).toThrow()
    const pinnedCase = { ...caseResult, prompt_version: v2.prompt_version, prompt_hash: v2.prompt_hash }
    expect(decodeEvaluation({ ...v2, cases: [pinnedCase] }).cases).toHaveLength(1)
    expect(() => decodeEvaluation({ ...v2, cases: [{ ...pinnedCase, expected: 'insufficient_evidence' }] })).toThrow()
    expect(decodeEvaluation({ ...v2, cases: [{ scenario: 'risk', expected: 'risk', state: 'failed', passed: false, tools: [], error: 'Configuration changed before inference' }] }).cases[0].error).toContain('before inference')
  })
  it('preserves progress without claiming success', () => {
    expect(decodeEvaluation(report)).toMatchObject({ state: 'running', passed: false, reserved_model_requests: 4 })
  })
  it('rejects incomplete or false success', () => {
    expect(() => decodeEvaluation({ ...report, state: 'completed' })).toThrow()
    expect(() => decodeEvaluation({ ...report, passed: true })).toThrow()
    const cases = Array.from({ length: 12 }, (_, i) => ({ ...caseResult, scenario: `case-${i}` }))
    const done = { ...report, state: 'completed', passed: true, cases, summary: { total: 12, completed: 12, passed: 12, failed: 0, technical_failures: 0 } }
    expect(decodeEvaluation(done).passed).toBe(true)
    expect(() => decodeEvaluation({ ...done, cases: [{ ...caseResult, passed: false }, ...cases.slice(1)] })).toThrow()
  })
  it('retains rejected outputs as failures', () => {
    const value = decodeEvaluation({ ...report, cases: [{
      scenario: 'unknown', expected: 'insufficient_evidence', state: 'failed', passed: false,
      tools: [], rejected_output: '{"assessment":"deliver"}', error: 'Contract rejected',
    }] })
    expect(value.cases[0].rejected_output).toContain('deliver')
    expect(value.cases[0].result).toBeUndefined()
  })
  it('requires a bounded budget, matching pinned config and explicit zero automation', () => {
    expect(() => decodeEvaluation({ ...report, reserved_model_requests: 52 })).toThrow()
    expect(() => decodeEvaluation({ ...report, config_hash: 'changed' })).toThrow()
    expect(decodeEvaluations({ reports: [report], automatic_model_budget: 0 })).toHaveLength(1)
    expect(() => decodeEvaluations({ reports: [report], automatic_model_budget: 48 })).toThrow()
  })
})
