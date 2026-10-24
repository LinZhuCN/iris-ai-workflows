import type { ApiErrorBody } from '../contracts'
import { notifyUnauthorized, trackAuthorizedRequest } from './auth'

export class ApiError extends Error {
  constructor(public status: number, public details: ApiErrorBody) {
    super(details.message)
  }
}

export async function apiRequest<T>(
  path: string,
  decode: (data: unknown) => T,
  signal?: AbortSignal,
  options?: { authorization: string; body?: object },
): Promise<T> {
  const tracked = options?.authorization ? trackAuthorizedRequest(options.authorization) : undefined
  const requestSignal = tracked ? signal ? AbortSignal.any([signal, tracked.controller.signal]) : tracked.controller.signal : signal
  try {
    const response = await fetch(`/api/monitor/v1${path}`, {
      credentials: 'omit',
      method: options?.body ? 'POST' : 'GET',
      headers: {
        Accept: 'application/json',
        ...(options ? { Authorization: options.authorization } : {}),
        ...(options?.body ? { 'Content-Type': 'application/json', 'X-Requested-With': 'IRIS-Workflows' } : {}),
      },
      body: options?.body ? JSON.stringify(options.body) : undefined,
      signal: requestSignal,
    })
    if (response.status === 401 && options?.authorization) notifyUnauthorized(options.authorization)
    const contentType = response.headers.get('content-type') ?? ''
    if (!contentType.includes('application/json')) {
      throw new ApiError(response.status, {
        code: 'invalid_response',
        message: response.status === 401
          ? 'Sign-in failed. Check your dedicated platform username and password.'
          : 'The platform API is not connected or did not return JSON. No preview fallback was used.',
        request_id: response.headers.get('x-request-id') ?? 'unavailable',
      })
    }
    const data: unknown = await response.json()
    if (!response.ok) {
      throw new ApiError(response.status, {
        code: 'request_failed',
        message: typeof data === 'object' && data !== null && 'message' in data && typeof data.message === 'string'
          ? data.message : `Platform API returned HTTP ${response.status}.`,
        request_id: response.headers.get('x-request-id') ?? 'unavailable',
      })
    }
    return decode(data)
  } finally { tracked?.release() }
}
