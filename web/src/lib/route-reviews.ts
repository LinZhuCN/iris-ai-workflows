import { eventObject } from './events'
import { decodeRouteScenario } from './governance'
import type { RouteScenario } from './governance'

export type ReviewEvent = { state: string; revision: number; category: string; actions: Record<string, unknown>[] }
export type RouteReview = {
  id: string; route_kind: string; batch_id: string; record_id?: string; state: string; created: number
  event: ReviewEvent; reserved_model_requests: number; actual_model_requests?: number; error?: string
  authorization_id?: string; runtime_version?: string; trigger?: string; parent_review_id?: string
}
export type RouteReviewState = {
  items: RouteReview[]; next_cursor: string; enabled: number; heartbeat: number
  observer_identity: string; error: string; automatic_new_batch_budget: 0
  authorizations: Record<string, { authorized_requests: number; reserved_requests: number }>
}
export type ReviewResult = {
  issues: { question_id: string; status: string; explanation: string; fact_ids: string[]
    citations: { evidence_id: string; passage_id: string; quote: string }[]
    applicability?: string; applicability_fact_ids?: string[]; condition_status?: string; affirmative_fact_ids?: string[]
    exceptions?: { status: string; explanation: string } }[]
  missing_information: string[]
  summary: { risk_detected: boolean; unresolved: boolean }
}
export type RouteReviewDetail = RouteReview & {
  scenario?: RouteScenario
  evidence?: Record<string, unknown>; result?: ReviewResult; phases?: Record<string, unknown>[]
  pin_basis?: string; report_id?: string; current_admission?: Record<string, unknown>
  failure?: Record<string, unknown>; sources?: Record<string, unknown>[]
}
const states = ['blocked_budget', 'running', 'completed', 'failed', 'interrupted', 'evidence_failed']
const eventStates = ['open', 'in_review', 'needs_information', 'resolved', 'ignored']
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid route review text')
  return value
}
function number(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('Invalid route review number')
  return value
}
function objects(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) throw new Error('Invalid review object list')
  return value.map(eventObject)
}
function strings(value: unknown): string[] {
  if (!Array.isArray(value)) throw new Error('Invalid review text list')
  return value.map(text)
}
export function decodeRouteReview(value: unknown): RouteReview {
  const r = eventObject(value), e = eventObject(r.event)
  if (!states.includes(text(r.state)) || !eventStates.includes(text(e.state)) || !Array.isArray(e.actions) ||
    !Number.isInteger(number(e.revision)) || number(e.revision) < 1) throw new Error('Invalid review/event state')
  return {
    id: text(r.id), route_kind: text(r.route_kind), batch_id: text(r.batch_id),
    record_id: r.record_id === undefined ? undefined : text(r.record_id), state: text(r.state), created: number(r.created),
    reserved_model_requests: number(r.reserved_model_requests),
    actual_model_requests: r.actual_model_requests === undefined ? undefined : number(r.actual_model_requests),
    error: r.error === undefined ? undefined : text(r.error),
    authorization_id: r.authorization_id === undefined ? undefined : text(r.authorization_id),
    runtime_version: r.runtime_version === undefined ? undefined : text(r.runtime_version),
    trigger: r.trigger === undefined ? undefined : text(r.trigger),
    parent_review_id: r.parent_review_id === undefined ? undefined : text(r.parent_review_id),
    event: { state: text(e.state), revision: number(e.revision), category: text(e.category), actions: e.actions.map(eventObject) },
  }
}
export function decodeRouteReviews(value: unknown): RouteReviewState {
  const s = eventObject(value)
  if (!Array.isArray(s.items) || (s.enabled !== 0 && s.enabled !== 1) ||
    s.execution !== 'not_executed' || s.automatic_new_batch_budget !== 0) throw new Error('Invalid automatic review contract')
  return { items: s.items.map(decodeRouteReview), next_cursor: text(s.next_cursor), enabled: s.enabled,
    heartbeat: number(s.heartbeat), observer_identity: text(s.observer_identity), error: text(s.error), automatic_new_batch_budget: 0,
    authorizations: Object.fromEntries(Object.entries(eventObject(s.authorizations)).map(([id, v]) => {
      const grant = eventObject(v)
      return [id, { authorized_requests: number(grant.authorized_requests), reserved_requests: number(grant.reserved_requests) }]
    })) }
}
export function decodeRouteReviewDetail(value: unknown): RouteReviewDetail {
  const v = eventObject(value), base = decodeRouteReview(v)
  const evidence = v.evidence === undefined ? undefined : eventObject(v.evidence)
  const approved = evidence?.approved === undefined ? undefined : eventObject(evidence.approved)
  const scenario = approved?.scenario === undefined ? undefined : decodeRouteScenario(approved.scenario)
  let decodedResult: ReviewResult | undefined
  if (v.execution !== 'not_executed' || v.origin !== 'automatic_after_send') throw new Error('Unexpected review execution/origin')
  if (base.state === 'completed') {
    const result = eventObject(v.result), summary = eventObject(result.summary)
    if (summary.execution !== 'not_executed' || summary.recommended_action !== 'manual_review' ||
      result.human_review_required !== true || typeof summary.risk_detected !== 'boolean' ||
      typeof summary.unresolved !== 'boolean') throw new Error('After-send review cannot execute/hold delivery')
    decodedResult = { summary: { risk_detected: summary.risk_detected, unresolved: summary.unresolved },
      missing_information: strings(result.missing_information), issues: objects(result.issues).map(issue => {
        const status = text(issue.status)
        if (!['risk_signal', 'unresolved', 'no_signal_on_checked_issue'].includes(status)) throw new Error('Invalid scoped issue status')
        return { question_id: text(issue.question_id), status, explanation: text(issue.explanation),
          fact_ids: strings(issue.fact_ids), citations: objects(issue.citations).map(citation => ({
            evidence_id: text(citation.evidence_id), passage_id: text(citation.passage_id), quote: text(citation.quote),
          })),
          ...(base.runtime_version === 'staged-risk-v4' ? conditionChain(issue) : {}),
        }
      }) }
  } else if (v.result !== undefined) throw new Error('Technical or budget failure cannot contain a verdict')
  return { ...base,
    evidence, scenario,
    result: decodedResult,
    phases: v.phases === undefined ? undefined : objects(v.phases),
    pin_basis: v.pin_basis === undefined ? undefined : text(v.pin_basis),
    report_id: v.report_id === undefined ? undefined : text(v.report_id),
    current_admission: v.current_admission === undefined ? undefined : eventObject(v.current_admission),
    failure: v.failure === undefined ? undefined : eventObject(v.failure),
    sources: v.sources === undefined ? undefined : objects(v.sources),
  }

  function conditionChain(issue: Record<string, unknown>) {
    const applicability = text(issue.applicability), condition_status = text(issue.condition_status), exceptions = eventObject(issue.exceptions)
    const applicability_fact_ids = strings(issue.applicability_fact_ids), affirmative_fact_ids = strings(issue.affirmative_fact_ids)
    if (!['applicable', 'not_applicable', 'unknown'].includes(applicability) ||
      !['met', 'not_met', 'unknown', 'not_applicable'].includes(condition_status) ||
      !['resolved', 'unresolved'].includes(text(exceptions.status))) throw new Error('Invalid V4 applicability/condition chain')
    if (issue.status === 'risk_signal' && (applicability !== 'applicable' || condition_status !== 'not_met' ||
      affirmative_fact_ids.length === 0 || applicability_fact_ids.length === 0 || exceptions.status !== 'resolved')) throw new Error('Risk cannot be inferred from missing applicability/evidence')
    if (issue.status === 'unresolved' && (condition_status !== 'unknown' || applicability === 'not_applicable' ||
      affirmative_fact_ids.length !== 0)) throw new Error('Unresolved issue cannot assert an affirmative condition finding')
    if (issue.status === 'no_signal_on_checked_issue' && (exceptions.status !== 'resolved' ||
      applicability_fact_ids.length === 0 || !((applicability === 'applicable' && condition_status === 'met' && affirmative_fact_ids.length > 0) ||
      (applicability === 'not_applicable' && condition_status === 'not_applicable' && affirmative_fact_ids.length === 0)))) throw new Error('No-signal cannot hide unknown conditions')
    return { applicability, condition_status, applicability_fact_ids, affirmative_fact_ids,
      exceptions: { status: text(exceptions.status), explanation: text(exceptions.explanation) } }
  }
}
