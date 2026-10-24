import { useEffect, useRef, useState } from 'react'
import { useAuth } from './auth'
import { PageHeading, Panel, Status } from './components/platform'
import { Button } from './components/ui/button'
import { Textarea } from './components/ui/textarea'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import { decodeManagedProduction, decodeProductionDetail, decodeProductionDiscovery, decodeProductionEvent, decodeProductionEvents, decodeProductionList, decodeProductionRisks, productionDistributionReviewLink } from './lib/productions'
import type { ProductionEvent, ProductionSnapshot } from './lib/productions'
import { ProductionObservationPanel } from './production-observation-panel'

export function ProductionComponentCatalog({ snapshot }: { snapshot: ProductionSnapshot }) {
  return <details><summary>Actual component catalog and configuration fingerprint</summary><p className="mono">{snapshot.config_hash}</p>
    <table className="data-table"><thead><tr><th>Host</th><th>Class</th><th>Business Partner</th><th>Enabled</th><th>Pool</th></tr></thead>
      <tbody>{snapshot.nodes.map(node => <tr key={node.name}><td>{node.name}</td><td>{node.class}</td>
        <td>{node.business_partner ? <Status tone="info">{node.business_partner}</Status> : 'Not supplied'}</td>
        <td>{node.enabled ? 'Yes' : 'No'}</td><td>{node.pool_size}</td></tr>)}</tbody></table>
  </details>
}
export function DistributionProductionReviewLink() {
  return <Panel title="Versioned organization-aware distribution evidence and advisory audit">
    <p>This Production uses the multi-organization distribution workflow. Inspect actual SQL, REST and HL7 branch receipts, pinned organization-policy revisions and separately authorized post-send AI audits in its dedicated workspace.</p>
    <p>The older generic M5 payload-review adapter does not establish review coverage for these message classes. Operational message observation below is separate from organization-aware advisory assessment.</p>
    <Button asChild variant="outline"><a href="/demo">Open organization-aware branch receipts and audit</a></Button>
  </Panel>
}

export function ProductionsPage() {
  const { authorization } = useAuth()
  const [state, setState] = useState<ReturnType<typeof decodeProductionList>>()
  const [discovery, setDiscovery] = useState<ReturnType<typeof decodeProductionDiscovery>>()
  const [selected, setSelected] = useState(() => {
    const value = new URLSearchParams(location.search).get('production') || ''
    return /^production-[a-f0-9]{64}$/.test(value) ? value : ''
  }), [choice, setChoice] = useState('')
  const [detail, setDetail] = useState<ReturnType<typeof decodeProductionDetail>>()
  const [events, setEvents] = useState<ReturnType<typeof decodeProductionEvents>>()
  const [before, setBefore] = useState(0), [refresh, setRefresh] = useState(0)
  const [pendingAnchor, setPendingAnchor] = useState('')
  const [riskOffset, setRiskOffset] = useState(0), [riskPage, setRiskPage] = useState<ReturnType<typeof decodeProductionRisks>>()
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [readError, setReadError] = useState(''), [listError, setListError] = useState('')
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  useEffect(() => {
    const controller = new AbortController()
    void apiRequest('/productions', decodeProductionList, controller.signal, { authorization }).then(value => {
      if (!controller.signal.aborted) { setState(value); setListError(''); setSelected(previous => previous || value.items[0]?.id || '') }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setListError(e instanceof Error ? e.message : 'Production list failed') })
    return () => controller.abort()
  }, [authorization, refresh])
  useEffect(() => {
    if (!selected) return
    const controller = new AbortController()
    void Promise.all([
      apiRequest(`/productions/${selected}`, decodeProductionDetail, controller.signal, { authorization }),
      apiRequest(`/productions/${selected}/events?before=${before}`, decodeProductionEvents, controller.signal, { authorization }),
      apiRequest(`/productions/${selected}/risks?before=${riskOffset}`, decodeProductionRisks, controller.signal, { authorization }),
    ]).then(([value, page, risks]) => {
      if (value.record.id !== selected || page.production_id !== selected || risks.production_id !== selected) throw new Error('Production response identity changed')
      if (!controller.signal.aborted) { setDetail(value); setEvents(page); setRiskPage(risks); setReadError('') }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setReadError(e instanceof Error ? e.message : 'Production read failed') })
    return () => controller.abort()
  }, [authorization, selected, before, riskOffset, refresh])
  useEffect(() => {
    if (!pendingAnchor || !events) return
    const target = document.getElementById(pendingAnchor)
    if (target) { target.scrollIntoView(); setPendingAnchor('') }
  }, [events, pendingAnchor])
  useEffect(() => { const timer = setInterval(() => setRefresh(n => n + 1), 5000); return () => clearInterval(timer) }, [])
  async function act(work: (signal: AbortSignal) => Promise<void>) {
    operation.current?.abort()
    const controller = new AbortController(); operation.current = controller
    setBusy(true); setError('')
    try { await work(controller.signal); if (!controller.signal.aborted) setRefresh(n => n + 1) }
    catch (e) { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Production action failed') }
    finally { if (!controller.signal.aborted) setBusy(false) }
  }
  function select(id: string) { setSelected(id); setDetail(undefined); setEvents(undefined); setPendingAnchor(''); setBefore(0); setRiskOffset(0); setRiskPage(undefined); setReadError(''); setError('') }
  const candidate = discovery?.items.find(s => s.id === choice)
  const record = detail?.record
  return <div className="monitor-page">
    <PageHeading eyebrow="IRIS · PRODUCTION OBSERVABILITY" title="Managed Productions"
      description="Discover running IRIS Productions and enroll the ones you choose. Each selected Production is observed across all its components, without registering individual business flows."
      action={<><Button asChild><a href="/demo/m5">Start fixed M5 onboarding</a></Button><Button variant="outline" disabled={busy || !state?.can_manage} onClick={() => { void act(async signal => {
        setDiscovery(await apiRequest('/productions/discover', decodeProductionDiscovery, signal, { authorization })); setChoice('')
      }) }}>Discover active Productions</Button><Button variant="outline" onClick={() => setRefresh(n => n + 1)}>Refresh Productions</Button></>} />
    <p className="callout">Read-only sidecar. Enrollment does not edit, start, stop or instrument business hosts, authorize payload access, grant AI budget or replay messages. Local structured-payload inspection requires separate explicit authorization. Operational warnings are not HIPAA findings.</p>
    <p className="callout">Production-wide scope, not a hand-picked route: new activity across its current components is in scope. Inspect actual message edges, session-linked evidence and bounded AI review below; these are not proof of complete end-to-end business paths. Enrollment grants no model budget.</p>
    {(error || readError || listError) && <p role="alert" className="callout">{error} {readError} {listError}</p>}
    {state?.error && <p role="alert" className="callout">{state.error}</p>}
    {discovery && <Panel title="Choose an active IRIS Production">
      {discovery.errors.map(e => <p role="alert" key={e.namespace}>{e.namespace}: {e.error}</p>)}
      <label className="field-label" htmlFor="production-choice">Active Production</label>
      <select id="production-choice" value={choice} onChange={e => setChoice(e.target.value)}>
        <option value="">Select namespace / Production</option>
        {discovery.items.map(s => <option key={s.id} value={s.id}>{s.namespace} / {s.production}{s.managed ? ' · already managed' : ''}</option>)}
      </select>
      {candidate && <><p>{candidate.nodes.length} components · configuration {candidate.config_hash}</p>
        {candidate.managed ? <p role="status">Already monitored. Select this Production in the inventory below to inspect it.</p> : <Button disabled={busy || !state?.can_manage} onClick={() => { void act(async signal => {
          const value = await apiRequest('/productions/enroll', decodeManagedProduction, signal, { authorization, body: {
            namespace: candidate.namespace, production: candidate.production, config_hash: candidate.config_hash, acknowledge_monitoring: true,
          } })
          select(value.id); setDiscovery(undefined)
        }) }}>Enable read-only monitoring</Button>}
      </>}
      {!discovery.items.length && <p>No accessible active Interoperability Production was found.</p>}
    </Panel>}
    <Panel title="Production inventory">
      {!state && <p>Loading managed objects…</p>}
      {state && !state.items.length && <p>No Production enrolled. Discover and select an active Production to begin.</p>}
      {state?.items.map(p => <article className="monitor-card" key={p.id}>
        <h3>{p.namespace} / {p.production}</h3>
        <p>{p.enabled ? 'Observer enabled' : 'Observer paused'} · {p.current.running && p.current.production === p.production ? 'Running at last scan' : 'Not active at last scan'} · scan {p.last_scan ? routeTime(p.last_scan) : 'Pending independent observer'}</p>
        {p.error && <p role="alert">{p.error}</p>}
        <Button variant={selected === p.id ? 'default' : 'outline'} onClick={() => select(p.id)}>Inspect {p.namespace} / {p.production}</Button>
      </article>)}
    </Panel>
    {record && <div key={record.id}>
      <Panel title={`${record.namespace} / ${record.production}`} action={<Button variant="outline" disabled={busy || !state?.can_manage || !!readError} onClick={() => { void act(async signal => {
        await apiRequest('/productions/manage', decodeManagedProduction, signal, { authorization, body: { id: record.id, revision: record.revision, enabled: !record.enabled } })
      }) }}>{record.enabled ? 'Pause observation' : 'Resume observation'}</Button>}>
        <p>Enrolled by {record.enrolled_by} · {routeTime(record.enrolled_at)}. Observation scope: local-iris / {record.namespace} / {record.production}.</p>
        <p>New attributed message headers: {record.header_count} · warning/error logs: {record.log_count}. Each scan reads at most 200 new rows per stream; retained cursors catch up.</p>
        <p className="subtle">Namespace headers lack a Production identity column. Attribution uses matching component names, enrollment time and the same active Production before/after collection; it cannot prove continuity between scans. Bodies are not inspected without separate consent; free-text logs are not collected. Configuration changes and inaccessible/stopped sources are explicit events/errors.</p>
        {record.error && <p role="alert">{record.error}</p>}
        <ProductionComponentCatalog snapshot={record.current} />
      </Panel>
      {record.namespace === 'DEMODISTRIBUTION' ? <DistributionProductionReviewLink /> :
        <ProductionObservationPanel key={record.id} record={record} canManage={!!state?.can_manage && !readError} refresh={refresh} onChanged={() => setRefresh(n => n + 1)} />}
      {record.namespace !== 'DEMODISTRIBUTION' && <Panel title="Business-risk reviews for this Production">
        <p className="callout">{detail.coverage}</p>
        <p className="subtle">Linked source review history can predate enrollment. These are persisted business findings, separate from newly captured operational events below.</p>
        {!riskPage?.items.length && <p>No linked business-risk review exists on this page. This is not a no-risk result.</p>}
        {riskPage?.items.map(r => <article key={`${r.source}/${r.id}`} className="monitor-card">
          <h3>{r.title || r.batch_id || r.id}</h3><Status tone={r.category === 'risk_identified' ? 'danger' : r.category === 'no_deviation_on_checked_use' ? 'success' : 'warning'}>{r.category.replaceAll('_', ' ')}</Status>
          <p>{r.source} · review {r.state} · event {r.event_state}</p>
          {r.record_id && <p className="mono">Declaration: {r.record_id}</p>}
          {r.result !== null && r.result !== '' && <details><summary>Actual saved assessment</summary><pre>{JSON.stringify(r.result, null, 2)}</pre></details>}
          <a href={r.link} onClick={event => {
            if (r.event_before !== undefined) {
              event.preventDefault(); setBefore(r.event_before); setPendingAnchor(r.link.slice(1))
            }
          }}>Open source evidence and review actions</a>
        </article>)}
        <div className="form-actions"><Button variant="outline" disabled={!riskOffset} onClick={() => setRiskOffset(0)}>First review page</Button>
          <Button variant="outline" disabled={!riskPage?.next_offset} onClick={() => setRiskOffset(riskPage?.next_offset || 0)}>More reviews</Button></div>
      </Panel>}
      <Panel title="Monitoring events for this Production" action={<span>{record.namespace} / {record.production}</span>}>
        {events?.items.map(e => <ProductionEventCard key={`${e.production_id}/${e.source_key}/${e.revision}`} event={e} disabled={busy || !state?.can_manage || !!readError} action={body => act(async signal => {
          const result = await apiRequest('/productions/action', decodeProductionEvent, signal, { authorization, body })
          if (result.production_id !== record.id) throw new Error('Event response belongs to another Production')
        })} />)}
        {events && !events.items.length && <p>No captured events in this page.</p>}
        <div className="form-actions"><Button variant="outline" disabled={!before} onClick={() => setBefore(0)}>Latest events</Button>
          <Button variant="outline" disabled={!events?.next_before} onClick={() => setBefore(events?.next_before || 0)}>Older events</Button></div>
      </Panel>
    </div>}
  </div>
}

export function ProductionEventCard({ event, disabled, action }: { event: ProductionEvent; disabled: boolean; action: (body: object) => Promise<void> }) {
  const [text, setText] = useState('')
  const distributionReview = productionDistributionReviewLink(event)
  const transitions = event.state === 'open' ? ['in_review', 'ignored'] : event.state === 'in_review' ? ['needs_information', 'resolved', 'ignored'] :
    event.state === 'needs_information' ? ['in_review', 'resolved', 'ignored'] : ['open']
  return <article id={`production-event-${event.production_id}-${event.source_key}`} className="monitor-card">
    <h3>{event.title}</h3><Status tone={event.severity === 'info' ? 'info' : 'warning'}>{event.category.replaceAll('_', ' ')}</Status>
    <p>{routeTime(event.created_at)} · {event.state} v{event.revision}</p>
    {distributionReview && <Button asChild variant="outline"><a href={distributionReview}>Inspect evidence / review</a></Button>}
    <details><summary>Metadata provenance</summary><pre>{JSON.stringify(event.evidence, null, 2)}</pre></details>
    <label className="field-label" htmlFor={`note-${event.source_key}`}>Event review note · {event.source_key}</label>
    <Textarea id={`note-${event.source_key}`} value={text} maxLength={2000} disabled={disabled} onChange={e => setText(e.target.value)} />
    <div className="form-actions">{transitions.map(next => <Button variant="outline" key={next} disabled={disabled || !text.trim()}
      onClick={() => { void action({ production_id: event.production_id, source_key: event.source_key, revision: event.revision, action: next, text }) }}>{next.replaceAll('_', ' ')}</Button>)}</div>
    {event.actions.map((a, i) => <p key={i}>{routeTime(a.time)} · {a.actor}: {a.before} → {a.after} · {a.text}</p>)}
  </article>
}
