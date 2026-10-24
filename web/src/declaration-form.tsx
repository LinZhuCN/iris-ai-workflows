import { useState } from 'react'
import type { FormEvent, ReactNode } from 'react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Textarea } from './components/ui/textarea'
import { Panel } from './components/platform'
import { dateInput, inputDate, newProposal, saveCommand } from './lib/declarations'
import type { DeclarationCatalog, DeclarationRecord, Proposal } from './lib/declarations'

function Field({ id, label, children }: { id: string; label: string; children: ReactNode }) {
  return <div><label className="field-label" htmlFor={id}>{label}</label>{children}</div>
}
export function DeclarationForm({ catalog, previous, busy, onSave, onCancel }: {
  catalog: DeclarationCatalog; previous?: DeclarationRecord; busy: boolean
  onSave: (command: ReturnType<typeof saveCommand>) => Promise<void>; onCancel: () => void
}) {
  const [id, setId] = useState(previous?.declaration_id ?? '')
  const [proposal, setProposal] = useState<Proposal>(() => previous ? structuredClone(previous.proposal) : newProposal())
  const [error, setError] = useState('')
  const set = <K extends keyof Proposal>(key: K, value: Proposal[K]) => setProposal(p => ({ ...p, [key]: value }))
  const toggle = (key: 'resources' | 'fields', value: string) => {
    const values = proposal.data[key]
    const next = values.includes(value) ? values.filter(item => item !== value) : [...values, value]
    set('data', { ...proposal.data, [key]: next,
      ...(key === 'resources' ? { fields: proposal.data.fields.filter(field => next.includes(field.split('.')[0])) } : {}) })
  }
  async function save(event: FormEvent) {
    event.preventDefault(); setError('')
    try { await onSave(saveCommand(id, proposal, previous)) }
    catch (e) { setError(e instanceof Error ? e.message : 'Declaration save failed') }
  }
  const recipient = catalog.recipients.find(r => r.id === proposal.recipient_id)
  const recipe = catalog.recipes.find(r => r.id === proposal.handling.recipe_id)
  return <Panel title={previous ? `Edit ${id} · new revision ${previous.revision + 1}` : 'New data-use declaration'}>
    <p>Describe the proposed use in your own words. Saving creates an immutable draft, without an assessment, approval or model charge.</p>
    {error && <div className="callout" role="alert">{error}</div>}
    <form onSubmit={save} className="declaration-form">
      <fieldset disabled={busy}>
        <legend>1 · Identity and intended use</legend>
        <div className="two-columns">
          <Field id="declaration-id" label="Declaration ID"><Input id="declaration-id" required readOnly={!!previous}
            pattern={"[A-Za-z][A-Za-z0-9_.\\-]{0,127}"} maxLength={128} value={id} onChange={e => setId(e.target.value)} /></Field>
          <Field id="declaration-title" label="Title"><Input id="declaration-title" required maxLength={200} value={proposal.title} onChange={e => set('title', e.target.value)} /></Field>
          <Field id="declaration-owner" label="Responsible office / owner"><Input id="declaration-owner" required maxLength={200} value={proposal.owner} onChange={e => set('owner', e.target.value)} /></Field>
          <Field id="declaration-category" label="Purpose category"><select id="declaration-category" value={proposal.purpose.category} onChange={e => set('purpose', { ...proposal.purpose, category: e.target.value })}>
            {catalog.purpose_categories.map(value => <option key={value} value={value}>{value.replaceAll('_', ' ')}</option>)}</select></Field>
        </div>
        {(['text', 'activities', 'expected_output'] as const).map(key => <Field key={key} id={`purpose-${key}`} label={{ text: 'Specific business purpose', activities: 'Planned activities', expected_output: 'Expected output' }[key]}>
          <Textarea id={`purpose-${key}`} required maxLength={2000} value={proposal.purpose[key]} onChange={e => set('purpose', { ...proposal.purpose, [key]: e.target.value })} />
        </Field>)}
      </fieldset>
      <fieldset disabled={busy}><legend>2 · Recipient and data scope</legend>
        <Field id="declaration-recipient" label="Recipient"><select id="declaration-recipient" value={proposal.recipient_id} onChange={e => set('recipient_id', e.target.value)}>
          {catalog.recipients.map(r => <option value={r.id} key={r.id}>{r.name}</option>)}</select></Field>
        <p className="subtle">Registered relationship: {recipient?.relationship}. Organization: {catalog.organization.organization_id}.
          {' '}{recipient?.executable ? 'A bounded execution recipe may be supported.' : 'Assessment only; no connected recipient execution.'}</p>
        <fieldset className="declaration-choices"><legend>Requested resources</legend>{catalog.resources.map(value => <label key={value}>
          <input type="checkbox" checked={proposal.data.resources.includes(value)} onChange={() => toggle('resources', value)} />{value}</label>)}</fieldset>
        <fieldset className="declaration-choices"><legend>Requested fields</legend>{catalog.fields.map(value => <label key={value}>
          <input type="checkbox" disabled={!proposal.data.resources.includes(value.split('.')[0])}
            checked={proposal.data.fields.includes(value)} onChange={() => toggle('fields', value)} />{value}</label>)}</fieldset>
        <div className="two-columns">
          <Field id="declaration-cohort" label="Cohort"><select id="declaration-cohort" value={proposal.data.cohort} onChange={e => set('data', { ...proposal.data, cohort: e.target.value })}>
            {catalog.cohorts.map(value => <option key={value}>{value}</option>)}</select></Field>
          <Field id="declaration-limit" label="Maximum records"><Input id="declaration-limit" type="number" required min={1} max={10000} step={1} value={proposal.data.max_records}
            onChange={e => set('data', { ...proposal.data, max_records: Number(e.target.value) })} /></Field>
        </div>
        <Field id="declaration-necessity" label="Why each data group is necessary"><Textarea id="declaration-necessity" required maxLength={2000}
          value={proposal.data.necessity} onChange={e => set('data', { ...proposal.data, necessity: e.target.value })} /></Field>
      </fieldset>
      <fieldset disabled={busy}><legend>3 · Processing and safeguards</legend>
        <div className="two-columns">
          <Field id="declaration-recipe" label="Processing recipe"><select id="declaration-recipe" value={proposal.handling.recipe_id} onChange={e => set('handling', { ...proposal.handling, recipe_id: e.target.value })}>
            {catalog.recipes.map(r => <option key={r.id} value={r.id}>{r.id}</option>)}</select></Field>
          <Field id="declaration-identifiability" label="Proposed identifiability"><select id="declaration-identifiability" value={proposal.handling.identifiability} onChange={e => set('handling', { ...proposal.handling, identifiability: e.target.value })}>
            {catalog.identifiability.map(value => <option key={value}>{value}</option>)}</select></Field>
        </div>
        <p className="subtle">{recipe?.description} {recipe?.executable ? 'Execution requires a completed no-risk review and separate human approval and delivery confirmation.' : 'This recipe can be assessed but cannot run.'}</p>
        {(['access', 'retention', 'onward_sharing'] as const).map(key => <Field key={key} id={`handling-${key}`} label={{ access: 'Who can access the output', retention: 'Retention and disposal', onward_sharing: 'Onward sharing' }[key]}>
          <Textarea id={`handling-${key}`} required maxLength={1000} value={proposal.handling[key]} onChange={e => set('handling', { ...proposal.handling, [key]: e.target.value })} />
        </Field>)}
        <Field id="declaration-arrangements" label="Applicable arrangements"><select id="declaration-arrangements" value={proposal.arrangements.status} onChange={e => set('arrangements', { ...proposal.arrangements, status: e.target.value })}>
          {catalog.arrangement_statuses.map(value => <option key={value} value={value}>{value.replaceAll('_', ' ')}</option>)}</select></Field>
        <Field id="arrangement-details" label="Arrangement details (when applicable)"><Textarea id="arrangement-details" required={proposal.arrangements.status === 'declared_available'} maxLength={2000}
          value={proposal.arrangements.details} onChange={e => set('arrangements', { ...proposal.arrangements, details: e.target.value })} /></Field>
        <div className="two-columns">
          {(['from', 'until'] as const).map(key => <Field key={key} id={`validity-${key}`} label={key === 'from' ? 'Valid from (local time)' : 'Valid until (local time)'}>
            <Input id={`validity-${key}`} type="datetime-local" required value={dateInput(proposal.validity[key])} onChange={e => {
              if (!e.target.value) { setError('Validity dates cannot be empty'); return }
              set('validity', { ...proposal.validity, [key]: inputDate(e.target.value) }); setError('')
            }} /></Field>)}
        </div>
      </fieldset>
      <div className="form-actions"><Button type="submit" disabled={busy}>Save draft revision</Button>
        <Button type="button" variant="outline" disabled={busy} onClick={onCancel}>Cancel edit</Button></div>
    </form>
  </Panel>
}
