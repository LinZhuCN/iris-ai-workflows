import { describe, expect, it } from 'vitest'
import { decodeEventDetail, decodeEvents, decodeLiveEvent, decodeReview, investigationBlockReason } from './events'

const event = { id: 'event-1', observation_id: 'demo-1', category: 'coverage_gap', detector: 'budget',
  title: 'Review awaits budget', detail: 'Not a privacy verdict.', state: 'open', revision: 1,
  created: 123, actions: [], opinions: [{ id: 'opinion-1', text: 'Hold analytics', actor: 'builder', time: 124, summary_state: 'not_requested' }] }
describe('Live operations boundaries', () => {
  it('explains why investigation is unavailable even after cost consent', () => {
    expect(investigationBlockReason(true, { schema: 2, scenario: 'failure' })).toContain('failure')
    expect(investigationBlockReason(true, { schema: 2, scenario: 'failure' })).toContain('not supported')
    expect(investigationBlockReason(true, { schema: 1, scenario: 'analytics' })).toContain('schema 2')
    expect(investigationBlockReason(false, { schema: 2, scenario: 'analytics' })).toContain('permission')
    expect(investigationBlockReason(true, { schema: 2, scenario: 'analytics' })).toBe('')
  })
  it('preserves human opinion without inventing an AI summary', () => {
    expect(decodeLiveEvent(event).opinions[0].summary_state).toBe('not_requested')
    expect(() => decodeLiveEvent({ ...event, state: 'automatically_resolved' })).toThrow()
  })
  it('does not label blocked budget as a completed review', () => {
    expect(decodeReview({ id: 'task-1', observation_id: 'demo-1', state: 'blocked_budget', origin: 'source_sample' }).analysis).toBeUndefined()
    expect(() => decodeReview({ id: 'task-1', observation_id: 'demo-1', state: 'success', origin: 'source_sample' })).toThrow()
  })
  it('rejects observations outside the isolated synthetic scope', () => {
    expect(() => decodeEventDetail({ event, observation: { synthetic: false, namespace: 'DEMO' } })).toThrow()
    expect(() => decodeEventDetail({ event, observation: { synthetic: true, namespace: 'USER' } })).toThrow()
    expect(decodeEventDetail({ event, observation: { synthetic: true, namespace: 'DEMO', schema: 2 } }).event.id).toBe('event-1')
  })
  it('requires real numeric coverage and explicit permissions', () => {
    const value = { events: [event], reviews: [], counts: { observed: 1 }, can_write: 1, user: 'builder', automatic_model_budget: 0 }
    expect(decodeEvents(value).automatic_model_budget).toBe(0)
    expect(() => decodeEvents({ ...value, counts: { observed: '1' } })).toThrow()
    expect(() => decodeEvents({ ...value, can_write: 'yes' })).toThrow()
  })
})
