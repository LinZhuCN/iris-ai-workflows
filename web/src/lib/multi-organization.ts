export const organizationIds = ['hospital', 'quality', 'research', 'clinic'] as const
export type OrganizationId = typeof organizationIds[number]
export type Relationship = 'same_covered_entity' | 'another_provider' | 'external'
export type OrganizationProfile = {
  id: OrganizationId; name: string; partner: string; type: string; parent_id: string
  responsibilities: string; purpose: string; relationship: Relationship
  allowed_fields: string[]; prohibited_fields: string[]; requirements: string
}
export type ProfileRecord = {
  id: OrganizationId; revision: number; profile: OrganizationProfile
  confirmed_by: string; confirmed_at: string | number; hash: string
}
export type OrganizationCatalog = { items: ProfileRecord[]; presets: OrganizationProfile[]; can_manage: boolean }
export type Json = null | boolean | number | string | Json[] | { [key: string]: Json }
export type DistributionAudit = {
  state: string; assessment: '' | 'not_assessed' | 'risk_identified' | 'information_required' | 'no_signal_on_checked_issues'; explanation: string; next_step: string
  report_id: string; model_requests: number; raw: Json
}
export type DistributionBranch = {
  id: 'quality' | 'research' | 'clinic'; organization: string; protocol: 'SQL' | 'REST' | 'HL7'
  namespace: string; state: string; message_id: string; session_id: string
  header_id?: string; evidence_hash?: string
  fields: string[]; payload_hash: string; receipt?: Json; policy_mismatches: string[]
  audit?: DistributionAudit; error?: string
}
export type DistributionRun = {
  id: string; variant: 'identifier-leak' | 'corrected'; state: string; created_at: string | number
  profiles: Record<OrganizationId, ProfileRecord>; source_pins: { resource: string; version: string; hash: string }[]
  branches: DistributionBranch[]; error?: string
  audit_state?: 'queued' | 'running' | 'completed' | 'completed_with_errors' | 'failed' | 'interrupted'
  audit_error?: string
}
export type DistributionState = {
  ready: boolean; readiness: { name: string; ready: boolean; detail: string }[]
  runs: DistributionRun[]; can_manage: boolean; model_request_limit: 6
}

function invalid(field: string): never { throw new Error(`Invalid multi-organization response: ${field}`) }
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return invalid('object')
  return value as Record<string, unknown>
}
function text(value: unknown): string {
  if (typeof value !== 'string') return invalid('text')
  return value
}
function nonempty(value: unknown): string {
  const result = text(value)
  if (!result.trim()) return invalid('empty identifier')
  return result
}
function digest(value: unknown): string {
  const hash = text(value)
  if (!/^[a-fA-F0-9]{64}$/.test(hash)) return invalid('SHA-256 digest')
  return hash
}
function integer(value: unknown): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0) return invalid('integer')
  return value
}
function boolean(value: unknown): boolean {
  if (value !== true && value !== false && value !== 0 && value !== 1) return invalid('boolean')
  return value === true || value === 1
}
function list<T>(value: unknown, decode: (value: unknown) => T): T[] {
  if (!Array.isArray(value)) return invalid('array')
  return value.map(decode)
}
function choice<T extends string>(value: unknown, values: readonly T[]): T {
  const result = values.find(item => item === value)
  return result ?? invalid('enum')
}
function timestamp(value: unknown): string | number {
  if (typeof value !== 'number') return nonempty(value)
  if (!Number.isFinite(value) || value < 0) return invalid('timestamp')
  return value
}
function unique<T>(items: T[], key: (item: T) => string): T[] {
  if (new Set(items.map(key)).size !== items.length) return invalid('duplicate identity')
  return items
}
export function decodeJson(value: unknown): Json {
  if (value === null || typeof value === 'string' || typeof value === 'boolean') return value
  if (typeof value === 'number' && Number.isFinite(value)) return value
  if (Array.isArray(value)) return value.map(decodeJson)
  return Object.fromEntries(Object.entries(object(value)).map(([key, item]) => [key, decodeJson(item)]))
}
export function distributionAuditSummary(audit: DistributionAudit) {
  const asObject = (value: Json | undefined): { [key: string]: Json } | undefined =>
    value !== null && typeof value === 'object' && !Array.isArray(value) ? value : undefined
  const result = asObject(asObject(audit.raw)?.result)
  const summary = asObject(result?.summary)
  const issues = Array.isArray(result?.issues) ? result.issues : []
  const firstExplanation = asObject(issues[0])?.explanation
  const explanation = typeof firstExplanation === 'string' && firstExplanation.trim() ? firstExplanation : audit.explanation
  const missing = [...new Set([result?.missing_information, summary?.missing_information]
    .flatMap(value => Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string' && !!item.trim()) : []))]
  return {
    reason: explanation.length > 360 ? `${explanation.slice(0, 360).trimEnd()}…` : explanation,
    unresolved: typeof summary?.unresolved === 'boolean' ? summary.unresolved : undefined,
    missing,
  }
}
export function decodeOrganizationProfile(value: unknown): OrganizationProfile {
  const p = object(value)
  const profile: OrganizationProfile = {
    id: choice(p.id, organizationIds), name: nonempty(p.name), partner: nonempty(p.partner), type: nonempty(p.type),
    parent_id: text(p.parent_id), responsibilities: text(p.responsibilities), purpose: text(p.purpose),
    relationship: choice(p.relationship, ['same_covered_entity', 'another_provider', 'external']),
    allowed_fields: unique(list(p.allowed_fields, nonempty), value => value),
    prohibited_fields: unique(list(p.prohibited_fields, nonempty), value => value), requirements: text(p.requirements),
  }
  if ((profile.parent_id && !organizationIds.some(id => id === profile.parent_id)) || profile.parent_id === profile.id) return invalid('parent organization')
  if (profile.allowed_fields.some(field => profile.prohibited_fields.includes(field))) return invalid('conflicting receiving policy')
  return profile
}
export function decodeProfileRecord(value: unknown): ProfileRecord {
  const r = object(value), profile = decodeOrganizationProfile(r.profile)
  const id = choice(r.id, organizationIds), revision = integer(r.revision)
  if (id !== profile.id || revision < 1) return invalid('profile identity/revision')
  return { id, revision, profile, confirmed_by: nonempty(r.confirmed_by), confirmed_at: timestamp(r.confirmed_at), hash: digest(r.hash) }
}
export function decodeOrganizationCatalog(value: unknown): OrganizationCatalog {
  const c = object(value)
  return { items: unique(list(c.items, decodeProfileRecord), r => r.id),
    presets: unique(list(c.presets, decodeOrganizationProfile), p => p.id), can_manage: boolean(c.can_manage) }
}
export function commaSeparatedFields(value: string): string[] {
  return [...new Set(value.split(',').map(field => field.trim()).filter(Boolean))]
}
export function profileConfirmation(profile: OrganizationProfile, expectedRevision: number, confirmed: boolean) {
  if (!confirmed) throw new Error('Confirm this exact synthetic profile before saving.')
  return { profile: decodeOrganizationProfile(profile), expected_revision: integer(expectedRevision), confirmed: true as const }
}
export function decodeDistributionAudit(value: unknown): DistributionAudit {
  const a = object(value), model_requests = integer(a.model_requests)
  if (model_requests > 6) return invalid('audit request budget')
  return { state: nonempty(a.state), assessment: choice(a.assessment, ['', 'not_assessed', 'risk_identified', 'information_required', 'no_signal_on_checked_issues']),
    explanation: text(a.explanation),
    next_step: text(a.next_step), report_id: text(a.report_id), model_requests, raw: decodeJson(a.raw) }
}
export function decodeDistributionBranch(value: unknown): DistributionBranch {
  const b = object(value), id = choice(b.id, ['quality', 'research', 'clinic'] as const)
  const protocol = choice(b.protocol, ['SQL', 'REST', 'HL7'] as const)
  const namespace = nonempty(b.namespace)
  const expected = { quality: ['SQL', 'DEMOQUALITY'], research: ['REST', 'DEMORESEARCH'], clinic: ['HL7', 'DEMOCLINIC'] }
  if (protocol !== expected[id][0] || namespace !== expected[id][1]) return invalid('local recipient binding')
  return { id, organization: nonempty(b.organization), protocol, namespace, state: nonempty(b.state),
    message_id: text(b.message_id), session_id: text(b.session_id), fields: list(b.fields, nonempty),
    payload_hash: b.payload_hash === '' ? '' : digest(b.payload_hash), policy_mismatches: list(b.policy_mismatches, nonempty),
    ...(b.header_id === undefined ? {} : { header_id: text(b.header_id) }),
    ...(b.evidence_hash === undefined ? {} : { evidence_hash: b.evidence_hash === '' ? '' : digest(b.evidence_hash) }),
    ...(b.receipt === undefined ? {} : { receipt: decodeJson(b.receipt) }),
    ...(b.audit === undefined ? {} : { audit: decodeDistributionAudit(b.audit) }),
    ...(b.error === undefined ? {} : { error: text(b.error) }) }
}
export function decodeDistributionRun(value: unknown): DistributionRun {
  const r = object(value)
  const branches = unique(list(r.branches, decodeDistributionBranch), b => b.id)
  if (branches.reduce((total, b) => total + (b.audit?.model_requests ?? 0), 0) > 6) return invalid('run request budget')
  const snapshots = object(r.profiles)
  const profiles = Object.fromEntries(organizationIds.map(id => {
    const profile = decodeProfileRecord(snapshots[id])
    if (profile.id !== id) return invalid('snapshot identity')
    return [id, profile]
  })) as Record<OrganizationId, ProfileRecord>
  return { id: nonempty(r.id), variant: choice(r.variant, ['identifier-leak', 'corrected']),
    state: nonempty(r.state), created_at: timestamp(r.created_at), profiles,
    source_pins: unique(list(r.source_pins, value => {
      const pin = object(value)
      return { resource: nonempty(pin.resource), version: nonempty(pin.version), hash: digest(pin.hash) }
    }), pin => pin.resource), branches, ...(r.error === undefined ? {} : { error: text(r.error) }),
    ...(r.audit_state === undefined ? {} : { audit_state: choice(r.audit_state, ['queued', 'running', 'completed', 'completed_with_errors', 'failed', 'interrupted'] as const) }),
    ...(r.audit_error === undefined ? {} : { audit_error: text(r.audit_error) }) }
}
export function decodeDistributionState(value: unknown): DistributionState {
  const s = object(value)
  if (integer(s.model_request_limit) !== 6) return invalid('model request limit')
  return { ready: boolean(s.ready), can_manage: boolean(s.can_manage), model_request_limit: 6,
    readiness: unique(list(s.readiness, value => {
      const r = object(value)
      return { name: nonempty(r.name), ready: boolean(r.ready), detail: text(r.detail) }
    }), r => r.name), runs: unique(list(s.runs, decodeDistributionRun), r => r.id) }
}
export function decodeSeedResult(value: unknown): { resources: string[]; version: string } {
  const source = object(value)
  const resources = unique(list(source.resources, nonempty), resource => resource)
  if (!resources.length) return invalid('source resource IDs')
  return { resources, version: nonempty(source.version) }
}
export function distributionRunRequest(runId: string, variant: DistributionRun['variant'], confirmed: boolean) {
  if (!confirmed) throw new Error('Confirm delivery to the three local synthetic receivers.')
  if (!/^[A-Za-z0-9-]{1,48}$/.test(runId)) return invalid('run identifier')
  return { run_id: nonempty(runId), variant: choice(variant, ['identifier-leak', 'corrected']), confirmed: true as const }
}
export function distributionAuditRequest(runId: string, cost: boolean, synthetic: boolean) {
  if (!cost || !synthetic) throw new Error('Both cost and synthetic-data acknowledgements are required.')
  return { run_id: nonempty(runId), acknowledge_cost: true as const, acknowledge_synthetic: true as const }
}
