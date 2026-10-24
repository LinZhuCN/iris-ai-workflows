import { useEffect, useState } from 'react'
import type { FormEvent } from 'react'
import { BookOpen, Database, FileText, ShieldCheck } from 'lucide-react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { PageHeading, Panel, Stat, Status } from './components/platform'
import { apiRequest } from './lib/api'
import { decodeKnowledge, decodeHits, decodeJob, decodeJobId } from './lib/knowledge'
import type { KnowledgeStatus, KnowledgeJob, KnowledgeHit } from './lib/knowledge'
import { useAuth } from './auth'

const example = 'Remove medical record numbers and all elements of dates except year Safe Harbor de-identification identifiers'

export function LiveKnowledgePage() {
  const { authorization } = useAuth()
  const [status, setStatus] = useState<KnowledgeStatus>()
  const [job, setJob] = useState<KnowledgeJob>()
  const [error, setError] = useState('')
  const [busy, setBusy] = useState(false)
  const [query, setQuery] = useState(example)
  const [result, setResult] = useState<{ hits: KnowledgeHit[]; version: string }>()

  useEffect(() => {
    if (!authorization || !status?.latestJob) return
    let cancelled = false
    const controller = new AbortController()
    const poll = async () => {
      try {
        const value = await apiRequest(`/knowledge/builds/${status.latestJob}`, decodeJob, controller.signal, { authorization })
        if (cancelled) return
        setJob(value)
        if (value.state === 'completed') {
          const updated = await apiRequest('/knowledge', decodeKnowledge, controller.signal, { authorization })
          if (!cancelled) setStatus(previous => previous?.indexVersion === updated.indexVersion ? previous : updated)
        }
      } catch (e) {
        if (!cancelled) setError(e instanceof Error ? e.message : 'Job status request failed')
      }
    }
    void poll()
    const timer = setInterval(() => { void poll() }, 4000)
    return () => { cancelled = true; controller.abort(); clearInterval(timer) }
  }, [authorization, status?.latestJob])

  const [refresh, setRefresh] = useState(0)
  useEffect(() => {
    const controller = new AbortController()
    void apiRequest('/knowledge', decodeKnowledge, controller.signal, { authorization }).then(value => {
      if (!controller.signal.aborted) { setStatus(value); setError('') }
    }).catch((e: unknown) => { if (!controller.signal.aborted) setError(e instanceof Error ? e.message : 'Knowledge load failed') })
    return () => controller.abort()
  }, [authorization, refresh])
  async function search(event: FormEvent) {
    event.preventDefault(); setBusy(true); setError(''); setResult(undefined)
    try {
      setResult(await apiRequest('/knowledge/search', decodeHits, undefined, { authorization, body: { query } }))
    } catch (e) { setError(e instanceof Error ? e.message : 'Retrieval failed') }
    finally { setBusy(false) }
  }
  async function build() {
    setBusy(true); setError('')
    try {
      const id = await apiRequest('/knowledge/builds', decodeJobId, undefined, { authorization, body: {} })
      setStatus(previous => previous ? { ...previous, latestJob: id } : previous)
    } catch (e) { setError(e instanceof Error ? e.message : 'Build failed to start') }
    finally { setBusy(false) }
  }
  return <>
    <PageHeading eyebrow="AI RESOURCES · LIVE LOCAL API" title="Knowledge" description="Traceable HIPAA evidence, embedded locally in IRIS. No paid model or live business Production calls."
      action={<Button variant="outline" onClick={() => setRefresh(n => n + 1)}>Refresh knowledge</Button>} />
    {error && <div className="callout" role="alert">{error}</div>}
    {!status ? <Panel title="Loading knowledge index"><p>Reading records using your workspace sign-in. Use Refresh knowledge to retry if needed.</p></Panel> : <>
      <div className="knowledge-hero"><div className="knowledge-book"><BookOpen size={33} /></div><div><div className="eyebrow">REAL IRIS VECTOR INDEX</div><h2>HIPAA & supporting guidance</h2><p>Selected default-scope sources. Historical and unreviewed records are excluded.</p></div><Status tone={status.ready ? 'success' : 'warning'}>{status.ready ? 'Indexed · local CPU' : 'Not ready'}</Status></div>
      <div className="stats-grid">
        <Stat label="Indexed records" value={String(status.documents)} note="682 normative · 27 technical · 5 orientation · 1 policy" icon={<FileText size={17} />} />
        <Stat label="Vector chunks" value={status.chunks.toLocaleString()} note={`Active version ${status.indexVersion}`} icon={<Database size={17} />} />
        <Stat label="Dimensions" value={String(status.dimensions)} note={status.model} icon={<BookOpen size={17} />} />
        <Stat label="Access" value={status.canBuild ? 'Builder' : 'Reader'} note="Server-enforced capabilities" icon={<ShieldCheck size={17} />} />
      </div>
      <Panel title="Test real retrieval" action={<Status tone="info">No generated answer</Status>}>
        <form onSubmit={search}><label className="field-label" htmlFor="knowledge-query">Public knowledge question · do not enter patient information</label>
          <Input id="knowledge-query" maxLength={1000} value={query} onChange={e => setQuery(e.target.value)} required />
          <div className="form-actions"><Button disabled={busy || !status.ready || !query.trim()}>{busy ? 'Working…' : 'Search local index'}</Button></div>
        </form>
        {result && <div aria-live="polite"><p className="subtle">{result.hits.length} evidence passages · index {result.version}. Similarity is not a legal confidence score.</p>
          {result.hits.length === 0 && <p>No evidence matched. No answer was substituted.</p>}
          {result.hits.map((hit, i) => <article className="knowledge-evidence" key={`${hit.locator}-${i}`}>
            <div><Status tone="info">{hit.scope}</Status><span className="subtle"> Similarity {hit.score.toFixed(3)}</span></div>
            <h3><a href={hit.url} target="_blank" rel="noreferrer">{hit.title}</a></h3>
            <p className="mono subtle">{hit.locator}</p><p className="body-copy">{hit.text}</p>
          </article>)}
        </div>}
        <div className="callout">Dated reference corpus, not compliance certification. “Normative” describes a retrieval scope, not a guarantee of current legal applicability.</div>
      </Panel>
      <Panel title="Index lifecycle" action={<Status tone="info">Shadow build</Status>}>
        <p className="body-copy">A build writes a new table, verifies 715 records and 1,785 chunks, tests retrieval, then switches the active pointer. The current index remains searchable during the build. Old versions are retained.</p>
        {job && <div aria-live="polite"><Status tone={job.state === 'completed' ? 'success' : job.state === 'failed' || job.state === 'interrupted' ? 'danger' : 'warning'}>Job {job.id} · {job.state}</Status>
          <p>{job.stage || 'queued'} · {job.documents} / {job.expected} records</p>
          {job.error && <p role="alert">{job.error}</p>}
        </div>}
        {status.canBuild ? <>
          <p>Build the fixed public corpus locally. The new index activates only after verification.</p>
          <div className="form-actions"><Button onClick={() => { void build() }} disabled={busy || job?.state === 'running' || job?.state === 'queued'}>Build new index version</Button></div>
        </> : <p className="subtle">Reader access: index rebuilding requires a dedicated Knowledge builder account.</p>}
        <p className="subtle knowledge-fingerprint">Prepared source SHA-256: {status.corpusId || 'Not provisioned'}</p>
      </Panel>
    </>}
  </>
}
