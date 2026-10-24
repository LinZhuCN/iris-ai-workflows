import { useEffect, useRef, useState } from 'react'
import { useAuth } from './auth'
import { PageHeading, Panel, Status } from './components/platform'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Textarea } from './components/ui/textarea'
import { apiRequest } from './lib/api'
import { routeTime } from './lib/governance'
import {
  commaSeparatedFields, decodeOrganizationCatalog, decodeProfileRecord, organizationIds, profileConfirmation,
  type OrganizationCatalog, type OrganizationId, type OrganizationProfile, type ProfileRecord,
} from './lib/multi-organization'

const textFields = [
  ['name', 'Organization name'], ['partner', 'Business Partner key'], ['type', 'Organization type'],
  ['parent_id', 'Parent organization ID'],
] as const
const longFields = [
  ['responsibilities', 'Responsibilities'], ['purpose', 'Purpose of disclosure'], ['requirements', 'Transformation and receiving requirements'],
] as const
export function OrganizationProfileEditor({ initial, record, canManage, busy, onSave, idPrefix = 'organization' }: {
  initial: OrganizationProfile; record?: ProfileRecord; canManage: boolean; busy: boolean
  idPrefix?: string
  onSave: (profile: OrganizationProfile, revision: number) => void
}) {
  const [draft, setDraft] = useState(() => structuredClone(initial))
  const [allowed, setAllowed] = useState(initial.allowed_fields.join(', '))
  const [prohibited, setProhibited] = useState(initial.prohibited_fields.join(', '))
  const [baseRevision] = useState(record?.revision ?? 0)
  function update<K extends keyof OrganizationProfile>(key: K, value: OrganizationProfile[K]) {
    setDraft(previous => ({ ...previous, [key]: value }))
  }
  return <form onSubmit={event => {
    event.preventDefault()
    if (busy || !canManage) return
    onSave({ ...draft, allowed_fields: commaSeparatedFields(allowed), prohibited_fields: commaSeparatedFields(prohibited) }, baseRevision)
  }}>
    <p><Status tone="warning">Editable draft · {draft.id}</Status> Based on {baseRevision ? `confirmed revision ${baseRevision}` : 'an unsaved preset'}.</p>
    <p>Presets only fill this form. They never save, send data or call a model.</p>
    <fieldset disabled={!canManage || busy}>
      <label className="field-label" htmlFor={`${idPrefix}-id`}>Stable organization ID</label>
      <Input id={`${idPrefix}-id`} value={draft.id} readOnly />
      {textFields.map(([field, label]) => <div key={field}>
        <label className="field-label" htmlFor={`${idPrefix}-${field}`}>{label}</label>
        <Input id={`${idPrefix}-${field}`} required={field !== 'parent_id'} value={draft[field]} onChange={event => update(field, event.target.value)} />
      </div>)}
      <label className="field-label" htmlFor={`${idPrefix}-relationship`}>Scenario relationship</label>
      <select id={`${idPrefix}-relationship`} value={draft.relationship} onChange={event => update('relationship', event.target.value as OrganizationProfile['relationship'])}>
        <option value="same_covered_entity">Same covered entity</option>
        <option value="another_provider">Another treating provider</option>
        <option value="external">External organization</option>
      </select>
      {longFields.map(([field, label]) => <div key={field}>
        <label className="field-label" htmlFor={`${idPrefix}-${field}`}>{label}</label>
        <Textarea id={`${idPrefix}-${field}`} value={draft[field]} onChange={event => update(field, event.target.value)} />
      </div>)}
      <label className="field-label" htmlFor={`${idPrefix}-allowed`}>Allowed fields (comma separated)</label>
      <Textarea id={`${idPrefix}-allowed`} value={allowed} onChange={event => setAllowed(event.target.value)} />
      <label className="field-label" htmlFor={`${idPrefix}-prohibited`}>Prohibited fields (comma separated)</label>
      <Textarea id={`${idPrefix}-prohibited`} value={prohibited} onChange={event => setProhibited(event.target.value)} />
      <p>Saving establishes these demo premises in a new version. It does not send data or call a model.</p>
      <Button type="submit" disabled={busy || !canManage}>{busy ? 'Saving…' : 'Save for demo'}</Button>
    </fieldset>
  </form>
}

export function ConfirmedOrganization({ record }: { record: ProfileRecord }) {
  return <div id={`organization-${record.id}`}>
    <h3>{record.profile.name} <Status tone="success">Confirmed revision {record.revision}</Status></h3>
    <p>{record.id} · Business Partner: {record.profile.partner} · {record.profile.type} · Parent: {record.profile.parent_id || 'None'}</p>
    <p>Confirmed by {record.confirmed_by} at {typeof record.confirmed_at === 'number' ? routeTime(record.confirmed_at) : record.confirmed_at}</p>
    <p className="break-all">Snapshot hash: <code>{record.hash}</code></p>
    <details><summary>Confirmed profile and policy snapshot</summary><pre className="overflow-auto">{JSON.stringify(record, null, 2)}</pre></details>
  </div>
}

export function OrganizationsPage() {
  const { authorization } = useAuth()
  const [catalog, setCatalog] = useState<OrganizationCatalog>()
  const [selected, setSelected] = useState<OrganizationId>('hospital')
  const [draft, setDraft] = useState<OrganizationProfile>()
  const [editorKey, setEditorKey] = useState(0), [refresh, setRefresh] = useState(0)
  const [busy, setBusy] = useState(false), [error, setError] = useState(''), [notice, setNotice] = useState('')
  const operation = useRef<AbortController | null>(null)
  useEffect(() => () => operation.current?.abort(), [])
  useEffect(() => {
    const controller = new AbortController()
    void apiRequest('/organizations', decodeOrganizationCatalog, controller.signal, { authorization })
      .then(value => { if (!controller.signal.aborted) { setCatalog(value); setError('') } })
      .catch((e: unknown) => { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Organization catalog unavailable') })
    return () => controller.abort()
  }, [authorization, refresh])
  const record = catalog?.items.find(item => item.id === selected)
  const initial = draft ?? record?.profile
  async function save(profile: OrganizationProfile, revision: number) {
    if (operation.current || !catalog?.can_manage) return
    const controller = new AbortController(); operation.current = controller
    setBusy(true); setError(''); setNotice('')
    try {
      const saved = await apiRequest('/organizations', decodeProfileRecord, controller.signal, {
        authorization, body: profileConfirmation(profile, revision, true),
      })
      if (saved.id !== profile.id || saved.revision !== revision + 1) throw new Error('Saved profile identity or revision did not match this confirmation.')
      if (!controller.signal.aborted) {
        setCatalog(previous => previous && { ...previous, items: [...previous.items.filter(item => item.id !== saved.id), saved] })
        setDraft(undefined); setEditorKey(key => key + 1); setNotice(`Saved ${saved.id} revision ${saved.revision}. No sends or model calls were made.`)
      }
    } catch (e) {
      if (!controller.signal.aborted) setError(`${e instanceof Error ? e.message : 'Profile save failed'} For a stale revision, refresh the catalog and explicitly load the latest confirmed revision before reapplying your edits. Your current draft is retained; nothing is automatically submitted again.`)
    } finally { operation.current = null; if (!controller.signal.aborted) setBusy(false) }
  }
  return <div className="monitor-page">
    <PageHeading eyebrow="LOCAL SYNTHETIC SCENARIO" title="Organizations"
      description="Confirm versioned organization responsibilities, relationships and receiving policies before distributing synthetic data."
      action={<><Button variant="outline" disabled={busy} onClick={() => setRefresh(value => value + 1)}>Refresh catalog</Button><Button asChild variant="outline"><a href="/demo">Open distribution demo</a></Button></>} />
    <p className="callout">Profiles are user-confirmed synthetic scenario premises, not verified contracts or legal authorization. Edits create new revisions; historical runs retain their own snapshots. No infrastructure or credentials are configured here.</p>
    {error && <p role="alert" className="callout">{error}</p>}
    {notice && <p role="status">{notice}</p>}
    {!catalog ? <p role="status">Loading organization catalog…</p> : <>
      {!catalog.can_manage && <p className="callout">Read-only account: confirming organization profiles requires a builder.</p>}
      <Panel title="Confirmed source and recipient organizations">
        {catalog.items.length === 0 && <p>No confirmed organizations. Select an editable preset below and explicitly save it.</p>}
        {catalog.items.map(item => <ConfirmedOrganization key={item.id} record={item} />)}
      </Panel>
      <Panel title="Organization and receiving-policy draft">
        <label className="field-label" htmlFor="organization-choice">Organization to edit</label>
        <select id="organization-choice" disabled={busy} value={selected} onChange={event => {
          setSelected(event.target.value as OrganizationId); setDraft(undefined); setEditorKey(key => key + 1); setNotice('')
        }}>{organizationIds.map(id => <option value={id} key={id}>{id}</option>)}</select>
        <div className="heading-actions">{catalog.presets.filter(preset => preset.id === selected).map(preset =>
          <Button key={preset.id} variant="outline" disabled={busy || !catalog.can_manage} onClick={() => {
            setDraft(structuredClone(preset)); setEditorKey(key => key + 1); setNotice('Preset loaded into the editable draft only. Nothing was saved, sent or reviewed.')
          }}>Fill editable {preset.id} preset</Button>)}
          {record && <Button variant="outline" disabled={busy || !catalog.can_manage} onClick={() => {
            setDraft(structuredClone(record.profile)); setEditorKey(key => key + 1)
            setNotice(`Loaded confirmed revision ${record.revision} into the draft, replacing unsaved edits. Nothing was saved or sent.`)
          }}>Load latest confirmed revision (replace draft)</Button>}
        </div>
        {initial ? <OrganizationProfileEditor key={`${selected}-${editorKey}`} initial={initial} record={record}
          canManage={catalog.can_manage} busy={busy} onSave={(profile, revision) => { void save(profile, revision) }} />
          : <p>Fill a preset to start a new draft. No profile is saved automatically.</p>}
      </Panel>
    </>}
  </div>
}
