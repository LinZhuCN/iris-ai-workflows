import { describe, expect, it } from 'vitest'
import { decodeGovernance, decodeRouteEvidence, decodeRouteRecord, decodeRouteScenario, decodeRouteTemplate, receiptInput, routeTime } from './governance'

const digest = 'a'.repeat(64)
function record() {
  return {
    id: 'route-unit', digest, record_hash: digest, submitted_by: 'unit', submitted_at: 5863000000,
    record_source: 'synthetic-demo-registry-v1', approval: '',
    core: {
      declaration: { schema: 1, synthetic: true, route_id: 'demo-route', revision: 1, kind: 'utilization',
        purpose_code: 'secondary-analysis', purpose_text: 'Synthetic analysis only', owner: 'office',
        service_identity: 'local-utilization-service', recipient: 'local-analysis-receiver',
        scope: { resources: ['Patient', 'Encounter'], fields: ['Patient.id', 'Patient.birthDate', 'Encounter.id', 'Encounter.status',
          'Encounter.class.system', 'Encounter.class.code', 'Encounter.subject.reference'], patient_selection: 'synthetic-four-resources-v1', max_records: 4 } },
      binding: { instance_id: 'local-triage-real', namespace: 'UTILIZATION', production: 'Contest.Utilization.Production', source: 'FHIRSource',
        sender: 'AnalysisReceiver', point: 'before_send', config_hash: digest, collector_version: 'utilization-receipt-v1', policy_version: 'utilization-exact-scope-v1' },
      valid_from: 5863000000, valid_until: 5865592000,
    },
  }
}
function evidence() {
  const labels = [
    ['declared_purpose', 'claim', 'unverified'], ['declared_context', 'claim', 'unverified'],
    ['approved_scope', 'observation', 'verified'], ['observed_output', 'observation', 'verified'],
    ['delivery_evidence', 'observation', 'verified'], ['evidence_limits', 'missing_information', 'unknown'],
  ]
  return {
    evidence: {
      schema: 1, adapter: 'route-evidence-v1', synthetic: true, model_calls: 0, execution: 'not_executed',
      route_kind: 'utilization', batch_id: 'unit-batch', evidence_hash: digest,
      approved: { record_id: 'route-unit', legal_authorization: 'not_established', historical_scope_match: true },
      observed: {
        inspection: { complete_hipaa_check: false, field_paths: ['Patient.id'], resource_counts: { Patient: 2, Encounter: 2 } },
        identifier_counts: { full_birth_dates: 0, stable_resource_ids: 4 }, transport: 'same-instance-BO-to-SQL',
        observed_at: 5863000001, configured_recipient: 'local-analysis-receiver', destination: { receiver_table: 'SQLUser.UtilizationReceipt' },
        runtime_binding: record().core.binding, message_id: '7', session_id: 11, readback_basis: 'frozen-receipt-and-current-SQL-readback',
      },
      provenance: Object.fromEntries(['source_hash', 'output_hash', 'config_hash', 'scope_hash', 'receipt_hash'].map(key => [key, digest])),
      packet: { synthetic: true, stage: 'after_send', facts: labels.map(([id, kind, verification]) => ({ id, kind, verification, origin: 'unit', text: 'synthetic' })) },
      fact_evidence: labels.map(([id]) => ({ fact_id: id, route_kind: 'utilization', batch_id: 'unit-batch', approval_id: 'route-unit', receipt_hash: digest })),
      limitations: 'No legal authorization or de-identification claim.',
    },
    current_admission: { state: 'expired', checked_at: 5866000000 },
  }
}

describe('route governance live contracts', () => {
  const scenario = { synthetic: true, policy_id: 'DEMO-INTERNAL-USE-1', policy_version: 1,
    organization_id: 'DEMO-HOSPITAL', recipient_relationship: 'same-covered-entity',
    permitted_use: 'Internal quality improvement, not commercial reuse',
    data_path: 'controlled-identifiable-data', conditions: 'Exact approval and internal recipient',
    deidentification_required: false, individual_authorization_required: false }
  it('shows explicit synthetic policy premises without claiming real authorization', () => {
    expect(decodeRouteScenario(scenario).organization_id).toBe('DEMO-HOSPITAL')
    for (const changed of [{ ...scenario, synthetic: false }, { ...scenario, recipient_relationship: 'external' },
      { ...scenario, deidentification_required: true }]) {
      expect(() => decodeRouteScenario(changed)).toThrow()
    }
  })
  it('requires all eight v2 facts and a bound scenario, not upgraded purpose claims', () => {
    const source = evidence()
    source.evidence.adapter = 'route-evidence-v2'
    const updated = { ...source, evidence: { ...source.evidence, approved: { ...source.evidence.approved, scenario } } }
    for (const [id, kind] of [['organization_policy', 'local_policy'], ['approved_scenario', 'observation']]) {
      updated.evidence.packet.facts.push({ id, kind, verification: 'verified', origin: 'synthetic-policy', text: 'Synthetic premise' })
      updated.evidence.fact_evidence.push({ fact_id: id, route_kind: 'utilization', batch_id: 'unit-batch', approval_id: 'route-unit', receipt_hash: digest })
    }
    expect(decodeRouteEvidence(updated).evidence.approved.scenario?.policy_id).toBe('DEMO-INTERNAL-USE-1')
    updated.evidence.packet.facts[0].verification = 'verified'
    expect(() => decodeRouteEvidence(updated)).toThrow()
    updated.evidence.packet.facts[0].verification = 'unverified'
    updated.evidence.packet.facts.pop()
    expect(() => decodeRouteEvidence(updated)).toThrow()
  })
  it('separates pending immutable registration from approval and activation', () => {
    const source = record(), decoded = decodeRouteRecord(source)
    expect(decoded.approval).toBeNull()
    const state = decodeGovernance({ records: [source], user: 'reader', can_write: false, next_cursor: '', runtime_activation: 'not_performed', model_calls: 0 })
    expect(state.can_write).toBe(false)
    expect(state.records[0].core.declaration.scope.max_records).toBe(4)
    expect(() => decodeGovernance({ ...state, runtime_activation: 'performed', model_calls: 0 })).toThrow()
  })
  it('rejects fake approval provenance or scope', () => {
    expect(() => decodeRouteRecord({ ...record(), approval: { approved_by: 'unit', approved_at: 5863000001,
      scope_hash: 'b'.repeat(64), route_record_id: 'route-unit', record_source: 'synthetic-demo-manual-approval-v1' } })).toThrow()
    expect(() => decodeRouteRecord({ ...record(), record_source: 'official-legal-approval' })).toThrow()
  })
  it('accepts only the bounded template without activation', () => {
    const source = record().core
    expect(decodeRouteTemplate({ ...source, runtime_activation: 'not_performed' }).declaration.scope.fields).toHaveLength(7)
    expect(() => decodeRouteTemplate({ ...source, runtime_activation: 'activated' })).toThrow()
  })
  it('keeps expired current admission distinct from valid historical evidence and claim kinds', () => {
    const decoded = decodeRouteEvidence(evidence())
    expect(decoded.current_admission.state).toBe('expired')
    expect(decoded.evidence.packet.facts[0].verification).toBe('unverified')
    expect(decoded.evidence.packet.facts[2].verification).toBe('verified')
    for (const variant of ['claim', 'refs', 'pin', 'legal', 'raw', 'stage']) {
      const changed = evidence()
      if (variant === 'claim') changed.evidence.packet.facts[0].verification = 'verified'
      if (variant === 'refs') changed.evidence.fact_evidence.pop()
      if (variant === 'pin') changed.evidence.fact_evidence[0].receipt_hash = 'b'.repeat(64)
      if (variant === 'legal') changed.evidence.approved.legal_authorization = 'approved'
      if (variant === 'stage') changed.evidence.packet.stage = 'before_send'
      expect(() => decodeRouteEvidence(variant === 'raw' ? { ...changed, evidence: { ...changed.evidence, source: [] } } : changed)).toThrow()
    }
  })
  it('loads only batch and pin from a receipt for the exact selected revision', () => {
    const selected = decodeRouteRecord(record())
    const receipt = { batch_id: 'unit-batch', approval_id: 'route-unit', scope_hash: digest, receipt_hash: digest,
      synthetic: true, outcome: 'delivered', receiver_message_id: '8' }
    expect(receiptInput(receipt, selected)).toEqual({ batch: 'unit-batch', pin: digest })
    expect(receiptInput({ receipt }, selected)).toEqual({ batch: 'unit-batch', pin: digest })
    expect(() => receiptInput({ ...receipt, approval_id: 'route-other-revision' }, selected)).toThrow()
    expect(() => receiptInput({ ...receipt, receipt_hash: '' }, selected)).toThrow()
  })
  it('converts IRIS UTC seconds rather than treating them as Unix timestamps', () => {
    expect(routeTime(4070908800)).toBe('1970-01-01 00:00:00 UTC')
  })
})
