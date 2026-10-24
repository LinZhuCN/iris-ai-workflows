import { eventObject } from './events'
import { decodeDeclarationRecord, irisNow } from './declarations'
import type { DeclarationRecord } from './declarations'

export type ExecutionConsent = {
  record_id: string; digest: string; decision_hash: string; task_id: string; task_hash: string
  config_hash: string; batch_id: string; acknowledge_delivery: boolean
}
export type ExecutionPlan = {
  consent: ExecutionConsent; recipe_id: string; max_records: number; recipient: string
  binding: { namespace: string; production: string; source: string; sender: string; config_hash: string }
}
export type Execution = {
  id: string; grant_hash: string; state: 'reserved' | 'running' | 'delivered' | 'reconciliation_required'
  grant: { consent: ExecutionConsent; record: DeclarationRecord; batch_id: string; created_by: string; created_at: number }
  error: string; monitoring_state: 'automatic_observer'
  receipt: null | {
    receipt_hash: string; output_hash: string; source_hash: string; config_hash: string; scope_hash: string
    batch_id: string; approval_id: string; message_id: string; receiver_message_id: string; session_id: number
    received_at: number; receiver_readback_match: true; transport: 'same-instance-BO-to-SQL'
    inspection: { field_paths: string[]; resource_counts: Record<string, number> }
    declaration_binding: { record_id: string; revision: number; declaration_digest: string; decision_hash: string; task_id: string; task_hash: string; recipe_id: string; execution_id: string; execution_hash: string }
  }
}
function text(v: unknown): string {
  if (typeof v !== 'string') throw new Error('Invalid execution text')
  return v
}
function number(v: unknown): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid execution number')
  return v
}
function hash(v: unknown): string {
  const value = text(v)
  if (!/^[a-f0-9]{64}$/.test(value)) throw new Error('Invalid execution digest')
  return value
}
function strings(v: unknown): string[] {
  if (!Array.isArray(v)) throw new Error('Invalid execution field list')
  return v.map(text)
}
export function validBatch(v: string): boolean { return /^[A-Za-z0-9-]{1,64}$/.test(v) }
function consent(v: unknown): ExecutionConsent {
  const c = eventObject(v)
  if (typeof c.acknowledge_delivery !== 'boolean' || !validBatch(text(c.batch_id))) throw new Error('Explicit bounded delivery consent required')
  return { record_id: text(c.record_id), digest: hash(c.digest), decision_hash: hash(c.decision_hash),
    task_id: text(c.task_id), task_hash: hash(c.task_hash), config_hash: hash(c.config_hash),
    batch_id: text(c.batch_id), acknowledge_delivery: c.acknowledge_delivery }
}
export function eligibleExecution(record: DeclarationRecord, now = irisNow()): boolean {
  return record.execution_state === 'ready' && record.capability.state === 'supported' &&
    record.decision?.action === 'approved' && record.review.task?.state === 'completed' &&
    record.review.task.assessment === 'no_risk_identified' && record.is_current_submission &&
    record.latest_revision === record.revision && record.proposal.validity.from <= now && record.proposal.validity.until > now
}
export function decodeExecutionPlan(v: unknown): ExecutionPlan {
  const p = eventObject(v), b = eventObject(p.binding), c = consent(p.consent)
  if (p.model_calls !== 0 || c.acknowledge_delivery || b.namespace !== 'UTILIZATION' ||
    b.production !== 'Contest.Utilization.Production' || hash(b.config_hash) !== c.config_hash ||
    p.recipe_id !== 'year-and-encounter-v1' || p.max_records !== 4 || p.recipient !== 'local-analysis-receiver') throw new Error('Unexpected executable recipe or authorization')
  return { consent: c, recipe_id: p.recipe_id, max_records: p.max_records, recipient: p.recipient,
    binding: { namespace: b.namespace, production: b.production, source: text(b.source), sender: text(b.sender), config_hash: hash(b.config_hash) } }
}
export function executionCommand(record: DeclarationRecord, plan: ExecutionPlan, confirmed: boolean): ExecutionConsent {
  const c = plan.consent
  if (!confirmed || !eligibleExecution(record) || c.record_id !== record.id || c.digest !== record.digest ||
    c.decision_hash !== record.decision?.record_hash || c.task_id !== record.review.task?.id || c.task_hash !== record.review.task.record_hash) throw new Error('Confirm the exact current approved declaration and execution plan')
  return { ...c, acknowledge_delivery: true }
}
export function decodeExecution(v: unknown): Execution {
  const e = eventObject(v), g = eventObject(e.grant), c = consent(g.consent), record = decodeDeclarationRecord(g.record)
  const state = text(e.state)
  if (!['reserved', 'running', 'delivered', 'reconciliation_required'].includes(state) ||
    e.model_calls !== 0 || e.monitoring_state !== 'automatic_observer' || !c.acknowledge_delivery ||
    c.record_id !== record.id || c.digest !== record.digest || c.task_id !== record.review.task?.id ||
    c.task_hash !== record.review.task.record_hash || c.decision_hash !== record.decision?.record_hash ||
    g.batch_id !== c.batch_id || record.decision.action !== 'approved') throw new Error('Invalid execution grant binding')
  if (state === 'delivered' ? e.receipt === null : e.receipt !== null) throw new Error('Delivery requires a verified receipt, never a fallback')
  let receipt: Execution['receipt'] = null
  if (e.receipt !== null) {
    const r = eventObject(e.receipt), link = eventObject(r.declaration_binding), i = eventObject(r.inspection)
    if (r.synthetic !== true || r.outcome !== 'delivered' || r.model_calls !== 0 || r.receiver_readback_match !== true ||
      r.transport !== 'same-instance-BO-to-SQL' || r.batch_id !== c.batch_id || r.approval_id !== e.id ||
      r.scope_hash !== e.grant_hash || r.config_hash !== c.config_hash || link.record_id !== record.id ||
      link.declaration_digest !== record.digest || link.revision !== record.revision || link.decision_hash !== c.decision_hash ||
      link.task_id !== c.task_id || link.task_hash !== c.task_hash || link.execution_id !== e.id ||
      link.execution_hash !== e.grant_hash || link.recipe_id !== record.proposal.handling.recipe_id) throw new Error('Receipt belongs to another declaration, approval or execution')
    receipt = { receipt_hash: hash(r.receipt_hash), output_hash: hash(r.output_hash), source_hash: hash(r.source_hash),
      config_hash: hash(r.config_hash), scope_hash: hash(r.scope_hash), batch_id: text(r.batch_id), approval_id: text(r.approval_id),
      message_id: text(r.message_id), receiver_message_id: text(r.receiver_message_id), session_id: number(r.session_id),
      received_at: number(r.received_at), receiver_readback_match: true, transport: r.transport,
      inspection: { field_paths: strings(i.field_paths), resource_counts: Object.fromEntries(Object.entries(eventObject(i.resource_counts)).map(([key, value]) => [key, number(value)])) },
      declaration_binding: { record_id: text(link.record_id), revision: number(link.revision), declaration_digest: hash(link.declaration_digest),
        decision_hash: hash(link.decision_hash), task_id: text(link.task_id), task_hash: hash(link.task_hash),
        recipe_id: text(link.recipe_id), execution_id: text(link.execution_id), execution_hash: hash(link.execution_hash) } }
  }
  return { id: text(e.id), grant_hash: hash(e.grant_hash),
    state: state === 'reserved' ? 'reserved' : state === 'running' ? 'running' : state === 'delivered' ? 'delivered' : 'reconciliation_required',
    grant: { consent: c, record, batch_id: text(g.batch_id), created_by: text(g.created_by), created_at: number(g.created_at) },
    error: text(e.error), monitoring_state: e.monitoring_state, receipt }
}
export function decodeExecutions(v: unknown) {
  const value = eventObject(v)
  if (value.model_calls !== 0 || !Array.isArray(value.items)) throw new Error('Execution history must be read-only')
  return { record_id: text(value.record_id), items: value.items.map(decodeExecution), next_cursor: text(value.next_cursor) }
}
