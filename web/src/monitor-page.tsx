import { useEffect, useState } from 'react'
import { Activity, Database, GitBranch, Server } from 'lucide-react'
import { Button } from './components/ui/button'
import { PageHeading, Panel, Stat, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeDeployment, decodeInstances, decodeMonitor, decodePipelineSummary, decodeSnapshot } from './lib/monitor'
import type { InstanceState, MonitorState } from './lib/monitor'
import { useAuth } from './auth'
import { AILogButton } from './components/ai-log'
import type { PipelineSummary, Snapshot } from './lib/monitor'
import { eventObject } from './lib/events'

export function matchingSnapshotSummary(snapshot?: Snapshot, summary?: PipelineSummary) {
  return snapshot && summary?.snapshot_id === snapshot.id && summary.config_hash === snapshot.config_hash ? summary : undefined
}
export function LiveMonitorPage({ path }: { path: string }) {
  const { authorization } = useAuth()
  const [instance, setInstance] = useState<InstanceState>()
  const [state, setState] = useState<MonitorState>()
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [confirmedPlan, setConfirmedPlan] = useState('')
  const [confirmedSummarySnapshot, setConfirmedSummarySnapshot] = useState('')
  const [notice, setNotice] = useState('')
  const title = path.startsWith('/instances') ? 'Instances' : path.startsWith('/demo') ? 'Synthetic demo' : 'Pipelines'

  useEffect(() => {
    if (!authorization) return
    let cancelled = false
    const controller = new AbortController()
    const refresh = async () => {
      try {
        const [value, connected] = await Promise.all([
          apiRequest('/pipelines', decodeMonitor, controller.signal, { authorization }),
          apiRequest('/instances', decodeInstances, controller.signal, { authorization }),
        ])
        if (!cancelled) { setState(value); setInstance(connected) }
      } catch (e) { if (!cancelled) setError(e instanceof Error ? e.message : 'Monitor refresh failed') }
    }
    void refresh()
    const timer = setInterval(() => { void refresh() }, 3000)
    const resume = () => { if (!document.hidden) void refresh() }
    window.addEventListener('focus', resume)
    document.addEventListener('visibilitychange', resume)
    return () => {
      cancelled = true; controller.abort(); clearInterval(timer)
      window.removeEventListener('focus', resume)
      document.removeEventListener('visibilitychange', resume)
    }
  }, [authorization])

  async function action(run?: () => Promise<void>) {
    setBusy(true); setError(''); setNotice('')
    try {
      if (run) await run()
      setInstance(await apiRequest('/instances', decodeInstances, undefined, { authorization }))
      const value = await apiRequest('/pipelines', decodeMonitor, undefined, { authorization })
      setState(value)
    } catch (e) { setError(e instanceof Error ? e.message : 'Monitor action failed') }
    finally { setBusy(false) }
  }
  const post = (body: object) => ({ authorization, body })
  const snapshot = state?.snapshot, plan = state?.deployment, canWrite = !!instance?.can_deploy

  return <div className="monitor-page">
    <PageHeading eyebrow="P2 · REAL CONNECTOR / SYNTHETIC BUSINESS DATA" title={title}
      description="A dedicated DEMO Production, authenticated HTTP Connector and durable observation transport. No patient data or external destination; AI summaries require explicit confirmation."
      action={<Button variant="outline" disabled={busy} onClick={() => { void action() }}>Refresh live status</Button>} />
    {error && <div className="callout" role="alert">{error}</div>}
    {notice && <div className="callout" role="status">{notice}</div>}
    {!instance ? <Panel title="Loading local demo instance"><p>Reading status using your workspace sign-in. Use Refresh live status to retry if needed.</p></Panel> : <>
      <div className="stats-grid">
        <Stat label="Instance" value="local-demo" note="Authenticated internal HTTP" icon={<Server size={17} />} />
        <Stat label="Namespace" value="DEMO" note={snapshot?.production || 'Discover the active Production'} icon={<Database size={17} />} />
        <Stat label="Deployment" value={plan?.state || (state ? 'Not deployed' : 'Unknown')} note="Active requires a received probe" icon={<GitBranch size={17} />} />
        <Stat label="Received observations" value={state ? String(state.received) : 'Unknown'} note="Durable inbox → platform service" icon={<Activity size={17} />} />
      </div>
      {path.startsWith('/instances') && <Panel title="Registered Connector" action={<Status tone="success">Connected</Status>}>
        <p className="mono body-copy">{instance.instance.iris_version}</p>
        <p>{instance.endpoint}</p>
        <p>Authorized namespaces: <strong>{instance.instance.namespaces.join(', ')}</strong>. Discovery does not enumerate other namespaces.</p>
        <div className="form-actions"><Button disabled={busy || !canWrite} onClick={() => { void action(async () => {
          await apiRequest('/instances/local-demo/discover', decodeSnapshot, undefined, post({}))
          setNotice('Immutable discovery snapshot saved. Open Pipelines to inspect and plan monitoring.')
        }) }}>Discover legacy DEMO configuration</Button><Button asChild variant="outline"><a href="/pipelines">Manage active Productions</a></Button><Button asChild variant="outline"><a href="/demo">Legacy DEMO connector</a></Button></div>
        {!canWrite && <p className="subtle">Reader account: viewing is allowed; discovery and deployment require the demo builder.</p>}
      </Panel>}
      {!state && <Panel title="Live status pending"><p>No successful status response yet. Use Refresh live status; errors are shown above.</p></Panel>}
      {state && !snapshot && <Panel title="Discovery required"><p>No snapshot yet. Use Instances → Discover active Production.</p></Panel>}
      {snapshot && !path.startsWith('/instances') && <>
        <Panel title="Live Production snapshot" action={<Status tone={snapshot.running ? 'success' : 'danger'}>{snapshot.running ? 'Running at discovery' : 'Stopped at discovery'}</Status>}>
          <p><strong>{snapshot.namespace} / {snapshot.production}</strong></p>
          <p><strong>Discovery-time description:</strong> {snapshot.summary}</p><p className="subtle">Description: {snapshot.summary_kind}, not LLM generated; independent of the optional AI assessment below. Snapshot time: {snapshot.observed_at} UTC.</p>
          <p className="mono subtle">Snapshot: {snapshot.id}<br />Config SHA-256: {snapshot.config_hash}</p>
          <div className="table-scroll"><table className="data-table"><thead><tr><th>Component</th><th>Class</th><th>Enabled</th><th>Pool</th></tr></thead><tbody>
            {snapshot.nodes.map(node => <tr key={node.name}><td>{node.name}</td><td className="mono">{node.class}</td><td>{node.enabled ? 'Yes' : 'No'}</td><td>{node.pool_size}</td></tr>)}
          </tbody></table></div>
          <h3>Confirmed routes</h3>
          {snapshot.edges.map(edge => <p key={`${edge.source}-${edge.target}`} className="body-copy"><strong>{edge.source} → {edge.target}</strong><br /><span className="subtle">{edge.basis}</span></p>)}
          <p className="subtle">Unknown routing: {snapshot.unknown_routing.join(', ') || 'None in this pinned demo. Arbitrary custom Production routing is not inferred.'}</p>
          <div className="form-actions"><Button variant="outline" disabled={busy || !canWrite} onClick={() => { void action(async () => {
            await apiRequest('/instances/local-demo/discover', decodeSnapshot, undefined, post({})); setConfirmedPlan('')
          }) }}>Refresh discovery</Button>
            <Button disabled={busy || !canWrite || !snapshot.supported} onClick={() => { void action(async () => {
              await apiRequest('/deployments/plan', decodeDeployment, undefined, post({ snapshot_id: snapshot.id })); setConfirmedPlan('')
            }) }}>Plan monitoring deployment</Button></div>
        </Panel>
        <Panel title="AI Hub pipeline summary" action={<Status tone={state?.summary?.state === 'completed' ? 'success' : 'info'}>{state?.summary?.state || 'Not requested'}</Status>}>
          <p className="body-copy">An actual AI Hub Agent explains this immutable snapshot. Only sanitized synthetic topology is sent; it has no tools or execution permissions. This may incur model charges.</p>
          {state?.summary && <>
            <p className="mono subtle">Snapshot: {state.summary.snapshot_id}<br />Config SHA-256: {state.summary.config_hash}<br />Model: {state.summary.model} · AI Hub session: {state.summary.agent_session || 'Not created yet'}</p>
            {state.summary.result && <><p className="body-copy">{state.summary.result.summary}</p><ul>{state.summary.result.limitations.map((item, i) => <li key={i}>{item}</li>)}</ul></>}
            {state.summary.error && <p role="alert">{state.summary.error}</p>}
            {state.summary.usage && <p className="mono subtle">SDK usage: {JSON.stringify(state.summary.usage)}</p>}
          </>}
          <label className="knowledge-confirm"><input type="checkbox" checked={confirmedSummarySnapshot === snapshot.id} onChange={e => setConfirmedSummarySnapshot(e.target.checked ? snapshot.id : '')} />Allow one real model invocation for this synthetic snapshot; possible model charges.</label>
          <div className="form-actions"><Button disabled={busy || !canWrite || !snapshot.supported || confirmedSummarySnapshot !== snapshot.id || ['queued', 'running'].includes(state?.summary?.state || '')} onClick={() => { void action(async () => {
            await apiRequest('/pipelines/summary', decodePipelineSummary, undefined, post({ snapshot_id: snapshot.id, acknowledge_cost: true }))
            setConfirmedSummarySnapshot('')
          }) }}>Generate AI Hub summary</Button><AILogButton key={`${snapshot.id}-${snapshot.config_hash}-${state?.summary?.id ?? ''}`}
            report={matchingSnapshotSummary(snapshot, state?.summary)} title="Selected discovery snapshot summary"
            load={matchingSnapshotSummary(snapshot, state?.summary) ? async () => apiRequest('/pipelines', value => {
              const saved = eventObject(value).summary
              const decoded = decodePipelineSummary(saved)
              if (!matchingSnapshotSummary(snapshot, decoded) || decoded.id !== state?.summary?.id) throw new Error('Saved summary does not match this exact snapshot execution')
              return saved
            }, undefined, { authorization }) : undefined} /></div>
          <p className="subtle">A failed model call stays failed; deterministic descriptions above are never substituted as an AI result. Refreshing discovery creates a new snapshot and does not reuse this summary silently.</p>
        </Panel>
        {plan && <Panel title="Review and deploy" action={<Status tone={plan.state === 'active' ? 'success' : 'warning'}>{plan.state}</Status>}>
          <p>{plan.diff}</p><p>{plan.impact}</p><p className="subtle">{plan.compensation}</p>
          <p className="mono subtle">Plan: {plan.id}<br />Exact approval digest: {plan.digest}<br />Snapshot: {plan.snapshot_id}</p>
          {plan.error && <p role="alert">{plan.error}</p>}
          {plan.probe && <p className="mono subtle">Probe message {plan.probe.message_id} · observation {plan.probe.observation_id}</p>}
          {plan.state === 'planned' && <label className="knowledge-confirm"><input type="checkbox" checked={confirmedPlan === plan.id} onChange={e => setConfirmedPlan(e.target.checked ? plan.id : '')} />Approve this exact plan for the synthetic DEMO Production only.</label>}
          <div className="form-actions">
            <Button disabled={busy || !canWrite || confirmedPlan !== plan.id || plan.state !== 'planned'} onClick={() => { void action(async () => {
              await apiRequest(`/deployments/${plan.id}/approve`, decodeDeployment, undefined, post({ digest: plan.digest })); setConfirmedPlan('')
            }) }}>Approve exact plan</Button>
            <Button disabled={busy || !canWrite || !['approved', 'unknown', 'verifying'].includes(plan.state)} onClick={() => { void action(async () => {
              await apiRequest(`/deployments/${plan.id}/apply`, decodeDeployment, undefined, post({ digest: plan.digest }))
            }) }}>{plan.state === 'unknown' ? 'Reconcile same deployment' : 'Apply and verify probe'}</Button>
          </div>
          <p className="subtle">No Production stop/restart. Only the preinstalled observer is configured; policy enforcement is not enabled.</p>
        </Panel>}
        <Panel title="Run synthetic messages">
          <p>Send a new message through the real DemoRouter and local sink. Observations refresh every 3 seconds. A destination failure is intentional and never calls a real system.</p>
          <div className="form-actions">{(['treatment', 'analytics', 'failure'] as const).map(scenario => <Button key={scenario} variant="outline" disabled={busy || !canWrite || plan?.state !== 'active'} onClick={() => { void action(async () => {
            await apiRequest('/demo/messages', value => {
              if (!value || typeof value !== 'object' || !('message_id' in value)) throw new Error('Invalid synthetic message receipt')
              if (!('capture_state' in value) || value.capture_state !== 'queued') throw new Error(`Synthetic message ${String(value.message_id)} ran, but its observation was not captured. Inspect coverage counters; do not replay the business message.`)
              setNotice(`Synthetic ${scenario} message ${String(value.message_id)} completed; observation delivery is asynchronous.`)
              return value
            }, undefined, post({ scenario }))
          }) }}>Send {scenario}</Button>)}</div>
        </Panel>
      </>}
      {state && <Panel title="Observation transport" action={<Status tone={state.transport.pending || state.transport.dropped || state.receiver_paused || state.transport.source_state !== 'live' || state.consumer_age_seconds > 15 ? 'warning' : 'success'}>{state.receiver_paused ? 'Receiver outage enabled' : state.transport.source_state !== 'live' || state.consumer_age_seconds > 15 ? 'Stale worker heartbeat' : state.transport.dropped ? 'Coverage gap' : state.transport.pending ? 'Pending delivery' : 'Queue drained'}</Status>}>
        <p>Seen: {state.transport.seen} · Before monitoring: {state.transport.not_monitored} · Pending: {state.transport.pending} · Retrying: {state.transport.retrying} · Dropped: {state.transport.dropped}</p>
        <p className="subtle">Source heartbeat: {state.transport.heartbeat || 'Not yet available'} UTC · Outbox capacity: 1,000 · Capped retry backoff: 30 seconds.</p>
        {state.transport.last_error && <p className="callout">Transport error: {state.transport.last_error}</p>}
        <div className="form-actions"><Button variant="outline" disabled={busy || !canWrite} onClick={() => { void action(async () => {
          await apiRequest('/demo/transport', value => value, undefined, post({ paused: !state.receiver_paused }))
        }) }}>{state.receiver_paused ? 'Restore demo receiver' : 'Simulate demo receiver outage'}</Button></div>
        <p className="subtle">Outage returns real HTTP 503 to the source. Business messages continue; observations remain in the source outbox and retry after restoration.</p>
      </Panel>}
      {state && <Panel title="Received observations · latest 50">
        <div className="table-scroll"><table className="data-table"><thead><tr><th>Scenario / outcome</th><th>Source message / session</th><th>Observation / deployment</th></tr></thead><tbody>
          {state.observations.map(o => <tr key={o.observation_id}><td>{o.scenario}<br /><Status tone={o.outcome === 'failed' ? 'danger' : 'success'}>{o.outcome}</Status></td>
            <td className="mono">{o.message_id} / {o.session_id}</td><td className="mono">{o.observation_id}<br /><span className="subtle">{o.deployment_id}</span></td></tr>)}
        </tbody></table></div>
        {!state.observations.length && <p>No observation received yet. An empty result is not replaced with fixture data.</p>}
      </Panel>}
    </>}
  </div>
}
