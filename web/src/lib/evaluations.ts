import { decodeAgent, decodeAgentCase } from './agents'
import type { AgentCase, AgentConfig } from './agents'
import { eventObject } from './events'

export type PrivacyEvaluation = {
  id: string; state: string; config: AgentConfig; config_hash: string
  manifest_hash: string; suite: string; cases: AgentCase[]; passed: boolean
  max_model_requests: number; reserved_model_requests: number
  limitations: string; error?: string; summary?: { total: number; completed: number; passed: number; failed: number; technical_failures: number }
  acceptance_policy?: string
  prompt_version?: string; prompt_hash?: string
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid evaluation text')
  return value
}
function count(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) throw new Error('Invalid evaluation count')
  return value
}
export function decodeEvaluation(value: unknown): PrivacyEvaluation {
  const v = eventObject(value), state = text(v.state)
  if (!['queued', 'running', 'completed', 'failed', 'interrupted'].includes(state)) throw new Error('Unknown evaluation state')
  if (typeof v.passed !== 'boolean' || !Array.isArray(v.cases) || v.suite !== 'privacy-synthetic-v1') throw new Error('Invalid evaluation contract')
  if (v.max_model_requests !== 48 || count(v.reserved_model_requests) > 48) throw new Error('Invalid evaluation budget')
  const cases = v.cases.map(decodeAgentCase), config = decodeAgent(v.config)
  const summary = v.summary === undefined ? undefined : eventObject(v.summary)
  if (cases.length > 12 || new Set(cases.map(c => c.scenario)).size !== cases.length) throw new Error('Invalid evaluation cases')
  if (summary && (summary.total !== 12 || summary.completed !== cases.length ||
    summary.passed !== cases.filter(c => c.passed).length ||
    summary.failed !== cases.filter(c => !c.passed).length ||
    summary.technical_failures !== cases.filter(c => c.state === 'failed').length)) throw new Error('Evaluation totals mismatch')
  if (state === 'completed' && (cases.length !== 12 || !summary)) throw new Error('Incomplete completed evaluation')
  if (v.passed && (state !== 'completed' || cases.some(c => !c.passed || c.state !== 'completed'))) throw new Error('False evaluation success')
  if (v.config_hash !== config.config_hash) throw new Error('Evaluation configuration mismatch')
  if (config.prompt_version && (v.prompt_version !== config.prompt_version || v.prompt_hash !== config.prompt_hash)) throw new Error('Evaluation prompt mismatch')
  if (config.prompt_version && cases.some(c => (c.state === 'completed' || c.agent_session || c.prompt_version !== undefined || c.prompt_hash !== undefined) &&
    (c.prompt_version !== config.prompt_version || c.prompt_hash !== config.prompt_hash))) throw new Error('Case prompt mismatch')
  if (cases.some(c => c.passed && c.result?.assessment !== c.expected)) throw new Error('Case outcome does not match its expected label')
  return { id: text(v.id), state, config, config_hash: text(v.config_hash), manifest_hash: text(v.manifest_hash), suite: v.suite,
    cases, passed: v.passed, max_model_requests: v.max_model_requests, reserved_model_requests: count(v.reserved_model_requests),
    limitations: text(v.limitations), error: v.error === undefined ? undefined : text(v.error),
    acceptance_policy: v.acceptance_policy === undefined ? undefined : text(v.acceptance_policy),
    prompt_version: v.prompt_version === undefined ? undefined : text(v.prompt_version), prompt_hash: v.prompt_hash === undefined ? undefined : text(v.prompt_hash),
    summary: summary && { total: count(summary.total), completed: count(summary.completed), passed: count(summary.passed),
      failed: count(summary.failed), technical_failures: count(summary.technical_failures) } }
}
export function decodeEvaluations(value: unknown): PrivacyEvaluation[] {
  const v = eventObject(value)
  if (!Array.isArray(v.reports) || v.automatic_model_budget !== 0) throw new Error('Invalid evaluation collection or automatic budget')
  return v.reports.map(decodeEvaluation)
}
