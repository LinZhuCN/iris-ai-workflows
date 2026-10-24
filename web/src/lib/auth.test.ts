import { afterEach, describe, expect, it, vi } from 'vitest'
import { abortAuthorizedRequests, basicAuthorization, demoLoginDefaults, notifyUnauthorized, onUnauthorized, trackAuthorizedRequest } from './auth'
import { apiRequest } from './api'

afterEach(() => { vi.unstubAllGlobals() })

describe('shared workspace authentication', () => {
  it('prefills only explicitly configured local development demos', () => {
    for (const host of ['localhost', '127.0.0.1', '[::1]']) {
      expect(demoLoginDefaults(host, true, 'demo-user', 'test-only')).toEqual({ username: 'demo-user', password: 'test-only' })
    }
    expect(demoLoginDefaults('example.com', true, 'demo-user', 'test-only')).toEqual({ username: '', password: '' })
    expect(demoLoginDefaults('localhost', false, 'demo-user', 'test-only')).toEqual({ username: '', password: '' })
    expect(demoLoginDefaults('localhost', true)).toEqual({ username: '', password: '' })
  })
  it('encodes ASCII and Unicode credentials without persisting them', () => {
    expect(basicAuthorization('reader', 'password')).toBe(`Basic ${btoa('reader:password')}`)
    const value = basicAuthorization('用户', '口令')
    expect(new TextDecoder().decode(Uint8Array.from(atob(value.slice(6)), char => char.charCodeAt(0)))).toBe('用户:口令')
  })
  it('rejects invalid Basic identities and empty passwords', () => {
    for (const [user, password] of [['', 'x'], ['  ', 'x'], ['a:b', 'x'], ['user', ''], ['user\n', 'x'], ['user', 'x\r']]) {
      expect(() => basicAuthorization(user, password)).toThrow()
    }
  })
  it('broadcasts only the failed identity and unsubscribes on unmount', () => {
    const listener = vi.fn(), dispose = onUnauthorized(listener)
    notifyUnauthorized('Basic old-session')
    expect(listener).toHaveBeenCalledWith('Basic old-session')
    dispose()
    notifyUnauthorized('Basic next-session')
    expect(listener).toHaveBeenCalledTimes(1)
  })
  it('sign-out aborts only requests belonging to that workspace identity', () => {
    const old = trackAuthorizedRequest('old'), current = trackAuthorizedRequest('current')
    abortAuthorizedRequests('old')
    expect(old.controller.signal.aborted).toBe(true)
    expect(current.controller.signal.aborted).toBe(false)
    current.release()
    abortAuthorizedRequests('current')
    expect(current.controller.signal.aborted).toBe(false)
  })
  it('invalidates a shared sign-in on JSON 401 without silently retrying', async () => {
    const listener = vi.fn(), dispose = onUnauthorized(listener)
    const fetch = vi.fn().mockResolvedValue(new Response(JSON.stringify({ message: 'Expired' }), {
      status: 401, headers: { 'Content-Type': 'application/json' },
    }))
    vi.stubGlobal('fetch', fetch)
    try {
      await expect(apiRequest('/events', data => data, undefined, { authorization: 'Basic session' })).rejects.toThrow('Expired')
      expect(listener).toHaveBeenCalledExactlyOnceWith('Basic session')
      expect(fetch).toHaveBeenCalledTimes(1)
    } finally { dispose() }
  })
  it('invalidates a shared sign-in even when a 401 has an HTML body', async () => {
    const listener = vi.fn(), dispose = onUnauthorized(listener)
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('Sign in', { status: 401 })))
    try {
      await expect(apiRequest('/knowledge', data => data, undefined, { authorization: 'Basic session' })).rejects.toThrow('Sign-in failed')
      expect(listener).toHaveBeenCalledExactlyOnceWith('Basic session')
    } finally { dispose() }
  })
  it('keeps valid sign-in on forbidden capabilities and transient errors', async () => {
    const listener = vi.fn(), dispose = onUnauthorized(listener)
    try {
      for (const status of [403, 409, 500]) {
        vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response(JSON.stringify({ message: 'Denied' }), {
          status, headers: { 'Content-Type': 'application/json' },
        })))
        await expect(apiRequest('/rules', data => data, undefined, { authorization: 'Basic session' })).rejects.toThrow('Denied')
      }
      expect(listener).not.toHaveBeenCalled()
    } finally { dispose() }
  })
})
