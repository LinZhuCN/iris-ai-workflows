import { eventObject } from './events'

export type Proposal = {
  schema: 1; synthetic: true; title: string; owner: string
  purpose: { category: string; text: string; activities: string; expected_output: string }
  recipient_id: string
  data: { resources: string[]; fields: string[]; cohort: string; max_records: number; necessity: string }
  handling: { recipe_id: string; identifiability: string; access: string; retention: string; onward_sharing: string }
  arrangements: { status: string; details: string }
  validity: { from: number; until: number }
}
export type Recipient = { id: string; name: string; relationship: string; service_identity: string; executable: boolean }
export type DeclarationCatalog = {
  version: string; organization: { organization_id: string; role: string; synthetic: true }
  recipients: Recipient[]; purpose_categories: string[]; resources: string[]; fields: string[]; cohorts: string[]
  recipes: { id: string; description: string; executable: boolean }[]
  identifiability: string[]; arrangement_statuses: string[]
}
export type Assessment = 'no_risk_identified' | 'risk_identified' | 'information_required'
export type Citation = { evidence_id: string; passage_id: string; quote: string; start: number; end: number }
export type ProposalResult = {
  assessment: Assessment; missing_information: string[]; risk_detected: boolean; unresolved: boolean
  issues: { question_id: string; status: string; fact_ids: string[]; explanation: string; citations: Citation[] }[]
}
export type ReviewConsent = {
  record_id: string; digest: string; task_id: string; agent_id: string; source_revision: number
  config_hash: string; input_hash: string; contract_hash: string; max_model_requests: 2; acknowledge_cost: boolean
}
export type DeclarationTask = {
  id: string; record_hash: string; state: 'blocked_budget' | 'queued' | 'running' | 'completed' | 'failed'
  assessment: Assessment | null; result: ProposalResult | null; reserved_requests: number; attempted_requests: number
  runtime?: { authorization: ReviewConsent; report_id: string; message_id: string; session_id: string; error: string }
}
export type DecisionAction = 'approved' | 'returned' | 'rejected'
export type DeclarationRecord = {
  id: string; declaration_id: string; revision: number; latest_revision: number; digest: string; parent_digest: string
  proposal: Proposal; state: 'draft' | 'submitted'; created_by: string; created_at: number
  context: { catalog_version: string; catalog_hash: string; organization: DeclarationCatalog['organization']; recipient: Recipient }
  review: { task: DeclarationTask | null }
  decision: null | { action: DecisionAction; reason: string; decided_by: string; decided_at: number; record_hash: string }
  capability: { state: 'supported' | 'unsupported'; reason: string }; execution_state: string; is_current_submission: boolean
}
export type DeclarationList = { items: DeclarationRecord[]; next_cursor: string; can_write: boolean }
export type DeclarationHistory = { declaration_id: string; items: DeclarationRecord[]; has_older: boolean; older_before_revision: number }
export type ReviewPlan = { consent: ReviewConsent; model: string }
export type DeclarationReport = {
  id: string; state: string; authorization: Omit<ReviewConsent, 'record_id' | 'digest' | 'task_id'> & { request_key: string }; source: {
    id: string; revision: number; model: string; table: string; index_version: number; corpus: string; config_hash: string
  }
  phases: { phase: string; state: string; agent_session: string; raw: string; prompt_tokens: number | null; completion_tokens: number | null; interactions: number | null }[]
  sources: { question_id: string; id: string; text: string; source_url: string; source_locator: string; source_version: string; source_sha256: string; verified: boolean }[]
  error?: string
}
function text(v: unknown): string {
  if (typeof v !== 'string') throw new Error('Invalid declaration text')
  return v
}
function num(v: unknown): number {
  if (typeof v !== 'number' || !Number.isFinite(v) || v < 0) throw new Error('Invalid declaration number')
  return v
}
function integer(v: unknown): number {
  const n = num(v)
  if (!Number.isSafeInteger(n)) throw new Error('Invalid declaration integer')
  return n
}
function bool(v: unknown): boolean {
  if (v !== true && v !== false && v !== 0 && v !== 1) throw new Error('Invalid declaration boolean')
  return v === true || v === 1
}
function list<T>(v: unknown, decode: (value: unknown) => T): T[] {
  if (!Array.isArray(v)) throw new Error('Invalid declaration list')
  return v.map(decode)
}
function hash(v: unknown): string {
  const s = text(v)
  if (!/^[a-f0-9]{64}$/.test(s)) throw new Error('Invalid declaration digest')
  return s
}
function choice<T extends string>(v: unknown, options: readonly T[]): T {
  const found = options.find(option => option === v)
  if (!found) throw new Error('Invalid declaration state')
  return found
}
function organization(v: unknown): DeclarationCatalog['organization'] {
  const o = eventObject(v)
  if (o.synthetic !== true) throw new Error('Synthetic organization required')
  return { organization_id: text(o.organization_id), role: text(o.role), synthetic: true }
}
function recipient(v: unknown): Recipient {
  const r = eventObject(v)
  return { id: text(r.id), name: text(r.name), relationship: text(r.relationship),
    service_identity: text(r.service_identity), executable: bool(r.executable) }
}
export function decodeDeclarationCatalog(v: unknown): DeclarationCatalog {
  const c = eventObject(v)
  if (c.schema !== 1 || c.model_calls !== 0) throw new Error('Non-inferencing catalog required')
  return { version: text(c.version), organization: organization(c.organization), recipients: list(c.recipients, recipient),
    purpose_categories: list(c.purpose_categories, text), resources: list(c.resources, text), fields: list(c.fields, text),
    cohorts: list(c.cohorts, text), recipes: list(c.recipes, value => {
      const r = eventObject(value)
      return { id: text(r.id), description: text(r.description), executable: bool(r.executable) }
    }), identifiability: list(c.identifiability, text), arrangement_statuses: list(c.arrangement_statuses, text) }
}
export function decodeProposal(v: unknown): Proposal {
  const p = eventObject(v), use = eventObject(p.purpose), data = eventObject(p.data)
  const h = eventObject(p.handling), a = eventObject(p.arrangements), validity = eventObject(p.validity)
  if (p.schema !== 1 || p.synthetic !== true || integer(validity.until) <= integer(validity.from)) throw new Error('Valid synthetic proposal required')
  return { schema: 1, synthetic: true, title: text(p.title), owner: text(p.owner), recipient_id: text(p.recipient_id),
    purpose: { category: text(use.category), text: text(use.text), activities: text(use.activities), expected_output: text(use.expected_output) },
    data: { resources: list(data.resources, text), fields: list(data.fields, text), cohort: text(data.cohort),
      max_records: integer(data.max_records), necessity: text(data.necessity) },
    handling: { recipe_id: text(h.recipe_id), identifiability: text(h.identifiability), access: text(h.access),
      retention: text(h.retention), onward_sharing: text(h.onward_sharing) },
    arrangements: { status: text(a.status), details: text(a.details) },
    validity: { from: integer(validity.from), until: integer(validity.until) } }
}
const assessments = ['no_risk_identified', 'risk_identified', 'information_required'] as const
export function decodeProposalResult(v: unknown): ProposalResult {
  const r = eventObject(v), assessment = choice(r.assessment, assessments)
  const missing_information = list(r.missing_information, text), risk_detected = bool(r.risk_detected), unresolved = bool(r.unresolved)
  if (r.basis !== 'proposed_use_as_declared' || risk_detected !== (assessment === 'risk_identified') ||
    (assessment === 'no_risk_identified' && (unresolved || missing_information.length)) ||
    (assessment === 'information_required' && (!unresolved || !missing_information.length))) throw new Error('Inconsistent proposal assessment')
  const issues = list(r.issues, value => {
    const i = eventObject(value)
    return { question_id: text(i.question_id), status: choice(i.status, ['risk_signal', 'no_signal_on_checked_issue', 'unresolved']),
      fact_ids: list(i.fact_ids, text), explanation: text(i.explanation), citations: list(i.citations, value => {
        const c = eventObject(value), start = integer(c.start), end = integer(c.end)
        if (end <= start) throw new Error('Invalid citation span')
        return { evidence_id: text(c.evidence_id), passage_id: text(c.passage_id), quote: text(c.quote), start, end }
      }) }
  })
  if (!issues.length || risk_detected !== issues.some(issue => issue.status === 'risk_signal') ||
    unresolved !== (missing_information.length > 0 || issues.some(issue => issue.status === 'unresolved'))) {
    throw new Error('Issue states disagree with the aggregate assessment')
  }
  return { assessment, missing_information, risk_detected, unresolved, issues }
}
function consentPins(v: unknown) {
  const c = eventObject(v)
  if (c.max_model_requests !== 2) throw new Error('Exact two-request consent required')
  return { agent_id: text(c.agent_id),
    source_revision: integer(c.source_revision), config_hash: hash(c.config_hash), input_hash: hash(c.input_hash),
    contract_hash: hash(c.contract_hash), max_model_requests: 2 as const, acknowledge_cost: bool(c.acknowledge_cost) }
}
function consent(v: unknown): ReviewConsent {
  const c = eventObject(v)
  return { ...consentPins(c), record_id: text(c.record_id), digest: hash(c.digest), task_id: text(c.task_id) }
}
function task(v: unknown, record: { id: string; digest: string; revision: number; declaration_id: string }): DeclarationTask {
  const t = eventObject(v), state = choice(t.state, ['blocked_budget', 'queued', 'running', 'completed', 'failed'])
  if (t.mode !== 'declaration' || t.record_id !== record.id || t.declaration_digest !== record.digest ||
    t.revision !== record.revision || t.declaration_id !== record.declaration_id) throw new Error('Review belongs to another revision')
  const assessment = t.assessment === null ? null : choice(t.assessment, assessments)
  const result = t.result === null ? null : decodeProposalResult(t.result)
  const reserved_requests = integer(t.reserved_requests), attempted_requests = integer(t.attempted_requests)
  if (attempted_requests > reserved_requests || reserved_requests > 2 ||
    (state === 'completed' ? !result || result.assessment !== assessment : assessment !== null || result !== null)) throw new Error('Invalid review state/result')
  const runtime = t.runtime === undefined ? undefined : eventObject(t.runtime)
  const authorization = runtime ? consent(runtime.authorization) : undefined
  if (authorization && (authorization.record_id !== record.id || authorization.digest !== record.digest ||
    authorization.task_id !== t.id || !authorization.acknowledge_cost || reserved_requests !== 2)) throw new Error('Invalid funded review binding')
  return { id: text(t.id), record_hash: hash(t.record_hash), state, assessment, result, reserved_requests, attempted_requests,
    runtime: runtime && authorization ? { authorization, report_id: text(runtime.report_id), message_id: text(runtime.message_id),
      session_id: typeof runtime.session_id === 'number' ? String(integer(runtime.session_id)) : text(runtime.session_id), error: text(runtime.error) } : undefined }
}
export function decodeDeclarationRecord(v: unknown): DeclarationRecord {
  const r = eventObject(v), c = eventObject(r.context), cap = eventObject(r.capability)
  const base = { id: text(r.id), digest: hash(r.digest), revision: integer(r.revision), declaration_id: text(r.declaration_id) }
  const review = { task: eventObject(r.review).task === null ? null : task(eventObject(r.review).task, base) }
  const d = r.decision === null ? null : eventObject(r.decision)
  if (d && (!review.task || d.record_id !== base.id || d.digest !== base.digest ||
    d.task_id !== review.task.id || d.task_hash !== review.task.record_hash)) throw new Error('Decision belongs to another review')
  if (d?.action === 'approved' && (review.task?.state !== 'completed' || review.task.assessment !== 'no_risk_identified')) throw new Error('Unreviewed or risky approval')
  return { ...base, proposal: decodeProposal(r.proposal), parent_digest: r.parent_digest === '' ? '' : hash(r.parent_digest),
    latest_revision: integer(r.latest_revision), created_by: text(r.created_by), created_at: num(r.created_at),
    state: choice(r.state, ['draft', 'submitted']), context: { catalog_version: text(c.catalog_version), catalog_hash: hash(c.catalog_hash),
      organization: organization(c.organization), recipient: recipient(c.recipient) }, review,
    decision: d ? { action: choice(d.action, ['approved', 'returned', 'rejected']), reason: text(d.reason),
      decided_by: text(d.decided_by), decided_at: num(d.decided_at), record_hash: hash(d.record_hash) } : null,
    capability: { state: choice(cap.state, ['supported', 'unsupported']), reason: text(cap.reason) },
    execution_state: text(r.execution_state), is_current_submission: bool(r.is_current_submission) }
}
export function decodeDeclarations(v: unknown): DeclarationList {
  const s = eventObject(v)
  if (s.model_calls !== 0) throw new Error('Listing cannot invoke models')
  return { items: list(s.items, decodeDeclarationRecord), next_cursor: text(s.next_cursor), can_write: bool(s.can_write) }
}
export function decodeDeclarationHistory(v: unknown): DeclarationHistory {
  const h = eventObject(v)
  return { declaration_id: text(h.declaration_id), items: list(h.items, decodeDeclarationRecord),
    has_older: bool(h.has_older), older_before_revision: integer(h.older_before_revision) }
}
export function decodeReviewPlan(v: unknown): ReviewPlan {
  const p = eventObject(v), c = consent(p.consent)
  if (p.model_calls !== 0 || c.acknowledge_cost) throw new Error('Planning cannot authorize inference')
  return { consent: c, model: text(eventObject(p.source).model) }
}
export function decodeDeclarationReport(v: unknown): DeclarationReport {
  const r = eventObject(v), s = eventObject(r.source)
  if (r.version !== 'declaration-review-v1') throw new Error('Unexpected proposal review version')
  return { id: text(r.id), state: text(r.state),
    authorization: { ...consentPins(r.authorization), request_key: text(eventObject(r.authorization).request_key) },
    source: { id: text(s.id), revision: integer(s.revision), model: text(s.model), table: text(s.table),
      index_version: integer(s.index_version), corpus: hash(s.corpus), config_hash: hash(s.config_hash) },
    phases: list(r.phases, value => {
      const p = eventObject(value), stats = p.sdk_stats === undefined ? undefined : eventObject(p.sdk_stats)
      return { phase: text(p.phase), state: text(p.state), agent_session: text(p.agent_session),
        raw: p.raw === undefined ? '' : text(p.raw), prompt_tokens: stats ? integer(stats.total_prompt_tokens) : null,
        completion_tokens: stats ? integer(stats.total_completion_tokens) : null, interactions: stats ? integer(stats.total_interactions) : null }
    }), sources: r.packages === undefined ? [] : list(r.packages, value => {
      const p = eventObject(value)
      return list(p.evidence, value => {
        const h = eventObject(value), m = eventObject(h.metadata)
        return { question_id: text(p.question_id), id: text(h.id), text: text(h.text), source_url: text(m.source_url),
          source_locator: text(m.source_locator), source_version: text(m.source_version), source_sha256: hash(m.source_sha256),
          verified: bool(h.source_hash_verified) }
      })
    }).flat(), error: r.error === undefined ? undefined : text(r.error) }
}
export function bindDeclarationReport(record: DeclarationRecord, report: DeclarationReport): DeclarationReport {
  const task = record.review.task, a = report.authorization, expected = task?.runtime?.authorization
  if (!expected || task?.runtime?.report_id !== report.id || a.request_key !== `declaration-${task.id}` ||
    !a.acknowledge_cost || a.input_hash !== expected.input_hash || a.contract_hash !== expected.contract_hash ||
    a.config_hash !== expected.config_hash || a.agent_id !== expected.agent_id || a.source_revision !== expected.source_revision ||
    report.source.id !== a.agent_id || report.source.revision !== a.source_revision || report.source.config_hash !== a.config_hash ||
    report.state !== task.state) throw new Error('Report does not match this exact review')
  for (const issue of task.result?.issues ?? []) {
    for (const citation of issue.citations) {
      const source = report.sources.find(s => s.question_id === issue.question_id && s.id === citation.evidence_id)
      if (!source?.verified || Array.from(source.text).slice(citation.start, citation.end).join('') !== citation.quote) {
        throw new Error('Citation does not match its pinned source')
      }
    }
  }
  return report
}
export const assessmentLabels: Record<Assessment, string> = {
  no_risk_identified: 'No HIPAA compliance risk identified',
  risk_identified: 'HIPAA compliance risk identified',
  information_required: 'Additional information required',
}
export function canDecide(record: DeclarationRecord, action: DecisionAction, now = irisNow()): boolean {
  const task = record.review.task
  if (record.decision || record.revision !== record.latest_revision || !record.is_current_submission ||
    !task || !['completed', 'failed'].includes(task.state)) return false
  return action !== 'approved' || (task.state === 'completed' && task.assessment === 'no_risk_identified' &&
    record.proposal.validity.from <= now && record.proposal.validity.until > now)
}
export function saveCommand(id: string, proposal: Proposal, previous?: DeclarationRecord) {
  if (previous && (id !== previous.declaration_id || previous.revision !== previous.latest_revision)) throw new Error('Edit the latest declaration revision')
  if (!/^[A-Za-z][A-Za-z0-9_.-]{0,127}$/.test(id) || !proposal.data.fields.length || !proposal.data.resources.length ||
    proposal.data.fields.some(field => !proposal.data.resources.includes(field.split('.')[0]))) throw new Error('Choose resources and matching fields, and a valid declaration ID')
  decodeProposal(proposal)
  return { declaration_id: id, expected_revision: previous?.revision ?? 0, expected_digest: previous?.digest ?? '', proposal }
}
export function decisionCommand(record: DeclarationRecord, action: DecisionAction, reason: string) {
  if (!canDecide(record, action) || !reason.trim() || reason.length > 1000 || !record.review.task) throw new Error('A reason and eligible exact reviewed revision are required')
  return { record_id: record.id, digest: record.digest, task_id: record.review.task.id,
    task_hash: record.review.task.record_hash, action, reason }
}
export function irisNow(): number { return Math.floor(Date.now() / 1000) + 4070908800 }
export function dateInput(value: number): string {
  const d = new Date((value - 4070908800) * 1000)
  return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16)
}
export function inputDate(value: string): number {
  const time = Date.parse(value)
  if (!Number.isFinite(time)) throw new Error('Choose a valid date and time')
  return Math.floor(time / 1000) + 4070908800
}
export function newProposal(): Proposal {
  const now = irisNow()
  return { schema: 1, synthetic: true, title: '', owner: '', purpose: { category: 'unspecified', text: '', activities: '', expected_output: '' },
    recipient_id: 'unspecified-recipient', data: { resources: [], fields: [], cohort: 'synthetic-four-resources-v1', max_records: 4, necessity: '' },
    handling: { recipe_id: 'retain-requested-fields', identifiability: 'unspecified', access: '', retention: '', onward_sharing: '' },
    arrangements: { status: 'not_specified', details: '' }, validity: { from: now - 60, until: now + 30 * 86400 } }
}
