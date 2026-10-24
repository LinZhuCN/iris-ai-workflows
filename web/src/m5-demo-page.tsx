import { useEffect, useRef, useState } from 'react'
import { useAuth } from './auth'
import { PageHeading, Panel, Status } from './components/platform'
import { AILog, AILogButton } from './components/ai-log'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { OrganizationProfileEditor } from './organizations-page'
import { apiRequest } from './lib/api'
import { decodeJson, decodeProfileRecord, profileConfirmation, type OrganizationProfile, type ProfileRecord } from './lib/multi-organization'
import { decodeM5Run, decodeM5Status, m5AuditLog, m5AuditRecorded, m5CanReconcileAudit, m5Capture, m5PublishedAgents, m5Result,
  m5SavedAuditRequest, m5Scope, type M5AuditRequest, type M5Run, type M5Status } from './lib/m5-demo'
import { routeTime } from './lib/governance'

const roles = ['hospital', 'research'] as const
function blankProfile(id: typeof roles[number]): OrganizationProfile {
  return { id, name: '', partner: '', type: '', parent_id: '', responsibilities: '', purpose: '',
    relationship: id === 'hospital' ? 'same_covered_entity' : 'external',
    allowed_fields: [], prohibited_fields: [], requirements: '' }
}
export function M5ProfileForm({ id, record, preset, enabled, busy, onSave }: {
  id: typeof roles[number]; record?: ProfileRecord; preset?: OrganizationProfile; enabled: boolean; busy: boolean
  onSave: (profile: OrganizationProfile, revision: number) => void
}) {
  const [example, setExample] = useState<OrganizationProfile>()
  const [version, setVersion] = useState(0)
  return <Panel title={id === 'hospital' ? 'Source hospital' : 'Research recipient'}>
    <p>{record ? `Saved M5-only revision ${record.revision}. Runs keep their original frozen snapshot.` : 'No M5 profile saved. Enter your synthetic organization details or fill an example.'}</p>
    <Button type="button" variant="outline" disabled={!enabled || busy || !preset} onClick={() => {
      setExample(preset && structuredClone(preset)); setVersion(v => v + 1)
    }}>Fill example</Button>
    <OrganizationProfileEditor key={`${record?.revision ?? 0}-${version}`} initial={example ?? record?.profile ?? blankProfile(id)}
      record={record} canManage={enabled} busy={busy} idPrefix={`m5-${id}`} onSave={onSave} />
  </Panel>
}
export function M5RunEvidence({ run }: { run: M5Run }) {
  const result = m5Result(run)
  const capture = m5Capture(run)
  const factText = (value: unknown) => typeof value === 'string' || typeof value === 'number' ? String(value) : 'Not recorded'
  return <Panel title={`Current results · ${run.id}`}>
    <p>Run: <Status tone={run.error ? 'danger' : 'info'}>{run.state}</Status> · Created {routeTime(run.created_at)}</p>
    <p>Message ID: {run.message_id || 'Not recorded'} · Session ID: {run.session_id || 'Not recorded'} · Receiver header ID: {run.header_id || 'Not recorded'}</p>
    {run.review_header_id && run.review_header_id !== run.header_id && <p>Review representative header ID: {run.review_header_id}. The target header above shares this session/body review; it is not a separate model assessment.</p>}
    {run.error && <p role="alert">{run.error}</p>}
    <section aria-label="Monitoring evidence">
      <h3>Monitoring evidence · Capture state: {capture.state}</h3>
      {!run.evidence && <p role="status">Waiting for collector. A receiver header or receipt is not yet stored monitoring evidence and does not enable an AI audit.</p>}
      {capture.reason && <p>Capture detail: {capture.reason}</p>}
      {capture.header && <p>Observed route: {factText(capture.header.source)} → {factText(capture.header.target)} · Observed session: {factText(capture.header.session_id)} · Observed header: {factText(capture.header.header_id)}</p>}
      {capture.captured && <div>
        <h4>Stored minimized fields and date precision</h4>
        {capture.facts == null ? <p>No minimized facts supplied. Inspect the collector record before interpreting coverage.</p>
          : <pre className="overflow-auto whitespace-pre-wrap break-words">{JSON.stringify(capture.facts, null, 2)}</pre>}
      </div>}
      {!capture.captured && run.evidence != null && <p role="status">Collector evidence is not in captured state. The audit remains disabled; missing, unsupported or failed capture is not a no-risk result.</p>}
    </section>
    <p>{run.receipt == null ? 'No receiving receipt captured; delivery is not independently confirmed.'
      : 'A receiver receipt is recorded. It is transport evidence, not proof of permitted downstream use.'}</p>
    <div className="grid gap-4 lg:grid-cols-2">
      <section aria-label="Current M5 assessment">
        <h3>Result: {result.label}</h3>
        <p>Audit state: {result.state}</p>
        <p>Why: {result.reason}</p>
        {result.unresolved && <p>Unresolved conditions remain separate from identified risk.</p>}
        {result.missing.length > 0 && <><h4>Missing information</h4><ul>{result.missing.map((item, i) => <li key={i}>{item}</li>)}</ul></>}
        <p>Next: {result.label === 'Not assessed'
          ? m5AuditRecorded(run) ? 'Wait for the saved result or inspect the recorded failure. Do not purchase a repeated authorization.'
            : 'After capture, explicitly authorize the bounded audit if desired.'
          : 'Ask a human to review the findings, unresolved conditions and cited evidence before acting.'}</p>
        <p>Missing, pending, failed or unsupported evidence is not a no-risk finding. This synthetic advisory assessment is not compliance certification and executes no business action.</p>
      </section>
      <AILog report={m5AuditLog(run)} />
    </div>
    <details><summary>Frozen source and recipient profiles used by this run</summary>
      <p>These M5-only snapshots, not later edits or retyped premises, are used for the audit.</p>
      <pre className="overflow-auto">{JSON.stringify(run.profiles, null, 2)}</pre>
    </details>
    <details><summary>Receipt, captured review, citations and complete saved report</summary>
      <pre className="overflow-auto">{JSON.stringify({ receipt: run.receipt, evidence: run.evidence, authorization: run.authorization, review: run.review, report: run.report }, null, 2)}</pre>
    </details>
  </Panel>
}

export function M5DemoPage() {
  const { authorization } = useAuth()
  return <M5DemoWorkspace key={authorization} authorization={authorization} />
}
export function M5ReviewerGuidance({ status }: { status?: M5Status }) {
  if (!status?.enrolled || !status.plan) return <p>Enroll the fixed Production to load its review plan and published reviewer choices.</p>
  return m5PublishedAgents(status.plan).length ? null
    : <p>No published eligible reviewer is available yet. Publish an eligible Agent separately; this page does not create one or offer draft Agents.</p>
}
function M5DemoWorkspace({ authorization }: { authorization: string }) {
  const [status, setStatus] = useState<M5Status>()
  const [selected, setSelected] = useState('')
  const [agentId, setAgentId] = useState('')
  const [costIdentity, setCostIdentity] = useState('')
  const [runId, setRunId] = useState(() => `m5-demo-${crypto.randomUUID()}`)
  const [resetText, setResetText] = useState(''), [generation, setGeneration] = useState(0)
  const [busy, setBusy] = useState(''), [error, setError] = useState(''), [readError, setReadError] = useState('')
  const [notice, setNotice] = useState(''), [refresh, setRefresh] = useState(0)
  const operation = useRef<AbortController | null>(null), read = useRef<AbortController | null>(null)
  const attemptedSends = useRef(new Set<string>()), attemptedAudits = useRef(new Set<string>())
  const auditRequests = useRef(new Map<string, M5AuditRequest>())
  const [sendAttempted, setSendAttempted] = useState(false), [auditAttempted, setAuditAttempted] = useState('')
  useEffect(() => () => { operation.current?.abort(); read.current?.abort() }, [])
  useEffect(() => {
    if (operation.current) return
    const controller = new AbortController(); read.current = controller
    void apiRequest('/m5-demo', decodeM5Status, controller.signal, { authorization })
      .then(value => {
        if (controller.signal.aborted) return
        setStatus(value); setReadError('')
        setSelected(previous => value.runs.some(run => run.id === previous) ? previous : value.runs[0]?.id ?? '')
      }).catch((e: unknown) => {
        if (!controller.signal.aborted) setReadError(e instanceof Error ? e.message : 'M5 status unavailable')
      })
    return () => controller.abort()
  }, [authorization, refresh])
  useEffect(() => { const timer = setInterval(() => setRefresh(v => v + 1), 4000); return () => clearInterval(timer) }, [])
  async function act(name: string, work: (signal: AbortSignal) => Promise<void>) {
    if (operation.current || !status?.can_manage || readError) return
    read.current?.abort()
    const controller = new AbortController(); operation.current = controller
    setBusy(name); setError(''); setNotice('')
    try { await work(controller.signal) }
    catch (e) {
      if (!controller.signal.aborted) setError(`${e instanceof Error ? e.message : 'M5 action failed'} Nothing is automatically retried. Refresh the saved state before taking further action.`)
    } finally {
      if (operation.current === controller) operation.current = null
      if (!controller.signal.aborted) { setBusy(''); setRefresh(v => v + 1) }
    }
  }
  const enabled = !!status?.can_manage && !busy && !readError
  const profilesReady = roles.every(id => status?.profiles.some(profile => profile.id === id))
  const run = status?.runs.find(item => item.id === selected)
  const plan = status?.plan
  const eligibleAgents = m5PublishedAgents(plan)
  const agent = eligibleAgents.find(item => item.id === agentId)
  const auditIdentity = JSON.stringify([run?.id, status?.production_id, status?.config_hash,
    plan?.contract_hash, agent?.id, agent?.revision, agent?.config_hash])
  useEffect(() => { setCostIdentity('') }, [auditIdentity])
  const costConfirmed = costIdentity === auditIdentity
  const hasAudit = !!run && m5AuditRecorded(run)
  const canAudit = enabled && !!run && m5Capture(run).captured && !!agent && !!status?.enrolled && !!status.inspection_enabled &&
    !hasAudit && !attemptedAudits.current.has(run?.id ?? '')
  const retryRequest = run && (m5SavedAuditRequest(run) ?? auditRequests.current.get(run.id))
  const canReconcile = enabled && !!run && m5Capture(run).captured && m5CanReconcileAudit(run) && !!retryRequest &&
    retryRequest.config_hash === status?.config_hash
  function chooseRun(id: string) { setSelected(id); setCostIdentity('') }
  function resetLocal(value: M5Status) {
    setStatus(value); setSelected(''); setAgentId(''); setCostIdentity(''); setResetText('')
    setRunId(`m5-demo-${crypto.randomUUID()}`); setGeneration(v => v + 1)
    attemptedSends.current.clear(); attemptedAudits.current.clear(); auditRequests.current.clear(); setSendAttempted(false); setAuditAttempted('')
  }
  return <div className="monitor-page">
    <PageHeading eyebrow="FIXED SYNTHETIC M5 ONBOARDING" title="M5 onboarding demo"
      description="Start with your source and recipient, enroll one fixed Production, inspect local synthetic traffic, then separately authorize an actual bounded AI audit."
      action={<><Button variant="outline" disabled={!!busy} onClick={() => setRefresh(v => v + 1)}>Refresh status</Button>
        <Button asChild variant="outline"><a href="/demo">Distribution demo</a></Button>
        <Button asChild variant="outline"><a href="/pipelines">Productions</a></Button></>} />
    <p className="callout">Fixed scope: M5OBSERVATION / Contest.M5.Production. Only local synthetic research data is sent.
      Opening this page, filling examples, saving profiles, enrollment, inspection and polling make no model calls.
      No automatic audit, paid retries or real PHI authorization.</p>
    {!status && !readError && <p role="status">Loading saved M5 state… No sends or model calls are started.</p>}
    {readError && <p role="alert">{readError} Controls are disabled until a successful status refresh.</p>}
    {error && <p role="alert">{error}</p>}
    {busy && <p role="status">Request in progress: {busy}. Waiting for the server; no additional action is submitted automatically.</p>}
    {notice && <p role="status">{notice}</p>}
    {status && !status.can_manage && <p>Read-only access. A builder must save profiles and explicitly authorize each consequential action.</p>}
    <Panel title="1. Enter source and recipient organizations">
      <p>Profiles belong only to this M5 demo. They are independent of the shared Organizations catalog and distribution profiles.
        Saving confirms synthetic business premises, not verified contracts or legal permission. Fill example changes the form only; it never saves.</p>
      <div className="grid gap-4 lg:grid-cols-2">
        {roles.map(id => <M5ProfileForm key={`${generation}-${id}-${status?.profiles.find(record => record.id === id)?.revision ?? 0}`} id={id} enabled={enabled} busy={!!busy}
          record={status?.profiles.find(record => record.id === id)} preset={status?.presets.find(profile => profile.id === id)}
          onSave={(profile, revision) => { void act(`profile-${id}`, async signal => {
            const saved = await apiRequest('/m5-demo/profiles', decodeProfileRecord, signal,
              { authorization, body: profileConfirmation(profile, revision, true) })
            if (saved.id !== id || saved.revision !== revision + 1) throw new Error('Saved M5 profile identity or revision mismatch.')
            if (!signal.aborted) {
              setStatus(previous => previous && { ...previous, profiles: [...previous.profiles.filter(p => p.id !== id), saved] })
              setNotice(`Saved M5-only ${id} revision ${saved.revision}. Existing runs retain frozen profiles.`)
            }
          }) }} />)}
      </div>
    </Panel>
    <Panel title="2. Enroll the fixed Production">
      <p>Enrollment enables read-only observation of M5OBSERVATION / Contest.M5.Production. It does not authorize payload inspection or model spending.</p>
      <p>Status: {status ? status.enrolled ? 'Enrolled' : 'Not enrolled' : 'Not yet loaded'}</p>
      <Button disabled={!enabled || !profilesReady || !!status?.enrolled} onClick={() => { if (!status) return; void act('enroll', async signal => {
        await apiRequest('/productions/enroll', decodeJson, signal, { authorization, body: {
          ...m5Scope, config_hash: status.config_hash, acknowledge_monitoring: true,
        } })
        if (!signal.aborted) setNotice('Enrollment accepted. Refreshing persisted state; no model calls requested.')
      }) }}>Enroll M5 Production</Button>
    </Panel>
    <Panel title="3. Authorize local synthetic inspection">
      <p>Allow structured-property capture for this exact fixed Production and current configuration. This is local inspection, not an AI audit.</p>
      <p>Status: {status ? status.inspection_enabled ? 'Inspection authorized' : 'Not authorized' : 'Not yet loaded'}</p>
      <Button disabled={!enabled || !status?.enrolled || status.inspection_enabled} onClick={() => { if (!status) return; void act('inspection', async signal => {
        await apiRequest('/productions/authorize-inspection', decodeJson, signal, { authorization, body: {
          production_id: status.production_id, config_hash: status.config_hash, acknowledge_local_synthetic_inspection: true,
        } })
        if (!signal.aborted) setNotice('Local synthetic inspection authorized. No send or AI audit was requested.')
      }) }}>Authorize local inspection</Button>
    </Panel>
    <Panel title="4. Trigger the fixed synthetic research flow">
      <p>This sends the fixed local hospital-to-research case and freezes both saved M5 profiles. It does not call a model.</p>
      <p className="break-all">Stable request ID: <code>{runId}</code></p>
      <Button disabled={!enabled || !profilesReady || !status?.enrolled || !status.inspection_enabled || sendAttempted || !!status.runs.length}
        onClick={() => { if (!status || attemptedSends.current.has(runId)) return; void act('send', async signal => {
          attemptedSends.current.add(runId); setSendAttempted(true)
          const value = await apiRequest('/m5-demo/send', decodeM5Run, signal, { authorization,
            body: { run_id: runId, config_hash: status.config_hash, confirmed: true } })
          if (value.id !== runId) throw new Error('M5 send response identity mismatch.')
          if (!signal.aborted) {
            setStatus(previous => previous && { ...previous, runs: [value, ...previous.runs.filter(r => r.id !== value.id)] })
            chooseRun(value.id); setNotice('Send accepted. Waiting for captured header and persisted results. No audit was requested.')
          }
        }) }}>Send fixed synthetic research data</Button>
      {(sendAttempted || !!status?.runs.length) && <p>This demo already has a send or send attempt. It is not replayed or automatically retried. Inspect saved state; use the explicit reset for a new logical start.</p>}
    </Panel>
    <Panel title="5. Authorize one actual bounded audit">
      <label className="field-label" htmlFor="m5-run">Saved M5 run</label>
      <select id="m5-run" disabled={!!busy} value={selected} onChange={e => chooseRun(e.target.value)}>
        <option value="">Select a saved run</option>
        {status?.runs.map(item => <option key={item.id} value={item.id}>{item.id} · {item.state}</option>)}
      </select>
      <label className="field-label" htmlFor="m5-agent">Eligible reviewer Agent</label>
      <select id="m5-agent" value={agent ? agentId : ''} disabled={!enabled} onChange={e => { setAgentId(e.target.value); setCostIdentity('') }}>
        <option value="">Select an eligible Agent</option>
        {eligibleAgents.map(item => <option key={item.id} value={item.id}>{item.id} · revision {item.revision} · {item.model}</option>)}
      </select>
      <M5ReviewerGuidance status={status} />
      <p>Authorize at most 1 review and 2 model requests. The server uses the selected run's frozen organization profiles and captured message; no retyped premises.
        Results may remain pending while the observer and reviewer run. No automatic model calls or paid retries.</p>
      <label className="confirmation-label"><input type="checkbox" disabled={!canAudit} checked={costConfirmed}
        onChange={e => setCostIdentity(e.target.checked ? auditIdentity : '')} />
        I acknowledge model charges for this exact run and Agent revision, bounded to 1 review and 2 model requests.
      </label>
      <div className="flex gap-2">
        <Button disabled={!canAudit || !costConfirmed} onClick={() => {
          if (!canAudit || !costConfirmed || !run || !status || !agent || !plan) return
          void act('audit', async signal => {
            attemptedAudits.current.add(run.id); setAuditAttempted(run.id); setCostIdentity('')
            const request: M5AuditRequest = {
              run_id: run.id, authorization_id: crypto.randomUUID(), agent_id: agent.id, source_revision: agent.revision,
              agent_config_hash: agent.config_hash, contract_hash: plan.contract_hash,
              config_hash: status.config_hash, acknowledge_cost: true,
            }
            auditRequests.current.set(run.id, request)
            await apiRequest('/m5-demo/audit', decodeJson, signal, { authorization, body: request })
            if (!signal.aborted) setNotice('Audit authorization accepted. Waiting for the actual saved review and report; no successful model response is implied yet.')
          })
        }}>Authorize bounded AI audit</Button>
        <AILogButton key={run?.id ?? 'no-run'} title={`AI log · ${run?.id ?? 'select a run'}`} report={m5AuditLog(run)} />
      </div>
      {run && (hasAudit || auditAttempted === run.id) && <p role="status">An audit record or single-use authorization attempt exists for this run. No new authorization will be generated. Pending and failed results are preserved. Polling reads saved state only.</p>}
      {retryRequest && run && m5CanReconcileAudit(run) && <div>
        <p>If submission was interrupted or its result is uncertain, explicitly reconcile the exact saved consent. This resubmits the same authorization ID, Agent revision, hashes and cost acknowledgment, not a new budget or model retry.</p>
        <p className="break-all">Single-use authorization ID: <code>{retryRequest.authorization_id}</code></p>
        <Button variant="outline" disabled={!canReconcile} onClick={() => {
          if (!canReconcile || !retryRequest) return
          void act('reconcile-audit', async signal => {
            await apiRequest('/m5-demo/audit', decodeJson, signal, { authorization, body: retryRequest })
            if (!signal.aborted) setNotice('Exact single-use authorization resubmitted. Read the saved state; no new authorization ID or budget was created.')
          })
        }}>Reconcile exact audit submission</Button>
      </div>}
    </Panel>
    {run && <M5RunEvidence run={run} />}
    <Panel title="Reset to a clean logical M5 start">
      <p>Reset archives M5-scoped records and clears only this demo's enrollment, profiles and runs. Physical IRIS messages and saved risk reports are retained.
        Other Productions and shared organization profiles are untouched. This is not physical deletion.</p>
      <label className="field-label" htmlFor="m5-reset">Type RESET M5 DEMO to confirm this consequential reset</label>
      <Input id="m5-reset" value={resetText} disabled={!enabled} onChange={e => setResetText(e.target.value)} />
      <Button variant="outline" disabled={!enabled || resetText !== 'RESET M5 DEMO'} onClick={() => {
        if (!status || resetText !== 'RESET M5 DEMO') return
        void act('reset', async signal => {
          const value = await apiRequest('/m5-demo/reset', decodeM5Status, signal, { authorization,
            body: { confirmation: 'RESET M5 DEMO', config_hash: status.config_hash } })
          if (!signal.aborted) {
            resetLocal(value); setNotice('M5 records archived. Clean logical start ready; physical messages and saved risk reports remain retained.')
          }
        })
      }}>Archive and reset M5 demo</Button>
    </Panel>
  </div>
}
