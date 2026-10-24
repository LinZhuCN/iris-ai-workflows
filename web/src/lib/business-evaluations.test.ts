import { describe, expect, it } from 'vitest'
import { decodeBusinessEvaluations } from './business-evaluations'

const config = { id: 'source', revision: 3, status: 'published', name: 'Privacy', purpose: 'Synthetic',
  retrieval_query: 'HIPAA', template: 'privacy_review', table: 'Contest.HIPAAIndex7',
  index_version: 7, corpus: 'corpus', model: 'unit', config_hash: 'config',
  max_iterations: 4, executor_version: 'privacy-v1' }
const report = { id: 'business-evaluation-1', state: 'running', suite: 'hipaa-business-context-v1',
  prompt_version: 'hipaa-business-runtime-v1', prompt_hash: 'a'.repeat(64), input_hash: 'b'.repeat(64),
  config, max_model_requests: 48, reserved_model_requests: 4, cases: [],
  execution: 'evaluation_only', human_review_required: true, hipaa_risk_validation: 'not_completed' }
const item = { case_id: 'business-01', state: 'completed', agent_session: 'unit',
  packet: { case_id: 'business-01', synthetic: true, stage: 'before_send' },
  result: { assessment: 'risk', recommended_action: 'hold_for_review', reason: 'Limited finding' },
  execution: 'not_executed', human_review_required: true, hipaa_risk_validation: 'not_completed' }
const decode = (r = report) => decodeBusinessEvaluations({ reports: [r], automatic_model_budget: 0, execution: 'evaluation_only' })
describe('business evaluations never conflate structural and legal acceptance', () => {
  it('keeps read-only progress separate from old flag suites', () => {
    expect(decode()[0].cases).toHaveLength(0)
    expect(decodeBusinessEvaluations({ reports: [], automatic_model_budget: 0, execution: 'evaluation_only' })).toEqual([])
    expect(() => decode({ ...report, suite: 'privacy-synthetic-v1' })).toThrow()
    expect(decode({ ...report, prompt_version: 'hipaa-business-runtime-v2' })[0].prompt_version).toBe('hipaa-business-runtime-v2')
    expect(() => decode({ ...report, prompt_version: 'unversioned' })).toThrow()
  })
  it('rejects false HIPAA pass, execution and incomplete completion', () => {
    expect(() => decode({ ...report, hipaa_risk_validation: 'passed' })).toThrow()
    expect(() => decode({ ...report, human_review_required: false })).toThrow()
    expect(() => decode({ ...report, state: 'completed' })).toThrow()
    expect(() => decode({ ...report, execution: 'delivered' })).toThrow()
    expect(() => decodeBusinessEvaluations({ reports: [{ ...report, passed: true }], automatic_model_budget: 0, execution: 'evaluation_only' })).toThrow()
  })
  it('checks stage, non-clean continuation, bounded counts and preserved failures', () => {
    const value = { ...report, cases: [item] }
    expect(decodeBusinessEvaluations({ reports: [value], automatic_model_budget: 0, execution: 'evaluation_only' })[0].cases[0].result?.assessment).toBe('risk')
    for (const changed of [
      { ...value, reserved_model_requests: 52 },
      { ...value, cases: [item, item] },
      { ...value, cases: [{ ...item, packet: { ...item.packet, stage: 'after_send' } }] },
      { ...value, cases: [{ ...item, result: { ...item.result, recommended_action: 'continue_under_existing_controls' } }] },
    ]) expect(() => decodeBusinessEvaluations({ reports: [changed], automatic_model_budget: 0, execution: 'evaluation_only' })).toThrow()
    const failed = { ...item, state: 'failed', result: undefined, error: 'Invalid citation', rejected_output: 'original answer' }
    expect(decodeBusinessEvaluations({ reports: [{ ...value, cases: [failed] }], automatic_model_budget: 0, execution: 'evaluation_only' })[0].cases[0].detail.rejected_output).toBe('original answer')
  })
  it('shows author-oracle gaps separately and rejects false derived success', () => {
    const diagnostic = { kind: 'author_oracle_machine_checks', human_review_required: true,
      aligned: 0, checked: 1, limitations: 'Exact locator matching is not legal entailment.',
      cases: [{ case_id: 'business-01', oracle_alignment: false, human_review_required: true,
        expected_assessment: 'risk', expected_recommendation: 'hold_for_review',
        checks: { expected_assessment: true, expected_recommendation: true, critical_facts_referenced: true, required_sections_cited: false } }] }
    const collection = { reports: [{ ...report, cases: [item], diagnostics: diagnostic }], automatic_model_budget: 0, execution: 'evaluation_only' }
    expect(decodeBusinessEvaluations(collection)[0].diagnostics?.aligned).toBe(0)
    expect(() => decodeBusinessEvaluations({ ...collection, reports: [{ ...collection.reports[0], diagnostics: { ...diagnostic, aligned: 1 } }] })).toThrow()
  })
  it.each(['hipaa-business-runtime-v3', 'hipaa-business-runtime-v4'])('keeps %s claims separate from conditions', version => {
    const v3 = { ...report, prompt_version: version, cases: [{ ...item, result: {
      assessment: 'insufficient_evidence', recommended_action: 'manual_review', reason: 'Agreement not verified.',
      claims: [{ status: 'contradicted', explanation: 'The encryption premise is unsupported.' }],
      findings: [{ condition: 'Applicable agreement', applicability: 'applicable', condition_status: 'unknown', explanation: 'Missing evidence, not proof of absence.' }],
    } }] }
    const read = (value = v3) => decodeBusinessEvaluations({ reports: [value], automatic_model_budget: 0, execution: 'evaluation_only' })
    expect(read()[0].cases[0].result?.claims?.[0].status).toBe('contradicted')
    expect(read()[0].cases[0].result?.conditions?.[0].status).toBe('unknown')
    expect(() => read({ ...v3, cases: [{ ...v3.cases[0], result: { ...v3.cases[0].result, assessment: 'risk' } }] })).toThrow()
    const policy = { version: 'stage-conservative-v1', conforms: true, expected_action_exact_match: false }
    const diagnostics = { kind: 'author_oracle_machine_checks', human_review_required: true,
      aligned: 0, checked: 1, limitations: 'Developer fixture, not a model run.',
      cases: [{ case_id: 'business-01', oracle_alignment: false, human_review_required: true,
        expected_assessment: 'insufficient_evidence', expected_recommendation: 'hold_for_review',
        action_policy: policy,
        checks: { expected_assessment: true, expected_recommendation: false, critical_facts_referenced: true, required_sections_cited: true } }] }
    const readPolicy = (p = policy) => decodeBusinessEvaluations({ reports: [{ ...v3, diagnostics: {
      ...diagnostics, cases: [{ ...diagnostics.cases[0], action_policy: p }],
    } }], automatic_model_budget: 0, execution: 'evaluation_only' })
    expect(readPolicy()[0].diagnostics?.cases[0].action_policy?.conforms).toBe(true)
    expect(() => readPolicy({ ...policy, expected_action_exact_match: true })).toThrow()
    expect(() => readPolicy({ ...policy, version: 'unreviewed' })).toThrow()
  })
})
