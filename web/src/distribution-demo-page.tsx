import { useEffect, useRef, useState } from 'react'
import { useAuth } from './auth'
import { PageHeading, Panel, Status, Steps } from './components/platform'
import { Button } from './components/ui/button'
import { AILog, AILogButton } from './components/ai-log'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import {
  decodeDistributionRun, decodeDistributionState, decodeSeedResult, distributionAuditRequest, distributionRunRequest, distributionAuditSummary,
  type DistributionAudit, type DistributionBranch, type DistributionRun, type DistributionState, type Json, type ProfileRecord,
} from './lib/multi-organization'

function errorText(error: unknown) { return error instanceof Error ? error.message : 'Distribution request failed' }
function hasAudit(run: DistributionRun) { return run.audit_state !== undefined || run.branches.some(branch => branch.audit !== undefined) }
export function JsonEvidence({ title, value, id }: { title: string; value: Json; id?: string }) {
  return <details id={id}><summary>{title}</summary><pre className="overflow-auto">{JSON.stringify(value, null, 2)}</pre></details>
}
export function distributionAuditNotice(run: DistributionRun): string {
  return ['queued', 'running'].includes(run.audit_state ?? '') || run.branches.some(branch => branch.audit && ['queued', 'running', 'pending'].includes(branch.audit.state))
    ? 'Audit authorized; waiting for saved results. Branch progress refreshes automatically; no additional authorization is needed.'
    : 'Audit results saved. Read each Result / Why / Next step; unresolved or failed reviews are not no-risk findings.'
}
export function DistributionAuditResult({ audit }: { audit?: DistributionAudit }) {
  if (!audit) return <div><h4>Result: Not reviewed</h4><p>Why: No AI audit record exists for this branch.</p><p>Next: Separately authorize a bounded advisory audit if needed.</p></div>
  const labels: Record<string, string> = {
    risk_identified: 'Potential risk identified', information_required: 'More information needed',
    not_assessed: 'Not assessed',
    no_signal_on_checked_issues: 'No signal on checked issues',
  }
  const completed = ['completed', 'completed_with_errors'].includes(audit.state)
  const notAssessed = !completed || !audit.assessment || audit.assessment === 'not_assessed'
  const outcome = notAssessed ? 'Not assessed' : labels[audit.assessment]
  const summary = distributionAuditSummary(audit)
  return <div>
    <h4>Result: {outcome} <Status tone={['failed', 'interrupted'].includes(audit.state) ? 'danger' : notAssessed ? 'warning' : 'neutral'}>{audit.state}</Status></h4>
    {audit.assessment && <p>Recorded assessment code: <code>{audit.assessment}</code></p>}
    {notAssessed && <p>No completed AI conclusion is available. A model or report-contract failure is not an information-required finding or a no-risk result.</p>}
    <p>Why: {summary.reason || 'No explanation has been recorded. This is not a no-risk result.'}</p>
    {(summary.unresolved !== undefined || summary.missing.length > 0) && <div>
      <h4>Unresolved conditions and missing information (separate from identified risk)</h4>
      <p>{summary.unresolved === true ? 'The AI report explicitly retains unresolved conditions.'
        : summary.unresolved === false ? 'The AI report marks unresolved conditions false.' : 'The AI report did not provide a valid unresolved-condition flag.'}</p>
      {summary.missing.length > 0 && <ul>{summary.missing.map((item, index) => <li key={index}>{item}</li>)}</ul>}
    </div>}
    <p>Next: {audit.next_step || 'Inspect the audit state and evidence; request human review before acting.'}</p>
    <p>Report: {audit.report_id || 'Not yet assigned'} · Model requests: {audit.model_requests} / 6 per run</p>
    <AILog report={audit.raw} />
    <details><summary>Complete recorded explanation</summary><p>{audit.explanation || 'No explanation recorded.'}</p></details>
    <JsonEvidence title="Raw advisory report, citations and preserved model output" value={audit.raw} />
  </div>
}
export function DistributionBranchEvidence({ branch, profile }: { branch: DistributionBranch; profile?: ProfileRecord }) {
  return <Panel title={`${branch.organization} · ${branch.protocol} · ${branch.namespace}`}>
    <p><Status tone={branch.error ? 'danger' : 'info'}>{branch.state}</Status> · <a href={`#snapshot-${branch.id}`}>Pinned organization snapshot</a> · <a href={`/organizations#organization-${branch.id}`}>Current organization profile</a></p>
    {branch.error && <p role="alert">Delivery error: {branch.error}</p>}
    <p>Message ID: {branch.message_id || 'Not recorded'} · Header ID: {branch.header_id || 'Not recorded'} · Session ID: {branch.session_id || 'Not recorded'}</p>
    <p className="break-all">Immutable evidence hash: <code>{branch.evidence_hash || 'Not captured'}</code></p>
    {profile ? <div>
      <h4>Declared receiving policy · immutable profile revision {profile.revision}</h4>
      <p>Allowed fields: {profile.profile.allowed_fields.join(', ') || 'None declared'}</p>
      <p>Prohibited fields: {profile.profile.prohibited_fields.join(', ') || 'None declared'}</p>
      <p>Purpose: {profile.profile.purpose}</p>
      <p>Requirements: {profile.profile.requirements}</p>
      <p className="break-all">Pinned profile hash: <code>{profile.hash}</code></p>
    </div> : <p>No pinned receiving profile supplied; allowed-versus-actual comparison is incomplete.</p>}
    <p>Actually sent fields: {branch.fields.length ? branch.fields.join(', ') : 'No field inventory captured; coverage gap.'}</p>
    <p className="break-all">Payload hash: <code>{branch.payload_hash || 'Not captured'}</code></p>
    <h4>Receiving-policy comparison (not a HIPAA assessment)</h4>
    {branch.policy_mismatches.length ? <ul>{branch.policy_mismatches.map((item, index) => <li key={`${index}-${item}`}>{item}</li>)}</ul>
      : <p>No policy mismatches recorded. This does not establish legal compliance or complete evidence coverage.</p>}
    {branch.receipt !== undefined && branch.receipt !== null
      ? <JsonEvidence title="Receiver receipt JSON — inspect correlated acceptance evidence" value={branch.receipt} />
      : <p>No receiver receipt captured. Delivery is not independently confirmed.</p>}
    <p>A transport acknowledgement is not proof of subsequent clinical use.</p>
    <DistributionAuditResult audit={branch.audit} />
  </Panel>
}
export function DistributionRunEvidence({ run }: { run: DistributionRun }) {
  const profiles = Object.entries(run.profiles)
  return <section aria-label="Persisted distribution run evidence">
    <Panel title={`Run ${run.id}`}>
      <p><Status tone={run.error ? 'danger' : 'info'}>{run.state}</Status> · {run.variant} · Created {typeof run.created_at === 'number' ? routeTime(run.created_at) : run.created_at}</p>
      <p>Receiver receipts captured: {run.branches.filter(branch => branch.receipt !== undefined && branch.receipt !== null).length} / {run.branches.length} recorded branches (3 expected).</p>
      {run.error && <p role="alert">{run.error}</p>}
      {run.audit_state && <p>AI audit status: <Status tone={['failed', 'interrupted', 'completed_with_errors'].includes(run.audit_state) ? 'danger' : 'info'}>{run.audit_state}</Status>. Delivery status is separate; inspect each branch assessment below.</p>}
      {run.audit_error && <p role="alert">AI audit error: {run.audit_error}</p>}
      <p><a href="#run-source-pins">Inspect FHIR source IDs, versions and source pins</a> · <a href="#run-profile-snapshots">Inspect immutable organization snapshots</a></p>
      <JsonEvidence id="run-source-pins" title="FHIR source pins and captured source evidence" value={run.source_pins} />
      <div id="run-profile-snapshots">
        <h3>Organizations and policies pinned to this run</h3>
        <p>These historical snapshots do not change when the current catalog is edited. Compare allowed and prohibited fields here with actual branch inventories below.</p>
        {profiles.map(([id, value]) => <JsonEvidence key={id} id={`snapshot-${id}`} title={`${id} — pinned profile, revision, confirmation and hash`} value={value} />)}
        {profiles.length === 0 && <p>No profile snapshots recorded; this is an evidence gap.</p>}
      </div>
    </Panel>
    {run.branches.length === 0 && <p role="status">No branch evidence recorded yet. This is not successful delivery.</p>}
    {run.branches.map(branch => <DistributionBranchEvidence key={branch.id} branch={branch} profile={run.profiles[branch.id]} />)}
  </section>
}

export function DistributionDemoPage() {
  const { authorization } = useAuth()
  const [state, setState] = useState<DistributionState>()
  const [selected, setSelected] = useState(() => new URLSearchParams(location.search).get('run') ?? '')
  const [run, setRun] = useState<DistributionRun>()
  const [refresh, setRefresh] = useState(0)
  const [readError, setReadError] = useState(''), [detailError, setDetailError] = useState(''), [actionError, setActionError] = useState('')
  const [busy, setBusy] = useState<'seed' | 'run' | 'audit' | null>(null)
  const [costConfirmed, setCostConfirmed] = useState(false)
  const [variant, setVariant] = useState<DistributionRun['variant']>('identifier-leak')
  const [runId, setRunId] = useState(() => `multi-${crypto.randomUUID()}`)
  const [seedResult, setSeedResult] = useState<{ [key: string]: Json }>()
  const [auditRequested, setAuditRequested] = useState<Set<string>>(() => new Set())
  const [notice, setNotice] = useState('')
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  useEffect(() => {
    const controller = new AbortController()
    let timer: ReturnType<typeof setTimeout>
    async function load() {
      try {
        const value = await apiRequest('/distribution', decodeDistributionState, controller.signal, { authorization })
        if (!controller.signal.aborted) {
          setState(value); setReadError(''); setSelected(previous => previous || value.runs[0]?.id || '')
        }
      } catch (error) { if (!controller.signal.aborted) setReadError(errorText(error)) }
      finally { if (!controller.signal.aborted) timer = setTimeout(() => { void load() }, 5000) }
    }
    void load()
    return () => { controller.abort(); clearTimeout(timer) }
  }, [authorization, refresh])
  useEffect(() => {
    if (!selected) return
    const controller = new AbortController()
    let timer: ReturnType<typeof setTimeout>
    async function load() {
      try {
        const value = await apiRequest(`/distribution/runs/${encodeURIComponent(selected)}`, decodeDistributionRun, controller.signal, { authorization })
        if (value.id !== selected) throw new Error('Run response identity does not match the selected run.')
        if (!controller.signal.aborted) { setRun(value); setDetailError('') }
      } catch (error) { if (!controller.signal.aborted) setDetailError(errorText(error)) }
      finally { if (!controller.signal.aborted) timer = setTimeout(() => { void load() }, 3000) }
    }
    void load()
    return () => { controller.abort(); clearTimeout(timer) }
  }, [authorization, selected, refresh])
  function chooseRun(id: string) {
    setSelected(id); setRun(undefined); setDetailError(''); setCostConfirmed(false)
    setActionError(''); setNotice('')
    history.replaceState(null, '', `/demo?run=${encodeURIComponent(id)}`)
  }
  async function act(kind: NonNullable<typeof busy>, work: (signal: AbortSignal) => Promise<void>) {
    if (operation.current || !state?.can_manage || readError) return
    const controller = new AbortController(); operation.current = controller
    setBusy(kind); setActionError(''); setNotice('')
    try { await work(controller.signal) }
    catch (error) {
      if (!controller.signal.aborted) setActionError(`${errorText(error)} The server may have retained partial progress. Refresh and inspect this run before any manual retry; nothing is automatically retried.`)
    } finally {
      operation.current = null
      if (!controller.signal.aborted) { setBusy(null); setRefresh(value => value + 1) }
    }
  }
  const enabled = !!state?.can_manage && !readError && !busy
  const currentRun = run?.id === selected ? run : undefined
  const existingRun = state?.runs.some(item => item.id === runId) || currentRun?.id === runId
  const auditing = (currentRun?.audit_state && ['queued', 'running'].includes(currentRun.audit_state))
    || currentRun?.branches.some(branch => branch.audit && ['queued', 'running', 'pending'].includes(branch.audit.state))
  const canAudit = enabled && !!currentRun && !detailError && ['completed', 'partial', 'failed'].includes(currentRun.state)
    && currentRun.branches.some(branch => branch.state === 'acknowledged' && branch.receipt != null) && !hasAudit(currentRun) && !auditRequested.has(currentRun.id)
  return <div className="monitor-page" aria-busy={busy !== null}>
    <PageHeading eyebrow="MULTI-ORGANIZATION · LOCAL SYNTHETIC DEMO" title="FHIR distribution and advisory audit"
      description="Read synthetic FHIR data, distribute actual outputs over SQL, REST and HL7, then separately authorize a bounded post-send AI review."
      action={<><Button asChild><a href="/demo/m5">Start fixed M5 onboarding</a></Button><Button asChild variant="outline"><a href="/organizations">Organization profiles</a></Button><Button asChild variant="outline"><a href="/demo/legacy">Legacy Live Monitor demo</a></Button><Button variant="outline" onClick={() => setRefresh(value => value + 1)}>Refresh server state</Button></>} />
    <p className="callout">Synthetic data and owned local receivers only. The identifier-leak variant intentionally retains synthetic research identifiers. This is post-send advisory review: it does not block delivery, authorize disclosure, change Production configuration or certify HIPAA compliance. No automatic model calls or paid retries.</p>
    <Steps labels={['Save organizations', 'Prepare demo data', 'Run distribution', 'Run AI audit']} current={currentRun ? 2 : 0} />
    {(readError || detailError || actionError) && <div role="alert" className="callout">
      {readError && <p>Server readiness unavailable: {readError}. Actions are disabled until a successful refresh.</p>}
      {detailError && <p>Run refresh failed: {detailError}. Previously captured evidence may be stale.</p>}
      {actionError && <p>{actionError}</p>}
    </div>}
    {notice && <p role="status">{notice.startsWith('Audit authorized;') && currentRun ? distributionAuditNotice(currentRun) : notice}</p>}
    <Panel title="Real server readiness">
      {!state ? <p role="status">Checking deployed services and organization confirmations…</p> : <>
        <p><Status tone={readError ? 'danger' : state.ready ? 'success' : 'warning'}>{readError ? 'Readiness unknown' : state.ready ? 'Server reports ready' : 'Not ready'}</Status></p>
        {!state.can_manage && <p>Read-only account: seed, distribution and paid audit require a builder.</p>}
        <ul>{state.readiness.map(item => <li key={item.name}><Status tone={item.ready ? 'success' : 'warning'}>{item.ready ? 'Ready' : 'Blocked'}</Status> {item.name}: {item.detail}</li>)}</ul>
        {state.readiness.length === 0 && <p>No detailed readiness checks were supplied. Do not infer provisioning success.</p>}
      </>}
      <p>Missing infrastructure must be provisioned by an administrator outside this UI. Confirm editable synthetic profiles on the <a href="/organizations">Organizations page</a>.</p>
    </Panel>
    <Panel title="1. Prepare demo data">
      <p>Load the fixed synthetic patient into FHIRDEMO. No distribution or model calls.</p>
      <Button disabled={!enabled} onClick={() => { void act('seed', async signal => {
        const value = await apiRequest('/distribution/seed', decodeSeedResult, signal, { authorization, body: { confirmed: true } })
        if (!signal.aborted) { setSeedResult(value); setNotice('Synthetic source load returned resource IDs. No distribution or AI audit was requested.') }
      }) }}>{busy === 'seed' ? 'Loading synthetic source…' : 'Prepare demo data'}</Button>
      {seedResult && <JsonEvidence title="Seed result and source resource IDs" value={seedResult} />}
    </Panel>
    <Panel title="2. Distribute to the three local receivers">
      <label className="field-label" htmlFor="distribution-variant">Research-output variant</label>
      <select id="distribution-variant" disabled={!!busy} value={variant} onChange={event => {
        setVariant(event.target.value as DistributionRun['variant'])
      }}>
        <option value="identifier-leak">Identifier leak — intentional synthetic policy contradiction</option>
        <option value="corrected">Corrected research output — removes the selected identifiers</option>
      </select>
      <p>{variant === 'identifier-leak' ? 'Unsafe synthetic example: research output retains name, MRN and full birth date, restricted to the owned local receiver.'
        : 'Comparison example: removing selected identifiers alone does not prove full Safe Harbor compliance.'}</p>
      <p className="break-all">Stable request ID: <code>{runId}</code></p>
      <Button variant="outline" disabled={!!busy} onClick={() => setRunId(`multi-${crypto.randomUUID()}`)}>Prepare a new run ID</Button>
      <p>Sends the selected case to DEMOQUALITY (SQL), DEMORESEARCH (REST) and DEMOCLINIC (HL7). No AI calls.</p>
      <Button disabled={!enabled || !state?.ready || !!existingRun} onClick={() => { void act('run', async signal => {
        chooseRun(runId)
        const value = await apiRequest('/distribution/run', decodeDistributionRun, signal, { authorization, body: distributionRunRequest(runId, variant, true) })
        if (value.id !== runId || value.variant !== variant) throw new Error('Distribution response does not match the confirmed run.')
        if (!signal.aborted) {
          chooseRun(value.id); setRun(value)
          setNotice('Distribution accepted. Inspect per-branch status and receipts below; no AI audit was requested.')
        }
      }) }}>{busy === 'run' ? 'Distributing synthetic data…' : 'Run distribution'}</Button>
      {existingRun && <p>This request ID already has a run. Inspect its persisted evidence; completed branches are not replayed here.</p>}
    </Panel>
    <Panel title="3. Persisted runs and separate AI cost authorization">
      <label className="field-label" htmlFor="distribution-run-choice">Saved distribution run</label>
      <select id="distribution-run-choice" disabled={!!busy} value={selected} onChange={event => chooseRun(event.target.value)}>
        <option value="">Select a persisted run</option>
        {selected && !state?.runs.some(item => item.id === selected) && <option value={selected}>{selected}</option>}
        {state?.runs.map(item => <option key={item.id} value={item.id}>{item.id} · {item.variant} · {item.state}</option>)}
      </select>
      {!selected && <p>No run selected. The latest saved run is loaded automatically when available; refreshing never re-sends data or calls a model.</p>}
      {selected && !currentRun && <p role="status">Loading persisted run evidence…</p>}
      <p>Authorize at most 3 branch reviews and {state?.model_request_limit ?? 6} model requests total for this run. AI audit can take approximately 180 seconds. It is advisory and does not retry automatically.</p>
      <label className="confirmation-label"><input type="checkbox" checked={costConfirmed} disabled={!canAudit} onChange={event => setCostConfirmed(event.target.checked)} />
        I acknowledge model charges for this exact saved run, bounded to 3 reviews and 6 model requests.
      </label>
      <Button disabled={!canAudit || !costConfirmed} onClick={() => { if (!currentRun || !canAudit || !costConfirmed) return; void act('audit', async signal => {
        const id = currentRun.id
        setAuditRequested(previous => new Set([...previous, id]))
        const value = await apiRequest('/distribution/audit', decodeDistributionRun, signal, {
          authorization, body: distributionAuditRequest(id, costConfirmed, true),
        })
        if (value.id !== id) throw new Error('Audit response does not match the authorized run.')
        if (!signal.aborted) {
          setRun(value); setCostConfirmed(false)
          setNotice(distributionAuditNotice(value))
        }
      }) }}>{busy === 'audit' ? 'AI audit running — please wait (up to ~180 seconds)…' : 'Run AI audit'}</Button>
      <AILogButton key={currentRun?.id ?? 'no-run'} title={`AI log · ${currentRun?.id ?? 'select a run'}`}
        report={currentRun?.branches.map(branch => branch.audit?.raw).filter(value => value !== undefined)} />
      {(busy === 'audit' || auditing) && <p role="status">Audit is in progress. Server state and branch evidence continue refreshing. Do not repeat the authorization if the request is interrupted; inspect the saved run first.</p>}
      {currentRun && hasAudit(currentRun) && <p>An audit record already exists. Preserved pending, completed or failed results are shown below; this page never automatically purchases a retry.</p>}
      {currentRun && auditRequested.has(currentRun.id) && !hasAudit(currentRun) && <p role="status">Audit authorization was requested for this run. Await its persisted audit record or reconcile a failed request with an administrator; this page will not submit it again.</p>}
    </Panel>
    {currentRun && <DistributionRunEvidence run={currentRun} />}
  </div>
}
