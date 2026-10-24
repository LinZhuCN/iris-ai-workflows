import { routeTime } from '../lib/governance'
import { useState } from 'react'
import { Button } from './ui/button'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from './ui/dialog'

function record(value: unknown): Record<string, unknown> | undefined {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as Record<string, unknown> : undefined
}
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : 'Not recorded'
}
function formatted(value: unknown): string {
  if (value === undefined || value === null) return 'Not recorded'
  if (typeof value !== 'string') return JSON.stringify(value, null, 2)
  try { return JSON.stringify(JSON.parse(value), null, 2) }
  catch { return value }
}
function time(value: unknown): string {
  return typeof value === 'number' && Number.isFinite(value) ? routeTime(value) : text(value)
}

export function AILog({ report }: { report: unknown }) {
  const saved = record(report), source = record(saved?.source), interop = record(saved?.interop)
  const phases = Array.isArray(saved?.phases) ? saved.phases : []
  return <section aria-label="AI log" className="monitor-card">
    <h4>AI log</h4>
    <p>Saved execution, not live inference. Reading this log makes no model requests. Sections labelled LLM response show preserved model output, not the application's rewritten finding.</p>
    <p>Model: {text(source?.model ?? saved?.model)} · Report: {text(saved?.id)} · State: {text(saved?.state)}</p>
    <p>Started: {time(saved?.started)} · Finished: {time(saved?.completed)}</p>
    {interop && <p>IRIS audit BP session: {text(interop.session_id)}</p>}
    {typeof saved?.error === 'string' && <p role="status">Audit error: {saved.error}</p>}
    {!phases.length && <p>No saved phase log is available. This does not establish that an LLM returned a response.</p>}
    {phases.map((value, index) => {
      const phase = record(value)
      if (!phase) return <p key={index}>Invalid saved phase record {index + 1}; inspect the original report.</p>
      const usage = record(phase.usage)
      return <article key={index}>
        <h5>{index + 1}. {phase.phase === 'locate' ? 'Identify audit questions' : phase.phase === 'judge' ? 'Assess evidence' : text(phase.phase)}</h5>
        <p>State: {text(phase.state)} · AI Hub session: {text(phase.agent_session ?? phase.session)}</p>
        {typeof phase.error === 'string' && <p role="status">Request error: {phase.error}</p>}
        <p>Prompt tokens: {text(usage?.prompt_tokens ?? phase.prompt_tokens)} · Completion tokens: {text(usage?.completion_tokens ?? phase.completion_tokens)} · Total tokens: {text(usage?.total_tokens)}</p>
        {typeof phase.usage === 'string' && <details><summary>Recorded usage</summary><pre>{formatted(phase.usage)}</pre></details>}
        <h6>LLM response</h6>
        {typeof phase.raw === 'string' && phase.raw.length
          ? <pre className="max-h-96 overflow-auto whitespace-pre-wrap break-words">{formatted(phase.raw)}</pre>
          : <p>No LLM response was preserved for this phase. A reserved request or session ID alone does not establish a successful response.</p>}
        <details><summary>Request input and system prompt</summary>
          <h6>System prompt</h6><pre className="max-h-96 overflow-auto whitespace-pre-wrap break-words">{formatted(phase.system_prompt)}</pre>
          <h6>Input</h6><pre className="max-h-96 overflow-auto whitespace-pre-wrap break-words">{formatted(phase.input)}</pre>
        </details>
      </article>
    })}
    {saved && <details><summary>Original saved execution record</summary>
      <p>Legacy records may contain only a validated result, not the original provider response. Missing output is not reconstructed.</p>
      <pre className="max-h-96 overflow-auto whitespace-pre-wrap break-words">{formatted(saved)}</pre>
    </details>}
    <p>Usage is SDK-reported, not a verified provider invoice. Model output is untrusted text; application validation and human review remain separate.</p>
  </section>
}

export function AILogButton({ report, title = 'AI log', load }: {
  report?: unknown; title?: string; load?: () => Promise<unknown>
}) {
  const [open, setOpen] = useState(false), [loading, setLoading] = useState(false)
  const [loaded, setLoaded] = useState<unknown>(), [error, setError] = useState('')
  async function show() {
    setOpen(true)
    if (!load) return
    setLoading(true); setError(''); setLoaded(undefined)
    try { setLoaded(await load()) }
    catch (error) { setError(error instanceof Error ? error.message : 'AI log could not be read') }
    finally { setLoading(false) }
  }
  const value = load ? loaded : report
  return <>
    <Button type="button" variant="outline" onClick={() => { void show() }}>AI log</Button>
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogContent className="max-h-[85vh] overflow-auto sm:max-w-4xl">
        <DialogHeader><DialogTitle>{title}</DialogTitle>
          <DialogDescription>Read-only saved execution. Opening this log never starts or retries an LLM request.</DialogDescription>
        </DialogHeader>
        {loading ? <p role="status">Loading saved AI log…</p> : error ? <p role="alert">{error}</p>
          : Array.isArray(value) ? value.length ? value.map((item, index) => <AILog key={index} report={item} />)
            : <p>No saved execution is available for this selection. No LLM response is implied.</p>
            : <AILog report={value} />}
      </DialogContent>
    </Dialog>
  </>
}
