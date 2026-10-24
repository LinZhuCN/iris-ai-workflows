import { describe, expect, it } from 'vitest'
import { decodeRouteReviewDetail, decodeRouteReviews } from './route-reviews'

const item = { id: 'utilization-batch', route_kind: 'utilization', batch_id: 'batch', state: 'blocked_budget',
  created: 1, reserved_model_requests: 0, event: { state: 'open', revision: 1, category: 'coverage_gap', actions: [] },
  origin: 'automatic_after_send', execution: 'not_executed' }
const state = { items: [item], next_cursor: '', enabled: 1, heartbeat: 1, observer_identity: 'worker',
  error: '', execution: 'not_executed', automatic_new_batch_budget: 0, authorizations: {} }

describe('automatic route monitoring contracts', () => {
  it('keeps unfunded observations visible without inventing a verdict', () => {
    expect(decodeRouteReviews(state).items[0].state).toBe('blocked_budget')
    expect(decodeRouteReviewDetail(item).result).toBeUndefined()
  })
  it('rejects technical failures with semantic results', () => {
    expect(() => decodeRouteReviewDetail({ ...item, state: 'failed', result: {} })).toThrow()
  })
  it('requires accepted after-send manual review, never hold or execute', () => {
    const result = { summary: { execution: 'not_executed', recommended_action: 'manual_review', risk_detected: false, unresolved: true },
      issues: [], missing_information: ['Unknown applicability'], human_review_required: true }
    expect(decodeRouteReviewDetail({ ...item, state: 'completed', result }).state).toBe('completed')
    expect(() => decodeRouteReviewDetail({ ...item, state: 'completed', result: { ...result,
      summary: { execution: 'not_executed', recommended_action: 'hold_for_review' } } })).toThrow()
  })
  it('rejects implicit budgets and unversioned human states', () => {
    expect(() => decodeRouteReviews({ ...state, automatic_new_batch_budget: 100 })).toThrow()
    expect(() => decodeRouteReviewDetail({ ...item, event: { ...item.event, revision: 0 } })).toThrow()
  })
  it('never renders a V4 risk with unknown applicability as accepted', () => {
    const result = { summary: { execution: 'not_executed', recommended_action: 'manual_review', risk_detected: true, unresolved: true },
      issues: [{ question_id: 'q1', status: 'risk_signal', explanation: 'Unknown basis', fact_ids: ['a'],
        citations: [], applicability: 'unknown', condition_status: 'unknown', affirmative_fact_ids: [],
        applicability_fact_ids: [], exceptions: { status: 'unresolved', explanation: 'Unknown basis' } }],
      missing_information: ['Basis'], human_review_required: true }
    expect(() => decodeRouteReviewDetail({ ...item, state: 'completed', runtime_version: 'staged-risk-v4', result })).toThrow()
  })
})
