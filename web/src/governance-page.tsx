import { useEffect, useRef, useState } from 'react'
import type { FormEvent } from 'react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Textarea } from './components/ui/textarea'
import { PageHeading, Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeGovernance, decodeRouteEvidence, decodeRouteRecord, decodeRouteTemplate, receiptInput, routeTime } from './lib/governance'
import type { GovernanceState, RouteEvidence, RouteRecord, RouteTemplate } from './lib/governance'
import { RouteReviewPanel } from './route-review-panel'
import { useAuth } from './auth'

export function LiveGovernancePage() {
  const { authorization } = useAuth()
  const [state, setState] = useState<GovernanceState>()
  const [selected, setSelected] = useState<RouteRecord>(), [template, setTemplate] = useState<RouteTemplate>()
  const [days, setDays] = useState(30)
  const [evidence, setEvidence] = useState<RouteEvidence>(), [batch, setBatch] = useState(''), [pin, setPin] = useState('')
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [notice, setNotice] = useState('')
  const session = useRef(0)
  const post = (body: object) => ({ authorization, body })

  function choose(record?: RouteRecord) {
    setSelected(record); setEvidence(undefined); setBatch(''); setPin(''); setError(''); setNotice('')
  }
  async function action(work: () => Promise<void>) {
    const current = session.current
    setBusy(true); setError(''); setNotice('')
    try { await work() }
    catch (e) { if (current === session.current) setError(e instanceof Error ? e.message : 'Governance operation failed') }
    finally { if (current === session.current) setBusy(false) }
  }
  async function refresh(after = '') {
    const value = await apiRequest(`/governance${after ? `?after=${encodeURIComponent(after)}` : ''}`, decodeGovernance, undefined, { authorization })
    setState(value)
    const current = selected && value.records.find(r => r.id === selected.id)
    choose(current ?? value.records[0])
  }
  useEffect(() => {
    const controller = new AbortController()
    void apiRequest('/governance', decodeGovernance, controller.signal, { authorization }).then(value => {
      if (!controller.signal.aborted) { setState(value); choose(value.records[0]) }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Governance load failed') })
    return () => { controller.abort(); session.current++ }
  }, [authorization])
  async function register(event: FormEvent) {
    event.preventDefault()
    if (!template) return
    await action(async () => {
      const record = await apiRequest('/governance/register', decodeRouteRecord, undefined, post({
        declaration: template.declaration, valid_from: template.valid_from,
        valid_until: template.valid_from + days * 86400, expected_config_hash: template.binding.config_hash,
      }))
      const value = await apiRequest('/governance', decodeGovernance, undefined, { authorization })
      setState(value); choose(record); setTemplate(undefined)
      setNotice('Immutable declaration registered. Not approved, not activated, no data sent. Review the exact version below.')
    })
  }
  const d = selected?.core.declaration
  const changeDraft = (field: 'route_id' | 'owner' | 'purpose_text' | 'revision', value: string | number) => {
    setTemplate(t => t ? { ...t, declaration: { ...t.declaration, [field]: value } } : t)
  }

  return <div className="monitor-page governance-page">
    <PageHeading eyebrow="LEGACY ROUTES · LIVE SYNTHETIC RECORDS" title="Legacy route governance"
      description="Register a bounded utilization purpose, review an exact approval version, then compare it with actual historical delivery. Registry approval never activates a route."
      action={<><Button asChild variant="outline"><a href="/declarations">New data-use declarations</a></Button><Button variant="outline" disabled={busy} onClick={() => { void action(() => refresh()) }}>Refresh records</Button></>} />
    <div className="callout">Synthetic data only. This page does not invoke models or activate/deliver routes. The independent background observer reviews only explicitly funded batches. Logical service labels are not verified end-user identities. Never enter patient information in business declarations.</div>
    {error && <div className="callout" role="alert">{error}</div>}
    {notice && <div className="callout" role="status">{notice}</div>}
    {!state ? <Panel title="Loading route governance"><p>Reading records using your workspace sign-in. Use Refresh records to retry if needed.</p></Panel> : <>
      <RouteReviewPanel key={authorization} authorization={authorization} canWrite={state.can_write} />
      <div className="two-columns">
        <Panel title="1 · Internal aggregation"><Status tone="info">Preset approval baseline</Status>
          <p>PIPELINE: four SQL tables / eight rows → eight FHIR resources in FHIRDEMO.</p>
          <p>Purpose: internal consolidation. The actual declaration and approval are selectable below; no automatic legal or Agent pass is implied.</p>
        </Panel>
        <Panel title="2 · Data utilization"><Status tone="info">Separate registration and approval</Status>
          <p>FHIRDEMO: two Patient + two Encounter resources → bounded projection → UTILIZATION BO / SQL receiver.</p>
          <p>Same-instance simulated downstream, not a remote HTTP receiver. Stable IDs remain linkable.</p>
          <Button disabled={busy || !state.can_write} onClick={() => { void action(async () => {
            const value = await apiRequest('/governance/template', decodeRouteTemplate, undefined, { authorization })
            setTemplate(value); setDays(30)
          }) }}>New utilization declaration</Button>
          {!state.can_write && <p className="subtle">Read-only account: registration and approval require builder permission.</p>}
        </Panel>
      </div>
      {template && <Panel title="Register a new immutable utilization version" action={<Button variant="outline" disabled={busy} onClick={() => setTemplate(undefined)}>Cancel proposal</Button>}>
        <form onSubmit={register}>
          <div className="two-columns"><div>
            <label className="field-label" htmlFor="route-id">Business route ID</label>
            <Input id="route-id" required pattern={"[A-Za-z][A-Za-z0-9_.\\-]{0,127}"} maxLength={128} value={template.declaration.route_id} onChange={e => changeDraft('route_id', e.target.value)} />
            <label className="field-label" htmlFor="route-revision">Revision</label>
            <Input id="route-revision" required type="number" min={1} max={100000} value={template.declaration.revision} onChange={e => changeDraft('revision', Number(e.target.value))} />
            <label className="field-label" htmlFor="route-owner">Responsible office / owner</label>
            <Input id="route-owner" required pattern={"[A-Za-z][A-Za-z0-9_.\\-]{0,127}"} maxLength={128} value={template.declaration.owner} onChange={e => changeDraft('owner', e.target.value)} />
            <label className="field-label" htmlFor="route-purpose">Declared business purpose · no patient information</label>
            <Textarea id="route-purpose" required maxLength={2000} rows={5} value={template.declaration.purpose_text} onChange={e => changeDraft('purpose_text', e.target.value)} />
            <label className="field-label" htmlFor="route-days">Validity in days (1–30)</label>
            <Input id="route-days" required type="number" min={1} max={30} value={days} onChange={e => setDays(Number(e.target.value))} />
          </div><div>
            <h3>Fixed executable recipe</h3><p>Purpose code: {template.declaration.purpose_code}</p>
            <p>Logical service identity: {template.declaration.service_identity}</p>
            <p>Recipient: {template.declaration.recipient}</p><p>Resources: {template.declaration.scope.resources.join(', ')} · maximum {template.declaration.scope.max_records} records.</p>
            <p>Cohort: {template.declaration.scope.patient_selection}</p>
            <ul>{template.declaration.scope.fields.map(field => <li key={field} className="mono">{field}</li>)}</ul>
            <p className="subtle">Identity, recipient, cohort and scope are fixed to the installed demo exporter. This form does not modify the transform or accept an arbitrary endpoint/query.</p>
            <p className="mono subtle">Bound configuration: {template.binding.config_hash}</p>
            <p>Valid from {routeTime(template.valid_from)}. A later revision gets no inherited approval. Duplicate submission is accepted only if the exact version content is unchanged.</p>
          </div></div>
          <div className="form-actions"><Button type="submit" disabled={busy}>Register only · no approval or activation</Button></div>
        </form>
      </Panel>}
      <Panel title="Immutable registry versions" action={<><Button variant="outline" disabled={busy} onClick={() => { void action(() => refresh()) }}>First page</Button>
        <Button variant="outline" disabled={busy || !state.next_cursor} onClick={() => { void action(() => refresh(state.next_cursor)) }}>Next 25 records</Button></>}>
        <div className="table-scroll"><table className="data-table"><thead><tr><th>Route / revision</th><th>Kind</th><th>Registry approval</th><th>Submitted by</th><th /></tr></thead>
          <tbody>{state.records.map(record => <tr key={record.id} aria-selected={selected?.id === record.id}>
            <td>{record.core.declaration.route_id} · v{record.core.declaration.revision}</td><td>{record.core.declaration.kind}</td>
            <td>{record.approval ? 'Recorded · not activation' : 'Pending'}</td><td>{record.submitted_by}</td>
            <td><Button variant={selected?.id === record.id ? 'default' : 'outline'} size="sm" disabled={busy} onClick={() => choose(record)}>Inspect version {record.core.declaration.revision}</Button></td>
          </tr>)}</tbody></table></div>
        {!state.records.length && <p>No registered versions on this page. No fixture record is substituted.</p>}
      </Panel>
      {selected && d && <>
        <h2>{d.route_id} · revision {d.revision}</h2>
        {d.kind === 'utilization' && <div className="form-actions"><Button variant="outline" disabled={busy || !state.can_write} onClick={() => { void action(async () => {
          const value = await apiRequest('/governance/template', decodeRouteTemplate, undefined, { authorization })
          setTemplate({ ...value, declaration: { ...d, revision: d.revision + 1 } }); setDays(30)
        }) }}>Draft next revision · approval not inherited</Button></div>}
        <p className="mono subtle">Record {selected.id}<br />Exact approval digest {selected.digest}</p>
        <div className="three-columns route-evidence-columns">
          <Panel title="Declared · business claim" action={<Status tone="warning">Unverified purpose</Status>}>
            <h3>{d.purpose_code}</h3><p>{d.purpose_text}</p><dl>
              <dt>Owner</dt><dd>{d.owner}</dd><dt>Logical service identity</dt><dd>{d.service_identity}</dd>
              <dt>Declared recipient</dt><dd>{d.recipient}</dd><dt>Cohort</dt><dd>{d.scope.patient_selection}</dd>
              <dt>Submitted</dt><dd>{selected.submitted_by} · {routeTime(selected.submitted_at)}</dd>
            </dl><p className="subtle">The submitted purpose is compared with organization policy and actual delivery; it is not proof of all downstream conduct.</p>
          </Panel>
          <Panel title="Approved · exact registry scope" action={<Status tone={selected.approval ? 'info' : 'warning'}>{selected.approval ? 'Recorded only' : 'Not approved'}</Status>}>
            {selected.approval?.scenario && <section aria-label="Approved organization scenario">
              <h3>{selected.approval.scenario.organization_id} · internal-use policy</h3>
              <p>{selected.approval.scenario.policy_id} v{selected.approval.scenario.policy_version} · same simulated covered entity</p>
              <p>{selected.approval.scenario.permitted_use}</p>
              <p>{selected.approval.scenario.conditions}</p>
              <p className="subtle">Controlled identifiable data. This scenario does not rely on de-identification or individual patient authorization. Separate namespaces represent technical isolation, not separate organizations.</p>
            </section>}
            <p>{d.scope.resources.join(', ')} · max {d.scope.max_records} resources</p>
            <ul>{d.scope.fields.map(field => <li key={field} className="mono">{field}</li>)}</ul>
            <p>Valid: {routeTime(selected.core.valid_from)} → {routeTime(selected.core.valid_until)}</p>
            <p className="mono subtle">{selected.core.binding.namespace} / {selected.core.binding.production}<br />Config {selected.core.binding.config_hash}</p>
            {selected.approval ? <p>Recorded by {selected.approval.approved_by} at {routeTime(selected.approval.approved_at)}. Current expiry/config status requires a separate applicability check; this badge does not assert current admission.</p> :
              d.kind === 'utilization' ? <>
                <p>Records this revision in the synthetic registry only. No activation, legal authorization or delivery.</p>
                <Button disabled={busy || !state.can_write} onClick={() => { void action(async () => {
                  const record = await apiRequest('/governance/approve', decodeRouteRecord, undefined, post({ id: selected.id, digest: selected.digest, confirm_registry_only: true }))
                  setSelected(record); setState(s => s ? { ...s, records: s.records.map(r => r.id === record.id ? record : r) } : s)
                  setNotice('Exact synthetic approval recorded. The active route and registration pointer were not changed; no data sent.')
                }) }}>Approve exact revision · registry only</Button>
              </> : <p>Preset aggregation approval is read-only on this page.</p>}
            <p className="subtle">No four-eyes separation is enforced. Synthetic approval is not legal authorization.</p>
          </Panel>
          <Panel title="Observed · actual historical delivery" action={<Status tone={evidence ? 'success' : 'neutral'}>{evidence ? 'Revalidated' : 'Not loaded'}</Status>}>
            {!evidence ? <p>No historical evidence has been loaded for this revision. This does not mean no delivery exists. Supply the original saved receipt below.</p> : <>
              <p>Batch <strong>{evidence.evidence.batch_id}</strong></p><p>{evidence.evidence.observed.transport}</p>
              <p>Configured recipient: {evidence.evidence.observed.configured_recipient}</p>
              <p>Message {evidence.evidence.observed.message_id} · session {evidence.evidence.observed.session_id}</p>
              <p>{routeTime(evidence.evidence.observed.observed_at)}</p>
              <h3>Resource counts</h3><dl>{Object.entries(evidence.evidence.observed.inspection.resource_counts).map(([key, value]) => <div key={key}><dt>{key}</dt><dd>{value}</dd></div>)}</dl>
              <h3>Known-field indicators</h3><dl>{Object.entries(evidence.evidence.observed.identifier_counts).map(([key, value]) => <div key={key}><dt>{key.replaceAll('_', ' ')}</dt><dd>{value}</dd></div>)}</dl>
              <p className="subtle">{evidence.evidence.observed.readback_basis}. Limited counts are not a PHI scan or a de-identification pass.</p>
            </>}
          </Panel>
        </div>
        <Panel title="Revalidate historical evidence · original receipt required">
          <p>The batch must belong to this exact declaration version. A new declaration has no inherited delivery evidence. Read-only revalidation does not send data or invoke an Agent.</p>
          <label className="field-label" htmlFor="route-receipt">Load original local receipt JSON · only its batch ID and digest are sent</label>
          <Input key={selected.id} id="route-receipt" type="file" accept=".json,application/json" disabled={busy} onChange={event => {
            const file = event.target.files?.[0]; setEvidence(undefined); setBatch(''); setPin(''); setError('')
            if (!file) return
            void action(async () => {
              if (file.size > 100000) throw new Error('Original receipt exceeds 100 KB')
              const value = receiptInput(JSON.parse(await file.text()), selected)
              setBatch(value.batch); setPin(value.pin)
            })
          }} />
          <form onSubmit={event => {
            event.preventDefault(); setEvidence(undefined)
            void action(async () => {
              const value = await apiRequest('/governance/evidence', decodeRouteEvidence, undefined, post({ id: selected.id, batch_id: batch, receipt_hash: pin }))
              if (value.evidence.approved.record_id !== selected.id || value.evidence.provenance.receipt_hash !== pin) throw new Error('Evidence response does not match this record and original pin')
              setEvidence(value)
            })
          }}>
            <label className="field-label" htmlFor="route-batch">Batch ID</label>
            <Input id="route-batch" required pattern={"[A-Za-z0-9\\-]{1,64}"} maxLength={64} value={batch} onChange={e => { setBatch(e.target.value); setEvidence(undefined) }} />
            <label className="field-label" htmlFor="route-pin">Original receipt SHA-256 · do not replace with a newly discovered digest</label>
            <Input id="route-pin" required pattern="[a-f0-9]{64}" maxLength={64} className="mono" value={pin} onChange={e => { setPin(e.target.value); setEvidence(undefined) }} />
            <div className="form-actions"><Button type="submit" disabled={busy}>Revalidate evidence · no delivery</Button></div>
          </form>
          {evidence && <div className="route-facts">
            <h3>Current admission: {evidence.current_admission.state}</h3>
            <p>Checked {routeTime(evidence.current_admission.checked_at)}. Separate from the historical evidence; it does not activate this version or authorize a new send.</p>
            <p>{evidence.evidence.limitations}</p>
            <details><summary>Actual output field paths and configured destination</summary><pre>{JSON.stringify({ fields: evidence.evidence.observed.inspection.field_paths, destination: evidence.evidence.observed.destination, binding: evidence.evidence.observed.runtime_binding }, null, 2)}</pre></details>
            {evidence.evidence.packet.facts.map(fact => <details key={fact.id}><summary>{fact.id} · {fact.kind} / {fact.verification}</summary>
              <p>{fact.text}</p><pre>{JSON.stringify(evidence.evidence.fact_evidence.find(ref => ref.fact_id === fact.id), null, 2)}</pre></details>)}
            <details><summary>Integrity links · unkeyed hashes, not signatures</summary><pre>{JSON.stringify({ evidence_hash: evidence.evidence.evidence_hash, ...evidence.evidence.provenance }, null, 2)}</pre></details>
          </div>}
        </Panel>
      </>}
    </>}
  </div>
}
