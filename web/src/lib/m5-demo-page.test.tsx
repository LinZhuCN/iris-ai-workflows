import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { M5DemoPage, M5ProfileForm, M5ReviewerGuidance, M5RunEvidence } from '../m5-demo-page'
import { DistributionDemoPage } from '../distribution-demo-page'
import { ProductionsPage } from '../productions-page'
import { decodeM5Run, decodeM5Status } from './m5-demo'
import { m5Profile, m5Record, m5Run, m5Status } from './m5-demo.test'

vi.mock('../auth', () => ({ useAuth: () => ({ authorization: 'Basic unit-test-only' }) }))
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals() })
describe('fixed M5 onboarding controls and saved evidence', () => {
  it('distinguishes an unloaded review plan from a loaded plan without published choices', () => {
    const clean = decodeM5Status(m5Status())
    const enroll = 'Enroll the fixed Production to load its review plan and published reviewer choices.'
    for (const status of [undefined, clean, { ...clean, enrolled: true }]) {
      const html = renderToStaticMarkup(<M5ReviewerGuidance status={status} />)
      expect(html).toContain(enroll)
      expect(html).not.toContain('Publish an eligible Agent')
    }
    const plan = { production_id: clean.production_id, config_hash: clean.config_hash, contract_hash: clean.config_hash,
      now: 100, max_reviews: 1, expiry_seconds: 3600, sampling: 'fixed', scope: 'synthetic', agents: [] }
    expect(renderToStaticMarkup(<M5ReviewerGuidance status={{ ...clean, enrolled: true, plan }} />))
      .toContain('Publish an eligible Agent separately')
    expect(renderToStaticMarkup(<M5ReviewerGuidance status={{ ...clean, enrolled: true, plan: { ...plan,
      agents: [{ id: 'published-agent', revision: 1, config_hash: clean.config_hash, model: 'unit', status: 'published' }],
    } }} />)).toBe('')
  })
  it('renders sequential explicit controls with only unchecked model-cost consent and no effects', () => {
    const fetch = vi.spyOn(globalThis, 'fetch')
    const html = renderToStaticMarkup(<M5DemoPage />)
    for (const label of ['Enroll M5 Production', 'Authorize local inspection', 'Send fixed synthetic research data',
      'Authorize bounded AI audit', 'Archive and reset M5 demo']) {
      expect(html.split('</button>').find(part => part.endsWith(`>${label}`))).toContain('disabled=""')
    }
    expect(html.match(/type="checkbox"/g)).toHaveLength(1)
    expect(html).not.toContain('checked=""')
    expect(html).toContain('1 review and 2 model requests')
    expect(html).toContain('RESET M5 DEMO')
    expect(html).toContain('Physical IRIS messages and saved risk reports are retained')
    expect(html).toContain('independent of the shared Organizations catalog')
    expect(html).toContain('>Authorize bounded AI audit</button><button')
    expect(html).toContain('>AI log</button>')
    expect(html).toContain('No automatic audit')
    expect(fetch).not.toHaveBeenCalled()
  })
  it('has independent editable source/recipient fields and non-saving examples', () => {
    const save = vi.fn(), fetch = vi.spyOn(globalThis, 'fetch')
    const html = renderToStaticMarkup(<>{(['hospital', 'research'] as const).map(id =>
      <M5ProfileForm key={id} id={id} record={m5Record(id)} preset={m5Profile(id)} enabled busy={false} onSave={save} />)}</>)
    for (const label of ['Source hospital', 'Research recipient', 'Organization name', 'Business Partner key',
      'Responsibilities', 'Purpose of disclosure', 'Transformation and receiving requirements', 'Scenario relationship',
      'Allowed fields', 'Prohibited fields', 'Fill example', 'Save for demo']) expect(html).toContain(label)
    expect(html).toContain('id="m5-hospital-name"')
    expect(html).toContain('id="m5-research-name"')
    expect(html).toContain('They never save, send data or call a model')
    expect(html).not.toContain('type="checkbox"')
    expect(save).not.toHaveBeenCalled()
    expect(fetch).not.toHaveBeenCalled()
  })
  it('preserves distribution routing and adds prominent M5 entry points', () => {
    vi.stubGlobal('location', { search: '' })
    for (const page of [<DistributionDemoPage />, <ProductionsPage />]) {
      const html = renderToStaticMarkup(page)
      expect(html).toContain('href="/demo/m5"')
      expect(html).toContain('Start fixed M5 onboarding')
    }
    expect(renderToStaticMarkup(<DistributionDemoPage />)).toContain('Run distribution')
    expect(renderToStaticMarkup(<M5DemoPage />)).toContain('href="/demo"')
  })
  it('shows pending capture, honest missing results, frozen profiles and adjacent saved AI log', () => {
    const html = renderToStaticMarkup(<M5RunEvidence run={decodeM5Run(m5Run())} />)
    for (const text of ['Waiting for collector', 'Result: Not assessed', 'Why:', 'Next:', 'AI log',
      'No saved phase log is available', 'Frozen source and recipient profiles', 'not compliance certification']) {
      expect(html).toContain(text)
    }
    expect(html).toContain('transport evidence, not proof')
    expect(html).not.toContain('No risk found')
  })
  it('preserves single-use consent and distinguishes the target from the representative review header', () => {
    const html = renderToStaticMarkup(<M5RunEvidence run={decodeM5Run({ ...m5Run(), header_id: '42',
      review_header_id: '39', authorization: { authorization_id: 'single-use-saved-consent' },
      review: { state: 'not_authorized', authorization_id: '' } })} />)
    expect(html).toContain('Receiver header ID: 42')
    expect(html).toContain('Review representative header ID: 39')
    expect(html).toContain('not a separate model assessment')
    expect(html).toContain('single-use-saved-consent')
    expect(html).toContain('Authorization recorded; awaiting saved execution')
    expect(html).toContain('No saved phase log is available')
    expect(html).toContain('Result: Not assessed')
  })
  it('never claims a receiver header alone is captured and visibly distinguishes stored minimized evidence', () => {
    const run = decodeM5Run({ ...m5Run(), header_id: '42' })
    let html = renderToStaticMarkup(<M5RunEvidence run={run} />)
    expect(html).toContain('Receiver header ID: 42')
    expect(html).toContain('Waiting for collector')
    expect(html).not.toContain('Captured header ID')
    expect(html).not.toContain('Stored minimized fields and date precision')
    html = renderToStaticMarkup(<M5RunEvidence run={decodeM5Run({ ...run, evidence: {
      header: { header_id: '42', session_id: '41', source: 'M5Source', target: 'ResearchReceiver' },
      capture: { state: 'captured', reason: '', facts: {
        fields: ['patient_code', 'birthDate'], date_precision: { birthDate: 'full_date' },
      } },
    } })} />)
    for (const text of ['Capture state: captured', 'M5Source', 'ResearchReceiver', 'Observed session: 41',
      'Stored minimized fields and date precision', 'patient_code', 'birthDate', 'full_date']) expect(html).toContain(text)
    expect(html).not.toContain('Waiting for collector')
  })
  it('separates failed execution from assessment and preserves model output and missing information', () => {
    const run = { ...decodeM5Run(m5Run()), header_id: '43', review: { state: 'failed', error: 'Contract rejected' },
      report: { state: 'failed', phases: [{ phase: 'judge', state: 'failed', raw: 'Original synthetic response' }] } }
    let html = renderToStaticMarkup(<M5RunEvidence run={run} />)
    expect(html).toContain('Result: Not assessed')
    expect(html).toContain('Contract rejected')
    expect(html).toContain('Original synthetic response')
    html = renderToStaticMarkup(<M5RunEvidence run={{ ...run, review: { state: 'completed' },
      report: { state: 'completed', result: { assessment: 'information_required',
        summary: { unresolved: true }, issues: [{ status: 'unresolved', explanation: 'Permission is unknown.' }],
        missing_information: ['Confirm permission'] } } }} />)
    expect(html).toContain('Result: More information needed')
    expect(html).toContain('Why: Permission is unknown.')
    expect(html).toContain('Confirm permission')
    expect(html).toContain('Unresolved conditions remain separate')
  })
})
