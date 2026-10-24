import { useEffect, useState } from 'react'
import { Activity, Bot, Layers, ShieldAlert } from 'lucide-react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { PageHeading, Panel, Stat, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeEventDetail, decodeEvents, decodeLiveEvent, decodeReview, investigationBlockReason, eventObject } from './lib/events'
import type { EventDetail, EventState } from './lib/events'
import { decodeAgentState } from './lib/agents'
import type { AgentState } from './lib/agents'
import { decodeEvaluations } from './lib/evaluations'
import type { PrivacyEvaluation } from './lib/evaluations'
import { decodeBusinessEvaluations } from './lib/business-evaluations'
import type { BusinessEvaluation } from './lib/business-evaluations'
import { useAuth } from './auth'
import { AILogButton } from './components/ai-log'
import type { Review } from './lib/events'

export function matchingInvestigationExecution(saved: { key: string; review: Review } | undefined, key: string, reviews: Review[]) {
  if (!saved || saved.key !== key) return undefined
  const current = reviews.find(review => review.id === saved.review.id)
  return current ?? saved.review
}
export function persistedInvestigationExecution(reviews: Review[], eventId: string, config?: AgentState['agents'][number]) {
  if (!config) return undefined
  return reviews.find(review => {
    const saved = eventObject(review).saved
    if (!saved || review.event_id !== eventId || review.origin !== 'manual_investigation') return false
    const raw = eventObject(saved), source = raw.config
    if (!source || typeof source !== 'object' || Array.isArray(source)) return false
    const agent = eventObject(source)
    return agent.id === config.id && agent.revision === config.revision && raw.config_hash === config.config_hash
  })
}
function decodeLoggedEvents(value: unknown): EventState {
  const state = decodeEvents(value), raw = eventObject(value).reviews as unknown[]
  return { ...state, reviews: state.reviews.map((review, index) => Object.assign(review, { saved: raw[index] })) }
}

export function LiveOperationsPage({ path }: { path: string }) {
  const { authorization } = useAuth()
  const [state, setState] = useState<EventState>()
  const [agents, setAgents] = useState<AgentState>()
  const [evaluations, setEvaluations] = useState<PrivacyEvaluation[]>([])
  const [businessEvaluations, setBusinessEvaluations] = useState<BusinessEvaluation[]>([])
  const [detail, setDetail] = useState<EventDetail>()
  const [reason, setReason] = useState('')
  const [agentId, setAgentId] = useState('')
  const [consent, setConsent] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [investigationExecution, setInvestigationExecution] = useState<{ key: string; review: Review }>()
  const [query, setQuery] = useState(() => new URLSearchParams(location.search).get('q') || '')
  const id = path.startsWith('/events/') ? path.split('/')[2] : ''
  const showEvaluations = path.startsWith('/runs')
  const title = path.startsWith('/overview') ? 'Overview' : path.startsWith('/runs') ? 'Runs' : 'Events'
  async function load(auth: string) {
    const [events, versions, reports, businessReports] = await Promise.all([
      apiRequest('/events', decodeLoggedEvents, undefined, { authorization: auth }),
      apiRequest('/agents', decodeAgentState, undefined, { authorization: auth }),
      showEvaluations ? apiRequest('/evaluations', decodeEvaluations, undefined, { authorization: auth }) : Promise.resolve([]),
      showEvaluations ? apiRequest('/business-evaluations', decodeBusinessEvaluations, undefined, { authorization: auth }) : Promise.resolve([]),
    ])
    const d = id ? await apiRequest(`/events/${encodeURIComponent(id)}`, decodeEventDetail, undefined, { authorization: auth }) : undefined
    setState(events); setAgents(versions); setEvaluations(reports); setBusinessEvaluations(businessReports); setDetail(d)
  }
  useEffect(() => {
    if (!authorization) return
    let cancelled = false
    const controller = new AbortController()
    const refresh = async () => {
      try {
        const value = await apiRequest('/events', decodeLoggedEvents, controller.signal, { authorization })
        const d = id ? await apiRequest(`/events/${encodeURIComponent(id)}`, decodeEventDetail, controller.signal, { authorization }) : undefined
        const reports = showEvaluations ? await apiRequest('/evaluations', decodeEvaluations, controller.signal, { authorization }) : []
        const businessReports = showEvaluations ? await apiRequest('/business-evaluations', decodeBusinessEvaluations, controller.signal, { authorization }) : []
        const versions = await apiRequest('/agents', decodeAgentState, controller.signal, { authorization })
        if (!cancelled) { setState(value); setDetail(d); setEvaluations(reports); setBusinessEvaluations(businessReports); setAgents(versions) }
      } catch (e) { if (!cancelled) setError(e instanceof Error ? e.message : 'Operations refresh failed') }
    }
    void refresh()
    const timer = setInterval(() => { if (!document.hidden) void refresh() }, 5000)
    const resume = () => { if (!document.hidden) void refresh() }
    window.addEventListener('focus', resume)
    document.addEventListener('visibilitychange', resume)
    return () => { cancelled = true; controller.abort(); clearInterval(timer); window.removeEventListener('focus', resume); document.removeEventListener('visibilitychange', resume) }
  }, [authorization, id, showEvaluations])
  async function action(run?: () => Promise<void>) {
    setBusy(true); setError(''); setNotice('')
    try { if (run) await run(); await load(authorization) }
    catch (e) { setError(e instanceof Error ? e.message : 'Operations action failed') }
    finally { setBusy(false) }
  }
  const event = detail?.event
  const consentKey = event ? `${event.id}:${event.revision}:${agentId}` : ''
  const investigationBlocked = detail && state ? investigationBlockReason(state.can_write, detail.observation) : ''
  const investigationReason = investigationBlocked || (busy ? 'An operation is in progress.'
    : !agentId ? 'Select a published privacy Agent.'
      : consent !== consentKey ? 'Acknowledge the model-request cost for this event and Agent to continue.' : '')
  const transitions = event?.state === 'open' ? ['in_review', 'ignored'] : event?.state === 'in_review' ? ['needs_information', 'resolved', 'ignored'] : event?.state === 'needs_information' ? ['in_review', 'resolved', 'ignored'] : ['open']
  const filtered = state?.events.filter(e => `${e.id} ${e.category} ${e.title} ${e.state}`.toLowerCase().includes(query.toLowerCase())) || []
  const investigationLog = matchingInvestigationExecution(investigationExecution, consentKey, state?.reviews ?? [])
    ?? (event ? persistedInvestigationExecution(state?.reviews ?? [], event.id, agents?.agents.find(agent => agent.id === agentId)) : undefined)
  return <div className="monitor-page agent-live-page">
    <PageHeading eyebrow="P5 · REAL OBSERVATIONS / LOCAL DEMO" title={event ? event.title : title}
      description="Durable events, review coverage and human actions. Automatic model budget is zero. A coverage gap or technical failure is not a privacy finding."
      action={<><Button asChild variant="outline"><a href="/pipelines">Events & risks by Production</a></Button>
        <Button variant="outline" disabled={busy} onClick={() => { void action() }}>Refresh operations</Button></>} />
    {error && <div className="callout" role="alert">{error}</div>}
    {notice && <div className="callout" role="status">{notice}</div>}
    {!state ? <Panel title="Loading operations"><p>Reading records using your workspace sign-in. Use Refresh operations to retry if needed.</p></Panel> : <>
      <div className="stats-grid">
        <Stat label="Persisted observations" value={String(state.counts.observed)} note="Idempotent platform intake" icon={<Activity size={17} />} />
        <Stat label="Eligible analytics" value={String(state.counts.eligible)} note="Schema 2 source facts only" icon={<Layers size={17} />} />
        <Stat label="Source-selected samples" value={String(state.counts.selected_persisted)} note="Not a guarantee of a completed review" icon={<Bot size={17} />} />
        <Stat label="Open events" value={String(state.events.filter(e => !['resolved', 'ignored'].includes(e.state)).length)} note="Within the latest 100 events" icon={<ShieldAlert size={17} />} />
      </div>
      {event && detail ? <>
        <a href="/events">Back to all events</a>
        <Panel title="Event and immutable observation" action={<Status tone="warning">{event.state}</Status>}>
          <p>{event.detail}</p><p className="mono">Event: {event.id}<br />Observation: {event.observation_id}<br />Category: {event.category} · Revision: {event.revision}</p>
          <details><summary>Actual source observation, facts and Gate decision</summary><pre className="agent-json">{JSON.stringify(detail.observation, null, 2)}</pre></details>
        </Panel>
        <Panel title="Human review and local opinions">
          <label htmlFor="event-reason" className="field-label">Reason / original opinion · retained locally, never automatically sent to a model</label>
          <textarea id="event-reason" maxLength={2000} value={reason} onChange={e => setReason(e.target.value)} />
          <div className="form-actions">
            {[...transitions, 'opinion'].map(actionName => <Button key={actionName} variant="outline" disabled={busy || !state.can_write || !reason.trim()} onClick={() => { void action(async () => {
              await apiRequest('/events/action', decodeLiveEvent, undefined, { authorization, body: { id: event.id, revision: event.revision, action: actionName, text: reason } })
              setReason(''); setNotice(actionName === 'opinion' ? 'Original opinion saved locally. No summary, rule generation or deployment was triggered.' : 'Human event state saved. Original findings and other events are unchanged.')
            }) }}>{actionName === 'opinion' ? 'Save original opinion' : actionName.replaceAll('_', ' ')}</Button>)}
          </div>
          {event.actions.map(a => <p key={a.id}>{a.actor}: {a.text}</p>)}
          {event.opinions.map(o => <div key={o.id}><p><strong>Opinion {o.id}</strong> · {o.actor}</p><p>{o.text}</p><p className="subtle">Summary: {o.summary_state}; no AI summary was substituted.</p></div>)}
        </Panel>
        <Panel title="Independent published-Agent investigation">
          <p>Only synthetic analytics observations with source facts support the current privacy template. Original opinions are not sent. Investigation does not resolve the event or change business delivery.</p>
          <label htmlFor="investigation-agent" className="field-label">Published privacy Agent</label>
          <select id="investigation-agent" value={agentId} onChange={e => { setAgentId(e.target.value); setConsent('') }}>
            <option value="">Select a published version</option>
            {agents?.agents.filter(a => a.status === 'published').map(a => <option key={a.id} value={a.id}>{a.name} · index {a.index_version}</option>)}
          </select>
          <label className="knowledge-confirm"><input type="checkbox" disabled={busy || !!investigationBlocked || !agentId} checked={consentKey !== '' && consent === consentKey} onChange={e => setConsent(e.target.checked ? consentKey : '')} />Authorize up to four real model requests for this exact event revision and Agent. Possible model charges.</label>
          {investigationReason && <p id="investigation-unavailable" role="status">{investigationReason}</p>}
          <div className="form-actions"><Button aria-describedby={investigationReason ? 'investigation-unavailable' : undefined} disabled={!!investigationReason} onClick={() => {
            if (investigationReason) return
            void action(async () => {
            setConsent('')
            const review = await apiRequest('/events/investigate', decodeReview, undefined, { authorization, body: { id: event.id, revision: event.revision, agent_id: agentId, acknowledge_cost: true } })
            setInvestigationExecution({ key: consentKey, review })
            setNotice('Investigation queued. View Runs for actual tools, results and any failure.')
          }) }}>Start independent AI Hub investigation</Button><AILogButton key={`${consentKey}-${investigationLog?.id ?? ''}`} report={investigationLog}
            title="Saved event and pinned Agent investigation" load={investigationLog ? async () => apiRequest('/events', value => {
              const reviews = eventObject(value).reviews
              if (!Array.isArray(reviews)) throw new Error('Saved investigations are unavailable')
              const saved = reviews.find(value => eventObject(value).id === investigationLog.id)
              if (!saved || decodeReview(saved).event_id !== event.id) throw new Error('This exact saved event investigation is unavailable')
              return saved
            }, undefined, { authorization }) : undefined} /></div>
          {investigationLog && <p className="subtle">Saved investigation for this event and exact Agent configuration. Its captured facts are historical; the saved request does not record the event revision and is not presented as a review of subsequent event changes.</p>}
        </Panel>
      </> : path.startsWith('/runs') ? <>
        <Panel title="Business-context HIPAA risk review · independent read-only runtime">
          <p>This reviewer reads business facts and chooses contextual searches against a pinned IRIS index. Findings link fact IDs to actual retrieved source quotes. Contract validity is not legal entailment or applicability; human review is always required. Recommendations do not execute a hold, delivery or configuration change.</p>
          {!businessEvaluations.length && <p>No business-context runtime batch has been recorded. Starting one requires separate explicit cost authorization; refreshing this page never calls a model.</p>}
          {businessEvaluations.map(report => <article key={report.id} className="monitor-card">
            <h3 className="mono">{report.id}</h3>
            <Status tone="info">{report.state} · human HIPAA review pending · no business execution</Status>
            <p className="mono">Prompt: {report.prompt_version}<br />Prompt SHA-256: {report.prompt_hash}<br />Inputs SHA-256: {report.input_hash}<br />Source configuration: {report.config.config_hash}<br />Model: {report.config.model} · Index: {report.config.index_version}</p>
            {report.prompt_version === 'hipaa-business-runtime-v4' && <p>Facts were server-prefilled. The single-use evidence tool runs discovery and mandatory clause lookups together (at most three retrievals). Component audit entries are not additional SDK tool calls. A completed lookup attempt does not guarantee relevant evidence.</p>}
            <p>Reserved: {report.reserved_model_requests}/48 requests (upper bound, not actual usage).
              {report.summary && <> Processed: {report.summary.completed}/12 · Valid output contracts: {report.summary.valid_contracts} · Technical failures: {report.summary.technical_failures}.</>}</p>
            {report.diagnostics && <>
              <p>Author-oracle machine checks aligned: {report.diagnostics.aligned}/{report.diagnostics.checked}. This is not a HIPAA accuracy score or human review.</p>
              <p>{report.diagnostics.limitations}</p>
            </>}
            {report.error && <p role="status">{report.error}</p>}
            {report.cases.map(c => <details key={c.case_id}><summary>{c.case_id} · {c.state} · {c.result?.assessment || 'no accepted output'} · recommendation only: {c.result?.recommended_action || 'none'}</summary>
              <p>{c.result?.reason || c.error}</p><p className="mono">AI Hub session: {c.agent_session || 'unavailable'}</p>
              {c.result?.claims && <div>
                <p><strong>Claim assessment — not proof of an underlying condition failure</strong></p>
                {c.result.claims.map((claim, i) => <p key={i}>{claim.status}: {claim.explanation}</p>)}
                <p><strong>Compliance-condition assessment</strong></p>
                {c.result.conditions?.map((finding, i) => <p key={i}>{finding.condition} · {finding.applicability} / {finding.status}: {finding.explanation}</p>)}
                <p>Action policy: stage-conservative-v1. Before-send holds can reflect uncertainty; they are recommendations, not a legal verdict or execution authorization.</p>
              </div>}
              {report.diagnostics?.cases.filter(d => d.case_id === c.case_id).map(d => <div key={d.case_id}>
                <p>Author expected: {d.expected_assessment} / {d.expected_recommendation}. Machine alignment: {d.oracle_alignment ? 'aligned, human review still pending' : 'not aligned'}.</p>
                {d.action_policy && <p>Local action-policy conformance: {d.action_policy.conforms ? 'yes' : 'no'} · exact author action match: {d.action_policy.expected_action_exact_match ? 'yes' : 'no'}. Neither is execution authorization.</p>}
                <p>Unmet checks: {Object.entries(d.checks).filter(([, value]) => !value).map(([key]) => key).join(', ') || 'none'}.</p>
              </div>)}
              <p>Inspect the actual facts, search queries, snippets, quotations and cumulative SDK counters below. No overall HIPAA pass is inferred.</p>
              <pre className="agent-json">{JSON.stringify(c.detail, null, 2)}</pre>
            </details>)}
          </article>)}
        </Panel>
        <Panel title="Twelve-case mechanism regression · actual provider evidence">
          <p>Read-only reports. Refresh never calls a model. These cases test predefined flag classifications, missing facts and tool boundaries, not business-context HIPAA risk identification. A 12/12 result is not HIPAA risk-validation acceptance, a compliance assessment or a diagnosis benchmark.</p>
          <p>The separate business-context runtime above covers disclosure purpose, recipient roles, de-identification paths and applicable clauses. Its reports and pending human review are separate from these mechanism results; neither changes business actions.</p>
          {!evaluations.length && <p>No evaluation has been explicitly authorized yet.</p>}
          {evaluations.map(report => <article key={report.id} className="monitor-card">
            <h3 className="mono">{report.id}</h3>
            <Status tone={report.passed ? 'success' : 'warning'}>{report.state} · {report.passed ? 'mechanism regression passed' : 'mechanism regression not passed'}</Status>
            <p>{report.limitations}</p><p className="mono">Model: {report.config.model} · Knowledge: {report.config.index_version}<br />Configuration: {report.config_hash}<br />Manifest: {report.manifest_hash}</p>
            <p className="mono">Prompt: {report.prompt_version || 'privacy-review-v1 (historical)'}{report.prompt_hash && <><br />Prompt SHA-256: {report.prompt_hash}</>}</p>
            <p>Acceptance policy: {report.acceptance_policy || 'Historical evaluation before the privacy-safety-v1 guard; original results are not reclassified.'}</p>
            <p>Budget reserved: {report.reserved_model_requests} / {report.max_model_requests} model requests (upper bounds, not actual usage).
              {report.summary && <> Completed: {report.summary.completed}/12 · Passed: {report.summary.passed} · Failed: {report.summary.failed} · Technical failures: {report.summary.technical_failures}.</>}</p>
            {report.error && <p role="status">{report.error}</p>}
            {report.cases.map(c => <details key={c.scenario}><summary>{c.scenario} · {c.passed ? 'passed' : 'not passed'} · expected {c.expected} / actual {c.result?.assessment || c.state}</summary>
              <p>{c.result?.reason || c.error}</p><p className="mono">AI Hub session: {c.agent_session || 'unavailable'}</p>
              <p>SDK usage is the final response only. sdk_stats contains cumulative session counters; reasoning tokens are already included in completion.</p>
              <pre className="agent-json">{JSON.stringify(c, null, 2)}</pre>
            </details>)}
          </article>)}
        </Panel>
        <Panel title="Actual observation review tasks and investigations">
          {!state.reviews.length && <p>No observation review tasks yet. Send an analytics message from Synthetic demo.</p>}
          {state.reviews.map(r => <details key={r.id}><summary>{r.origin} · {r.state} · {r.id}</summary>
            <p>{r.reason || r.error || 'See actual run evidence below.'}</p><p className="mono">Observation: {r.observation_id}</p>
            {r.analysis && <pre className="agent-json">{JSON.stringify(r.analysis, null, 2)}</pre>}
          </details>)}
        </Panel>
        <Panel title="Agent builder and acceptance runs">
          {agents?.jobs.map(j => <p key={j.id} className="mono">{j.kind} · {j.state} · {j.id} {j.passed === undefined ? '' : j.passed ? 'passed' : 'not passed'}</p>)}
          <a href="/agents">Open Agent versions and full test evidence</a>
        </Panel>
      </> : <>
        <Panel title="Real event inbox">
          <label htmlFor="event-search" className="field-label">Filter events</label>
          <Input id="event-search" value={query} onChange={e => {
            setQuery(e.target.value); const u = new URL(location.href); if (e.target.value) u.searchParams.set('q', e.target.value); else u.searchParams.delete('q'); history.replaceState(null, '', u)
          }} placeholder="Category, state, title or event ID" />
          {!filtered.length ? <p>No matching real events. Send synthetic messages in Demo; no fixture events are substituted.</p> :
            <div className="table-scroll"><table className="data-table"><thead><tr><th>Event</th><th>Category</th><th>State</th></tr></thead><tbody>{filtered.map(e => <tr key={e.id}>
              <td><a href={`/events/${e.id}`}>{e.title}</a><p className="mono subtle">{e.id}</p></td><td>{e.category}</td><td>{e.state}</td>
            </tr>)}</tbody></table></div>}
        </Panel>
        <Panel title="Coverage boundaries">
          <p>Source sampling defaults to enabled, rate 0 plus UTC daily first analytics sample. The daily marker commits with the source outbox; paused is different from rate 0. No traffic creates no sample.</p>
          <p>Automatic model budget: {state.automatic_model_budget}. Selected samples remain explicitly blocked, not marked reviewed. Legacy schema 1 observations without source facts: {state.counts.legacy_without_facts}.</p>
          <div className="form-actions"><Button asChild variant="outline"><a href="/demo">Send synthetic messages</a></Button><Button asChild variant="outline"><a href="/runs">Inspect real tasks</a></Button></div>
        </Panel>
      </>}
    </>}
  </div>
}
