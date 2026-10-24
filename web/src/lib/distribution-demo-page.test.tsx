import { renderToStaticMarkup } from 'react-dom/server'
import { afterEach, describe, expect, it, vi } from 'vitest'
import {
  DistributionAuditResult, DistributionBranchEvidence, DistributionDemoPage, DistributionRunEvidence, distributionAuditNotice,
} from '../distribution-demo-page'
import { decodeDistributionRun, organizationIds, type DistributionAudit, type DistributionBranch } from './multi-organization'
import { routeTime } from './governance'
import { distributionAuditSummary } from './multi-organization'

vi.mock('../auth', () => ({ useAuth: () => ({ authorization: 'Basic unit-test-only' }) }))
afterEach(() => { vi.restoreAllMocks(); vi.unstubAllGlobals() })
const branch: DistributionBranch = {
  id: 'research', organization: 'Synthetic research center', protocol: 'REST', namespace: 'DEMORESEARCH',
  state: 'uncertain', message_id: '12', session_id: '10', fields: ['name', 'mrn', 'birthDate'],
  payload_hash: 'b'.repeat(64), policy_mismatches: ['name', 'mrn', 'birthDate'], error: 'Receiver readback timed out',
}
const audit: DistributionAudit = {
  state: 'completed', assessment: 'risk_identified', explanation: 'Actual identifiers conflict with the declared export.',
  next_step: 'Ask a human to review the research export.', report_id: 'report-unit', model_requests: 2,
  raw: { citations: [{ source: 'local-source' }], preserved_model_output: 'Unit synthetic report' },
}
describe('distribution guidance and actual evidence', () => {
  it('keeps the primary reason short while showing unresolved conditions separately and preserving complete evidence', () => {
    const first = 'Synthetic direct identifiers conflict with the selected Safe Harbor declaration.'
    const permission = 'The alternative permission premise remains unresolved.'
    const full = `${first} ${permission} ${'Additional recorded explanation. '.repeat(30)}`
    const value: DistributionAudit = { ...audit, explanation: full, raw: { result: {
      summary: { unresolved: true }, missing_information: ['Confirm the separate permission premise.'],
      issues: [{ explanation: first, citations: [{ quote: 'Preserved source quote' }] }, { explanation: permission }],
    } } }
    const html = renderToStaticMarkup(<DistributionAuditResult audit={value} />)
    expect(html).toContain(`Why: ${first}</p>`)
    expect(html).not.toContain(`Why: ${full}`)
    expect(html).toContain('Unresolved conditions and missing information (separate from identified risk)')
    expect(html).toContain('explicitly retains unresolved conditions')
    expect(html).toContain('Confirm the separate permission premise.')
    expect(html).toContain(full)
    expect(html).toContain('Preserved source quote')
    expect(html).toContain(permission)
  })
  it('guards partial raw reports and never fabricates unresolved findings from malformed values', () => {
    for (const raw of [null, 'unparsed output', [], { result: null }, { result: { issues: [null], summary: { unresolved: 'true' }, missing_information: [42, {}] } }]) {
      const summary = distributionAuditSummary({ ...audit, explanation: 'x'.repeat(900), raw })
      expect(summary.reason.length).toBeLessThanOrEqual(361)
      expect(summary.unresolved).toBeUndefined()
      expect(summary.missing).toEqual([])
      expect(() => renderToStaticMarkup(<DistributionAuditResult audit={{ ...audit, raw }} />)).not.toThrow()
    }
  })
  it('separates three explicit actions and keeps model consent unchecked and disabled before readiness', () => {
    vi.stubGlobal('location', { search: '' })
    const fetch = vi.spyOn(globalThis, 'fetch')
    const html = renderToStaticMarkup(<DistributionDemoPage />)
    for (const label of ['Prepare demo data', 'Run distribution', 'Run AI audit']) {
      expect(html.split('</button>').find(part => part.endsWith('>' + label))).toContain('disabled=""')
    }
    expect(html).toContain('/demo/legacy')
    expect(html).toContain('Legacy Live Monitor demo')
    expect(html).toContain('Real server readiness')
    expect(html).toContain('No automatic model calls or paid retries')
    expect(html).toContain('3 reviews and 6 model requests')
    expect(html).toContain('180 seconds')
    expect(html).not.toContain('checked=""')
    expect(html.match(/type="checkbox"/g)).toHaveLength(1)
    expect(html).toContain('I acknowledge model charges')
    expect(html).toContain('>Run AI audit</button><button')
    expect(html).toContain('>AI log</button>')
    expect(html).not.toContain('I confirm loading')
    expect(html).not.toContain('I confirm this variant')
    expect(html).not.toContain('I confirm this is synthetic data')
    expect(fetch).not.toHaveBeenCalled()
  })
  it('shows branch failures, coverage gaps and local mismatch separately from AI assessment', () => {
    const html = renderToStaticMarkup(<DistributionBranchEvidence branch={branch} />)
    expect(html).toContain('uncertain')
    expect(html).toContain('Receiver readback timed out')
    expect(html).toContain('No receiver receipt captured')
    expect(html).toContain('not a HIPAA assessment')
    expect(html).toContain('Actually sent fields: name, mrn, birthDate')
    expect(html).toContain('Result: Not reviewed')
    expect(html).toContain('Message ID: 12')
    expect(html).toContain('Session ID: 10')
    expect(html).toContain('href="#snapshot-research"')
    expect(html).toContain('href="/organizations#organization-research"')
    expect(html).not.toContain('No risk found')
  })
  it('preserves receipts as expandable JSON without treating ACK as clinical use', () => {
    const html = renderToStaticMarkup(<DistributionBranchEvidence branch={{ ...branch, receipt: { status: 201, delivery_id: 'unit' } }} />)
    expect(html).toContain('<details>')
    expect(html).toContain('Receiver receipt JSON')
    expect(html).toContain('delivery_id')
    expect(html).toContain('not proof of subsequent clinical use')
  })
  it('leads with Result / Why / Next and retains failed or unresolved reviews without all-clear wording', () => {
    const html = renderToStaticMarkup(<DistributionAuditResult audit={audit} />)
    expect(html.indexOf('Result:')).toBeLessThan(html.indexOf('Why:'))
    expect(html.indexOf('Why:')).toBeLessThan(html.indexOf('Next:'))
    expect(html.indexOf('Next:')).toBeLessThan(html.indexOf('<details>'))
    expect(html).toContain('risk_identified')
    expect(html).toContain('Potential risk identified')
    expect(html).toContain(audit.explanation)
    expect(html).toContain(audit.next_step)
    expect(html).toContain('citations')
    for (const state of ['pending', 'failed', 'blocked_budget']) {
      const failed = renderToStaticMarkup(<DistributionAuditResult audit={{ ...audit, state, assessment: '', explanation: '', next_step: '' }} />)
      expect(failed).toContain('Not assessed')
      expect(failed).toContain(state)
      expect(failed).toContain('not a no-risk result')
      expect(failed).not.toContain('No risk found')
    }
  })
  it('links pinned profile snapshots and source versions, not merely mutable current profiles', () => {
    const profiles = Object.fromEntries(organizationIds.map(id => [id, {
      id, revision: 2, profile: {
        id, name: 'Synthetic organization', partner: `Demo${id}`, type: 'unit', parent_id: '',
        responsibilities: 'Synthetic responsibilities', purpose: 'Synthetic purpose', relationship: 'external',
        allowed_fields: ['birthYear'], prohibited_fields: ['name'], requirements: 'Synthetic receiving rules',
      }, confirmed_by: 'builder', confirmed_at: 100, hash: 'a'.repeat(64),
    }]))
    const run = decodeDistributionRun({ id: 'multi-unit', variant: 'identifier-leak', state: 'partial', created_at: 5863734680.576677,
      profiles, source_pins: [{ resource: 'Patient/synthetic-unit', version: '2', hash: 'c'.repeat(64) }], branches: [branch],
      audit_state: 'completed_with_errors', audit_error: 'Research report contract failed' })
    const html = renderToStaticMarkup(<DistributionRunEvidence run={run} />)
    expect(html).toContain('partial')
    expect(html).toContain('0 / 1 recorded branches (3 expected)')
    expect(html).toContain('id="run-source-pins"')
    expect(html).toContain('Patient/synthetic-unit')
    for (const id of organizationIds) expect(html).toContain(`id="snapshot-${id}"`)
    expect(html).toContain('historical snapshots do not change')
    expect(html).toContain('immutable profile revision 2')
    expect(html).toContain('Allowed fields: birthYear')
    expect(html).toContain('Prohibited fields: name')
    expect(html).toContain('AI audit status:')
    expect(html).toContain('completed_with_errors')
    expect(html).toContain('AI audit error: Research report contract failed')
    expect(html).toContain(`Created ${routeTime(5863734680.576677)}`)
    expect(html).not.toContain('Created 5863734680.576677')
    expect(html).toContain('2026-10-24')
    for (const audit_state of ['queued', 'running'] as const) {
      expect(distributionAuditNotice({ ...run, audit_state })).toContain('waiting for saved results')
    }
    for (const audit_state of ['completed', 'completed_with_errors', 'failed', 'interrupted'] as const) {
      expect(distributionAuditNotice({ ...run, audit_state })).toContain('Audit results saved')
      expect(distributionAuditNotice({ ...run, audit_state })).not.toContain('waiting')
    }
  })
  it('shows not_assessed model failures explicitly, never as information-required or no-risk conclusions', () => {
    for (const state of ['failed', 'interrupted', 'completed_with_errors']) {
      const html = renderToStaticMarkup(<DistributionAuditResult audit={{ ...audit, state, assessment: 'not_assessed',
        explanation: 'Model report contract failed', next_step: 'Investigate preserved output' }} />)
      expect(html).toContain('Result: Not assessed')
      expect(html).toContain('not_assessed')
      expect(html).toContain('No completed AI conclusion')
      expect(html).toContain('Model report contract failed')
      expect(html).not.toContain('More information needed')
      expect(html).not.toContain('status-success')
      expect(html).not.toContain('No risk identified')
    }
  })
})
