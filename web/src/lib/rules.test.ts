import { describe, expect, it } from 'vitest'
import { decodeRuleDraft, decodeRulePlan, decodeRuleState } from './rules'

const hash = 'a'.repeat(64)
const draft = { id: 'rule-1', revision: 1, state: 'draft', bundle_hash: hash, bundle: {}, event_id: 'e1', opinion_id: 'o1', origin: 'manual_template_not_ai' }
const plan = { id: 'p1', rule_id: 'rule-1', state: 'loaded', digest: hash, bundle_hash: hash, expected_revision: 0, source_hash: hash, bundle: {}, previous_bundle: {}, effect: 'Synthetic DEMO only' }
describe('live rule contracts', () => {
  it('preserves explicit manual provenance', () => {
    expect(decodeRuleDraft(draft).origin).toBe('manual_template_not_ai')
    expect(() => decodeRuleDraft({ ...draft, origin: 'ai_generated' })).toThrow()
  })
  it('does not turn loaded into effect verified', () => {
    expect(decodeRulePlan(plan).state).toBe('loaded')
    expect(() => decodeRulePlan({ ...plan, state: 'success' })).toThrow()
  })
  it('requires digests and integral revisions', () => {
    expect(() => decodeRulePlan({ ...plan, digest: '' })).toThrow()
    expect(() => decodeRuleDraft({ ...draft, revision: 1.5 })).toThrow()
  })
  it('rejects malformed collections and permissions without fixtures', () => {
    const state = { drafts: [draft], plans: [plan], target: { revision: 0, bundle: {} }, template: {}, user: 'viewer', can_write: 0 }
    expect(decodeRuleState(state).can_write).toBe(false)
    expect(() => decodeRuleState({ ...state, plans: {} })).toThrow()
    expect(() => decodeRuleState({ ...state, can_write: 'false' })).toThrow()
  })
})
