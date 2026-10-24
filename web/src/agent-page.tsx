import { useEffect, useState } from 'react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { PageHeading, Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeAgent, decodeAgentJob, decodeAgentState } from './lib/agents'
import type { AgentConfig, AgentState } from './lib/agents'
import { decodeMonitor } from './lib/monitor'
import { decodeEvaluations } from './lib/evaluations'
import type { PrivacyEvaluation } from './lib/evaluations'
import { useAuth } from './auth'
import { AILogButton } from './components/ai-log'
import type { AgentJob } from './lib/agents'
import { eventObject } from './lib/events'

export function matchingAgentExecution(jobs: AgentJob[], config?: AgentConfig) {
  return config ? jobs.find(job => job.kind === 'test' && job.config_hash === config.config_hash
    && (!job.agent_id || job.agent_id === config.id)) : undefined
}
function decodeLoggedAgentState(value: unknown): AgentState {
  const state = decodeAgentState(value), raw = eventObject(value).jobs as unknown[]
  return { ...state, jobs: state.jobs.map((job, index) => Object.assign(job, { saved: raw[index] })) }
}

function DraftEditor({ config, disabled, save }: { config: AgentConfig; disabled: boolean; save: (draft: object) => void }) {
  const [name, setName] = useState(config.name)
  const [purpose, setPurpose] = useState(config.purpose)
  const [query, setQuery] = useState(config.retrieval_query)
  return <form onSubmit={e => { e.preventDefault(); save({ name, purpose, retrieval_query: query }) }} className="knowledge-login">
    <label className="field-label" htmlFor="agent-name">Name</label>
    <Input id="agent-name" value={name} onChange={e => setName(e.target.value)} required maxLength={80} disabled={disabled} />
    <label className="field-label" htmlFor="agent-purpose-edit">Purpose (descriptive, not executable instructions)</label>
    <textarea id="agent-purpose-edit" value={purpose} onChange={e => setPurpose(e.target.value)} required maxLength={800} disabled={disabled} />
    <label className="field-label" htmlFor="agent-query">Pinned-index retrieval query</label>
    <textarea id="agent-query" value={query} onChange={e => setQuery(e.target.value)} required maxLength={500} disabled={disabled} />
    <Button disabled={disabled} type="submit">Save draft · invalidate previous tests</Button>
  </form>
}

export function LiveAgentPage() {
  const { authorization } = useAuth()
  const [state, setState] = useState<AgentState>()
  const [evaluations, setEvaluations] = useState<PrivacyEvaluation[]>([])
  const [selected, setSelected] = useState('')
  const [purpose, setPurpose] = useState('检查合成分析导出消息是否存在隐私风险，根据 HIPAA 资料给出证据和建议。')
  const [generationConsent, setGenerationConsent] = useState('')
  const [testConsent, setTestConsent] = useState('')
  const [retestConsent, setRetestConsent] = useState('')
  const [snapshotId, setSnapshotId] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')
  const [generatedExecution, setGeneratedExecution] = useState<{ purpose: string; job: AgentJob }>()
  const [retestExecution, setRetestExecution] = useState<{ token: string; job: AgentJob }>()
  const [generationJobId, setGenerationJobId] = useState('')
  const config = state?.agents.find(a => a.id === selected)
  const token = config ? `${config.id}:${config.revision}` : ''
  const canWrite = !!state?.can_write
  const activeJob = state?.jobs.some(j => j.state === 'queued' || j.state === 'running')
  useEffect(() => {
    if (!authorization) return
    let cancelled = false
    const controller = new AbortController()
    const refresh = async () => {
      try {
        const [value, reports] = await Promise.all([
          apiRequest('/agents', decodeLoggedAgentState, controller.signal, { authorization }),
          apiRequest('/evaluations', decodeEvaluations, controller.signal, { authorization }),
        ])
        if (!cancelled) { setState(value); setEvaluations(reports) }
      } catch (e) { if (!cancelled) setError(e instanceof Error ? e.message : 'Agent refresh failed') }
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
      setState(await apiRequest('/agents', decodeLoggedAgentState, undefined, { authorization }))
      setEvaluations(await apiRequest('/evaluations', decodeEvaluations, undefined, { authorization }))
    } catch (e) { setError(e instanceof Error ? e.message : 'Agent action failed') }
    finally { setBusy(false) }
  }
  const post = (body: object) => ({ authorization, body })
  const mutate = (operation: string) => action(async () => {
    if (!config) throw new Error('Select an Agent version')
    await apiRequest(`/agents/${operation}`, decodeAgent, undefined, post({ id: config.id, revision: config.revision }))
    setTestConsent('')
  })
  const report = matchingAgentExecution(state?.jobs ?? [], config)
  const generated = generationJobId ? state?.jobs.find(job => job.id === generationJobId && job.kind === 'generate') : generatedExecution?.purpose === purpose
    ? state?.jobs.find(job => job.id === generatedExecution.job.id) ?? generatedExecution.job : undefined
  const retest = retestExecution?.token === token
    ? state?.jobs.find(job => job.id === retestExecution.job.id) ?? retestExecution.job
    : config && state?.jobs.find(job => {
      const raw = eventObject(job).saved
      return job.kind === 'test' && job.config_hash === config.config_hash && raw !== undefined
        && typeof eventObject(raw).retry_of === 'string'
    })
  const loadJob = (job?: AgentJob) => job ? async () => apiRequest('/agents', value => {
    const jobs = eventObject(value).jobs
    if (!Array.isArray(jobs)) throw new Error('Saved Agent jobs are unavailable')
    const saved = jobs.find(value => eventObject(value).id === job.id)
    if (!saved) throw new Error('This exact saved Agent execution is no longer available')
    const decoded = decodeAgentJob(saved)
    if (decoded.config_hash !== job.config_hash || decoded.kind !== job.kind) throw new Error('Saved execution identity changed')
    return saved
  }, undefined, { authorization }) : undefined
  const evaluation = config && evaluations.find(r => r.config.id === config.id && r.config.revision === config.revision && r.config_hash === config.config_hash)
  const versioned = !!config?.prompt_version
  const canPublish = versioned ? evaluation?.state === 'completed' && evaluation.passed : report?.state === 'completed' && report.passed
  return <div className="monitor-page agent-live-page">
    <PageHeading eyebrow="P4 · REAL AI HUB / SYNTHETIC ACCEPTANCE" title="Agents"
      description="Create a bounded privacy reviewer. Test against a pinned knowledge version before publishing. Binding records intent only; automatic observation processing remains disabled."
      action={<Button variant="outline" disabled={busy} onClick={() => { void action() }}>Refresh Agent status</Button>} />
    {error && <div className="callout" role="alert">{error}</div>}
    {notice && <div className="callout" role="status">{notice}</div>}
    {!state ? <Panel title="Loading Agent workspace"><p>Reading records using your workspace sign-in. Use Refresh Agent status to retry if needed.</p></Panel> : <>
      <Panel title="1 · Describe a privacy reviewer">
        <label htmlFor="agent-purpose" className="field-label">Purpose · synthetic/public information only</label>
        <textarea id="agent-purpose" value={purpose} onChange={e => setPurpose(e.target.value)} maxLength={800} />
        <p className="subtle">Only privacy_review is supported. The model generates name/purpose/retrieval query, never code, endpoints or tool permissions. Two read-only tools and a four-iteration test limit are fixed by the server.</p>
        <label className="knowledge-confirm"><input type="checkbox" checked={generationConsent === purpose && purpose !== ''} onChange={e => setGenerationConsent(e.target.checked ? purpose : '')} />Allow one real model request for this purpose; possible model charges.</label>
        <div className="form-actions"><Button disabled={busy || activeJob || !canWrite || !purpose.trim() || generationConsent !== purpose} onClick={() => { void action(async () => {
          setGenerationConsent('')
          const job = await apiRequest('/agents/generate', decodeAgentJob, undefined, post({ purpose, acknowledge_cost: true }))
          setGeneratedExecution({ purpose, job })
          setGenerationJobId(job.id)
          setNotice('Builder queued. A completed job creates a draft; select it below. No publishing or binding occurs automatically.')
        }) }}>Generate restricted draft</Button><AILogButton key={`generate-${generated?.id ?? purpose}`} report={generated} load={loadJob(generated)} title="Restricted draft generation" /></div>
        <label className="field-label" htmlFor="generation-execution">Saved generation execution (explicit ID; not matched by purpose)</label>
        <select id="generation-execution" value={generationJobId} onChange={event => setGenerationJobId(event.target.value)}>
          <option value="">No saved execution selected</option>
          {state.jobs.filter(job => job.kind === 'generate').map(job => <option key={job.id} value={job.id}>{job.id} · {job.state}</option>)}
        </select>
      </Panel>
      <Panel title="2 · Review a version">
        {!state.agents.length ? <p>No Agent versions yet. Generate a draft above.</p> : <>
          <label htmlFor="agent-version" className="field-label">Agent version</label>
          <select id="agent-version" value={selected} onChange={e => { setSelected(e.target.value); setTestConsent('') }}>
            <option value="">Select a version</option>
            {state.agents.map(a => <option key={a.id} value={a.id}>{a.name} · {a.prompt_version || 'privacy-review-v1'} · {a.status} · r{a.revision}</option>)}
          </select>
          {config && <>
            <p><Status tone={config.status === 'published' ? 'success' : 'info'}>{config.status}</Status> Model: {config.model} · Knowledge index: {config.index_version}</p>
            <p className="mono subtle">Version: {config.id}<br />Configuration SHA-256: {config.config_hash}<br />Corpus SHA-256: {config.corpus}</p>
            <p className="mono subtle">Prompt: {config.prompt_version || 'privacy-review-v1 (legacy)'}{config.prompt_hash && <><br />Prompt SHA-256: {config.prompt_hash}</>}{config.parent_id && <><br />Parent: {config.parent_id}<br />Parent SHA-256: {config.parent_hash}</>}</p>
            {config.status === 'published' && !versioned && <Button variant="outline" disabled={busy || !canWrite} onClick={() => { void action(async () => {
              const candidate = await apiRequest('/agents/revise', decodeAgent, undefined, post({ id: config.id, revision: config.revision }))
              setSelected(candidate.id); setTestConsent('')
              setNotice('Versioned v2 draft created or reopened. Legacy version and binding are unchanged. No model request, publication or business execution was triggered.')
            }) }}>Create v2 instruction draft · no model call</Button>}
            <DraftEditor key={token} config={config} disabled={busy || !canWrite || config.status !== 'draft'} save={draft => { void action(async () => {
              await apiRequest('/agents/edit', decodeAgent, undefined, post({ id: config.id, revision: config.revision, draft }))
              setTestConsent('')
            }) }} />
            <details><summary>Fixed execution contract</summary><pre className="agent-json">{JSON.stringify(config, null, 2)}</pre><p>Tools: ReadPrivacyFacts and SearchPrivacyEvidence. Published configurations are immutable; create a new draft for changes.</p></details>
          </>}
        </>}
      </Panel>
      {config && <Panel title="3 · Test, publish and bind">
        {versioned ? <>
          <p>This version requires the complete twelve-case evaluation, not the legacy three-case test. Start a separately cost-authorized evaluation for this exact Agent ID using the documented API/script (at most 48 requests, no retries).</p>
          <p>Latest matching twelve-case report: {evaluation ? `${evaluation.state} · ${evaluation.passed ? 'passed' : 'not passed'}` : 'None'}.</p>
          <a href="/runs">Inspect exact evaluation cases, prompt provenance and evidence</a>
        </> : <>
        <p>Real synthetic acceptance: risk, no finding, insufficient evidence. Each must read bound facts and pinned evidence. Matching all three expected outcomes is required; this is not a compliance certification.</p>
        <label className="knowledge-confirm"><input type="checkbox" checked={testConsent === token} onChange={e => setTestConsent(e.target.checked ? token : '')} />Allow up to 12 real model requests (3 tests × at most 4 agent iterations) for this revision; no application-level retries.</label>
        <div className="form-actions"><Button disabled={busy || activeJob || !canWrite || config.status !== 'draft' || testConsent !== token} onClick={() => { void action(async () => {
          setTestConsent('')
          await apiRequest('/agents/test', decodeAgentJob, undefined, post({ id: config.id, revision: config.revision, acknowledge_cost: true }))
        }) }}>Run three real AI Hub tests</Button><AILogButton key={`test-${token}-${report?.id ?? ''}`} report={report} load={loadJob(report)} title="Selected Agent revision tests" /></div>
        <p>Latest matching report: {report ? `${report.state} · ${report.passed === undefined ? 'not evaluated' : report.passed ? 'passed' : 'not passed'}` : 'None'}</p>
        {report && (retest || (report.state === 'completed' && report.cases?.length === 3 && report.cases.filter(c => !c.passed).length === 1)) && <>
          <label className="knowledge-confirm"><input type="checkbox" checked={retestConsent === `${token}:${report.id}`} onChange={e => setRetestConsent(e.target.checked ? `${token}:${report.id}` : '')} />Allow at most 4 additional requests to retest only the failed scenario; retain provenance of the two original passes.</label>
          <div className="form-actions"><Button disabled={busy || activeJob || !canWrite || config.status !== 'draft' || report.state !== 'completed'
            || report.cases?.length !== 3 || report.cases.filter(c => !c.passed).length !== 1 || retestConsent !== `${token}:${report.id}`} onClick={() => { void action(async () => {
            setRetestConsent('')
            const job = await apiRequest('/agents/retest', decodeAgentJob, undefined, post({ id: config.id, revision: config.revision, report_id: report.id, acknowledge_cost: true }))
            setRetestExecution({ token, job })
          }) }}>Retest only failed scenario</Button><AILogButton key={`retest-${token}-${retest?.id ?? ''}`} report={retest} load={loadJob(retest)} title="Selected Agent failed-scenario retest" /></div>
        </>}
        </>}
        <p>Publishing saves this tested version without binding or executing it.</p>
        <div className="form-actions">
          <Button disabled={busy || !canWrite || config.status !== 'draft' || !canPublish} onClick={() => { void mutate('publish') }}>Publish tested version</Button>
          <Button variant="outline" disabled={busy || !canWrite || config.status !== 'published'} onClick={() => { void mutate('disable') }}>Disable published version</Button>
        </div>
        <hr />
        <Button variant="outline" disabled={busy} onClick={() => { void action(async () => {
          const monitor = await apiRequest('/pipelines', decodeMonitor, undefined, { authorization })
          if (!monitor.snapshot) throw new Error('Discover the DEMO Production in Instances first')
          setSnapshotId(monitor.snapshot.id)
        }) }}>Load current discovery snapshot</Button>
        <p className="mono subtle">Binding target: local-demo / DEMO / Demo.Production / route.complete / analytics<br />Snapshot: {snapshotId || 'Not selected'}</p>
        <p>Recording this version and snapshot binding does not enable automatic monitoring or change business routing.</p>
        <Button disabled={busy || !canWrite || config.status !== 'published' || !snapshotId} onClick={() => { void action(async () => {
          await apiRequest('/agents/bind', decodeAgent, undefined, post({ id: config.id, revision: config.revision, snapshot_id: snapshotId }))
          setNotice('Binding recorded. Automatic observation execution remains disabled; business delivery is unchanged.')
        }) }}>Record analytics binding</Button>
      </Panel>}
      {state.binding && <Panel title="Recorded binding · not an active monitor">
        <p className="mono">{state.binding.agent_id}<br />{state.binding.snapshot_id}</p>
        <p>Enabled intent: {state.binding.enabled ? 'Yes' : 'No'} · Execution: {state.binding.execution}</p>
      </Panel>}
      <Panel title="Actual builder and test runs">
        <p className="subtle">Persistent jobs, model/session provenance, SDK usage and actual tool calls. Failed or interrupted jobs are not retried automatically. A running job has no cancellation guarantee.</p>
        {!state.jobs.length && <p>No runs yet.</p>}
        {state.jobs.map(job => <details key={job.id} className="agent-run">
          <summary>{job.kind} · {job.state}{job.passed !== undefined ? ` · ${job.passed ? 'PASSED' : 'NOT PASSED'}` : ''} · {job.id}</summary>
          <p>Model: {job.model} · Maximum model requests: {job.max_model_requests}{job.agent_session ? ` · AI Hub session: ${job.agent_session}` : ''}</p>
          {job.error && <p className="callout">{job.error}</p>}
          {job.agent_id && <p className="mono">Created draft: {job.agent_id}</p>}
          {job.usage && <p className="mono">SDK usage: {JSON.stringify(job.usage)}</p>}
          {job.cases?.map(c => <div key={c.scenario} className="agent-case">
            <h3>{c.scenario} · {c.state} · {c.passed ? 'Passed' : 'Not passed'}</h3>
            <p>Expected: {c.expected} · AI Hub session: {c.agent_session || 'Not created'}</p>
            {c.source_job && <p className="mono">Retained original passing case from: {c.source_job}</p>}
            {c.error && <p className="callout">{c.error}</p>}
            {c.rejected_output && <details><summary>Rejected output · not an accepted result</summary><pre className="agent-json">{c.rejected_output}</pre></details>}
            {c.result && <><p><strong>{c.result.assessment}</strong> — {c.result.reason}</p><p>Citations: {c.result.citations.join(', ')}</p></>}
            <p>Actual tools: {c.tools.map(t => t.tool).join(' → ') || 'None recorded'}</p>
            {c.usage && <p className="mono">SDK final-response usage (not the full tool loop): {JSON.stringify(c.usage)}</p>}
            {c.sdk_stats ? <p className="mono">SDK cumulative session stats: {JSON.stringify(c.sdk_stats)}</p> : <p className="subtle">Cumulative session statistics were not retained for this earlier case; final-response usage is not a full cost total.</p>}
            {c.evidence?.map(e => <details key={e.id}>
              <summary>{e.id} · {e.metadata.source_locator} · {e.metadata.kind}</summary>
              <p>{e.metadata.legal_status} · Scope: {e.metadata.retrieval_scope}</p>
              <p className="mono">Chunk: {e.chunk_id}</p>
              {e.metadata.source_url.startsWith('https://') ? <a href={e.metadata.source_url} target="_blank" rel="noreferrer">Open source</a> : <p>{e.metadata.source_url}</p>}
              <p className="agent-evidence">{e.text}</p>
            </details>)}
          </div>)}
        </details>)}
      </Panel>
    </>}
  </div>
}
