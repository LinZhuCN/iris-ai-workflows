import { eventObject } from './events'
import type { ReviewResult } from './route-reviews'

export type MonitorConsent = {
  id: string; evidence_hash: string; receipt_hash: string; agent_id: string; source_revision: number
  config_hash: string; contract_hash: string; max_model_requests: 2; acknowledge_cost: boolean
}
export type DeclarationMonitor = {
  id: string; state: string; heartbeat: number; observer_error: string; error: string
  reserved_requests: number; attempted_requests: number; authorized_requests: number; receipt_hash?: string; evidence_hash?: string
  evidence?: { record_id: string; revision: number; decision_hash: string; task_hash: string; batch_id: string; limits: string }
  event: { state: string; revision: number; actions: { actor: string; time: number; text: string; before: string; after: string }[] }
  result: ReviewResult | null
  report?: { id: string; model: string; contract: string; phases: { phase: string; state: string; session: string; raw: string; usage: string }[]
    sources: { question: string; id: string; locator: string; version: string; text: string; verified: boolean }[] }
}
const object = eventObject
function text(v: unknown) { if (typeof v !== 'string') throw new Error('Invalid monitoring text'); return v }
function num(v: unknown) { if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid monitoring number'); return v }
function hash(v: unknown) { const s = text(v); if (!/^[a-f0-9]{64}$/.test(s)) throw new Error('Invalid monitoring hash'); return s }
function array<T>(v: unknown, fn: (v: unknown) => T): T[] { if (!Array.isArray(v)) throw new Error('Invalid monitoring list'); return v.map(fn) }
export function decodeMonitorPlan(v: unknown) {
  const p = object(v), c = object(p.consent)
  if (p.model_calls !== 0 || c.max_model_requests !== 2 || c.acknowledge_cost !== false) throw new Error('Plan cannot authorize monitoring')
  const consent: MonitorConsent = { id: text(c.id), evidence_hash: hash(c.evidence_hash), receipt_hash: hash(c.receipt_hash),
    agent_id: text(c.agent_id), source_revision: num(c.source_revision), config_hash: hash(c.config_hash),
    contract_hash: hash(c.contract_hash), max_model_requests: 2, acknowledge_cost: false }
  return { consent, model: text(p.model) }
}
export function decodeDeclarationMonitor(v: unknown): DeclarationMonitor {
  const m = object(v), e = object(m.event), evidence = m.evidence === undefined ? undefined : object(m.evidence)
  const state = text(m.state)
  if (m.origin !== 'automatic_after_send' || !['blocked_budget', 'running', 'completed', 'failed', 'interrupted', 'evidence_failed'].includes(state) ||
    !['open', 'in_review', 'needs_information', 'resolved', 'ignored'].includes(text(e.state)) ||
    (state === 'completed' ? m.result === null : m.result !== null)) throw new Error('Invalid automatic monitor state')
  let report: DeclarationMonitor['report']
  if (m.report !== undefined) {
    const r = object(m.report), s = object(r.source), auth = object(r.authorization)
    if (r.version !== 'staged-risk-v4' || r.id !== m.report_id || auth.request_key !== `monitor-${text(m.id)}`) throw new Error('Monitoring report task mismatch')
    report = { id: text(r.id), model: text(s.model), contract: hash(auth.contract_hash),
      phases: array(r.phases, value => {
        const p = object(value)
        return { phase: text(p.phase), state: text(p.state), session: text(p.agent_session),
          raw: p.raw === undefined ? '' : text(p.raw), usage: p.sdk_stats === undefined ? 'Usage not recorded' : JSON.stringify(object(p.sdk_stats)) }
      }), sources: r.packages === undefined ? [] : array(r.packages, value => {
        const p = object(value)
        return array(p.evidence, value => {
          const h = object(value), meta = object(h.metadata)
          return { question: text(p.question_id), id: text(h.id), text: text(h.text), locator: text(meta.source_locator),
            version: text(meta.source_version), verified: h.source_hash_verified === true || h.source_hash_verified === 1 }
        })
      }).flat() }
  }
  let result: ReviewResult | null = null
  if (state === 'completed') {
    const r = object(m.result), summary = object(r.summary)
    if (typeof summary.risk_detected !== 'boolean' || typeof summary.unresolved !== 'boolean' || !report ||
      summary.execution !== 'not_executed' || summary.recommended_action !== 'manual_review') throw new Error('Completed review requires actual non-executing report and summary')
    result = { summary: { risk_detected: summary.risk_detected, unresolved: summary.unresolved },
      missing_information: array(r.missing_information, text), issues: array(r.issues, value => {
        const i = object(value)
        if (!['risk_signal', 'no_signal_on_checked_issue', 'unresolved'].includes(text(i.status))) throw new Error('Invalid observed issue')
        const applicability = text(i.applicability), condition_status = text(i.condition_status), exceptions = object(i.exceptions)
        if (!['applicable', 'not_applicable', 'unknown'].includes(applicability) ||
          !['met', 'not_met', 'unknown', 'not_applicable'].includes(condition_status) ||
          !['resolved', 'unresolved'].includes(text(exceptions.status))) throw new Error('Invalid observed condition chain')
        return { question_id: text(i.question_id), status: text(i.status), explanation: text(i.explanation), fact_ids: array(i.fact_ids, text),
          applicability, condition_status, applicability_fact_ids: array(i.applicability_fact_ids, text),
          affirmative_fact_ids: array(i.affirmative_fact_ids, text), exceptions: { status: text(exceptions.status), explanation: text(exceptions.explanation) },
          citations: array(i.citations, value => {
            const c = object(value), source = report?.sources.find(s => s.question === i.question_id && s.id === c.evidence_id)
            if (!source?.verified || Array.from(source.text).slice(num(c.start), num(c.end)).join('') !== c.quote) throw new Error('Observed citation does not match source')
            return { evidence_id: text(c.evidence_id), passage_id: text(c.passage_id), quote: text(c.quote) }
          }) }
      }) }
    if (!result.issues.length || result.summary.risk_detected !== result.issues.some(i => i.status === 'risk_signal') ||
      result.summary.unresolved !== (result.missing_information.length > 0 || result.issues.some(i => i.status === 'unresolved'))) {
      throw new Error('Monitoring aggregate contradicts actual issues')
    }
  }
  return { id: text(m.id), state, heartbeat: num(m.heartbeat), observer_error: text(m.observer_error), error: text(m.error),
    reserved_requests: num(m.reserved_requests), attempted_requests: num(m.attempted_requests), authorized_requests: num(m.authorized_requests),
    receipt_hash: m.receipt_hash === undefined ? undefined : hash(m.receipt_hash), evidence_hash: m.evidence_hash === undefined ? undefined : hash(m.evidence_hash),
    evidence: evidence ? { record_id: text(evidence.record_id), revision: num(evidence.revision), decision_hash: hash(evidence.decision_hash),
      task_hash: hash(evidence.task_hash), batch_id: text(evidence.batch_id), limits: text(evidence.limits) } : undefined,
    result, report, event: { state: text(e.state), revision: num(e.revision), actions: array(e.actions, value => {
      const a = object(value)
      return { actor: text(a.actor), time: num(a.time), text: text(a.text), before: text(a.before), after: text(a.after) }
    }) } }
}
