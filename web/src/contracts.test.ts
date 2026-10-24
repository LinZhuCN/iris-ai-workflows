import { describe, expect, it } from 'vitest'
import { canPublishAgent, deploymentConfirmed } from './contracts'
import { apiRequest } from './lib/api'
import { vi, afterEach } from 'vitest'

afterEach(() => vi.unstubAllGlobals())
describe('version lifecycle contracts', () => {
  it('does not confuse approval or a different loaded hash with active deployment', () => {
    expect(deploymentConfirmed('v8', 'v7', 'active')).toBe(false)
    expect(deploymentConfirmed('v8', 'v8', 'approved')).toBe(false)
    expect(deploymentConfirmed('v8', null, 'unknown')).toBe(false)
    expect(deploymentConfirmed('v8', 'v8', 'active')).toBe(true)
  })
  it('invalidates publication when tested configuration changes', () => {
    expect(canPublishAgent('draft', 'a', 'a')).toBe(false)
    expect(canPublishAgent('tested', 'a', 'b')).toBe(false)
    expect(canPublishAgent('tested', 'a', 'a')).toBe(true)
  })
})
describe('real API never falls back to preview fixtures', () => {
  it('rejects the frontend HTML fallback', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('<html/>', {
      headers: { 'content-type': 'text/html' },
    })))
    await expect(apiRequest('/overview', () => ({}))).rejects.toThrow('No preview fallback')
  })
  it('propagates network failure', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('network offline')))
    await expect(apiRequest('/overview', () => ({}))).rejects.toThrow('network offline')
  })
  it('checks data through the supplied runtime decoder', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', {
      headers: { 'content-type': 'application/json' },
    })))
    await expect(apiRequest('/overview', () => { throw new Error('Invalid overview') })).rejects.toThrow('Invalid overview')
  })
})
