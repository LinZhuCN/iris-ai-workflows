import { useEffect, useState } from 'react'
import { Button } from './components/ui/button'
import { Textarea } from './components/ui/textarea'
import { Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import { decodeRouteReviewDetail, decodeRouteReviews } from './lib/route-reviews'
import type { RouteReviewDetail, RouteReviewState } from './lib/route-reviews'

export function RouteReviewPanel({ authorization, canWrite }: { authorization: string; canWrite: boolean }) {
  const [state, setState] = useState<RouteReviewState>(), [detail, setDetail] = useState<RouteReviewDetail>()
  const [error, setError] = useState(''), [busy, setBusy] = useState(false), [reason, setReason] = useState('')
  const [cursor, setCursor] = useState('')
  const selectedId = detail?.id
  useEffect(() => {
    let active = true, running = false
    async function refresh() {
      if (running) return
      running = true
      try {
        const next = await apiRequest(`/route-reviews${cursor ? `?after=${encodeURIComponent(cursor)}` : ''}`, decodeRouteReviews, undefined, { authorization })
        const current = selectedId && next.items.some(item => item.id === selectedId)
          ? await apiRequest(`/route-reviews/${encodeURIComponent(selectedId)}`, decodeRouteReviewDetail, undefined, { authorization }) : undefined
        if (active) { setState(next); setDetail(current); setError('') }
      } catch (e) { if (active) setError(e instanceof Error ? e.message : 'Automatic review read failed') }
      finally { running = false }
    }
    void refresh()
    const timer = setInterval(() => { void refresh() }, 5000)
    return () => { active = false; clearInterval(timer) }
  }, [authorization, cursor, selectedId])

  async function inspect(id: string) {
    setBusy(true); setError('')
    try {
      setDetail(await apiRequest(`/route-reviews/${encodeURIComponent(id)}`, decodeRouteReviewDetail, undefined, { authorization }))
      setReason('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Review read failed'); setDetail(undefined) }
    finally { setBusy(false) }
  }
  async function transition(action: string) {
    if (!detail) return
    setBusy(true); setError('')
    try {
      setDetail(await apiRequest('/route-reviews', decodeRouteReviewDetail, undefined, {
        authorization, body: { id: detail.id, revision: detail.event.revision, action, text: reason },
      }))
      setReason('')
    } catch (e) { setError(e instanceof Error ? e.message : 'Human action failed') }
    finally { setBusy(false) }
  }
  const actions = detail?.event.state === 'open' ? ['in_review', 'ignored']
    : detail?.event.state === 'in_review' ? ['needs_information', 'resolved', 'ignored']
      : detail?.event.state === 'needs_information' ? ['in_review', 'resolved', 'ignored'] : ['open']
  const scenario = detail?.scenario

  return <Panel title="Automatic sidecar monitoring · AI Hub review">
    <p>Completed batches are discovered automatically by the background observer, not by opening this page.
      Reviews never block or replay delivery, activate a route, or change approval. This page only reads results and records human triage.</p>
    {error && <div className="callout" role="alert">{error} Previously loaded values may be stale.</div>}
    {state && <>
      <p><Status tone={state.enabled ? 'info' : 'neutral'}>{state.enabled ? 'Automatic observer enabled' : 'Observer not enabled'}</Status>
        {' '}Last successful scan: {state.heartbeat ? routeTime(state.heartbeat) : 'Not yet observed'} · worker {state.observer_identity || 'Not yet observed'}</p>
      {state.error && <div className="callout" role="alert">{state.error}</div>}
      <p className="subtle">New-batch model budget: 0. Unfunded batches are automatically captured as blocked_budget, not silently skipped.
        Exact batch-specific authorizations are listed below; reservations are never replenished or automatically retried.
        Synthetic approval is not a legal determination; a technical failure is not a privacy finding.</p>
      <ul>{Object.entries(state.authorizations).map(([id, grant]) => <li key={id}>{id}: {grant.reserved_requests} reserved / {grant.authorized_requests} explicitly authorized model requests</li>)}</ul>
      <div className="form-actions"><Button variant="outline" disabled={busy || !cursor} onClick={() => setCursor('')}>First review page</Button>
        <Button variant="outline" disabled={busy || !state.next_cursor} onClick={() => setCursor(state.next_cursor)}>Next 25 reviews</Button></div>
      {state.items.length === 0 && <p>No completed-batch observations recorded yet. This is not an all-clear.</p>}
      <div className="table-scroll"><table className="data-table"><thead><tr><th>Actual batch</th><th>Review</th><th>Event / human state</th><th>Model requests</th><th /></tr></thead>
        <tbody>{state.items.map(item => <tr key={item.id}><td>{item.route_kind}<br />{item.batch_id}<br />{item.runtime_version ?? 'staged-risk-v3'} · {item.trigger ?? 'original capture'}</td><td>{item.state}</td>
          <td>{item.event.category}<br />{item.event.state}</td><td>{item.actual_model_requests ?? (item.reserved_model_requests ? 'Not yet recorded' : 0)} attempted / {item.reserved_model_requests} reserved</td>
          <td><Button variant="outline" disabled={busy} onClick={() => { void inspect(item.id) }}>Inspect {item.id}</Button></td></tr>)}</tbody></table></div>
    </>}
    {detail && <div className="route-facts">
      <h3>{detail.batch_id} · {detail.state}</h3>
      <p>Reviewer: {detail.runtime_version ?? 'staged-risk-v3'} · Trigger: {detail.trigger ?? 'original automatic capture'}
        {detail.parent_review_id && <> · Preserved previous task: {detail.parent_review_id}</>}</p>
      <p>Declaration record: {detail.record_id ?? 'Evidence unavailable'} · pin basis: {detail.pin_basis ?? 'Unavailable'}</p>
      {scenario && <section aria-label="Policy, project and observation">
        <h3>1 · Organization policy and project approval</h3>
        <p>{scenario.organization_id} · {scenario.policy_id} v{scenario.policy_version}</p>
        <p>{scenario.permitted_use}</p>
        <p>Same simulated covered entity · controlled identifiable data. De-identification and patient signatures are not prerequisites of this scenario.</p>
        <h3>2 · Observed delivery</h3>
        <p>Revalidated messages, actual destination configuration and output scope are compared with the exact approval. The submitted purpose remains a claim, not proof of later conduct.</p>
        <h3>3 · Monitoring coverage</h3>
        <p>Later recipient conduct and overall legal compliance are outside this review, not automatically missing project prerequisites.</p>
      </section>}
      <p className="subtle">A first-observer pin detects later changes; it is not an independent pre-observation integrity guarantee.
        Original seeded batches use their independently saved receipt pins.</p>
      {detail.error && <div className="callout" role="alert">{detail.error}</div>}
      {detail.failure && <pre>{JSON.stringify(detail.failure, null, 2)}</pre>}
      {detail.result && <p className="callout">Scoped comparison within the synthetic organization scenario, not a legal certification.
        Structural/reference checks do not prove semantic accuracy. Findings and material gaps can be triaged below; a no-finding does not certify all future use.</p>}
      {detail.result && <section aria-label="Accepted scoped AI result">
        <h3>Scoped AI comparison · policy / approval / actual behavior</h3>
        <p><Status tone={detail.result.summary.risk_detected ? 'warning' : 'info'}>{detail.result.summary.risk_detected ? 'Risk signal reported' : 'No risk signal on checked issues'}</Status>
          {' '}<Status tone={detail.result.summary.unresolved ? 'warning' : 'neutral'}>{detail.result.summary.unresolved ? 'Unresolved questions remain' : 'No material gap reported on checked issues'}</Status></p>
        {detail.result.issues.map(issue => <div key={issue.question_id}>
          <h4>{issue.question_id} · {issue.status.replaceAll('_', ' ')}</h4><p>{issue.explanation}</p>
          {issue.applicability && <div>
            <p>Applicability: <strong>{issue.applicability}</strong> · Condition: <strong>{issue.condition_status}</strong></p>
            <p className="subtle">Applicability facts: {issue.applicability_fact_ids?.join(', ') || 'None established'} · Affirmative facts: {issue.affirmative_fact_ids?.join(', ') || 'None established'}</p>
            <p>Exceptions: {issue.exceptions?.status} · {issue.exceptions?.explanation}</p>
          </div>}
          <p className="subtle">Facts: {issue.fact_ids.join(', ')}</p>
          <details><summary>Checked source passages · {issue.citations.length} citations</summary>
            {issue.citations.map(citation => <div key={`${citation.evidence_id}/${citation.passage_id}`}>
              <p><strong>{citation.evidence_id} / {citation.passage_id}</strong></p><pre>{citation.quote}</pre>
            </div>)}</details>
        </div>)}
        {detail.result.missing_information.length > 0 ? <>
          <h4>Material information requested by the model</h4>
          <ul>{detail.result.missing_information.map(item => <li key={item}>{item}</li>)}</ul>
          <p className="subtle">These requests need human assessment; they are not proof that an applicable legal requirement failed.</p>
        </> : <p>No material missing information requested for this scoped comparison. This does not certify overall legal compliance.</p>}
      </section>}
      {detail.evidence && <details><summary>Bound declaration, approval, actual delivery and fact provenance</summary><pre>{JSON.stringify(detail.evidence, null, 2)}</pre></details>}
      <details><summary>AI Hub sessions, token counters and report linkage</summary><pre>{JSON.stringify({ report_id: detail.report_id, phases: detail.phases, current_admission_at_capture: detail.current_admission }, null, 2)}</pre></details>
      {detail.sources && <details><summary>Dated normative source provenance · not verified current law</summary><pre>{JSON.stringify(detail.sources, null, 2)}</pre></details>}
      <details><summary>Human event history · no business execution</summary><pre>{JSON.stringify(detail.event, null, 2)}</pre></details>
      <label className="field-label" htmlFor="route-review-reason">Human triage reason · retained locally, never sent to a model</label>
      <Textarea id="route-review-reason" maxLength={2000} value={reason} onChange={e => setReason(e.target.value)} />
      <div className="form-actions">{actions.map(action => <Button key={action} variant="outline"
        disabled={busy || !canWrite || !reason.trim() || detail.state === 'running'}
        onClick={() => { void transition(action) }}>Mark {action.replaceAll('_', ' ')}</Button>)}</div>
      <p className="subtle">Resolving/ignoring an event records a human workflow decision only. It does not certify compliance or authorize a send.</p>
    </div>}
  </Panel>
}
