import { eventObject as object } from './events'
import { decodeJson, decodeOrganizationProfile, decodeProfileRecord, type Json } from './multi-organization'
import { decodeReviewPlan } from './production-observation'

export const m5Scope = { namespace: 'M5OBSERVATION', production: 'Contest.M5.Production' } as const
function invalid(): never { throw new Error('Invalid fixed M5 demo response') }
function text(v: unknown): string { return typeof v === 'string' ? v : invalid() }
function nonempty(v: unknown): string { const s = text(v); return s.trim() ? s : invalid() }
function hash(v: unknown): string { const s = text(v); return /^[a-f0-9]{64}$/.test(s) ? s : invalid() }
function flag(v: unknown): boolean { return v === true || v === 1 ? true : v === false || v === 0 ? false : invalid() }
function list<T>(v: unknown, decode: (v: unknown) => T): T[] { return Array.isArray(v) ? v.map(decode) : invalid() }
function unique<T extends { id: string }>(values: T[]): T[] {
  return new Set(values.map(v => v.id)).size === values.length ? values : invalid()
}
function scoped<T extends { id: string }>(value: T): T {
  return ['hospital', 'research'].includes(value.id) ? value : invalid()
}
export function decodeM5Run(v: unknown) {
  const r = object(v), profiles = object(r.profiles)
  const hospital = decodeProfileRecord(profiles.hospital), research = decodeProfileRecord(profiles.research)
  if (hospital.id !== 'hospital' || research.id !== 'research' || Object.keys(profiles).length !== 2 ||
    typeof r.created_at !== 'number' || !Number.isFinite(r.created_at) || r.created_at < 0) invalid()
  const id = nonempty(r.id)
  if (!/^m5-demo-[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/.test(id)) invalid()
  return { id, state: nonempty(r.state), created_at: r.created_at,
    profiles: { hospital, research }, message_id: text(r.message_id), session_id: text(r.session_id), header_id: text(r.header_id),
    ...(r.receipt === undefined ? {} : { receipt: decodeJson(r.receipt) }),
    ...(r.evidence === undefined ? {} : { evidence: decodeJson(r.evidence) }),
    ...(r.error === undefined ? {} : { error: text(r.error) }),
    ...(r.authorization === undefined ? {} : { authorization: decodeJson(r.authorization) }),
    ...(r.review_header_id === undefined ? {} : { review_header_id: text(r.review_header_id) }),
    ...(r.review === undefined ? {} : { review: decodeJson(r.review) }),
    ...(r.report === undefined || r.report === '' ? {} : { report: decodeJson(r.report) }) }
}
export type M5Run = ReturnType<typeof decodeM5Run>
export function decodeM5Status(v: unknown) {
  const s = object(v), production_id = text(s.production_id), config_hash = hash(s.config_hash)
  if (s.namespace !== m5Scope.namespace || s.production !== m5Scope.production ||
    !/^production-[a-f0-9]{64}$/.test(production_id)) invalid()
  const plan = s.plan === undefined ? undefined : decodeReviewPlan(s.plan)
  if (plan && (plan.production_id !== production_id || plan.config_hash !== config_hash)) invalid()
  return { ...m5Scope, production_id, config_hash, can_manage: flag(s.can_manage), enrolled: flag(s.enrolled),
    inspection_enabled: flag(s.inspection_enabled),
    profiles: unique(list(s.profiles, value => scoped(decodeProfileRecord(value)))),
    presets: unique(list(s.presets, value => scoped(decodeOrganizationProfile(value)))),
    runs: unique(list(s.runs, decodeM5Run)), plan }
}
export type M5Status = ReturnType<typeof decodeM5Status>
export function jsonObject(v: Json | undefined): { [key: string]: Json } | undefined {
  return v !== null && typeof v === 'object' && !Array.isArray(v) ? v : undefined
}
export function m5AuditRecorded(run: M5Run): boolean {
  const review = jsonObject(run.review)
  return run.authorization != null || run.report != null || !!review?.authorization_id ||
    ['running', 'completed', 'failed', 'interrupted'].includes(String(review?.state))
}
export function m5Capture(run: M5Run) {
  const evidence = jsonObject(run.evidence), capture = jsonObject(evidence?.capture), header = jsonObject(evidence?.header)
  return { captured: capture?.state === 'captured', state: typeof capture?.state === 'string' ? capture.state : 'Waiting for collector',
    reason: typeof capture?.reason === 'string' ? capture.reason : '', header, facts: capture?.facts }
}
export type M5AuditRequest = {
  run_id: string; authorization_id: string; agent_id: string; source_revision: number
  agent_config_hash: string; contract_hash: string; config_hash: string; acknowledge_cost: true
}
export function m5SavedAuditRequest(run: M5Run): M5AuditRequest | undefined {
  const a = jsonObject(run.authorization)
  if (!a) return undefined
  try {
    if (typeof a.source_revision !== 'number' || !Number.isSafeInteger(a.source_revision) || a.source_revision < 1 ||
      a.acknowledge_cost !== true) return undefined
    return { run_id: run.id, authorization_id: nonempty(a.authorization_id), agent_id: nonempty(a.agent_id),
      source_revision: a.source_revision, agent_config_hash: hash(a.agent_config_hash),
      contract_hash: hash(a.contract_hash), config_hash: hash(a.config_hash), acknowledge_cost: true }
  } catch { return undefined }
}
export function m5CanReconcileAudit(run: M5Run): boolean {
  const review = jsonObject(run.review)
  return run.report == null && !review?.authorization_id &&
    (!review || ['not_authorized', 'pending_observer', 'pending', 'blocked_budget'].includes(String(review.state)))
}
export function m5PublishedAgents(plan: M5Status['plan']) {
  return plan?.agents.filter(agent => agent.status === 'published') ?? []
}
export function m5AuditLog(run?: M5Run): Json | undefined {
  return run?.report ?? (run?.authorization == null ? undefined : {
    state: 'Authorization recorded; awaiting saved execution', authorization: run.authorization,
  })
}
export function m5Result(run: M5Run) {
  const review = jsonObject(run.review), report = jsonObject(run.report), result = jsonObject(report?.result)
  const issues = Array.isArray(result?.issues) ? result.issues.map(jsonObject).filter(v => v !== undefined) : []
  const labels: Record<string, string> = { risk_identified: 'Potential risk identified',
    information_required: 'More information needed', no_signal_on_checked_issues: 'No signal on checked issues' }
  const assessment = typeof result?.assessment === 'string' ? result.assessment : ''
  const completed = review?.state === 'completed' && report?.state === 'completed'
  const label = completed ? labels[assessment] ?? 'Not assessed' : 'Not assessed'
  const reason = issues.find(i => i.status === 'risk_signal')?.explanation ?? issues[0]?.explanation
  const missing = Array.isArray(result?.missing_information)
    ? result.missing_information.filter((v): v is string => typeof v === 'string') : []
  return { label, state: typeof review?.state === 'string' ? review.state : 'Not authorized',
    reason: completed && typeof reason === 'string' ? reason : typeof review?.error === 'string' && review.error
      ? review.error : typeof review?.reason === 'string' && review.reason ? review.reason : 'No completed AI conclusion is available.',
    missing, unresolved: jsonObject(result?.summary)?.unresolved === true }
}
