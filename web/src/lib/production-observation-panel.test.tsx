import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { ExportMessageComparison, ProductionObservationPanel, ReviewResultSummary } from '../production-observation-panel'
import type { decodeProductionReviewDetail } from './production-observation'
import type { ManagedProduction } from './productions'

vi.mock('../auth', () => ({ useAuth: () => ({ authorization: 'Basic unit-test-only' }) }))

const id = 'production-' + 'a'.repeat(64)
const snapshot = { id, instance_id: 'local-iris', namespace: 'UNIT', production: 'Unit.Production', state: 1, running: true,
  config_hash: 'b'.repeat(64), observed_at: 100, nodes: [] }
const record: ManagedProduction = { id, namespace: 'UNIT', production: 'Unit.Production', enabled: true, revision: 1,
  enrolled_by: 'builder', enrolled_at: 100, last_scan: 101, error: '', header_count: 0, log_count: 0,
  baseline: snapshot, current: snapshot }

afterEach(() => vi.restoreAllMocks())
describe('Production observation controls render fail-closed', () => {
  it('compares the observed declaration with field names, without inventing a verdict', () => {
    const facts = { export_context: { method: 'safe_harbor', processing_status: 'deidentified', purpose: 'external_statistics' },
      fields: { name: 1, mrn: 1, birthDate: 1 }, dates: { full_date: 1, year_only: 0 } }
    const html = renderToStaticMarkup(<ExportMessageComparison facts={facts} />)
    expect(html).toContain('Declared vs. sent')
    expect(html).toContain('name, mrn, birthDate')
    expect(html).toContain('1 full dates')
    expect(html).not.toContain('Potential risk found')
    expect(renderToStaticMarkup(<ExportMessageComparison facts={null} />)).toBe('')
  })
  it('puts a plain outcome, short reason and next step ahead of audit data', () => {
    const detail: Pick<ReturnType<typeof decodeProductionReviewDetail>, 'assessment' | 'issues' | 'missing' | 'review'> = {
      assessment: 'no_signal_on_checked_issues', missing: [],
      review: { id: 'test', production_id: id, observation_hash: '', report_id: '', authorization_id: '',
        header_id: '30', state: 'completed', reason: '', error: '', reserved: 2, attempted: 2, raw: {} },
      issues: [{ question: 'q1', status: 'no_signal_on_checked_issue', explanation: 'Records were shared for treatment. The legal analysis follows.', citations: [] }],
    }
    const render = () => renderToStaticMarkup(<ReviewResultSummary detail={detail} />)
    expect(render()).toContain('No risk found in this check')
    expect(render()).toContain('Records were shared for treatment.')
    expect(render()).not.toContain('The legal analysis follows.')
    expect(render()).toContain('Next:')
    detail.assessment = 'information_required'
    detail.missing = ['Who receives the data?']
    expect(render()).toContain('More information needed')
    expect(render()).toContain('Who receives the data?')
    detail.assessment = 'risk_identified'
    expect(render()).toContain('Potential risk found')
    detail.assessment = undefined
    detail.issues = []
    detail.review.reason = 'No registered adapter'
    expect(render()).toContain('Not assessed')
    expect(render()).toContain('No registered adapter')
    expect(render()).not.toContain('No risk found')
  })
  it('never performs inference, authorization or network calls during rendering', () => {
    const fetch = vi.spyOn(globalThis, 'fetch')
    const changed = vi.fn()
    const html = renderToStaticMarkup(<ProductionObservationPanel record={record} canManage refresh={0} onChanged={changed} />)
    expect(html).toContain('All current components are observed without per-flow registration.')
    expect(html).toContain('never flow enrollment')
    expect(html).not.toContain('Confirm paid review authorization</button>')
    expect(html).not.toContain('checked=""')
    expect(changed).not.toHaveBeenCalled()
    expect(fetch).not.toHaveBeenCalled()
  })
  it('keeps only the two useful review options and one paid-cost confirmation checkbox', () => {
    const html = renderToStaticMarkup(<ProductionObservationPanel record={record} canManage refresh={0} onChanged={() => {}} />)
    expect(html.match(/type="checkbox"/g)).toHaveLength(3)
    for (const label of [
      'Supply user-approved demo business premises for one source session.',
      'Include previously unreviewed stored captures (not replays or reassessments).',
      'I accept paid model costs up to the selected request-count limit; failures consume reserved budget.',
    ]) expect(html).toContain(label)
    expect(html).not.toContain('checked=""')
    expect(html).toContain('Explicit AI authorization permits export of minimized synthetic facts')
    expect(html).not.toContain('I authorize export of minimized synthetic facts')
    expect(html).not.toContain('I authorize local inspection')
    for (const label of ['Authorize local synthetic inspection', 'Revoke local inspection']) {
      const button = html.split('</button>').find(part => part.endsWith('>' + label))
      expect(button).toBeDefined()
      expect(button).not.toContain('disabled=""')
    }
    const prepare = html.split('</button>').find(part => part.endsWith('>Prepare exact review authorization'))
    expect(prepare).toContain('disabled=""')
    expect(html).toContain('preserves historical evidence')
    expect(html).toContain('Durable AI authorization history')
  })
  it('disables direct inspection authorization for inactive Productions without disabling revocation', () => {
    const inactive = { ...record, current: { ...record.current, running: false } }
    const html = renderToStaticMarkup(<ProductionObservationPanel record={inactive} canManage refresh={0} onChanged={() => {}} />)
    expect(html.split('</button>').find(part => part.endsWith('>Authorize local synthetic inspection'))).toContain('disabled=""')
    expect(html.split('</button>').find(part => part.endsWith('>Revoke local inspection'))).not.toContain('disabled=""')
  })
  it('renders reader-only changes disabled and separate from evidence reads', () => {
    const html = renderToStaticMarkup(<ProductionObservationPanel record={record} canManage={false} refresh={0} onChanged={() => {}} />)
    expect(html).toContain('Read-only account: authorization and context changes require a builder.')
    for (const label of ['Authorize local synthetic inspection', 'Prepare exact review authorization', 'Add optional declared context']) {
      const button = html.split('</button>').find(part => part.endsWith('>' + label))
      expect(button, label).toContain('disabled=""')
    }
    expect(html).toContain('Message evidence and session correlation')
    expect(html).toContain('Sampled review records')
    expect(html).toContain('tabindex="-1" role="region" aria-label="Selected evidence and review detail"')
  })
  it('does not present pre-load empty counts as success or certify receiver acceptance', () => {
    const html = renderToStaticMarkup(<ProductionObservationPanel record={record} canManage refresh={0} onChanged={() => {}} />)
    expect(html).toContain('Loading evidence and review coverage')
    expect(html).toContain('not a no-risk result')
    expect(html).toContain('Demo assessment: user-approved business premises + observed message facts + HIPAA sources.')
    expect(html).toContain('no real-system connection is required')
    expect(html).toContain('Supply user-approved demo business premises for one source session.')
    expect(html).toContain('not reconstructed end-to-end business paths')
    expect(html).not.toContain('100%')
  })
})
