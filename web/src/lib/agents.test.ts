import { describe, expect, it } from 'vitest'
import { decodeAgent, decodeAgentJob, decodeAgentState } from './agents'

const config = {
  id: 'agent-1', revision: 1, status: 'draft', name: 'Privacy reviewer', purpose: 'Review exports',
  retrieval_query: 'HIPAA de-identification', template: 'privacy_review', table: 'Contest.HIPAAIndex7',
  index_version: 7, corpus: 'corpus-sha', model: 'deepseek-flash', config_hash: 'config-sha',
  max_iterations: 4, executor_version: 'privacy-v1',
}
const job = {
  id: 'job-1', kind: 'test', state: 'completed', config_hash: 'config-sha', model: 'deepseek-flash',
  started: 123, max_model_requests: 12, passed: true, cases: [{
    scenario: 'risk', expected: 'risk', state: 'completed', passed: true, agent_session: '7',
    source_job: 'original-report', usage: { total_tokens: 4325 },
    result: { assessment: 'risk', reason: 'Synthetic identifiers warrant review.', citations: ['evidence-0'] },
    tools: [{ tool: 'ReadPrivacyFacts', time: 124 }, { tool: 'SearchPrivacyEvidence', time: 125 }],
    evidence: [{ id: 'evidence-0', chunk_id: 'chunk-sha', text: 'Public evidence.', metadata: {
      source_url: 'https://www.hhs.gov/', source_locator: '164.514', kind: 'prepared_text',
      legal_status: 'reference', retrieval_scope: 'normative',
    } }],
  }],
}
describe('Agent API boundaries', () => {
  it('keeps legacy hash semantics and requires pinned v2 prompt provenance', () => {
    expect(decodeAgent(config).prompt_version).toBeUndefined()
    const v2 = { ...config, prompt_version: 'privacy-review-v2', prompt_hash: 'a'.repeat(64), parent_id: 'original', parent_hash: 'original-hash' }
    expect(decodeAgent(v2)).toMatchObject({ prompt_version: 'privacy-review-v2', parent_id: 'original' })
    expect(() => decodeAgent({ ...v2, prompt_hash: '' })).toThrow()
    expect(() => decodeAgent({ ...v2, prompt_version: 'arbitrary' })).toThrow()
    expect(() => decodeAgent({ ...config, prompt_hash: 'a'.repeat(64) })).toThrow()
  })
  it('accepts numeric index versions and retains pinned provenance', () => {
    expect(decodeAgent(config)).toMatchObject({ index_version: '7', config_hash: 'config-sha', max_iterations: 4 })
  })
  it('rejects unsupported tools/templates and changed executor limits', () => {
    expect(() => decodeAgent({ ...config, template: 'arbitrary' })).toThrow()
    expect(() => decodeAgent({ ...config, max_iterations: 100 })).toThrow()
    expect(() => decodeAgent({ ...config, status: 'active' })).toThrow()
  })
  it('preserves real test evidence, tools, usage and retained-case origin', () => {
    expect(decodeAgentJob(job).cases?.[0]).toMatchObject({
      source_job: 'original-report', agent_session: '7', usage: { total_tokens: 4325 },
      result: { citations: ['evidence-0'] },
    })
  })
  it('rejects success-shaped test bodies without results or pass status', () => {
    expect(() => decodeAgentJob({ ...job, passed: undefined })).toThrow()
    expect(() => decodeAgentJob({ ...job, cases: [{ ...job.cases[0], result: undefined }] })).toThrow()
    expect(() => decodeAgentJob({ ...job, cases: [{ ...job.cases[0], result: { ...job.cases[0].result, assessment: 'deliver' } }] })).toThrow()
  })
  it('keeps rejected output as failure, not an accepted result', () => {
    const failed = decodeAgentJob({ ...job, passed: false, cases: [{
      scenario: 'insufficient_evidence', expected: 'insufficient_evidence', state: 'failed',
      passed: false, error: 'Contract rejected', rejected_output: '{"action":"deliver"}', tools: [],
    }] })
    expect(failed.cases?.[0].rejected_output).toBe('{"action":"deliver"}')
    expect(failed.cases?.[0].result).toBeUndefined()
  })
  it('distinguishes an intent binding from active observation execution', () => {
    const state = decodeAgentState({ agents: [config], jobs: [job], user: 'builder', can_write: 1,
      binding: { agent_id: 'agent-1', config_hash: 'config-sha', snapshot_id: 'snapshot-1',
        snapshot_hash: 'snapshot-sha', scenario: 'analytics', enabled: true, execution: 'not_connected_until_P5' } })
    expect(state.binding?.execution).toBe('not_connected_until_P5')
    expect(() => decodeAgentState({ agents: [], jobs: [], user: 'viewer', can_write: 'yes', binding: '' })).toThrow()
  })
})
