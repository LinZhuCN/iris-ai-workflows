import { useEffect, useRef, useState } from 'react'
import { AILogButton } from './components/ai-log'
import { Button } from './components/ui/button'
import { Textarea } from './components/ui/textarea'
import { PageHeading, Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import {
  assessmentLabels, bindDeclarationReport, canDecide, decisionCommand, decodeDeclarationCatalog,
  decodeDeclarationHistory, decodeDeclarationRecord, decodeDeclarationReport, decodeDeclarations, decodeReviewPlan,
} from './lib/declarations'
import type {
  DeclarationCatalog, DeclarationHistory, DeclarationList, DeclarationRecord, DeclarationReport, DecisionAction, ReviewPlan,
} from './lib/declarations'
import { DeclarationForm } from './declaration-form'
import { DeclarationExecutionPanel } from './declaration-execution-panel'
import { useAuth } from './auth'

function errorText(error: unknown) { return error instanceof Error ? error.message : 'Declaration operation failed' }
function isAbort(error: unknown) { return error instanceof DOMException && error.name === 'AbortError' }

export function LiveDeclarationsPage() {
  const { authorization } = useAuth()
  const [connected, setConnected] = useState<{ authorization: string; catalog: DeclarationCatalog; list: DeclarationList }>()
  const [error, setError] = useState(''), [refresh, setRefresh] = useState(0)
  useEffect(() => {
    const controller = new AbortController()
    void (async () => {
      try {
      const [catalog, list] = await Promise.all([
        apiRequest('/declarations/catalog', decodeDeclarationCatalog, controller.signal, { authorization }),
        apiRequest('/declarations', decodeDeclarations, controller.signal, { authorization }),
      ])
        if (!controller.signal.aborted) { setConnected({ authorization, catalog, list }); setError('') }
      } catch (e) { if (!isAbort(e) && !controller.signal.aborted) setError(errorText(e)) }
    })()
    return () => controller.abort()
  }, [authorization, refresh])
  return <div className="monitor-page declarations-page">
    <PageHeading eyebrow="DECLARATION → AI REVIEW → HUMAN DECISION" title="Data-use declarations"
      description="Propose a new data use, inspect its HIPAA assessment, revise it and record an exact-version decision."
      action={<Button asChild variant="outline"><a href="/governance">Legacy routes & monitoring</a></Button>} />
    <div className="callout">Synthetic-data demo. Do not enter patient information. Model requests require explicit confirmation; reading, saving and human decisions do not call a model.</div>
    {connected ? <DeclarationWorkspace key={connected.authorization} authorization={connected.authorization} catalog={connected.catalog} initial={connected.list} />
      : <Panel title="Loading declarations">
        {error && <div className="callout" role="alert">{error}</div>}
        {error ? <Button variant="outline" onClick={() => setRefresh(n => n + 1)}>Retry loading declarations</Button> : <p>Reading records using your workspace sign-in…</p>}
      </Panel>}
  </div>
}

function DeclarationWorkspace({ authorization, catalog, initial }: {
  authorization: string; catalog: DeclarationCatalog; initial: DeclarationList
}) {
  const [list, setList] = useState(initial), [cursor, setCursor] = useState('')
  const [selectedId, setSelectedId] = useState(initial.items[0]?.id ?? '')
  const [record, setRecord] = useState<DeclarationRecord>(), [history, setHistory] = useState<DeclarationHistory>()
  const [report, setReport] = useState<DeclarationReport>(), [revisionPage, setRevisionPage] = useState<number>()
  const [editor, setEditor] = useState<{ previous?: DeclarationRecord }>()
  const [plan, setPlan] = useState<ReviewPlan>(), [acknowledged, setAcknowledged] = useState(false)
  const [decision, setDecision] = useState<DecisionAction>(), [reason, setReason] = useState('')
  const [confirmed, setConfirmed] = useState(false)
  const [busy, setBusy] = useState(false), [loading, setLoading] = useState(false)
  const [error, setError] = useState(''), [readError, setReadError] = useState(''), [notice, setNotice] = useState('')
  const [refresh, setRefresh] = useState(0)
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  const getOptions = { authorization }
  const running = record?.review.task?.state === 'queued' || record?.review.task?.state === 'running'

  useEffect(() => {
    if (!selectedId) return
    const controller = new AbortController()
    setLoading(true)
    async function load() {
      try {
        const next = await apiRequest(`/declarations/${encodeURIComponent(selectedId)}`, decodeDeclarationRecord, controller.signal, { authorization })
        const historyPath = `/declarations/${encodeURIComponent(next.declaration_id)}/history${revisionPage ? `?before=${revisionPage}` : ''}`
        const [revisions, actual] = await Promise.all([
          apiRequest(historyPath, decodeDeclarationHistory, controller.signal, { authorization }),
          next.review.task?.runtime?.report_id && ['completed', 'failed'].includes(next.review.task.state)
            ? apiRequest(`/declarations/${encodeURIComponent(next.id)}/review-report`, decodeDeclarationReport, controller.signal, { authorization })
              .then(value => bindDeclarationReport(next, value)) : undefined,
        ])
        if (!controller.signal.aborted) {
          setRecord(next); setHistory(revisions); setReport(actual); setReadError('')
          setList(previous => ({ ...previous, items: previous.items.map(item => item.id === next.id ? next : item) }))
        }
      } catch (e) {
        if (!controller.signal.aborted) { setReadError(errorText(e)); setReport(undefined) }
      } finally { if (!controller.signal.aborted) setLoading(false) }
    }
    void load()
    return () => controller.abort()
  }, [authorization, selectedId, refresh, revisionPage])
  useEffect(() => {
    if (!running || busy || readError) return
    const timer = setInterval(() => setRefresh(n => n + 1), 4000)
    return () => clearInterval(timer)
  }, [running, busy, readError])

  function clearActions() { setPlan(undefined); setAcknowledged(false); setDecision(undefined); setReason(''); setConfirmed(false) }
  function choose(id: string) {
    setSelectedId(id); setRecord(undefined); setReport(undefined); setHistory(undefined); setRevisionPage(undefined)
    setEditor(undefined); setError(''); setReadError(''); setNotice(''); clearActions()
    setRefresh(n => n + 1)
  }
  async function action(work: (signal: AbortSignal) => Promise<void>) {
    operation.current?.abort()
    const controller = new AbortController(); operation.current = controller
    setBusy(true); setError(''); setNotice('')
    try { await work(controller.signal) }
    catch (e) { if (!controller.signal.aborted) setError(errorText(e)) }
    finally { if (!controller.signal.aborted) setBusy(false) }
  }
  async function reloadList(signal: AbortSignal, after = cursor) {
    const next = await apiRequest(`/declarations${after ? `?after=${encodeURIComponent(after)}` : ''}`, decodeDeclarations, signal, getOptions)
    if (!signal.aborted) { setList(next); setCursor(after) }
  }
  async function changed(next: DeclarationRecord, signal: AbortSignal, message: string) {
    if (signal.aborted) return
    clearActions(); setEditor(undefined); setSelectedId(next.id); setRecord(next); setReport(undefined)
    setRevisionPage(undefined); setRefresh(n => n + 1); setNotice(message)
    await reloadList(signal)
  }
  async function submit() {
    if (!record) return
    await action(async signal => {
      const next = record.review.task ? record : await apiRequest('/declarations/submit', decodeDeclarationRecord, signal,
        { authorization, body: { record_id: record.id, digest: record.digest } })
      setRecord(next); setRefresh(n => n + 1)
      const prepared = await apiRequest(`/declarations/${encodeURIComponent(next.id)}/review-plan`, decodeReviewPlan, signal, getOptions)
      if (prepared.consent.record_id !== next.id || prepared.consent.digest !== next.digest || prepared.consent.task_id !== next.review.task?.id) throw new Error('Cost plan does not match the selected revision')
      if (!signal.aborted) { setPlan(prepared); setAcknowledged(false); setNotice('Review intent saved. No model called yet; confirm the exact cost plan below.') }
      await reloadList(signal)
    })
  }
  const editable = !!record && record.revision === record.latest_revision && !running
  const disabled = busy || loading || !!readError
  const canWrite = list.can_write
  const task = record?.review.task
  const result = task?.result
  const currentCatalog = record?.context.catalog_version === catalog.version
  return <>
    {error && <div className="callout" role="alert">{error} No successful outcome is assumed. Refresh before retrying a changed revision.</div>}
    {readError && <div className="callout" role="alert">{readError} Loaded data may be stale; mutations are disabled until a successful refresh.</div>}
    {notice && <div className="callout" role="status">{notice}</div>}
    <Panel title="Declarations" action={<Button disabled={busy || !canWrite || !!editor} onClick={() => { clearActions(); setEditor({}); setNotice(''); setError('') }}>New declaration</Button>}>
      {!canWrite && <p className="subtle">Read-only account. Saving, model authorization and decisions are disabled.</p>}
      <div className="form-actions">
        <Button variant="outline" disabled={busy || loading} onClick={() => { clearActions(); void action(async signal => { await reloadList(signal); setRefresh(n => n + 1) }) }}>Refresh records</Button>
        <Button variant="outline" disabled={busy || !cursor} onClick={() => { void action(signal => reloadList(signal, '')) }}>First page</Button>
        <Button variant="outline" disabled={busy || !list.next_cursor} onClick={() => { void action(signal => reloadList(signal, list.next_cursor)) }}>Next 25 declarations</Button>
      </div>
      {!list.items.length && <p>No declarations on this page. Create a proposal to begin.</p>}
      <div className="table-scroll"><table className="data-table"><thead><tr><th>Declaration / version</th><th>AI review</th><th>Human decision</th><th /></tr></thead>
        <tbody>{list.items.map(item => <tr key={item.id}><td>{item.proposal.title}<br /><code>{item.declaration_id}</code> · v{item.revision}</td>
          <td>{item.review.task?.assessment ? assessmentLabels[item.review.task.assessment] : item.review.task?.state ?? 'Not submitted'}</td>
          <td>{item.decision?.action ?? 'Pending'}</td><td><Button variant="outline" disabled={busy || !!editor} onClick={() => choose(item.id)} aria-label={`Inspect ${item.declaration_id}`}>Inspect</Button></td></tr>)}</tbody></table></div>
    </Panel>
    {editor && canWrite && <DeclarationForm key={editor.previous?.id ?? 'new'} catalog={catalog} previous={editor.previous} busy={busy}
      onCancel={() => setEditor(undefined)} onSave={async command => {
        await action(async signal => {
          const next = await apiRequest('/declarations', decodeDeclarationRecord, signal, { authorization, body: command })
          await changed(next, signal, 'New draft revision saved. It has no inherited AI result or human approval.')
        })
      }} />}
    {loading && !record && <p role="status">Loading immutable declaration…</p>}
    {record && !editor && <>
      <Panel title={`${record.proposal.title} · revision ${record.revision}`} action={<Button variant="outline" disabled={disabled || !canWrite || !editable}
        onClick={() => { clearActions(); setEditor({ previous: record }) }}>Edit as new revision</Button>}>
        <p><Status tone={record.revision === record.latest_revision ? 'info' : 'warning'}>{record.revision === record.latest_revision ? 'Latest version' : `Historical version · latest is ${record.latest_revision}`}</Status>
          {' '}<Status>{record.state}</Status> <Status>{record.decision?.action ?? 'Human decision pending'}</Status></p>
        <p className="mono">Record: {record.id}<br />Proposal digest: {record.digest}</p>
        <p>Created by {record.created_by} · {routeTime(record.created_at)}. Registered context: {record.context.organization.organization_id} / {record.context.recipient.relationship}.</p>
        <div className="two-columns">
          <section><h3>Proposed business use</h3><p><strong>{record.proposal.purpose.category.replaceAll('_', ' ')}</strong> · {record.proposal.purpose.text}</p>
            <p>Activities: {record.proposal.purpose.activities}</p><p>Expected output: {record.proposal.purpose.expected_output}</p>
            <p>Recipient: {record.context.recipient.name} · {record.context.recipient.id}</p><p>Responsible office: {record.proposal.owner}</p></section>
          <section><h3>Data and handling</h3><p>{record.proposal.data.max_records} records · {record.proposal.data.cohort}</p><p>{record.proposal.data.fields.join(', ')}</p>
            <p>Necessity: {record.proposal.data.necessity}</p><p>{record.proposal.handling.recipe_id} · {record.proposal.handling.identifiability}</p>
            <p>Access: {record.proposal.handling.access}<br />Retention: {record.proposal.handling.retention}<br />Onward sharing: {record.proposal.handling.onward_sharing}</p>
            <p>Arrangements: {record.proposal.arrangements.status} {record.proposal.arrangements.details}</p></section>
        </div>
        <p>Validity: {routeTime(record.proposal.validity.from)} → {routeTime(record.proposal.validity.until)}</p>
        <p><Status tone={record.capability.state === 'supported' ? 'info' : 'warning'}>{record.capability.state === 'supported' ? 'Bounded recipe supported' : 'Assessment only · execution unsupported'}</Status>
          {' '}Execution: {record.execution_state}. {record.capability.reason}</p>
        <p className="subtle">AI assessment and human approval are separate. An eligible approved revision can run only after a separate exact-batch delivery confirmation below.</p>
        {!task || task.state === 'blocked_budget' ? <Button disabled={disabled || !canWrite || !editable || !!record.decision}
          onClick={() => { void submit() }}>{task ? 'Prepare model cost confirmation' : 'Submit for AI review'}</Button> : null}
        <AILogButton key={record.id} title={`AI log · declaration ${record.id}`} report={report ?? task} />
      </Panel>
      {plan && <Panel title="Confirm this exact AI review">
        <p>{record.declaration_id} · revision {record.revision} · model {plan.model}. At most <strong>2 model requests</strong>: issue localization and judgment.
          Provider charges may apply. No automatic retry, human approval or delivery is included.</p>
        <p className="mono">Task: {plan.consent.task_id}<br />Agent: {plan.consent.agent_id} · revision {plan.consent.source_revision}<br />
          Input: {plan.consent.input_hash}<br />Prompt contract: {plan.consent.contract_hash}</p>
        <label className="confirmation-label"><input type="checkbox" checked={acknowledged} disabled={busy} onChange={e => setAcknowledged(e.target.checked)} />I authorize up to 2 model requests for this exact revision.</label>
        <div className="form-actions"><Button disabled={disabled || !canWrite || !acknowledged} onClick={() => { void action(async signal => {
          const next = await apiRequest('/declarations/review', decodeDeclarationRecord, signal, { authorization, body: { ...plan.consent, acknowledge_cost: true } })
          await changed(next, signal, 'AI review queued. Progress refreshes are read-only; no retry is automatic.')
        }) }}>Authorize and queue review</Button><AILogButton key={record.id} title={`AI log · declaration ${record.id}`} report={report ?? task} /><Button variant="outline" disabled={busy} onClick={clearActions}>Cancel authorization</Button></div>
      </Panel>}
      <Panel title="AI review of proposed use">
        {!task ? <p>Not submitted. No AI assessment exists.</p> : <>
          <p role={running ? 'status' : undefined}><Status tone={task.state === 'failed' ? 'danger' : 'info'}>{task.state}</Status>
            {' '}{task.attempted_requests} attempted / {task.reserved_requests} reserved model requests.</p>
          {running && <p>AI Hub review is in progress. This page polls stored task state; navigating away does not cancel the IRIS worker.</p>}
          {task.state === 'blocked_budget' && <p>Waiting for explicit model authorization. No conclusion has been generated.</p>}
          {task.state === 'failed' && <div className="callout" role="alert">Technical review failure — no business conclusion. {task.runtime?.error}
            {' '}Inspect preserved phase output below, then correct and submit a new revision. This task will not retry.</div>}
          {result && <section aria-label="Accepted proposal assessment">
            <h3><Status tone={result.assessment === 'no_risk_identified' ? 'success' : 'warning'}>{assessmentLabels[result.assessment]}</Status></h3>
            <p>This assessment concerns the proposed use as declared, before approval or delivery.</p>
            {result.missing_information.length > 0 && <><h4>Information to supply in a new revision</h4><ul>{result.missing_information.map(item => <li key={item}>{item}</li>)}</ul></>}
            {result.issues.map(issue => <section className="declaration-issue" key={issue.question_id}>
              <h4>{issue.question_id} · {issue.status.replaceAll('_', ' ')}</h4><p>{issue.explanation}</p>
              <p className="subtle">Proposal facts: {issue.fact_ids.join(', ')}</p>
              {issue.citations.map(citation => {
                const source = report?.sources.find(s => s.question_id === issue.question_id && s.id === citation.evidence_id)
                const safeLink = source && /^https:\/\/(www\.)?(ecfr\.gov|hhs\.gov)\//.test(source.source_url)
                return <details key={`${citation.evidence_id}/${citation.passage_id}`}><summary>{source?.source_locator ?? citation.evidence_id} · {citation.passage_id}</summary>
                  <blockquote>{citation.quote}</blockquote><p>{source?.source_version} {source?.verified ? '· Complete source hash verified' : ''}</p>
                  {safeLink && <a href={source.source_url} target="_blank" rel="noreferrer">Open source reference</a>}
                  <p className="mono">{source?.source_sha256}</p></details>
              })}
            </section>)}
          </section>}
          {task.runtime && <p className="mono">Task: {task.id}<br />IRIS session: {task.runtime.session_id || 'Pending'} · message body: {task.runtime.message_id || 'Pending'}<br />Report: {task.runtime.report_id || 'Pending'}</p>}
          {report && <details><summary>Model, knowledge and preserved phase output</summary>
            <p>Model: {report.source.model} · source Agent revision {report.source.revision}<br />
              Knowledge: {report.source.table} · index {report.source.index_version}</p>
            <p className="mono">Corpus: {report.source.corpus}<br />Prompt contract: {report.authorization.contract_hash}</p>
            {report.phases.map(phase => <section key={phase.agent_session}><h4>{phase.phase} · {phase.state} · Agent session {phase.agent_session}</h4>
              <p>{phase.interactions ?? 'Not recorded'} SDK interactions · {phase.prompt_tokens ?? 'Not recorded'} input / {phase.completion_tokens ?? 'Not recorded'} output tokens</p>
              <pre>{phase.raw || 'No provider response recorded.'}</pre></section>)}
            {report.error && <p role="alert">{report.error}</p>}
          </details>}
        </>}
      </Panel>
      <Panel title="Human decision · exact reviewed revision">
        {record.decision ? <><Status>{record.decision.action}</Status><p>{record.decision.reason}</p>
          <p>{record.decision.decided_by} · {routeTime(record.decision.decided_at)}. This decision is immutable; changes require a new reviewed revision.</p></>
          : <><p>A positive AI result does not approve the proposal. Approval requires the latest submitted, valid, completed no-risk revision.
            Risks and material gaps must be addressed in a new reviewed revision.</p>
            <div className="form-actions">{(['approved', 'returned', 'rejected'] as const).map(value => <Button key={value} variant={value === 'approved' ? 'default' : 'outline'}
              disabled={disabled || !canWrite || !currentCatalog || !canDecide(record, value)} onClick={() => { setDecision(value); setReason(''); setConfirmed(false) }}>
              {{ approved: 'Approve revision', returned: 'Return for changes', rejected: 'Reject revision' }[value]}</Button>)}</div>
            {decision && <form onSubmit={event => { event.preventDefault(); void action(async signal => {
              const next = await apiRequest('/declarations/decide', decodeDeclarationRecord, signal,
                { authorization, body: decisionCommand(record, decision, reason) })
              await changed(next, signal, `Human decision recorded: ${decision}. No model called or data delivered.`)
            }) }}>
              <label className="field-label" htmlFor="declaration-decision-reason">Decision reason</label>
              <Textarea id="declaration-decision-reason" required maxLength={1000} value={reason} disabled={busy} onChange={e => setReason(e.target.value)} />
              <label className="confirmation-label"><input type="checkbox" checked={confirmed} disabled={busy} onChange={e => setConfirmed(e.target.checked)} />
                Confirm {decision} for {record.declaration_id} revision {record.revision} and task {task?.id}.</label>
              <div className="form-actions"><Button type="submit" disabled={disabled || !confirmed || !reason.trim()}>Record decision</Button>
                <Button type="button" variant="outline" disabled={busy} onClick={clearActions}>Cancel decision</Button></div>
            </form>}
          </>}
      </Panel>
      <DeclarationExecutionPanel key={record.id} record={record} authorization={authorization} canWrite={canWrite} readOnly={disabled} />
      {history && <Panel title="Immutable revision history">
        <p>Each revision keeps its own task, assessment and decision. A newer revision never inherits approval.</p>
        <div className="form-actions"><Button variant="outline" disabled={busy || revisionPage === undefined} onClick={() => setRevisionPage(undefined)}>Latest 25 revisions</Button>
          <Button variant="outline" disabled={busy || !history.has_older} onClick={() => setRevisionPage(history.older_before_revision)}>Older 25 revisions</Button></div>
        <div className="table-scroll"><table className="data-table"><thead><tr><th>Revision</th><th>Review / decision</th><th>Model requests</th><th /></tr></thead><tbody>
          {history.items.map(item => <tr key={item.id}><td>v{item.revision} · {item.proposal.title}</td>
            <td>{item.review.task?.assessment ? assessmentLabels[item.review.task.assessment] : item.review.task?.state ?? 'Not submitted'}<br />{item.decision?.action ?? 'Pending'}</td>
            <td>{item.review.task?.attempted_requests ?? 0}</td><td><Button variant="outline" disabled={busy} onClick={() => choose(item.id)} aria-label={`Inspect revision ${item.revision}`}>Inspect v{item.revision}</Button></td></tr>)}
        </tbody></table></div>
      </Panel>}
    </>}
  </>
}
