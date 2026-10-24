export type AgentConfig = {
  id: string; revision: number; status: 'draft' | 'published' | 'disabled'; name: string
  purpose: string; retrieval_query: string; template: string; table: string
  index_version: string; corpus: string; model: string; config_hash: string
  max_iterations: number; executor_version: string; test_job?: string
  prompt_version?: string; prompt_hash?: string; parent_id?: string; parent_hash?: string; evaluation_id?: string
}
export type AgentCase = {
  scenario: string; expected: string; state: string; passed: boolean; error?: string
  agent_session?: string; usage?: Record<string, unknown>
  rejected_output?: string; source_job?: string; sdk_stats?: Record<string, unknown>
  acceptance_policy?: string; rejection_kind?: string
  prompt_version?: string; prompt_hash?: string
  result?: { assessment: string; reason: string; citations: string[] }
  tools: { tool: string; time: number }[]
  evidence?: { id: string; chunk_id: string; text: string; metadata: {
    source_url: string; source_locator: string; kind: string; legal_status: string
    retrieval_scope: string
  } }[]
}
export type AgentJob = {
  id: string; kind: 'generate' | 'test'; state: string; model: string; started: number
  config_hash: string; max_model_requests: number; passed?: boolean; error?: string
  agent_id?: string; agent_session?: string; usage?: Record<string, unknown>; cases?: AgentCase[]
}
export type AgentBinding = {
  agent_id: string; config_hash: string; snapshot_id: string; snapshot_hash: string
  scenario: string; enabled: boolean; execution: string
}
export type AgentState = {
  agents: AgentConfig[]; jobs: AgentJob[]; user: string; can_write: boolean; binding?: AgentBinding
}
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid Agent API object')
  return value as Record<string, unknown>
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid Agent API text')
  return value
}
function number(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('Invalid Agent API count')
  return value
}
function flag(value: unknown): boolean {
  if (value === true || value === 1) return true
  if (value === false || value === 0) return false
  throw new Error('Invalid Agent API boolean')
}
function list<T>(value: unknown, decode: (v: unknown) => T): T[] {
  if (!Array.isArray(value)) throw new Error('Invalid Agent API list')
  return value.map(decode)
}
function optionalText(value: unknown): string | undefined {
  return value === undefined ? undefined : text(value)
}
export function decodeAgent(value: unknown): AgentConfig {
  const v = object(value)
  if (v.template !== 'privacy_review' || v.max_iterations !== 4 || v.executor_version !== 'privacy-v1') throw new Error('Unsupported Agent configuration')
  const status = v.status
  if (status !== 'draft' && status !== 'published' && status !== 'disabled') throw new Error('Unknown Agent version state')
  if (v.prompt_version !== undefined && (v.prompt_version !== 'privacy-review-v2' || typeof v.prompt_hash !== 'string' || !/^[a-f0-9]{64}$/.test(v.prompt_hash))) throw new Error('Unsupported or unpinned privacy prompt')
  if (v.prompt_version === undefined && v.prompt_hash !== undefined) throw new Error('Prompt hash lacks a version')
  return {
    id: text(v.id), revision: number(v.revision), status, name: text(v.name), purpose: text(v.purpose),
    retrieval_query: text(v.retrieval_query), template: v.template, table: text(v.table),
    index_version: typeof v.index_version === 'number' ? String(number(v.index_version)) : text(v.index_version), corpus: text(v.corpus), model: text(v.model),
    config_hash: text(v.config_hash), max_iterations: v.max_iterations,
    executor_version: v.executor_version, test_job: optionalText(v.test_job),
    prompt_version: optionalText(v.prompt_version), prompt_hash: optionalText(v.prompt_hash),
    parent_id: optionalText(v.parent_id), parent_hash: optionalText(v.parent_hash), evaluation_id: optionalText(v.evaluation_id),
  }
}
export function decodeAgentCase(value: unknown): AgentCase {
    const c = object(value), result = c.result === undefined ? undefined : object(c.result)
    if (c.state === 'completed' && !result) throw new Error('Completed test lacks a result')
    if (result && !['risk', 'no_finding', 'insufficient_evidence'].includes(text(result.assessment))) throw new Error('Invalid assessment')
    return {
      scenario: text(c.scenario), expected: text(c.expected), state: text(c.state), passed: flag(c.passed),
      error: optionalText(c.error), agent_session: optionalText(c.agent_session),
      usage: c.usage === undefined ? undefined : object(c.usage),
      rejected_output: optionalText(c.rejected_output), source_job: optionalText(c.source_job),
      acceptance_policy: optionalText(c.acceptance_policy), rejection_kind: optionalText(c.rejection_kind),
      prompt_version: optionalText(c.prompt_version), prompt_hash: optionalText(c.prompt_hash),
      sdk_stats: c.sdk_stats === undefined ? undefined : object(c.sdk_stats),
      result: result && { assessment: text(result.assessment), reason: text(result.reason), citations: list(result.citations, text) },
      tools: list(c.tools, value => { const t = object(value); return { tool: text(t.tool), time: number(t.time) } }),
      evidence: c.evidence === undefined ? undefined : list(c.evidence, value => {
        const e = object(value), m = object(e.metadata)
        return { id: text(e.id), chunk_id: text(e.chunk_id), text: text(e.text), metadata: {
          source_url: text(m.source_url), source_locator: text(m.source_locator),
          kind: text(m.kind), legal_status: text(m.legal_status), retrieval_scope: text(m.retrieval_scope),
        } }
      }),
    }
}
export function decodeAgentJob(value: unknown): AgentJob {
  const v = object(value)
  if (v.kind !== 'generate' && v.kind !== 'test') throw new Error('Unknown Agent job kind')
  const state = text(v.state)
  if (!['queued', 'running', 'completed', 'failed', 'interrupted'].includes(state)) throw new Error('Unknown Agent job state')
  const cases = v.cases === undefined ? undefined : list(v.cases, decodeAgentCase)
  if (v.kind === 'test' && state === 'completed' && v.passed === undefined) throw new Error('Test report lacks pass status')
  return {
    id: text(v.id), kind: v.kind, state, model: text(v.model), started: number(v.started),
    config_hash: text(v.config_hash), max_model_requests: number(v.max_model_requests),
    passed: v.passed === undefined ? undefined : flag(v.passed), error: optionalText(v.error),
    agent_id: optionalText(v.agent_id), agent_session: optionalText(v.agent_session),
    usage: v.usage === undefined ? undefined : object(v.usage), cases,
  }
}
export function decodeAgentState(value: unknown): AgentState {
  const v = object(value), b = v.binding === '' ? undefined : object(v.binding)
  return {
    agents: list(v.agents, decodeAgent), jobs: list(v.jobs, decodeAgentJob), user: text(v.user),
    can_write: flag(v.can_write),
    binding: b && { agent_id: text(b.agent_id), config_hash: text(b.config_hash),
      snapshot_id: text(b.snapshot_id), snapshot_hash: text(b.snapshot_hash), scenario: text(b.scenario),
      enabled: flag(b.enabled), execution: text(b.execution) },
  }
}
