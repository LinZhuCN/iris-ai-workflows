import { decodeAgent } from './agents'
import type { AgentConfig } from './agents'
import { eventObject } from './events'

export type BusinessCase = {
  case_id: string; state: 'completed' | 'failed'
  agent_session?: string; error?: string
  result?: { assessment: string; recommended_action: string; reason: string
    claims?: { status: string; explanation: string }[]
    conditions?: { condition: string; applicability: string; status: string; explanation: string }[]
  }
  detail: Record<string, unknown>
}
export type BusinessEvaluation = {
  id: string; state: string; config: AgentConfig; input_hash: string
  prompt_version: string; prompt_hash: string; reserved_model_requests: number
  cases: BusinessCase[]; error?: string
  summary?: { completed: number; valid_contracts: number; technical_failures: number }
  diagnostics?: { aligned: number; checked: number; limitations: string; cases: {
    case_id: string; oracle_alignment: boolean; expected_assessment: string; expected_recommendation: string; checks: Record<string, boolean>
    action_policy?: { version: string; conforms: boolean; expected_action_exact_match: boolean }
  }[] }
}
function text(value: unknown): string {
  if (typeof value !== 'string' || !value) throw new Error('Invalid business evaluation text')
  return value
}
function count(value: unknown): number {
  if (typeof value !== 'number' || !Number.isInteger(value) || value < 0) throw new Error('Invalid business evaluation count')
  return value
}
function hash(value: unknown): string {
  const result = text(value)
  if (!/^[a-f0-9]{64}$/.test(result)) throw new Error('Invalid business evaluation hash')
  return result
}
export function decodeBusinessEvaluations(value: unknown): BusinessEvaluation[] {
  const collection = eventObject(value)
  if (!Array.isArray(collection.reports) || collection.automatic_model_budget !== 0 || collection.execution !== 'evaluation_only') throw new Error('Business evaluation must be read-only with zero automatic budget')
  return collection.reports.map(raw => {
    const v = eventObject(raw)
    if (v.suite !== 'hipaa-business-context-v1' ||
      !['hipaa-business-runtime-v1', 'hipaa-business-runtime-v2', 'hipaa-business-runtime-v3', 'hipaa-business-runtime-v4'].includes(text(v.prompt_version)) ||
      v.execution !== 'evaluation_only' || v.human_review_required !== true || v.hipaa_risk_validation !== 'not_completed' || v.passed !== undefined) throw new Error('Business structure checks cannot claim HIPAA acceptance')
    const state = text(v.state), reserved = count(v.reserved_model_requests)
    if (!['queued', 'running', 'completed', 'failed', 'interrupted'].includes(state) || v.max_model_requests !== 48 || reserved > 48 || reserved % 4 !== 0 || !Array.isArray(v.cases)) throw new Error('Invalid business evaluation progress or budget')
    const cases = v.cases.map(rawCase => {
      const c = eventObject(rawCase)
      if (c.state !== 'completed' && c.state !== 'failed') throw new Error('Invalid business case state')
      const id = text(c.case_id)
      if (!/^business-(0[1-9]|1[0-2])$/.test(id) || c.execution !== 'not_executed' || c.human_review_required !== true || c.hipaa_risk_validation !== 'not_completed' || c.passed !== undefined) throw new Error('Invalid case identity or execution claim')
      const result = c.result === undefined ? undefined : eventObject(c.result)
      if (c.state === 'completed' && !result) throw new Error('Completed business case lacks output')
      if (c.state === 'completed' && !c.agent_session) throw new Error('Completed business case lacks an AI Hub session')
      if (result && (!['risk', 'no_finding', 'insufficient_evidence'].includes(text(result.assessment)) ||
        !['hold_for_review', 'manual_review', 'continue_under_existing_controls'].includes(text(result.recommended_action)))) throw new Error('Invalid business assessment/recommendation')
      const packet = eventObject(c.packet)
      if (packet.case_id !== id || packet.synthetic !== true) throw new Error('Business packet mismatch')
      if (result?.recommended_action === 'hold_for_review' && packet.stage !== 'before_send') throw new Error('A post-send/configuration hold is impossible')
      if (result && result.assessment !== 'no_finding' && result.recommended_action === 'continue_under_existing_controls') throw new Error('Non-clean assessment cannot authorize continuing')
      let claims: NonNullable<BusinessCase['result']>['claims']
      let conditions: NonNullable<BusinessCase['result']>['conditions']
      if (result && ['hipaa-business-runtime-v3', 'hipaa-business-runtime-v4'].includes(text(v.prompt_version))) {
        if (!Array.isArray(result.claims) || result.claims.length > 10 ||
          !Array.isArray(result.findings) || result.findings.length > 10) throw new Error('V3 requires separate claims and conditions')
        claims = result.claims.map(rawClaim => {
          const claim = eventObject(rawClaim), status = text(claim.status)
          if (!['supported', 'contradicted', 'unverified'].includes(status)) throw new Error('Invalid claim status')
          return { status, explanation: text(claim.explanation) }
        })
        conditions = result.findings.map(rawFinding => {
          const f = eventObject(rawFinding), status = text(f.condition_status), applicability = text(f.applicability)
          if (!['met', 'not_met', 'unknown', 'not_applicable'].includes(status) ||
            !['applicable', 'not_applicable', 'unknown'].includes(applicability)) throw new Error('Invalid condition status')
          return { condition: text(f.condition), applicability, status, explanation: text(f.explanation) }
        })
        const expected = conditions.some(f => f.status === 'not_met') ? 'risk' :
          conditions.length === 0 || conditions.some(f => f.status === 'unknown') || claims.some(f => f.status === 'unverified') ?
            'insufficient_evidence' : 'no_finding'
        if (result.assessment !== expected) throw new Error('V3 assessment contradicts its conditions/claims')
      }
      return { case_id: id, state: c.state,
        agent_session: c.agent_session === undefined ? undefined : text(c.agent_session),
        error: c.error === undefined ? undefined : text(c.error),
        result: result && { assessment: text(result.assessment), recommended_action: text(result.recommended_action), reason: text(result.reason),
          claims, conditions },
        detail: c } satisfies BusinessCase
    })
    if (cases.length > 12 || cases.length * 4 > reserved || new Set(cases.map(c => c.case_id)).size !== cases.length || (state === 'completed' && cases.length !== 12)) throw new Error('Business case count mismatch')
    const summary = v.summary === undefined ? undefined : eventObject(v.summary)
    if (summary && (summary.completed !== cases.length || summary.valid_contracts !== cases.filter(c => c.state === 'completed').length ||
      summary.technical_failures !== cases.filter(c => c.state === 'failed').length)) throw new Error('Business totals mismatch')
    if (state === 'completed' && !summary) throw new Error('Completed business evaluation lacks totals')
    const d = v.diagnostics === undefined ? undefined : eventObject(v.diagnostics)
    let diagnostics: BusinessEvaluation['diagnostics']
    if (d) {
      if (d.kind !== 'author_oracle_machine_checks' || d.human_review_required !== true || !Array.isArray(d.cases)) throw new Error('Invalid author-oracle diagnostics')
      const diagnosed = d.cases.map(rawCheck => {
        const c = eventObject(rawCheck), flags = eventObject(c.checks), checks: Record<string, boolean> = {}
        if (c.human_review_required !== true || typeof c.oracle_alignment !== 'boolean') throw new Error('Machine checks cannot replace human review')
        for (const key of ['expected_assessment', 'expected_recommendation', 'critical_facts_referenced', 'required_sections_cited']) {
          const flag = flags[key]
          if (typeof flag !== 'boolean') throw new Error('Invalid business check flag')
          checks[key] = flag
        }
        if (c.oracle_alignment !== Object.values(checks).every(Boolean)) throw new Error('False author-oracle alignment')
        let actionPolicy: { version: string; conforms: boolean; expected_action_exact_match: boolean } | undefined
        if (['hipaa-business-runtime-v3', 'hipaa-business-runtime-v4'].includes(text(v.prompt_version))) {
          const policy = eventObject(c.action_policy)
          if (policy.version !== 'stage-conservative-v1' || typeof policy.conforms !== 'boolean' ||
            typeof policy.expected_action_exact_match !== 'boolean' ||
            policy.expected_action_exact_match !== checks.expected_recommendation) throw new Error('Invalid v3 action-policy check')
          actionPolicy = { version: policy.version, conforms: policy.conforms, expected_action_exact_match: policy.expected_action_exact_match }
        }
        return { case_id: text(c.case_id), oracle_alignment: c.oracle_alignment,
          expected_assessment: text(c.expected_assessment), expected_recommendation: text(c.expected_recommendation), checks,
          action_policy: actionPolicy }
      })
      if (d.checked !== cases.length || diagnosed.length !== cases.length ||
        new Set(diagnosed.map(c => c.case_id)).size !== diagnosed.length ||
        diagnosed.some(c => !cases.some(item => item.case_id === c.case_id)) ||
        d.aligned !== diagnosed.filter(c => c.oracle_alignment).length) throw new Error('Business diagnostic totals mismatch')
      diagnostics = { aligned: count(d.aligned), checked: count(d.checked), limitations: text(d.limitations), cases: diagnosed }
    }
    return { id: text(v.id), state, config: decodeAgent(v.config), input_hash: hash(v.input_hash),
      prompt_version: text(v.prompt_version), prompt_hash: hash(v.prompt_hash), reserved_model_requests: reserved, cases,
      error: v.error === undefined ? undefined : text(v.error),
      diagnostics,
      summary: summary && { completed: count(summary.completed), valid_contracts: count(summary.valid_contracts), technical_failures: count(summary.technical_failures) } }
  })
}
