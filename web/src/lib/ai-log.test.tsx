import { renderToStaticMarkup } from 'react-dom/server'
import { describe, expect, it, vi } from 'vitest'
import { AILog, AILogButton } from '../components/ai-log'

describe('saved AI log', () => {
  it('renders a read-only log button without fetching or exposing output before opening', () => {
    const load = vi.fn()
    const html = renderToStaticMarkup(<AILogButton load={load} report={{ raw: 'private saved output' }} />)
    expect(html).toContain('>AI log</button>')
    expect(html).not.toContain('private saved output')
    expect(load).not.toHaveBeenCalled()
  })
  it('shows actual phase responses, provenance and usage without running a model', () => {
    const fetch = vi.spyOn(globalThis, 'fetch')
    const html = renderToStaticMarkup(<AILog report={{
      id: 'report-1', state: 'completed', source: { model: 'test-model' },
      started: 5863734680, completed: 5863734682,
      interop: { session_id: 59 },
      phases: [{ phase: 'judge', state: 'returned', agent_session: '222',
        raw: '{"issues":[{"explanation":"Actual model answer <script>"}]}',
        usage: { total_tokens: 123 }, input: { synthetic: true }, system_prompt: 'Bounded review' }],
    }} />)
    for (const value of ['AI log', 'Saved execution', 'test-model', '222', '59', 'Actual model answer', '123', 'LLM response', 'Bounded review']) {
      expect(html).toContain(value)
    }
    expect(html).toContain('&lt;script&gt;')
    expect(html).not.toContain('<script>')
    expect(fetch).not.toHaveBeenCalled()
    fetch.mockRestore()
  })
  it('distinguishes provider errors, missing output and missing log records from successful replies', () => {
    const html = renderToStaticMarkup(<AILog report={{ state: 'failed', error: 'Audit failed',
      phases: [{ phase: 'judge', state: 'failed', error: 'Provider timed out' }] }} />)
    expect(html).toContain('Provider timed out')
    expect(html).toContain('No LLM response was preserved')
    expect(html).not.toContain('Total tokens: 0')
    expect(renderToStaticMarkup(<AILog report={null} />)).toContain('No saved phase log')
    expect(renderToStaticMarkup(<AILog report={{ phases: [null] }} />)).toContain('Invalid saved phase record')
  })
})
