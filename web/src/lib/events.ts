export type HumanEntry = { id: string; actor: string; text: string; time: number; summary_state?: string }
export type LiveEvent = {
  id: string; observation_id: string; category: string; detector: string; title: string; detail: string
  state: string; revision: number; created: number; actions: HumanEntry[]; opinions: HumanEntry[]
}
export type Review = {
  id: string; observation_id: string; state: string; origin: string; reason?: string; error?: string
  event_id?: string; analysis?: Record<string, unknown>
}
export type EventState = {
  events: LiveEvent[]; reviews: Review[]; counts: Record<string, number>
  can_write: boolean; user: string; automatic_model_budget: number
}
export type EventDetail = { event: LiveEvent; observation: Record<string, unknown> }
export function investigationBlockReason(canWrite: boolean, observation: Record<string, unknown>): string {
  if (!canWrite) return 'Your account does not have permission to start an investigation.'
  if (observation.schema !== 2) return 'This observation lacks the schema 2 source facts required by this privacy reviewer.'
  if (observation.scenario !== 'analytics') {
    const scenario = typeof observation.scenario === 'string' ? observation.scenario : 'unknown'
    return `This event's scenario is "${scenario}", not "analytics". This privacy reviewer only supports synthetic analytics exports; this event is not supported. Cost consent cannot enable it.`
  }
  return ''
}
export function eventObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid operations API object')
  return value as Record<string, unknown>
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid operations text')
  return value
}
function count(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('Invalid operations count')
  return value
}
function list<T>(value: unknown, decode: (v: unknown) => T): T[] {
  if (!Array.isArray(value)) throw new Error('Invalid operations list')
  return value.map(decode)
}
function entry(value: unknown): HumanEntry {
  const e = eventObject(value)
  return { id: text(e.id), actor: text(e.actor), text: text(e.text), time: count(e.time),
    summary_state: e.summary_state === undefined ? undefined : text(e.summary_state) }
}
export function decodeLiveEvent(value: unknown): LiveEvent {
  const e = eventObject(value), state = text(e.state)
  if (!['open', 'in_review', 'needs_information', 'resolved', 'ignored'].includes(state)) throw new Error('Unknown event state')
  return { id: text(e.id), observation_id: text(e.observation_id), category: text(e.category), detector: text(e.detector),
    title: text(e.title), detail: text(e.detail), state, revision: count(e.revision), created: count(e.created),
    actions: list(e.actions, entry), opinions: list(e.opinions, entry) }
}
export function decodeEventDetail(value: unknown): EventDetail {
  const d = eventObject(value), observation = eventObject(d.observation)
  if (observation.synthetic !== true || observation.namespace !== 'DEMO') throw new Error('Unexpected observation source')
  return { event: decodeLiveEvent(d.event), observation }
}
export function decodeReview(value: unknown): Review {
  const r = eventObject(value), state = text(r.state)
  if (!['blocked_budget', 'queued', 'running', 'interrupted', 'failed', 'completed'].includes(state)) throw new Error('Unknown review state')
  return { id: text(r.id), observation_id: text(r.observation_id), state, origin: text(r.origin),
    reason: r.reason === undefined ? undefined : text(r.reason), error: r.error === undefined ? undefined : text(r.error),
    event_id: r.event_id === undefined ? undefined : text(r.event_id),
    analysis: r.analysis === undefined ? undefined : eventObject(r.analysis) }
}
export function decodeEvents(value: unknown): EventState {
  const v = eventObject(value), counts = eventObject(v.counts), decoded: Record<string, number> = {}
  for (const [key, value] of Object.entries(counts)) decoded[key] = count(value)
  if (v.can_write !== true && v.can_write !== false && v.can_write !== 0 && v.can_write !== 1) throw new Error('Invalid operations permission')
  return { events: list(v.events, decodeLiveEvent), reviews: list(v.reviews, decodeReview), counts: decoded,
    can_write: v.can_write === true || v.can_write === 1, user: text(v.user), automatic_model_budget: count(v.automatic_model_budget) }
}
