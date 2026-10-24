import { eventObject } from './events'

export type RuleDraft = {
  id: string; revision: number; state: string; bundle_hash: string; bundle: Record<string, unknown>
  event_id: string; opinion_id: string; origin: string; report?: Record<string, unknown>
}
export type RulePlan = {
  id: string; rule_id: string; state: string; digest: string; bundle_hash: string
  expected_revision: number; source_hash: string; bundle: Record<string, unknown>
  previous_bundle: Record<string, unknown>; effect: string; error?: string
}
export type RuleState = {
  drafts: RuleDraft[]; plans: RulePlan[]; target: Record<string, unknown>
  template: Record<string, unknown>; user: string; can_write: boolean
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid rule text')
  return value
}
function count(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) throw new Error('Invalid rule revision')
  return value
}
function hash(value: unknown): string {
  const result = text(value)
  if (!/^[a-f0-9]{64}$/.test(result)) throw new Error('Invalid rule digest')
  return result
}
export function decodeRuleDraft(value: unknown): RuleDraft {
  const d = eventObject(value), state = text(d.state)
  if (!['draft', 'tested', 'test_failed'].includes(state) || d.origin !== 'manual_template_not_ai') throw new Error('Unknown rule draft provenance/state')
  return { id: text(d.id), revision: count(d.revision), state, bundle_hash: hash(d.bundle_hash), bundle: eventObject(d.bundle),
    event_id: text(d.event_id), opinion_id: text(d.opinion_id), origin: d.origin, report: d.report === undefined ? undefined : eventObject(d.report) }
}
export function decodeRulePlan(value: unknown): RulePlan {
  const p = eventObject(value), state = text(p.state)
  if (!['planned', 'approved', 'unknown', 'loaded', 'effect_verified'].includes(state)) throw new Error('Unknown rule deployment state')
  return { id: text(p.id), rule_id: text(p.rule_id), state, digest: hash(p.digest), bundle_hash: hash(p.bundle_hash),
    expected_revision: count(p.expected_revision), source_hash: hash(p.source_hash), bundle: eventObject(p.bundle),
    previous_bundle: eventObject(p.previous_bundle), effect: text(p.effect), error: p.error === undefined ? undefined : text(p.error) }
}
export function decodeRuleState(value: unknown): RuleState {
  const s = eventObject(value)
  if (!Array.isArray(s.drafts) || !Array.isArray(s.plans)) throw new Error('Invalid rule collections')
  if (s.can_write !== true && s.can_write !== false && s.can_write !== 0 && s.can_write !== 1) throw new Error('Invalid rule permission')
  const target = eventObject(s.target)
  count(target.revision); eventObject(target.bundle)
  return { drafts: s.drafts.map(decodeRuleDraft), plans: s.plans.map(decodeRulePlan), target,
    template: eventObject(s.template), user: text(s.user), can_write: s.can_write === true || s.can_write === 1 }
}
