import { describe, expect, it } from 'vitest'
import { decodeDeployment, decodeInstances, decodeMonitor, decodePipelineSummary } from './monitor'

describe('Live monitor response boundaries', () => {
  it('rejects missing collections instead of displaying fixture data', () => {
    expect(() => decodeMonitor({})).toThrow()
  })
  it('rejects an unregistered Connector identity', () => {
    expect(() => decodeInstances({ instance: { instance_id: 'other' } })).toThrow('Unregistered instance')
  })
  it('rejects success-shaped unknown deployment states', () => {
    expect(() => decodeDeployment({ state: 'probably-success' })).toThrow('Unknown deployment state')
  })
  it('decodes an empty but live platform without inventing a pipeline', () => {
    const result = decodeMonitor({ snapshot: '', deployment: '', observations: [], received: 0, can_deploy: 0, receiver_paused: 0, consumer_age_seconds: 1,
      transport: { pending: 0, retrying: 0, dropped: 0, seen: 0, not_monitored: 0, last_error: '', heartbeat: '', source_state: 'live' } })
    expect(result.snapshot).toBeUndefined()
    expect(result.deployment).toBeUndefined()
    expect(result.observations).toEqual([])
    expect(result.can_deploy).toBe(false)
  })
  it('does not accept a completed AI summary without evidence or a real kind', () => {
    expect(() => decodePipelineSummary({ state: 'completed', kind: 'ai-hub-agent' })).toThrow('missing its result')
    expect(() => decodePipelineSummary({ state: 'completed', kind: 'fixture' })).toThrow('not an AI Hub result')
  })
  it('preserves snapshot-bound AI provenance and limitations', () => {
    const summary = decodePipelineSummary({ id: 'summary-1', snapshot_id: 'snapshot-1', config_hash: 'hash',
      state: 'completed', model: 'verified-model', kind: 'ai-hub-agent', agent_session: 'session-1',
      usage: { total_tokens: 100 }, result: { summary: 'A synthetic pipeline.', limitations: ['Not live-health proof.'] } })
    expect(summary.snapshot_id).toBe('snapshot-1')
    expect(summary.usage?.total_tokens).toBe(100)
    expect(summary.result?.limitations).toEqual(['Not live-health proof.'])
  })
})
