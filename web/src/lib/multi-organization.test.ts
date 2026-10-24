import { describe, expect, it } from 'vitest'
import {
  commaSeparatedFields, decodeDistributionRun, decodeDistributionState, decodeOrganizationCatalog,
  decodeOrganizationProfile, decodeProfileRecord, decodeSeedResult, distributionAuditRequest,
  distributionRunRequest, profileConfirmation,
} from './multi-organization'

export const profile = {
  id: 'research' as const, name: 'Synthetic research center', partner: 'DemoResearch', type: 'research',
  parent_id: '', responsibilities: 'Statistical research', purpose: 'External statistics',
  relationship: 'external' as const, allowed_fields: ['patient_code', 'birth_year'],
  prohibited_fields: ['name', 'mrn', 'birthDate'], requirements: 'Remove direct identifiers.',
}
export const record = { id: 'research' as const, revision: 1, profile, confirmed_by: 'builder', confirmed_at: 100, hash: 'a'.repeat(64) }
const profiles = Object.fromEntries(['hospital', 'quality', 'research', 'clinic'].map(id => [id, {
  ...record, id, profile: { ...profile, id },
}]))
export const run = {
  id: 'run-unit', variant: 'identifier-leak', state: 'completed', created_at: 100,
  profiles, source_pins: [{ resource: 'Patient/synthetic-patient', version: '1', hash: 'c'.repeat(64) }],
  branches: [{
    id: 'research', organization: 'research', protocol: 'REST', namespace: 'DEMORESEARCH', state: 'acknowledged',
    message_id: '12', session_id: '10', fields: ['name', 'mrn', 'birthDate'], payload_hash: 'b'.repeat(64),
    receipt: { id: 'receipt-1', status: 201 }, policy_mismatches: ['name', 'mrn', 'birthDate'],
  }],
}
describe('organization contract and explicit profile confirmation', () => {
  it('decodes confirmed metadata and editable presets without mutating either', () => {
    const input = { items: [record], presets: [profile], can_manage: true }
    const catalog = decodeOrganizationCatalog(input)
    catalog.presets[0].allowed_fields.push('example')
    expect(input.presets[0].allowed_fields).not.toContain('example')
    expect(catalog.items[0]).toEqual(record)
    expect(decodeOrganizationCatalog({ ...input, can_manage: 0 }).can_manage).toBe(false)
  })
  it.each([
    { ...profile, id: 'unknown' }, { ...profile, relationship: 'trusted' },
    { ...profile, allowed_fields: 'name,mrn' }, { ...profile, prohibited_fields: ['name', 'name'] },
    { ...profile, name: '' }, { ...profile, requirements: null },
  ])('rejects malformed profile %#', input => {
    expect(() => decodeOrganizationProfile(input)).toThrow('Invalid multi-organization response')
  })
  it('rejects identity substitution, invalid revision, duplicate records and coercive permissions', () => {
    expect(() => decodeProfileRecord({ ...record, id: 'clinic' })).toThrow()
    for (const revision of [0, -1, 1.5, '1', NaN]) expect(() => decodeProfileRecord({ ...record, revision })).toThrow()
    expect(() => decodeOrganizationCatalog({ items: [record, record], presets: [], can_manage: true })).toThrow()
    expect(() => decodeOrganizationCatalog({ items: [], presets: [], can_manage: 'true' })).toThrow()
  })
  it('requires exact user confirmation and expected revision, including new profile revision zero', () => {
    expect(() => profileConfirmation(profile, 0, false)).toThrow('Confirm')
    expect(profileConfirmation(profile, 0, true)).toEqual({ profile, expected_revision: 0, confirmed: true })
    expect(profileConfirmation(profile, 7, true).expected_revision).toBe(7)
    expect(() => profileConfirmation(profile, -1, true)).toThrow()
    expect(commaSeparatedFields(' name, mrn,, birthDate, name , ')).toEqual(['name', 'mrn', 'birthDate'])
  })
  it('accepts repository-standard fractional epoch timestamps while keeping revision and budgets integral', () => {
    const time = 1792823000.125
    expect(decodeProfileRecord({ ...record, confirmed_at: time }).confirmed_at).toBe(time)
    expect(decodeDistributionRun({ ...run, created_at: time }).created_at).toBe(time)
    for (const timestamp of [-0.1, NaN, Infinity, -Infinity]) {
      expect(() => decodeProfileRecord({ ...record, confirmed_at: timestamp })).toThrow('timestamp')
      expect(() => decodeDistributionRun({ ...run, created_at: timestamp })).toThrow('timestamp')
    }
    expect(() => decodeProfileRecord({ ...record, revision: 1.25 })).toThrow('integer')
    expect(() => profileConfirmation(profile, 1.25, true)).toThrow('integer')
    expect(() => decodeDistributionState({ ready: true, readiness: [], runs: [], can_manage: true, model_request_limit: 6.25 })).toThrow('integer')
    expect(() => decodeDistributionRun({ ...run, branches: [{ ...run.branches[0], audit: {
      state: 'running', assessment: '', explanation: '', next_step: '', report_id: '', model_requests: 1.25, raw: {},
    } }] })).toThrow('integer')
  })
})
describe('distribution contract and separate bounded audit consent', () => {
  it('retains actual receiver receipts, source pins and immutable snapshots', () => {
    expect(decodeDistributionRun(run)).toEqual(run)
    expect(decodeDistributionState({ ready: false, readiness: [{ name: 'FHIR', ready: 0, detail: 'Unavailable' }],
      runs: [run], can_manage: true, model_request_limit: 6 }).readiness[0].ready).toBe(false)
  })
  it('requires confirmation for business sends and both independent audit acknowledgements', () => {
    expect(() => distributionRunRequest('unit', 'identifier-leak', false)).toThrow('Confirm')
    expect(distributionRunRequest('unit', 'corrected', true)).toEqual({ run_id: 'unit', variant: 'corrected', confirmed: true })
    expect(() => distributionRunRequest('a'.repeat(49), 'corrected', true)).toThrow('identifier')
    for (const [cost, synthetic] of [[false, false], [false, true], [true, false]]) {
      expect(() => distributionAuditRequest('unit', cost, synthetic)).toThrow('Both')
    }
    expect(distributionAuditRequest('unit', true, true)).toEqual({ run_id: 'unit', acknowledge_cost: true, acknowledge_synthetic: true })
  })
  it('rejects invented recipient bindings and duplicate branch identities', () => {
    for (const patch of [{ namespace: 'TRIAGE' }, { protocol: 'SQL' }, { id: 'hospital' }, { policy_mismatches: null }]) {
      expect(() => decodeDistributionRun({ ...run, branches: [{ ...run.branches[0], ...patch }] })).toThrow()
    }
    expect(() => decodeDistributionRun({ ...run, branches: [run.branches[0], run.branches[0]] })).toThrow()
  })
  it('does not reinterpret failed and uncertain delivery as success', () => {
    const failed = decodeDistributionRun({ ...run, state: 'partial', error: 'One branch failed',
      branches: [{ ...run.branches[0], state: 'uncertain', error: 'Receiver readback timed out' }] })
    expect(failed.state).toBe('partial')
    expect(failed.branches[0].error).toContain('timed out')
    expect(failed.branches[0].audit).toBeUndefined()
  })
  it('preserves actual header and immutable evidence identifiers without coercion', () => {
    const captured = { ...run.branches[0], header_id: '42', evidence_hash: 'd'.repeat(64) }
    expect(decodeDistributionRun({ ...run, branches: [captured] }).branches[0]).toEqual(captured)
    expect(() => decodeDistributionRun({ ...run, branches: [{ ...captured, header_id: 42 }] })).toThrow()
    expect(() => decodeDistributionRun({ ...run, branches: [{ ...captured, evidence_hash: 'unverified' }] })).toThrow()
  })
  it('checks required audit fields and both branch and run-wide model budgets', () => {
    const audit = { state: 'completed', assessment: 'risk_identified', explanation: 'Identifier present',
      next_step: 'Human review', report_id: 'report-1', model_requests: 2, raw: { citations: [] } }
    expect(decodeDistributionRun({ ...run, branches: [{ ...run.branches[0], audit }] }).branches[0].audit).toEqual(audit)
    for (const patch of [{ model_requests: 7 }, { model_requests: -1 }, { explanation: undefined }, { raw: undefined }]) {
      expect(() => decodeDistributionRun({ ...run, branches: [{ ...run.branches[0], audit: { ...audit, ...patch } }] })).toThrow()
    }
    expect(() => decodeDistributionRun({ ...run, branches: [
      { ...run.branches[0], audit: { ...audit, model_requests: 4 } },
      { ...run.branches[0], id: 'quality', protocol: 'SQL', namespace: 'DEMOQUALITY', audit: { ...audit, model_requests: 4 } },
    ] })).toThrow('budget')
  })
  it('preserves explicit unassessed branch failures and aggregate audit errors without fabricating conclusions', () => {
    const audit = { state: 'failed', assessment: 'not_assessed', explanation: 'Model output violated the report contract',
      next_step: 'Human investigation required', report_id: 'failed-report', model_requests: 1, raw: { error: 'invalid_output' } }
    const decoded = decodeDistributionRun({ ...run, audit_state: 'completed_with_errors', audit_error: 'One branch could not be assessed',
      branches: [{ ...run.branches[0], audit }] })
    expect(decoded.audit_state).toBe('completed_with_errors')
    expect(decoded.audit_error).toBe('One branch could not be assessed')
    expect(decoded.branches[0].audit).toEqual(audit)
    for (const assessment of ['unknown', 'no_risk_identified', null]) {
      expect(() => decodeDistributionRun({ ...run, branches: [{ ...run.branches[0], audit: { ...audit, assessment } }] })).toThrow()
    }
    expect(() => decodeDistributionRun({ ...run, audit_error: {} })).toThrow()
    expect(() => decodeDistributionRun({ ...run, audit_state: 'success' })).toThrow()
  })
  it('fails closed for malformed envelopes, missing source pins and altered configured budget', () => {
    for (const source_pins of [undefined, null, 'not-pinned']) expect(() => decodeDistributionRun({ ...run, source_pins })).toThrow()
    expect(() => decodeDistributionRun({ ...run, profiles: { research: record } })).toThrow()
    expect(() => decodeDistributionRun({ ...run, profiles: { ...profiles, research: profiles.hospital } })).toThrow()
    expect(() => decodeDistributionRun({ ...run, source_pins: [{ resource: 'Patient/unit', hash: 'hash' }] })).toThrow()
    expect(() => decodeDistributionState({ ready: true, readiness: [], runs: [], can_manage: true, model_request_limit: 8 })).toThrow()
    expect(() => decodeSeedResult({})).toThrow()
    expect(decodeSeedResult({ resources: ['Patient/synthetic-1'], version: '1' })).toEqual({ resources: ['Patient/synthetic-1'], version: '1' })
  })
})
