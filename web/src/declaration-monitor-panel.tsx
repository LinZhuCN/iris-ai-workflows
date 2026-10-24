import { useEffect, useRef, useState } from 'react'
import { AILogButton } from './components/ai-log'
import { Button } from './components/ui/button'
import { Textarea } from './components/ui/textarea'
import { Status } from './components/platform'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import { decodeDeclarationMonitor, decodeMonitorPlan } from './lib/declaration-monitor'
import type { DeclarationMonitor } from './lib/declaration-monitor'
import type { Execution } from './lib/declaration-execution'

export function DeclarationMonitorPanel({ run, authorization, canWrite }: { run: Execution; authorization: string; canWrite: boolean }) {
  const [item, setItem] = useState<DeclarationMonitor>(), [plan, setPlan] = useState<ReturnType<typeof decodeMonitorPlan>>()
  const [ack, setAck] = useState(false), [error, setError] = useState(''), [busy, setBusy] = useState(false)
  const [refresh, setRefresh] = useState(0), [reason, setReason] = useState('')
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  function bind(value: DeclarationMonitor) {
    if (value.id !== run.id || (value.evidence && (value.receipt_hash !== run.receipt?.receipt_hash ||
      value.evidence.record_id !== run.grant.record.id || value.evidence.revision !== run.grant.record.revision ||
      value.evidence.task_hash !== run.grant.consent.task_hash || value.evidence.decision_hash !== run.grant.consent.decision_hash))) {
      throw new Error('After-send review belongs to another batch or approved revision')
    }
    return value
  }
  useEffect(() => {
    const controller = new AbortController()
    void apiRequest(`/declarations/monitor/${encodeURIComponent(run.id)}`, decodeDeclarationMonitor, controller.signal, { authorization })
      .then(bind).then(value => { if (!controller.signal.aborted) { setItem(value); setError('') } })
      .catch((e: unknown) => { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Observer read failed') })
    return () => controller.abort()
  }, [run.id, authorization, refresh])
  useEffect(() => {
    if (item && !['running', 'blocked_budget'].includes(item.state)) return
    const timer = setInterval(() => setRefresh(n => n + 1), 5000)
    return () => clearInterval(timer)
  }, [item])
  async function action(work: (signal: AbortSignal) => Promise<void>) {
    const controller = new AbortController(); operation.current?.abort(); operation.current = controller
    setBusy(true); setError('')
    try { await work(controller.signal) }
    catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Monitoring action failed') }
    finally { if (!controller.signal.aborted) setBusy(false) }
  }
  const transitions = item?.event.state === 'open' ? ['in_review', 'ignored'] :
    item?.event.state === 'in_review' ? ['needs_information', 'resolved', 'ignored'] :
      item?.event.state === 'needs_information' ? ['in_review', 'resolved', 'ignored'] : ['open']
  return <section aria-label={`Post-send comparison ${run.grant.batch_id}`}>
    <h4>Automatic post-send comparison</h4>
    {error && <p className="callout" role="alert">{error} No monitoring success is assumed; refresh to retry the read.</p>}
    {!item && <p>Waiting for the independent observer to capture this delivered batch. This page does not start a review.</p>}
    {item && <>
      <p><Status tone={item.state === 'completed' ? 'success' : 'warning'}>{item.state}</Status> · {item.attempted_requests} attempted / {item.reserved_requests} reserved model requests.</p>
      <p>Observer scan: {item.heartbeat ? routeTime(item.heartbeat) : 'Not recorded'} · event {item.event.state} v{item.event.revision}</p>
      {(item.error || item.observer_error) && <p role="alert">{item.error} {item.observer_error}</p>}
      {item.state === 'blocked_budget' && <p>{item.authorized_requests ? 'Cost consent recorded. Waiting for the independent background worker; no page action is needed.'
        : 'The batch was automatically discovered and its evidence captured. AI comparison awaits separate cost consent; delivery is already complete.'}</p>}
      {item.state === 'blocked_budget' && !item.authorized_requests && !plan && <Button variant="outline" disabled={busy || !canWrite || !!error} onClick={() => { void action(async signal => {
        const value = await apiRequest(`/declarations/monitor/${encodeURIComponent(run.id)}/plan`, decodeMonitorPlan, signal, { authorization })
        if (value.consent.id !== item.id || value.consent.receipt_hash !== item.receipt_hash || value.consent.evidence_hash !== item.evidence_hash) throw new Error('Cost plan does not match captured evidence')
        setPlan(value); setAck(false)
      }) }}>Prepare post-send AI cost plan</Button>}
      {plan && <div><p>{plan.model} · at most 2 requests, separately charged. The background observer runs the comparison; no delivery replay or automatic retry.</p>
        <label className="confirmation-label"><input type="checkbox" checked={ack} disabled={busy} onChange={e => setAck(e.target.checked)} />I authorize up to 2 post-send model requests for this exact receipt.</label>
        <Button disabled={busy || !canWrite || !!error || !ack} onClick={() => { void action(async signal => {
          setItem(bind(await apiRequest('/declarations/monitor/authorize', decodeDeclarationMonitor, signal,
            { authorization, body: { ...plan.consent, acknowledge_cost: true } })))
          setPlan(undefined); setAck(false); setRefresh(n => n + 1)
        }) }}>Authorize automatic comparison</Button>
        <AILogButton key={run.id} title={`AI log · post-send ${run.id}`} report={item.report ?? item} /></div>}
      {!plan && <AILogButton key={run.id} title={`AI log · post-send ${run.id}`} report={item.report ?? item} />}
      {item.result && <div><h4>{item.result.summary.risk_detected ? 'Observed-use risk identified' : item.result.summary.unresolved ? 'Observed-use information required' : 'No deviation identified on checked use'}</h4>
        <ul>{item.result.missing_information.map(text => <li key={text}>{text}</li>)}</ul>
        {item.result.issues.map(issue => <section key={issue.question_id}><p>{issue.explanation}</p>
          <p>Applicability: {issue.applicability} · Condition: {issue.condition_status} · Exceptions: {issue.exceptions?.status}. {issue.exceptions?.explanation}</p>
          <p className="subtle">Facts: {issue.fact_ids.join(', ')}. Affirmative observed facts: {issue.affirmative_fact_ids?.join(', ')}.</p>
          {issue.citations.map(c => <details key={`${c.evidence_id}/${c.passage_id}`}><summary>{c.evidence_id} · {c.passage_id}</summary><blockquote>{c.quote}</blockquote></details>)}
        </section>)}</div>}
      {item.evidence && <p className="subtle">{item.evidence.limits}</p>}
      {item.report && <details><summary>After-send model provenance and raw phases</summary><p>{item.report.model} · {item.report.id}</p>
        <p className="mono">Contract: {item.report.contract}<br />Evidence: {item.evidence_hash}<br />Receipt: {item.receipt_hash}</p>
        {item.report.phases.map(p => <section key={p.session}><p>{p.phase} · {p.state} · Agent session {p.session}</p><pre>{p.usage}</pre><pre>{p.raw}</pre></section>)}</details>}
      <label className="field-label" htmlFor={`monitor-reason-${run.id}`}>Monitoring event review note</label>
      <Textarea id={`monitor-reason-${run.id}`} value={reason} maxLength={2000} disabled={busy || !canWrite} onChange={e => setReason(e.target.value)} />
      <div className="form-actions">{transitions.map(next => <Button variant="outline" key={next} disabled={busy || !canWrite || !!error || !reason.trim() || item.state === 'running'}
        onClick={() => { void action(async signal => {
          setItem(bind(await apiRequest('/declarations/monitor/action', decodeDeclarationMonitor, signal,
            { authorization, body: { id: item.id, revision: item.event.revision, action: next, text: reason } })))
          setReason('')
        }) }}>{next.replaceAll('_', ' ')}</Button>)}
        <Button variant="outline" disabled={busy} onClick={() => setRefresh(n => n + 1)}>Refresh comparison</Button></div>
      {item.event.actions.map((a, i) => <p key={i}>{routeTime(a.time)} · {a.actor}: {a.before} → {a.after} · {a.text}</p>)}
      <p className="subtle">Human event actions never modify the approval, deliver data, retry the model or turn an unfunded/failed review into a completed assessment.</p>
    </>}
  </section>
}
