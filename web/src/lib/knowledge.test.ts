import { describe, expect, it } from 'vitest'
import { decodeHits, decodeJobId, decodeKnowledge } from './knowledge'

describe('Knowledge API response guards', () => {
  it('rejects malformed status instead of rendering fixture data', () => {
    expect(() => decodeKnowledge({ ready: true })).toThrow()
  })
  it('preserves real source provenance', () => {
    const result = decodeHits({ index_version: 6, value: [{
      text: 'Public evidence', score: 0.6, metadata: {
        title: 'Regulation', source_url: 'https://www.ecfr.gov/current/title-45',
        source_locator: '45 CFR 164.514', retrieval_scope: 'normative',
      },
    }] })
    expect(result.version).toBe('6')
    expect(result.hits[0].locator).toBe('45 CFR 164.514')
  })
  it('rejects executable evidence links and malformed hit collections', () => {
    expect(() => decodeHits({ value: {} })).toThrow()
    expect(() => decodeHits({ value: [{
      metadata: { source_url: 'javascript:alert(1)' },
    }] })).toThrow('Unsafe evidence URL')
  })
  it('only accepts numeric server job IDs', () => {
    expect(decodeJobId({ job_id: 6 })).toBe('6')
    expect(() => decodeJobId({ job_id: '../other' })).toThrow()
  })
})
