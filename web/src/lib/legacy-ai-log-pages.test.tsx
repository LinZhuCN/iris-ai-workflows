import { afterEach, describe, expect, it, vi } from 'vitest'
import { renderToStaticMarkup } from 'react-dom/server'
import { LiveAgentPage, matchingAgentExecution } from '../agent-page'
import { LiveMonitorPage, matchingSnapshotSummary } from '../monitor-page'
import { LiveOperationsPage, matchingInvestigationExecution, persistedInvestigationExecution } from '../operations-page'
import type { AgentConfig, AgentJob } from './agents'
import type { PipelineSummary, Snapshot } from './monitor'
import type { Review } from './events'

vi.mock('../auth', () => ({ useAuth: () => ({ authorization: 'Basic test-only' }) }))
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals() })

describe('legacy AI log exact execution mapping', () => {
  const config = { id: 'agent-unit', revision: 2, config_hash: 'exact-hash' } as AgentConfig
  const job: AgentJob = { id: 'job-unit', kind: 'test', state: 'queued', config_hash: 'exact-hash',
    agent_id: 'agent-unit', model: 'unit', started: 100, max_model_requests: 12 }
  it('selects tests for the exact Agent identity/hash, including queued and failed records', () => {
    expect(matchingAgentExecution([job], config)).toBe(job)
    expect(matchingAgentExecution([{ ...job, state: 'failed', error: 'Provider failed' }], config)?.error).toBe('Provider failed')
    expect(matchingAgentExecution([job], { ...config, config_hash: 'other-revision' })).toBeUndefined()
    expect(matchingAgentExecution([{ ...job, agent_id: 'other-agent' }], config)).toBeUndefined()
    expect(matchingAgentExecution([{ ...job, kind: 'generate' }], config)).toBeUndefined()
    expect(matchingAgentExecution([job])).toBeUndefined()
  })
  it('rejects summaries for a different immutable discovery snapshot or hash', () => {
    const snapshot = { id: 'snapshot-unit', config_hash: 'snapshot-hash' } as Snapshot
    const summary = { id: 'summary-unit', snapshot_id: snapshot.id, config_hash: snapshot.config_hash,
      state: 'running', model: 'unit' } as PipelineSummary
    expect(matchingSnapshotSummary(snapshot, summary)).toBe(summary)
    expect(matchingSnapshotSummary({ ...snapshot, id: 'new-snapshot' }, summary)).toBeUndefined()
    expect(matchingSnapshotSummary({ ...snapshot, config_hash: 'new-hash' }, summary)).toBeUndefined()
    expect(matchingSnapshotSummary(snapshot)).toBeUndefined()
  })
  it('ties investigation logs to the exact user-selected event revision and Agent, then refreshes only that saved ID', () => {
    const review: Review = { id: 'review-unit', observation_id: 'obs-unit', event_id: 'event-unit',
      state: 'queued', origin: 'investigation' }
    const key = 'event-unit:2:agent-unit'
    const saved = { key, review }
    const finished = { ...review, state: 'failed', error: 'Actual saved error' }
    expect(matchingInvestigationExecution(saved, key, [finished])).toBe(finished)
    expect(matchingInvestigationExecution(saved, key, [])).toBe(review)
    expect(matchingInvestigationExecution(saved, 'event-unit:3:agent-unit', [finished])).toBeUndefined()
    expect(matchingInvestigationExecution(saved, 'event-unit:2:another-agent', [finished])).toBeUndefined()
    expect(matchingInvestigationExecution(undefined, key, [finished])).toBeUndefined()
  })
  it('does not execute models or fetch logs merely by rendering the pages', () => {
    vi.stubGlobal('location', { search: '' })
    const fetch = vi.spyOn(globalThis, 'fetch')
    renderToStaticMarkup(<LiveAgentPage />)
    renderToStaticMarkup(<LiveMonitorPage path="/demo" />)
    renderToStaticMarkup(<LiveOperationsPage path="/events/event-unit" />)
    expect(fetch).not.toHaveBeenCalled()
  })
  it('reopens only investigations with the saved event and exact pinned Agent ID, revision and hash', () => {
    const review = { id: 'saved-review', event_id: 'event-unit', observation_id: 'obs-unit', state: 'completed',
      origin: 'manual_investigation', saved: { config: { id: config.id, revision: config.revision }, config_hash: config.config_hash,
        analysis: { result: { reason: 'Actual saved model response' } } } }
    expect(persistedInvestigationExecution([review], 'event-unit', config)).toBe(review)
    expect(persistedInvestigationExecution([review], 'another-event', config)).toBeUndefined()
    expect(persistedInvestigationExecution([review], 'event-unit', { ...config, revision: 3 })).toBeUndefined()
    expect(persistedInvestigationExecution([review], 'event-unit', { ...config, config_hash: 'changed' })).toBeUndefined()
    const missingIdentity = { ...review, saved: {} }
    expect(persistedInvestigationExecution([missingIdentity], 'event-unit', config)).toBeUndefined()
  })
})
