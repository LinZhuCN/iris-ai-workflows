import { useEffect, useState } from 'react'
import { Button } from './components/ui/button'
import { PageHeading, Panel, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeEvents } from './lib/events'
import type { EventState } from './lib/events'
import { decodeRuleDraft, decodeRulePlan, decodeRuleState } from './lib/rules'
import type { RuleState } from './lib/rules'
import { useAuth } from './auth'

export function LiveRulePage() {
  const { authorization } = useAuth()
  const [state, setState] = useState<RuleState>()
  const [events, setEvents] = useState<EventState>()
  const [selected, setSelected] = useState('')
  const [bundle, setBundle] = useState('')
  const [consent, setConsent] = useState('')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  async function load(auth: string) {
    const [rules, observations] = await Promise.all([
      apiRequest('/rules', decodeRuleState, undefined, { authorization: auth }),
      apiRequest('/events', decodeEvents, undefined, { authorization: auth }),
    ])
    setState(rules); setEvents(observations)
    setBundle(current => current || JSON.stringify(rules.template, null, 2))
  }
  useEffect(() => {
    const controller = new AbortController()
    void Promise.all([
      apiRequest('/rules', decodeRuleState, controller.signal, { authorization }),
      apiRequest('/events', decodeEvents, controller.signal, { authorization }),
    ]).then(([rules, observations]) => {
      if (!controller.signal.aborted) {
        setState(rules); setEvents(observations); setBundle(JSON.stringify(rules.template, null, 2))
      }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Rule load failed') })
    return () => controller.abort()
  }, [authorization])
  async function action(run?: () => Promise<unknown>) {
    setBusy(true); setError('')
    try { if (run) await run(); await load(authorization); setConsent('') }
    catch (e) { setError(e instanceof Error ? e.message : 'Rule action failed') }
    finally { setBusy(false) }
  }
  const opinions = events?.events.flatMap(event => event.opinions.map(opinion => ({ event, opinion }))) || []
  const choice = opinions.find(o => o.opinion.id === selected)
  return <div className="monitor-page agent-live-page">
    <PageHeading eyebrow="P6 · REVIEWED LOCAL DEMO GATE" title="Rules"
      description="Manual bounded rules, not AI-generated code. Test → plan → approve the exact digest → activate → verify real source receipts. No model calls."
      action={<Button variant="outline" disabled={busy} onClick={() => { void action() }}>Refresh rules</Button>} />
    {error && <div className="callout" role="alert">{error}</div>}
    {!state ? <Panel title="Loading rules"><p>Reading records using your workspace sign-in. Use Refresh rules to retry if needed.</p></Panel> : <>
      <Panel title="Actual target policy" action={<Status tone="info">Revision {String(state.target.revision)}</Status>}>
        <p>Only local-demo / DEMO / Demo.Production / before_send is supported. A hold prevents the local Sink call; it does not replay, redact or delete an old message. Unknown facts fail closed while enabled.</p>
        <pre className="agent-json">{JSON.stringify(state.target, null, 2)}</pre>
      </Panel>
      <Panel title="Create a manual rule from a saved opinion">
        <p>Saving an opinion alone changes nothing. This separate action links its immutable hash to a manual AST. No raw opinion is sent to a model.</p>
        <label htmlFor="rule-opinion" className="field-label">Saved event opinion</label>
        <select id="rule-opinion" value={selected} onChange={e => setSelected(e.target.value)}><option value="">Select an opinion saved in Events</option>
          {opinions.map(({ event, opinion }) => <option key={opinion.id} value={opinion.id}>{event.title} · {opinion.text.slice(0, 120)}</option>)}</select>
        {!opinions.length && <p><a href="/events">Open Events and save an original opinion first.</a></p>}
        <label htmlFor="rule-bundle" className="field-label">Bounded JSON AST · maximum 3,000 UTF-8 bytes, five rules and five AND conditions per rule</label>
        <textarea id="rule-bundle" rows={12} value={bundle} onChange={e => setBundle(e.target.value)} />
        <Button disabled={busy || !state.can_write || !choice} onClick={() => { void action(async () => {
          if (!choice) throw new Error('Select a saved opinion')
          const parsed: unknown = JSON.parse(bundle)
          return apiRequest('/rules/create', decodeRuleDraft, undefined, { authorization, body: { event_id: choice.event.id, opinion_id: choice.opinion.id, bundle: parsed } })
        }) }}>Create draft · no deployment</Button>
      </Panel>
      <Panel title="Drafts and deterministic tests">
        {!state.drafts.length && <p>No rule drafts yet.</p>}
        {state.drafts.map(d => <article key={d.id} className="monitor-card">
          <h3 className="mono">{d.id}</h3><Status tone={d.state === 'tested' ? 'success' : 'warning'}>{d.state} · r{d.revision}</Status>
          <p className="mono">Bundle {d.bundle_hash}<br />Origin: {d.origin} · <a href={`/events/${d.event_id}`}>Source event</a></p>
          <details><summary>Exact bundle and golden test results</summary><pre className="agent-json">{JSON.stringify({ bundle: d.bundle, report: d.report }, null, 2)}</pre></details>
          <div className="form-actions">
            <Button variant="outline" disabled={busy || !state.can_write || d.state !== 'draft'} onClick={() => { void action(() => apiRequest('/rules/test', decodeRuleDraft, undefined, { authorization, body: { id: d.id, revision: d.revision } })) }}>Test exact bundle</Button>
            <Button variant="outline" disabled={busy || !state.can_write || d.state !== 'tested'} onClick={() => { void action(() => apiRequest('/rules/plan', decodeRulePlan, undefined, { authorization, body: { id: d.id, revision: d.revision } })) }}>Create target plan</Button>
          </div>
        </article>)}
      </Panel>
      <Panel title="Approval, activation and rollback history">
        <p>Plans and approvals expire after 15 minutes. Loaded is not effect-verified: Refresh waits for two real, hash/revision-matched source observations. Rollback creates a new tested plan and still needs approval. No held message is replayed.</p>
        {state.plans.map(p => <article key={p.id} className="monitor-card">
          <h3 className="mono">{p.id}</h3><Status tone={p.state === 'effect_verified' ? 'success' : 'warning'}>{p.state}</Status>
          <p>{p.effect}</p><p className="mono">Approval digest: {p.digest}<br />Source configuration: {p.source_hash}<br />Expected policy revision: {p.expected_revision}</p>
          {p.error && <p role="status">{p.error}</p>}
          <details><summary>Desired vs previous bundle</summary><pre className="agent-json">{JSON.stringify({ desired: p.bundle, previous: p.previous_bundle }, null, 2)}</pre></details>
          {p.state === 'planned' && <label><input type="checkbox" checked={consent === `${p.id}:${p.digest}`} onChange={e => setConsent(e.target.checked ? `${p.id}:${p.digest}` : '')} /> I approve this exact digest for the local synthetic DEMO.</label>}
          <div className="form-actions">
            <Button variant="outline" disabled={busy || !state.can_write || p.state !== 'planned' || consent !== `${p.id}:${p.digest}`} onClick={() => { void action(() => apiRequest('/rules/approve', decodeRulePlan, undefined, { authorization, body: { id: p.id, digest: p.digest } })) }}>Approve exact plan</Button>
            <Button disabled={busy || !state.can_write || !['approved', 'unknown', 'loaded'].includes(p.state)} onClick={() => { void action(() => apiRequest('/rules/apply', decodeRulePlan, undefined, { authorization, body: { id: p.id, digest: p.digest } })) }}>{p.state === 'unknown' ? 'Reconcile same deployment' : 'Activate and send new synthetic probes'}</Button>
            <Button variant="outline" disabled={busy || !state.can_write || !['loaded', 'effect_verified'].includes(p.state)} onClick={() => { void action(() => apiRequest('/rules/rollback', decodeRulePlan, undefined, { authorization, body: { id: p.id } })) }}>Plan rollback · requires approval</Button>
          </div>
        </article>)}
      </Panel>
    </>}
  </div>
}
