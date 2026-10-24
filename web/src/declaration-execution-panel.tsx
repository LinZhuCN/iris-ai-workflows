import { useEffect, useRef, useState } from 'react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import { decodeExecution, decodeExecutionPlan, decodeExecutions, eligibleExecution, executionCommand, validBatch } from './lib/declaration-execution'
import type { Execution, ExecutionPlan } from './lib/declaration-execution'
import type { DeclarationRecord } from './lib/declarations'
import { DeclarationMonitorPanel } from './declaration-monitor-panel'

export function DeclarationExecutionPanel({ record, authorization, canWrite, readOnly }: {
  record: DeclarationRecord; authorization: string; canWrite: boolean; readOnly: boolean
}) {
  const [batch, setBatch] = useState(''), [plan, setPlan] = useState<ExecutionPlan>()
  const [confirmed, setConfirmed] = useState(false), [busy, setBusy] = useState(false)
  const [items, setItems] = useState<Execution[]>([]), [error, setError] = useState(''), [notice, setNotice] = useState('')
  const [refresh, setRefresh] = useState(0), [cursor, setCursor] = useState(''), [nextCursor, setNextCursor] = useState('')
  const [loading, setLoading] = useState(true), [readError, setReadError] = useState('')
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  useEffect(() => {
    const controller = new AbortController()
    setLoading(true)
    void apiRequest(`/declarations/${encodeURIComponent(record.id)}/executions${cursor ? `?before=${encodeURIComponent(cursor)}` : ''}`,
      decodeExecutions, controller.signal, { authorization }).then(value => {
      if (value.record_id !== record.id) throw new Error('Execution history belongs to another declaration')
      if (!controller.signal.aborted) { setItems(value.items); setNextCursor(value.next_cursor); setReadError('') }
    }).catch((e: unknown) => {
      if (!controller.signal.aborted) setReadError(e instanceof Error ? e.message : 'Execution history read failed')
    }).finally(() => { if (!controller.signal.aborted) setLoading(false) })
    return () => controller.abort()
  }, [authorization, record.id, cursor, refresh])
  const inFlight = items.some(item => ['reserved', 'running'].includes(item.state))
  useEffect(() => {
    if (!inFlight || busy || readError) return
    const timer = setInterval(() => setRefresh(value => value + 1), 5000)
    return () => clearInterval(timer)
  }, [inFlight, busy, readError])
  useEffect(() => {
    setPlan(undefined); setConfirmed(false)
  }, [record.digest, record.execution_state, record.latest_revision])
  const allowed = eligibleExecution(record), disabled = busy || loading || readOnly || !!readError
  async function act(work: (signal: AbortSignal) => Promise<void>) {
    operation.current?.abort()
    const controller = new AbortController(); operation.current = controller
    setBusy(true); setError(''); setNotice('')
    try { await work(controller.signal) }
    catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Execution failed') }
    finally { if (!controller.signal.aborted) setBusy(false) }
  }
  return <Panel title="Run an approved synthetic batch">
    <p>The supported recipe reads two synthetic Patient and two Encounter resources, projects seven approved fields with year-only birth dates,
      and writes one receipt through the existing UTILIZATION BS/BP/BO to its same-instance SQL receiver. No model is called.</p>
    {!allowed && <p className="subtle">Execution unavailable: {record.execution_state}. Only the latest current approved, valid, supported no-risk revision can authorize a new batch.</p>}
    {readError && <div role="alert" className="callout">{readError} Delivery controls are disabled until history refresh succeeds.</div>}
    {error && <div role="alert" className="callout">{error} A lost response is not proof of failure. Refresh receipt history with the same batch ID; never choose a new ID just to retry an uncertain send.</div>}
    {notice && <div role="status" className="callout">{notice}</div>}
    <form onSubmit={event => { event.preventDefault(); void act(async signal => {
      const value = await apiRequest(`/declarations/${encodeURIComponent(record.id)}/execution-plan?batch_id=${encodeURIComponent(batch)}`,
        decodeExecutionPlan, signal, { authorization })
      if (value.consent.record_id !== record.id || value.consent.digest !== record.digest || value.consent.batch_id !== batch ||
        value.consent.decision_hash !== record.decision?.record_hash) throw new Error('Execution plan does not match this exact approval')
      setPlan(value); setConfirmed(false)
    }) }}>
      <label className="field-label" htmlFor="execution-batch">New batch ID</label>
      <Input id="execution-batch" required maxLength={64} pattern={"[A-Za-z0-9\\-]{1,64}"} value={batch} disabled={disabled || !allowed || !canWrite}
        onChange={e => { setBatch(e.target.value); setPlan(undefined); setConfirmed(false) }} />
      <div className="form-actions"><Button type="submit" variant="outline" disabled={disabled || !canWrite || !allowed || !validBatch(batch)}>Prepare delivery plan</Button>
        <Button type="button" variant="outline" disabled={busy} onClick={() => { setPlan(undefined); setConfirmed(false); setRefresh(value => value + 1) }}>Refresh receipt history</Button></div>
    </form>
    {plan && <section aria-label="Exact synthetic delivery confirmation">
      <h3>Confirm actual synthetic delivery</h3>
      <p>{record.declaration_id} · revision {record.revision} · batch <strong>{plan.consent.batch_id}</strong>.
        {' '}{plan.max_records} resources → {plan.recipient} · {plan.recipe_id}.</p>
      <p>{plan.binding.namespace} / {plan.binding.production}: {plan.binding.source} → {plan.binding.sender}.</p>
      <p className="mono">Decision: {plan.consent.decision_hash}<br />Review: {plan.consent.task_id}<br />Configuration: {plan.consent.config_hash}</p>
      <label className="confirmation-label"><input type="checkbox" checked={confirmed} disabled={disabled} onChange={e => setConfirmed(e.target.checked)} />
        I confirm delivery of this synthetic batch against this exact approved revision.</label>
      <div className="form-actions"><Button disabled={disabled || !canWrite || !allowed || !confirmed} onClick={() => { void act(async signal => {
        const run = await apiRequest('/declarations/execute', decodeExecution, signal,
          { authorization, body: executionCommand(record, plan, confirmed) })
        if (run.grant.record.id !== record.id || run.grant.batch_id !== batch) throw new Error('Execution response belongs to another batch')
        setItems(previous => [run, ...previous.filter(item => item.id !== run.id)])
        setPlan(undefined); setConfirmed(false); setCursor(''); setRefresh(value => value + 1)
        setNotice(run.state === 'delivered' ? 'Synthetic delivery verified by SQL readback. No model called by delivery. The background observer independently captures the batch; AI comparison needs separate consent.'
          : 'Execution recorded without confirmed delivery. Inspect its state and refresh; no automatic replay.')
      }) }}>{busy ? 'Executing…' : 'Confirm and run synthetic batch'}</Button>
        <Button variant="outline" disabled={busy} onClick={() => { setPlan(undefined); setConfirmed(false) }}>Cancel delivery</Button></div>
    </section>}
    <h3>Linked execution receipts · this exact revision</h3>
    <div className="form-actions"><Button variant="outline" disabled={busy || !cursor} onClick={() => setCursor('')}>Latest 25 executions</Button>
      <Button variant="outline" disabled={busy || !nextCursor} onClick={() => setCursor(nextCursor)}>Older 25 executions</Button></div>
    {!items.length && <p>{loading ? 'Reading execution history…' : 'No batch has been authorized for this revision.'}</p>}
    {items.map(run => <section className="declaration-issue" key={run.id}>
      <h4>{run.grant.batch_id} · <Status tone={run.state === 'delivered' ? 'success' : 'warning'}>{run.state}</Status></h4>
      <p>Authorized by {run.grant.created_by} · {routeTime(run.grant.created_at)}.</p>
      {run.error && <div role="alert" className="callout">{run.error}</div>}
      <p className="mono">Execution: {run.id}<br />Grant: {run.grant_hash}</p>
      {run.receipt && <details><summary>Verified SQL receipt and declaration linkage</summary>
        <p>Delivered: {routeTime(run.receipt.received_at)} · SQL readback verified · {run.receipt.transport}.</p>
        <p>{Object.entries(run.receipt.inspection.resource_counts).map(([name, count]) => `${name}: ${count}`).join(' · ')}</p>
        <p>Actual fields: {run.receipt.inspection.field_paths.join(', ')}</p>
        <p className="mono">Declaration: {run.receipt.declaration_binding.record_id} · revision {run.receipt.declaration_binding.revision}<br />
          Decision: {run.receipt.declaration_binding.decision_hash}<br />IRIS session: {run.receipt.session_id} · source body: {run.receipt.message_id} · receiver body: {run.receipt.receiver_message_id}<br />
          Receipt: {run.receipt.receipt_hash}<br />Source: {run.receipt.source_hash}<br />Output: {run.receipt.output_hash}</p>
      </details>}
      {run.state === 'delivered' ? <DeclarationMonitorPanel run={run} authorization={authorization} canWrite={canWrite} />
        : <p className="subtle">Unconfirmed delivery is not reviewed as an observed successful batch.</p>}
    </section>)}
  </Panel>
}
