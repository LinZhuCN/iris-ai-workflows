import { useEffect, useRef, useState } from 'react'
import { AILog, AILogButton } from './components/ai-log'
import { useAuth } from './auth'
import { Panel, Status } from './components/platform'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Textarea } from './components/ui/textarea'
import { apiRequest } from './lib/api'
import { eventObject } from './lib/events'
import { routeTime } from './lib/governance'
import type { ManagedProduction } from './lib/productions'
import { buildReviewConsent, decodeContext, decodeContexts, decodeEdges, decodeEvidencePage, decodeGrant, decodeInspectionGrant, decodeProductionReviewDetail, decodeReviewPage, decodeReviewPlan } from './lib/production-observation'

type ReviewDetail = ReturnType<typeof decodeProductionReviewDetail>
type Context = ReturnType<typeof decodeContext>
const pretty = (v: unknown) => JSON.stringify(v, null, 2)

export function ExportMessageComparison({ facts }: { facts: Record<string, unknown> | null }) {
  if (!facts || facts.export_context === undefined) return null
  const context = eventObject(facts.export_context), fields = Object.keys(eventObject(facts.fields)), dates = eventObject(facts.dates)
  return <section aria-label="Export declaration compared with actual message">
    <h4>Declared vs. sent</h4>
    <p><strong>Message declares: </strong>{String(context.method)} · marked {String(context.processing_status)} · {String(context.purpose)}</p>
    <p><strong>Fields actually sent: </strong>{fields.join(', ')}</p>
    <p><strong>Date precision: </strong>{String(dates.full_date)} full dates · {String(dates.year_only)} year-only dates</p>
    <p>The declaration is a label to check, not proof that de-identification succeeded. Identifier values stay local.</p>
  </section>
}

export function ReviewResultSummary({ detail }: { detail: Pick<ReviewDetail, 'assessment' | 'issues' | 'missing' | 'review'> }) {
  const outcome = detail.assessment === 'risk_identified'
    ? { title: 'Potential risk found', next: 'Review the flagged disclosure and confirm corrective steps.' }
    : detail.assessment === 'information_required'
      ? { title: 'More information needed', next: 'Supply the missing business facts before drawing a conclusion.' }
      : detail.assessment === 'no_signal_on_checked_issues'
        ? { title: 'No risk found in this check', next: 'No issue flagged for this scenario. This is not an overall compliance approval.' }
        : { title: 'Not assessed', next: 'Check the processing details below. No risk conclusion is available.' }
  const relevant = detail.assessment === 'risk_identified'
    ? detail.issues.filter(issue => issue.status === 'risk_signal')
    : detail.assessment === 'information_required'
      ? detail.issues.filter(issue => issue.status === 'unresolved')
      : detail.issues
  const reasons = relevant.length ? relevant : detail.issues
  return <section aria-label="Assessment summary">
    <h3>{outcome.title}</h3>
    {reasons.map(issue => <p key={issue.question}><strong>Why: </strong>{issue.explanation.split(/(?<=[.!?])\s+(?=[A-Z])/)[0]}</p>)}
    {!reasons.length && <p>{detail.review.error || detail.review.reason || 'No completed AI assessment.'}</p>}
    {!!detail.missing.length && <><h4>Missing information</h4><ul>{detail.missing.map(item => <li key={item}>{item}</li>)}</ul></>}
    <p><strong>Next: </strong>{outcome.next}</p>
    <p>Advisory only · No message was blocked, changed or replayed by this review.</p>
  </section>
}

export function ProductionObservationPanel({ record, canManage, refresh, onChanged }: {
  record: ManagedProduction; canManage: boolean; refresh: number; onChanged: () => void
}) {
  const { authorization } = useAuth()
  const [evidence, setEvidence] = useState<ReturnType<typeof decodeEvidencePage>>()
  const [edges, setEdges] = useState<ReturnType<typeof decodeEdges>>()
  const [reviews, setReviews] = useState<ReturnType<typeof decodeReviewPage>>()
  const [contexts, setContexts] = useState<ReturnType<typeof decodeContexts>>()
  const [plan, setPlan] = useState<ReturnType<typeof decodeReviewPlan>>()
  const [before, setBefore] = useState(0), [reviewBefore, setReviewBefore] = useState(0)
  const [edgeAfter, setEdgeAfter] = useState(''), [contextAfter, setContextAfter] = useState('')
  const [sessionInput, setSessionInput] = useState(''), [session, setSession] = useState('')
  const [detail, setDetail] = useState<ReviewDetail>(), [detailHeader, setDetailHeader] = useState('')
  const [detailError, setDetailError] = useState('')
  const [detailRequest, setDetailRequest] = useState(0)
  const detailRegion = useRef<HTMLDivElement>(null)
  const [readError, setReadError] = useState(''), [error, setError] = useState(''), [notice, setNotice] = useState('')
  const [busy, setBusy] = useState(false)
  const [reviewKey, setReviewKey] = useState(''), [agent, setAgent] = useState('')
  const [every, setEvery] = useState('1'), [maxReviews, setMaxReviews] = useState('1'), [minutes, setMinutes] = useState('10')
  const [existing, setExisting] = useState(false), [cost, setCost] = useState(false)
  const [prepared, setPrepared] = useState<ReturnType<typeof buildReviewConsent>>()
  const [demoEnabled, setDemoEnabled] = useState(false)
  const [premises, setPremises] = useState({ session_id: '', recipient: '', relationship: 'unknown', purpose: '',
    permission_basis: 'unknown', permission_details: '', authorization_status: 'unknown', safeguards: '', exceptions: '',
    recipient_mapping: '', data_scope: '', confirmed: false })
  const [contextKey, setContextKey] = useState(''), [configText, setConfigText] = useState('')
  const [editing, setEditing] = useState<Context>()
  const operation = useRef<AbortController | null>(null)
  const consentRequest = useRef<ReturnType<typeof buildReviewConsent> | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  useEffect(() => {
    const controller = new AbortController(), prefix = `/productions/${record.id}`
    void Promise.all([
      apiRequest(`${prefix}/evidence?before=${before}&session=${session}`, decodeEvidencePage, controller.signal, { authorization }),
      apiRequest(`${prefix}/paths?after=${edgeAfter}`, decodeEdges, controller.signal, { authorization }),
      apiRequest(`${prefix}/reviews?before=${reviewBefore}`, decodeReviewPage, controller.signal, { authorization }),
      apiRequest(`${prefix}/flows?after=${contextAfter}`, decodeContexts, controller.signal, { authorization }),
      apiRequest(`${prefix}/review-plan`, decodeReviewPlan, controller.signal, { authorization }),
    ]).then(([e, paths, r, c, p]) => {
      if ([e, paths, r, c, p].some(v => v.production_id !== record.id)) throw new Error('Production observation response identity changed')
      if (!controller.signal.aborted) {
        setEvidence(e); setEdges(paths); setReviews(r); setContexts(c); setPlan(p); setReadError('')
      }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setReadError(e instanceof Error ? e.message : 'Observation read failed') })
    return () => controller.abort()
  }, [record.id, authorization, before, session, edgeAfter, reviewBefore, contextAfter, refresh])
  useEffect(() => {
    if (!detailHeader) return
    const controller = new AbortController()
    void apiRequest(`/productions/${record.id}/reviews/${detailHeader}`, decodeProductionReviewDetail, controller.signal, { authorization })
      .then(value => {
        if (value.evidence.production_id !== record.id || value.evidence.header_id !== detailHeader) throw new Error('Review detail identity changed')
        if (!controller.signal.aborted) { setDetail(value); setDetailError('') }
      }).catch((e: unknown) => { if (!controller.signal.aborted) { setDetail(undefined); setDetailError(e instanceof Error ? e.message : 'Review detail failed') } })
    return () => controller.abort()
  }, [authorization, record.id, detailHeader, detailRequest, refresh])
  useEffect(() => {
    if (!detailHeader) return
    detailRegion.current?.focus({ preventScroll: true })
    detailRegion.current?.scrollIntoView({ block: 'start' })
  }, [detailHeader, detailRequest])

  async function grantLogs(grantId: string) {
    if (!grantId) return []
    const reports: unknown[] = [], seen = new Set<number>()
    let before = 0
    for (let page = 0; page < 100; page++) {
      const values = await apiRequest(`/productions/${record.id}/reviews?before=${before}`, decodeReviewPage, undefined, { authorization })
      if (values.production_id !== record.id) throw new Error('AI log Production identity changed')
      for (const review of values.items.filter(item => item.authorization_id === grantId)) {
        const saved = await apiRequest(`/productions/${record.id}/reviews/${review.header_id}`, decodeProductionReviewDetail, undefined, { authorization })
        if (saved.evidence.production_id !== record.id || saved.review.authorization_id !== grantId) throw new Error('AI log authorization identity changed')
        reports.push(saved.report ?? saved.review.raw)
      }
      if (!values.next_before) return reports
      if (seen.has(values.next_before)) throw new Error('AI log pagination repeated a cursor')
      seen.add(values.next_before); before = values.next_before
    }
    throw new Error('AI log history exceeds the read limit; inspect individual review records instead.')
  }
  function inspectReview(header: string) {
    setDetail(undefined); setDetailError(''); setDetailHeader(header)
    setDetailRequest(request => request + 1)
  }

  async function act(work: (signal: AbortSignal) => Promise<void>) {
    if (operation.current || !canManage || readError) return
    const controller = new AbortController(); operation.current = controller
    setBusy(true); setError(''); setNotice('')
    try { await work(controller.signal); if (!controller.signal.aborted) onChanged() }
    catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Observation action failed') }
    finally { operation.current = null; if (!controller.signal.aborted) setBusy(false) }
  }
  function checkScope(pid: string) { if (pid !== record.id) throw new Error('Action response belongs to another Production') }
  const disabled = busy || !canManage || !!readError
  const active = record.enabled && record.current.running && record.current.id === record.id
  const planMatches = plan?.config_hash === record.current.config_hash
  const resetConsent = () => { setPrepared(undefined); consentRequest.current = null; setCost(false); setPremises(p => ({ ...p, confirmed: false })); setError('') }
  function prepareConsent() {
    try {
      if (disabled || !active || !cost || prepared) throw new Error('Select paid cost confirmation for an active Production before preparing authorization')
      if (!plan || !planMatches) throw new Error('Refresh the exact active Production plan first')
      const body = buildReviewConsent(plan, { key: reviewKey, agent, every: Number(every), reviews: Number(maxReviews),
        minutes: Number(minutes), existing, cost, synthetic: true, ...(demoEnabled ? { premises: { ...premises, confirmed: true } } : {}) })
      setPrepared(body); consentRequest.current = body; setError('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Invalid authorization') }
  }
  function editContext(value?: Context) {
    setEditing(value); setContextKey(value?.key || '')
    setConfigText(pretty(value?.config || {
      schema: 1, synthetic: true, title: '', owner: '', source: '', processors: [], sender: '',
      purpose: '', recipient_id: '', declaration: null,
      collector: { id: 'structured-message-v1', format: 'json-object', fields: ['patient_id'] }, review_policy: 'observed-use-v1',
    }))
  }
  return <section className="production-observation" aria-label="Production evidence and review workspace">
    <Panel title="Evidence coverage and review health">
      <p className="callout"><strong>Demo assessment: user-approved business premises + observed message facts + HIPAA sources.</strong> Enter and confirm recipient, purpose, authorization and safeguards in the AI review approval below. These are usable premises within this demo; no real-system connection is required. Reports distinguish your inputs from collected message evidence. Unknown answers may require more information; results are not real-world compliance certification.</p>
      <p>Scope: {record.namespace} / {record.production}. All current components are observed without per-flow registration.</p>
      <p className="callout">Production-wide counts below are not filtered by page or source session. Capture counts are message headers, not patients or unique deliveries. Review sampling uses session/body references, not every edge. Missing, unsupported, skipped or budget-blocked evidence is not a no-risk result.</p>
      {readError && <p role="alert">{readError} Previously loaded observations may be stale; write controls are disabled.</p>}
      {error && <p role="alert">{error}</p>}
      {notice && <p role="status">{notice}</p>}
      {!evidence && !readError && <p>Loading evidence and review coverage…</p>}
      {evidence && <>
        <CountTable title="Local capture dispositions" values={evidence.counts} />
        <p>Capture scan: {evidence.observer.last_scan ? routeTime(evidence.observer.last_scan) : 'Not yet scanned'} · full capture batch: {evidence.observer.batch_full ? 'Yes, catch-up needed' : 'No'} · unattributed headers: {evidence.observer.unattributed}</p>
        {evidence.observer.error && <p role="alert">{evidence.observer.error}</p>}
        <p className="subtle">{evidence.history} Retention: {evidence.observer.retention}. Retention-loss detection: {evidence.observer.retention_loss_detection}; complete capture is not guaranteed.</p>
      </>}
      {reviews && <>
        <CountTable title="Review dispositions" values={reviews.counts} />
        <p>Reviewer: {reviews.paused ? 'Production paused' : 'Observation enabled'} · heartbeat: {reviews.heartbeat ? routeTime(reviews.heartbeat) : 'Not yet reported'} · scan: {reviews.last_scan ? routeTime(reviews.last_scan) : 'Not yet scanned'} · cursor {reviews.cursor} · unprocessed records: {reviews.batch_full ? 'Yes' : 'No at last read'}</p>
        {(reviews.error || reviews.worker_error) && <p role="alert">{reviews.error} {reviews.worker_error}</p>}
      </>}
    </Panel>
    <Panel title="Observed message edges">
      <p>Actual source → target headers, including responses; not reconstructed end-to-end business paths. Use a source session below to correlate messages.</p>
      <table className="data-table"><thead><tr><th>Source host</th><th>Target host</th><th>Basis</th></tr></thead>
        <tbody>{edges?.items.map(e => <tr key={e.id}><td>{e.source}</td><td>{e.target}</td><td>Actual message header</td></tr>)}</tbody></table>
      {edges && !edges.items.length && <p>No observed edges on this page; this is not proof of inactivity.</p>}
      <div className="form-actions"><Button variant="outline" disabled={!edgeAfter || busy} onClick={() => setEdgeAfter('')}>First edge page</Button>
        <Button variant="outline" disabled={!edges?.next_after || busy || !!readError} onClick={() => setEdgeAfter(edges?.next_after || '')}>More observed edges</Button></div>
    </Panel>
    <Panel title="Message evidence and session correlation">
      <form onSubmit={event => {
        event.preventDefault()
        if (sessionInput && !/^[0-9]{1,15}$/.test(sessionInput)) { setError('Source session must be an exact numeric reference'); return }
        setSession(sessionInput); setBefore(0); setError('')
      }}>
        <label className="field-label" htmlFor="observation-session">Exact source session (optional)</label>
        <Input id="observation-session" value={sessionInput} onChange={e => setSessionInput(e.target.value)} />
        <Button type="submit" variant="outline">Filter evidence by session</Button>
        <Button type="button" variant="outline" onClick={() => { setSession(''); setSessionInput(''); setBefore(0) }}>Clear session filter</Button>
      </form>
      <p>Session filter: {session || 'All source sessions'}. Evidence is immutable; the current review status is a separate live overlay.</p>
      {evidence?.items.map(e => <article className="monitor-card" key={e.id}>
        <h3>Header {e.header_id} · {e.source} → {e.target}</h3>
        <Status tone={e.capture_state === 'captured' ? 'info' : 'warning'}>{e.capture_state.replaceAll('_', ' ')}</Status>
        <p>Session {e.session} · {e.body_class} #{e.body_id} · outcome {e.outcome} · {e.delivery_evidence}</p>
        <p>{e.reason} Current review: {e.current?.state || 'pending_observer'}.</p>
        <Button variant="outline" onClick={() => { setSession(e.session); setSessionInput(e.session); setBefore(0) }}>Correlate session {e.session}</Button>
        {canManage && e.capture_state === 'captured' && <Button variant="outline" disabled={disabled || !!prepared} onClick={() => {
          setDemoEnabled(true); setExisting(true); setPremises(p => ({ ...p, session_id: e.session, confirmed: false }))
          setNotice(`Session ${e.session} selected. Complete the demo business premises in AI review approval below. Existing terminal reviews are not automatically reassessed.`)
        }}>Use session {e.session} for demo approval</Button>}
        {e.current && e.current.state !== 'pending_observer' && <Button variant="outline" onClick={() => inspectReview(e.header_id)}>Inspect evidence / review {e.header_id}</Button>}
        <details><summary>Minimized facts and immutable provenance · {e.header_id}</summary>
          <pre>{pretty({ facts: e.facts, record_hash: e.record_hash, config_hash: e.config_hash, limits: e.limits })}</pre></details>
      </article>)}
      {evidence && !evidence.items.length && <p>No captured observations match this page/filter. No safety conclusion is available.</p>}
      <div className="form-actions"><Button variant="outline" disabled={!before || busy} onClick={() => setBefore(0)}>Latest evidence</Button>
        <Button variant="outline" disabled={!evidence?.next_before || busy || !!readError} onClick={() => setBefore(evidence?.next_before || 0)}>Older evidence</Button></div>
    </Panel>
    <Panel title="Sampled review records">
      <p>Includes unsupported, unsampled, unfunded and failed items; only completed reports contain an AI assessment. Neither review nor human notes execute a business action.</p>
      <table className="data-table"><thead><tr><th>Header</th><th>Disposition</th><th>Reserved / attempted requests</th><th>Detail</th></tr></thead>
        <tbody>{reviews?.items.map(r => <tr key={r.header_id}><td>{r.header_id}</td><td>{r.state}<br />{r.reason || r.error}</td><td>{r.reserved} / {r.attempted}</td>
          <td>{r.header_id && <Button variant="outline" onClick={() => { if (r.header_id) inspectReview(r.header_id) }}>Review detail {r.header_id}</Button>}</td></tr>)}</tbody></table>
      {reviews && !reviews.items.length && <p>No review dispositions on this page; this is not an all-clear.</p>}
      <div className="form-actions"><Button variant="outline" disabled={!reviewBefore || busy} onClick={() => setReviewBefore(0)}>Latest review records</Button>
        <Button variant="outline" disabled={!reviews?.next_before || busy || !!readError} onClick={() => setReviewBefore(reviews?.next_before || 0)}>Older review records</Button></div>
      <div ref={detailRegion} tabIndex={-1} role="region" aria-label="Selected evidence and review detail" aria-busy={!!detailHeader && !detail && !detailError}>
      {detailError && <p role="alert">{detailError}</p>}
      {detailHeader && !detail && !detailError && <p role="status">Loading bound review {detailHeader}…</p>}
      {detail && <article key={detail.evidence.header_id} className="monitor-card" aria-label={`Review detail ${detail.evidence.header_id}`}>
        <p>Message {detail.evidence.header_id} · Session {detail.evidence.session}</p>
        <ReviewResultSummary detail={detail} />
        <ExportMessageComparison facts={detail.evidence.facts} />
        {detail.approval && <details>
          <summary>Business background supplied by the user</summary>
          <p>Confirmed by {detail.approval.actor} · {routeTime(detail.approval.confirmed_at)} · session {detail.approval.premises.session_id}. These inputs are established within the simulation, not independently verified real-world facts.</p>
          <p>Recipient: {detail.approval.premises.recipient} · relationship: {detail.approval.premises.relationship}. Purpose: {detail.approval.premises.purpose}</p>
          <p>Permission basis: {detail.approval.premises.permission_basis} · individual authorization: {detail.approval.premises.authorization_status}. {detail.approval.premises.permission_details}</p>
          <p>Safeguards: {detail.approval.premises.safeguards}</p><p>Special conditions / exceptions: {detail.approval.premises.exceptions}</p>
          {detail.approval.premises.recipient_mapping !== undefined && <><p>Technical-host / recipient mapping: {detail.approval.premises.recipient_mapping}</p><p>Message data scope: {detail.approval.premises.data_scope}</p></>}
        </details>}
        {detail.business && <details>
          <summary>Local business evidence</summary>
          <p>This adapter supports a synthetic local-policy assessment, not a validated HIPAA legal determination.</p>
          <p>SQL readback matched persisted message/session and payload hash. Receiver {detail.business.receiver} · batch {detail.business.batch} · {routeTime(detail.business.received)}.</p>
          <p>Business relationship: {detail.business.established ? 'Established within the registered synthetic scenario' : 'Unknown; SQL acceptance does not establish business purpose or permission'}.</p>
          <p>Local rule: {detail.business.policy}</p><p>{detail.business.scope}</p>
          <details><summary>Frozen business receipt, policy and evidence binding</summary><pre>{pretty(detail.business.raw)}</pre></details>
        </details>}
        {!!detail.issues.length && <details><summary>Full reasoning and legal references</summary>
        {detail.issues.map(i => <section key={i.question}>
          <h4>{i.question} · {i.status}</h4><p>{i.explanation}</p>
          {i.citations.map((c, index) => <blockquote key={`${c.id}/${c.passage}/${index}`}><p>{c.quote}</p><cite>{c.id} / {c.passage} · exact source span validated</cite></blockquote>)}
        </section>)}
        </details>}
        <details><summary>Technical audit details</summary>
        <p>Processing status: {detail.review.state}. Observation digest {detail.evidence.record_hash}.</p>
        <p>Model requests reserved: {detail.review.reserved}; attempted: {detail.review.attempted}.</p>
        {(detail.review.error || detail.review.reason) && <p>{detail.review.error || detail.review.reason}</p>}
        <AILog report={detail.report} />
        <details><summary>AI Hub sessions, usage, prompts and preserved output</summary><pre>{pretty(detail.report)}</pre></details>
        <details><summary>Dated normative sources and provenance</summary>{detail.sources.map(s => <section key={`${s.question}/${s.id}`}>
          <h4>{s.question} / {s.id}</h4><pre>{pretty(s.metadata)}</pre><pre>{s.text}</pre></section>)}</details>
        <details><summary>Frozen observation and optional context</summary><pre>{pretty({ observation: detail.evidence.raw, review: detail.review.raw })}</pre></details>
        </details>
      </article>}
      </div>
    </Panel>
    <Panel title="Independent inspection and AI authorization">
      <p className="callout">Enrollment, inspection and model spending are separate. These controls are builder-only. Opening, refreshing and reading reports call no model. Real PHI is not authorized by this synthetic demo.</p>
      {!canManage && <p>Read-only account: authorization and context changes require a builder.</p>}
      <details><summary>Local structured-property inspection (no model calls)</summary>
        <p>Only registered FHIR/JSON properties are inspected locally. Unknown/custom formats remain visible. This affects future capture only, not historical backfill or retry. Historical capture outcomes do not prove current consent.</p>
        <p className="mono">Exact configuration: {record.current.config_hash}</p>
        <p>Authorize local inspection of synthetic message properties for this exact Production/configuration. No model budget is granted.</p>
        <Button disabled={disabled || !active} onClick={() => { if (!active) return; void act(async signal => {
          const value = await apiRequest('/productions/authorize-inspection', decodeInspectionGrant, signal, { authorization, body: {
            production_id: record.id, config_hash: record.current.config_hash, acknowledge_local_synthetic_inspection: true,
          } })
          checkScope(value.production_id); setNotice('Local inspection authorized. No model budget granted; no historical messages replayed.')
        }) }}>Authorize local synthetic inspection</Button>
        <p>Revoking inspection disables future body reads and preserves historical evidence.</p>
        <Button variant="outline" disabled={disabled} onClick={() => { void act(async signal => {
          const value = await apiRequest('/productions/revoke-inspection', decodeInspectionGrant, signal, { authorization, body: { production_id: record.id } })
          checkScope(value.production_id); setNotice('Local inspection revoked. Existing evidence and separate AI grants are unchanged.')
        }) }}>Revoke local inspection</Button>
      </details>
      <details open={demoEnabled}><summary>AI review approval, demo business premises and bounded funding</summary>
        <p>{plan?.sampling} First eligible body then every Nth is deterministic, not per-path fairness. No automatic reassessment of terminal records.</p>
        <p>Model input: minimized synthetic observations, your confirmed demo premises (if enabled), optional declared purpose and dated normative sources. Request cap is not a fixed monetary/token cost guarantee. Each selected review reserves two requests, including failed/interrupted attempts.</p>
        <label className="confirmation-label"><input type="checkbox" checked={demoEnabled} disabled={disabled || !!prepared} onChange={e => {
          setDemoEnabled(e.target.checked); setPremises(p => ({ ...p, confirmed: false }))
        }} />Supply user-approved demo business premises for one source session.</label>
        {demoEnabled && <fieldset disabled={disabled || !!prepared}>
          <legend>Business background for this demo assessment</legend>
          <p>Act as the requester/approver. Describe the synthetic scenario; no hospital, contract or authorization-system connection is needed. Confirmation establishes these premises for the demo, not real-world truth or legal permission. Do not enter real patient information, signatures or credentials. Write “unknown” where information is unavailable; do not invent it.</p>
          <label className="field-label" htmlFor="demo-session">Source session ID</label>
          <Input id="demo-session" maxLength={15} value={premises.session_id} onChange={e => setPremises(p => ({ ...p, session_id: e.target.value, confirmed: false }))} />
          <p>Use a session shown in message evidence above. This approval applies only to that session in this Production/configuration, not other business paths. All paths remain monitored. Other sessions consume no requests under this grant. Previously completed, failed or skipped terminal reviews are not reassessed by a new approval.</p>
          <label className="field-label" htmlFor="demo-recipient">Business recipient (organization or team)</label>
          <Input id="demo-recipient" maxLength={200} value={premises.recipient} onChange={e => setPremises(p => ({ ...p, recipient: e.target.value, confirmed: false }))} />
          <label className="field-label" htmlFor="demo-relationship">Recipient relationship in the scenario</label>
          <select id="demo-relationship" value={premises.relationship} onChange={e => setPremises(p => ({ ...p, relationship: e.target.value, confirmed: false }))}>
            <option value="unknown">Unknown</option><option value="same_covered_entity">Same covered entity / internal team</option>
            <option value="another_provider">Another treating provider</option><option value="business_associate">Business associate</option><option value="external">Other external recipient</option>
          </select>
          <label className="field-label" htmlFor="demo-purpose">Actual intended use in the demo</label>
          <Textarea id="demo-purpose" maxLength={600} value={premises.purpose} onChange={e => setPremises(p => ({ ...p, purpose: e.target.value, confirmed: false }))} placeholder="Who uses the information, for which activity, and why these data are needed?" />
          <label className="field-label" htmlFor="demo-recipient-mapping">How do technical message hosts represent the business recipient?</label>
          <Textarea id="demo-recipient-mapping" maxLength={600} value={premises.recipient_mapping} onChange={e => setPremises(p => ({ ...p, recipient_mapping: e.target.value, confirmed: false }))} placeholder="For example: Source/Process are internal transport; Receiver represents the named clinic in this simulation. This is your demo mapping, not an automatically verified identity. Write unknown if not established." />
          <label className="field-label" htmlFor="demo-data-scope">Which data / patient / activity do these session messages concern?</label>
          <Textarea id="demo-data-scope" maxLength={600} value={premises.data_scope} onChange={e => setPremises(p => ({ ...p, data_scope: e.target.value, confirmed: false }))} placeholder="Explain whether the observed session's messages concern the same synthetic patient, approved activity and data scope. Do not enter patient values. Write unknown if not established." />
          <label className="field-label" htmlFor="demo-basis">Permission basis to be assessed (not a legal conclusion)</label>
          <select id="demo-basis" value={premises.permission_basis} onChange={e => setPremises(p => ({ ...p, permission_basis: e.target.value, confirmed: false }))}>
            <option value="unknown">Unknown</option><option value="treatment">Treatment</option><option value="healthcare_operations">Health care operations</option>
            <option value="individual_authorization">Individual authorization</option><option value="other">Other basis — explain below</option>
          </select>
          <label className="field-label" htmlFor="demo-authorization">Individual authorization in the scenario</label>
          <select id="demo-authorization" value={premises.authorization_status} onChange={e => setPremises(p => ({ ...p, authorization_status: e.target.value, confirmed: false }))}>
            <option value="unknown">Unknown / not checked</option><option value="present">Present — describe scope and validity below</option>
            <option value="absent">Explicitly absent in this scenario</option><option value="not_relied_upon">Not relied upon for the stated basis</option>
          </select>
          <p>Missing authorization is not automatically a violation: some permissions do not require it. “Present” alone does not establish that the authorization covers this use.</p>
          <label className="field-label" htmlFor="demo-permission-details">Data category and permission / authorization details</label>
          <Textarea id="demo-permission-details" maxLength={1000} value={premises.permission_details} onChange={e => setPremises(p => ({ ...p, permission_details: e.target.value, confirmed: false }))} placeholder="Ordinary data or separately maintained psychotherapy notes? Describe authorization parties, data, purpose, validity/revocation and any required remuneration statement, or other relied-upon permission. Use synthetic descriptions, not documents." />
          <label className="field-label" htmlFor="demo-safeguards">Safeguards and data necessity in this scenario</label>
          <Textarea id="demo-safeguards" maxLength={600} value={premises.safeguards} onChange={e => setPremises(p => ({ ...p, safeguards: e.target.value, confirmed: false }))} placeholder="Access, permitted fields, minimum-necessary scope when applicable, sharing or other relevant safeguards; unknown if not established." />
          <label className="field-label" htmlFor="demo-exceptions">Special restrictions, exceptions and relevant arrangements</label>
          <Textarea id="demo-exceptions" maxLength={600} value={premises.exceptions} onChange={e => setPremises(p => ({ ...p, exceptions: e.target.value, confirmed: false }))} placeholder="For example: notes-related exceptions, marketing payment/face-to-face conditions, relevant agreements. Explicitly state none or unknown as appropriate; do not assume every exception is excluded." />
          <p>Preparing the approval establishes these user-entered facts as the premises of this synthetic demo assessment. It does not certify real-world facts or choose the AI verdict.</p>
        </fieldset>}
        <label className="field-label" htmlFor="review-grant-key">New immutable authorization ID (letters, digits, hyphens; max 40)</label>
        <Input id="review-grant-key" maxLength={40} value={reviewKey} disabled={disabled || !!prepared} onChange={e => setReviewKey(e.target.value)} />
        <label className="field-label" htmlFor="review-source-agent">Exact eligible Agent</label>
        <select id="review-source-agent" value={agent} disabled={disabled || !!prepared} onChange={e => setAgent(e.target.value)}>
          <option value="">Select Agent revision</option>{plan?.agents.map(a => <option key={a.id} value={a.id}>{a.model} · {a.status} · revision {a.revision} · {a.id}</option>)}
        </select>
        <label className="field-label" htmlFor="review-every">Sample every N eligible session/body references</label>
        <Input id="review-every" type="number" min={1} max={1000} value={every} disabled={disabled || !!prepared} onChange={e => setEvery(e.target.value)} />
        <label className="field-label" htmlFor="review-maximum">Maximum selected reviews (two requests each)</label>
        <Input id="review-maximum" type="number" min={1} max={plan?.max_reviews || 20} value={maxReviews} disabled={disabled || !!prepared} onChange={e => setMaxReviews(e.target.value)} />
        <label className="field-label" htmlFor="review-expiry">Authorization lifetime (minutes, at most 1440)</label>
        <Input id="review-expiry" type="number" min={1} max={1440} value={minutes} disabled={disabled || !!prepared} onChange={e => setMinutes(e.target.value)} />
        <label className="confirmation-label"><input type="checkbox" checked={existing} disabled={disabled || !!prepared} onChange={e => setExisting(e.target.checked)} />Include previously unreviewed stored captures (not replays or reassessments).</label>
        <p>Explicit AI authorization permits export of minimized synthetic facts, user-approved demo premises and optional declared context only; real PHI is not authorized.</p>
        <label className="confirmation-label"><input type="checkbox" checked={cost} disabled={disabled || !!prepared} onChange={e => setCost(e.target.checked)} />I accept paid model costs up to the selected request-count limit; failures consume reserved budget.</label>
        <div className="form-actions"><Button variant="outline" disabled={disabled || !active || !planMatches || !cost || !!prepared} onClick={prepareConsent}>Prepare exact review authorization</Button>
          {!prepared && <AILogButton key={reviewKey} title={`AI log · authorization ${reviewKey || 'not selected'}`} load={() => grantLogs(reviewKey)} />}</div>
        {prepared && <>
          <p className="callout">Final confirmation: at most {prepared.max_reviews} reviews / {prepared.max_model_requests} model requests, expires {routeTime(prepared.expires_at)}. Granting this budget can enable background inference immediately. Production/configuration and Agent revision are pinned below.</p>
          {prepared.demo_premises && <p>Demo business premises for session {prepared.demo_premises.session_id} are frozen in this approval. The server records the confirming user and time. They will be used for HIPAA-condition reasoning within the simulation, not independently verified as real-world facts.</p>}
          <pre>{pretty(prepared)}</pre>
          <Button disabled={disabled || !active || !planMatches || plan?.config_hash !== prepared.config_hash || plan?.contract_hash !== prepared.contract_hash} onClick={() => { void act(async signal => {
            const body = consentRequest.current
            if (!body) throw new Error('Prepare exact consent first')
            const grant = await apiRequest('/productions/authorize-review', decodeGrant, signal, { authorization, body })
            checkScope(grant.production_id)
            if (grant.id !== body.authorization_id) throw new Error('Authorization identity mismatch')
            resetConsent(); setNotice(`Authorization ${grant.id} saved. Retries never replenish this budget; revoke it separately to stop future phases.`)
          }) }}>Confirm paid review authorization</Button>
          <AILogButton key={prepared.authorization_id} title={`AI log · authorization ${prepared.authorization_id}`} load={() => grantLogs(prepared.authorization_id)} />
          <Button variant="outline" disabled={busy} onClick={resetConsent}>Discard prepared consent</Button>
          <p>A failed or lost response is not proof that no grant was saved. Retry this same prepared ID/body or inspect the durable grants below; do not create a replacement ID to bypass the budget.</p>
        </>}
      </details>
      <h3>Durable AI authorization history</h3>
      {!reviews?.grants.length && <p>No AI authorization recorded for this Production.</p>}
      {reviews?.grants.map(g => <article className="monitor-card" key={g.id}>
        <h4>{g.id}</h4>
        <AILogButton key={g.id} title={`AI log · authorization ${g.id}`} load={() => grantLogs(g.id)} />
        <p>{!g.enabled ? 'Revoked' : plan && g.expires <= plan.now ? 'Expired' : g.config_hash !== record.current.config_hash ? 'Configuration mismatch' : 'Enabled until expiry'} · {g.used} / {g.max_reviews} review slots reserved ({g.used * 2} / {g.requests} model-request budget).</p>
        <p>Agent {g.agent} revision {g.revision} · every {g.every_n} eligible bodies · include previous captures: {g.include_existing ? 'Yes' : 'No'} · expires {routeTime(g.expires)} · actor {g.actor}</p>
        {g.premises && <section aria-label={`Saved demo premises ${g.id}`}>
          <h5>User-approved demo premises · session {g.premises.session_id}</h5>
          <p>Confirmed by {g.actor} · {routeTime(g.confirmed_at || 0)}. Established for this simulation, not independently verified.</p>
          <p>{g.premises.recipient} · {g.premises.relationship} · {g.premises.purpose}</p>
          <p>{g.premises.permission_basis} · authorization {g.premises.authorization_status}: {g.premises.permission_details}</p>
          <p>Safeguards: {g.premises.safeguards} · Special conditions: {g.premises.exceptions}</p>
          {g.premises.recipient_mapping !== undefined && <p>Technical-host / recipient mapping: {g.premises.recipient_mapping} · Message data scope: {g.premises.data_scope}</p>}
        </section>}
        <details><summary>Pinned authorization definition · {g.id}</summary><pre>{pretty(g.raw)}</pre></details>
        <p>Revoking {g.id} preserves spent/reserved budget and all results.</p>
        <Button variant="outline" disabled={disabled || !g.enabled} onClick={() => { if (!g.enabled) return; void act(async signal => {
          const value = await apiRequest('/productions/revoke-review', decodeGrant, signal, { authorization, body: { production_id: record.id, authorization_id: g.id } })
          checkScope(value.production_id); setNotice(`AI authorization ${g.id} revoked. No cancellation or refund of an in-flight/reserved request is implied.`)
        }) }}>Revoke AI authorization {g.id}</Button>
      </article>)}
    </Panel>
    <Panel title="Optional semantic context (never flow enrollment)">
      <p className="callout">Monitoring and review work without these records. Context supplies declared purpose, not verified downstream use, recipient acceptance or legal permission. Configured hosts are not discovered paths. Missing or ambiguous matches remain explicit.</p>
      {contexts?.items.map(c => <article className="monitor-card" key={c.id}>
        <h3>{String(c.config.title)} · revision {c.revision}</h3><p>{String(c.config.purpose)}</p>
        <details><summary>Exact saved context · {c.key}</summary><pre>{pretty(c.raw)}</pre></details>
        <Button variant="outline" disabled={disabled} onClick={() => editContext(c)}>Revise optional context {c.key}</Button>
      </article>)}
      {contexts && !contexts.items.length && <p>No optional context on this page. This does not exclude any component from observation or review.</p>}
      <div className="form-actions"><Button variant="outline" disabled={!contextAfter || busy} onClick={() => setContextAfter('')}>First context page</Button>
        <Button variant="outline" disabled={!contexts?.next_after || busy || !!readError} onClick={() => setContextAfter(contexts?.next_after || '')}>More optional contexts</Button>
        <Button variant="outline" disabled={disabled} onClick={() => editContext()}>Add optional declared context</Button></div>
      {configText && <form onSubmit={event => {
        event.preventDefault()
        if (disabled || !active) return
        void act(async signal => {
          const config = eventObject(JSON.parse(configText))
          if (!/^[A-Za-z][A-Za-z0-9_.-]{0,127}$/.test(contextKey)) throw new Error('Bounded literal context key required')
          const value = await apiRequest('/production-flows/save', decodeContext, signal, { authorization, body: {
            production_id: record.id, flow_key: contextKey, expected_revision: editing?.revision || 0, expected_digest: editing?.digest || '',
            production_config_hash: record.current.config_hash, config,
          } })
          checkScope(value.production_id); setConfigText(''); setEditing(undefined); setNotice(`Optional context revision ${value.revision} saved. No capture, model funding or replay was activated.`)
        })
      }}>
        <p>Advanced exact-contract editor. Use actual enabled component names and a catalogued synthetic recipient ID from <a href="/declarations">Declarations</a>. A declaration link is optional and must use its exact record ID/digest; null does not mean approval. Saved revisions never rewrite old evidence.</p>
        <label className="field-label" htmlFor="context-key">Optional context key</label>
        <Input id="context-key" value={contextKey} disabled={disabled || !!editing} onChange={e => setContextKey(e.target.value)} />
        <label className="field-label" htmlFor="context-config">Declared context JSON</label>
        <Textarea id="context-config" rows={18} value={configText} disabled={disabled} onChange={e => setConfigText(e.target.value)} />
        <p>Saving creates a new immutable context revision only; this is not flow enrollment or permission.</p>
        <Button type="submit" disabled={disabled || !active}>Save optional context revision</Button>
        <Button type="button" variant="outline" disabled={busy} onClick={() => { setConfigText(''); setEditing(undefined) }}>Cancel context editing</Button>
      </form>}
    </Panel>
  </section>
}

function CountTable({ title, values }: { title: string; values: Record<string, number> }) {
  return <><h3>{title}</h3><table className="data-table"><thead><tr><th>Disposition</th><th>Header count</th></tr></thead>
    <tbody>{Object.entries(values).map(([state, count]) => <tr key={state}><td>{state.replaceAll('_', ' ')}</td><td>{count}</td></tr>)}</tbody></table>
    {!Object.keys(values).length && <p>No dispositions yet; not a clean assessment.</p>}</>
}
