export type Snapshot = {
  id: string; namespace: string; production: string; running: boolean; supported: boolean
  config_hash: string; observed_at: string; summary: string; summary_kind: string
  nodes: { name: string; class: string; enabled: boolean; pool_size: number }[]
  edges: { source: string; target: string; basis: string }[]; unknown_routing: string[]
}
export type Deployment = {
  id: string; digest: string; state: string; snapshot_id: string; expected_hash: string
  diff: string; impact: string; compensation: string; error?: string
  probe?: { observation_id: string; message_id: string }
}
export type Observation = {
  observation_id: string; message_id: string; session_id: string; scenario: string
  outcome: string; deployment_id: string; snapshot_hash: string; point: string
}
export type MonitorState = {
  snapshot?: Snapshot; deployment?: Deployment; observations: Observation[]
  transport: { pending: number; retrying: number; dropped: number; seen: number; not_monitored: number; last_error: string; heartbeat: string; source_state: string }
  receiver_paused: boolean; received: number; can_deploy: boolean; consumer_age_seconds: number
  summary?: PipelineSummary
}
export type PipelineSummary = {
  id: string; snapshot_id: string; config_hash: string; state: string; model: string
  agent_session?: string; usage?: Record<string, unknown>; error?: string
  result?: { summary: string; limitations: string[] }
}
export type InstanceState = {
  user: string; can_deploy: boolean; endpoint: string
  instance: { instance_id: string; iris_version: string; namespaces: string[] }
}
function object(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid monitor API object')
  return value as Record<string, unknown>
}
function text(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid monitor text')
  return value
}
function number(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('Invalid monitor count')
  return value
}
function flag(value: unknown): boolean {
  if (value === true || value === 1) return true
  if (value === false || value === 0) return false
  throw new Error('Invalid monitor boolean')
}
function list<T>(value: unknown, decode: (value: unknown) => T): T[] {
  if (!Array.isArray(value)) throw new Error('Invalid monitor collection')
  return value.map(decode)
}
export function decodeSnapshot(value: unknown): Snapshot {
  const v = object(value)
  if (v.namespace !== 'DEMO') throw new Error('Unexpected Connector namespace')
  return {
    id: text(v.id), namespace: text(v.namespace), production: text(v.production),
    running: flag(v.running), supported: flag(v.supported), config_hash: text(v.config_hash),
    observed_at: text(v.observed_at), summary: text(v.summary), summary_kind: text(v.summary_kind),
    nodes: list(v.nodes, value => {
      const n = object(value)
      return { name: text(n.name), class: text(n.class), enabled: flag(n.enabled), pool_size: number(n.pool_size) }
    }),
    edges: list(v.edges, value => {
      const e = object(value)
      return { source: text(e.source), target: text(e.target), basis: text(e.basis) }
    }), unknown_routing: list(v.unknown_routing, text),
  }
}
export function decodeDeployment(value: unknown): Deployment {
  const v = object(value)
  const states = ['planned', 'approved', 'applying', 'verifying', 'active', 'stale', 'failed', 'unknown']
  const state = text(v.state)
  if (!states.includes(state)) throw new Error('Unknown deployment state')
  return {
    id: text(v.id), digest: text(v.digest), state, snapshot_id: text(v.snapshot_id), expected_hash: text(v.expected_hash),
    diff: text(v.diff), impact: text(v.impact), compensation: text(v.compensation),
    error: v.error === undefined ? undefined : text(v.error),
    probe: v.probe === undefined ? undefined : {
      observation_id: text(object(v.probe).observation_id), message_id: text(object(v.probe).message_id),
    },
  }
}
export function decodeInstances(value: unknown): InstanceState {
  const v = object(value), i = object(v.instance)
  if (i.instance_id !== 'local-demo') throw new Error('Unregistered instance')
  return { user: text(v.user), can_deploy: flag(v.can_deploy), endpoint: text(v.endpoint),
    instance: { instance_id: text(i.instance_id), iris_version: text(i.iris_version), namespaces: list(i.namespaces, text) } }
}
export function decodePipelineSummary(value: unknown): PipelineSummary {
  const v = object(value)
  const state = text(v.state)
  if (!['queued', 'running', 'completed', 'failed', 'interrupted'].includes(state)) throw new Error('Invalid summary state')
  if (v.kind !== 'ai-hub-agent') throw new Error('Summary is not an AI Hub result')
  const result = v.result === undefined ? undefined : object(v.result)
  if (state === 'completed' && !result) throw new Error('Completed summary is missing its result')
  return {
    id: text(v.id), snapshot_id: text(v.snapshot_id), config_hash: text(v.config_hash), state, model: text(v.model),
    agent_session: v.agent_session === undefined ? undefined : text(v.agent_session),
    usage: v.usage === undefined ? undefined : object(v.usage), error: v.error === undefined ? undefined : text(v.error),
    result: result && { summary: text(result.summary), limitations: list(result.limitations, text) },
  }
}
export function decodeMonitor(value: unknown): MonitorState {
  const v = object(value), t = object(v.transport)
  return {
    snapshot: v.snapshot === '' ? undefined : decodeSnapshot(v.snapshot),
    deployment: v.deployment === '' ? undefined : decodeDeployment(v.deployment),
    summary: v.summary === '' || v.summary === undefined ? undefined : decodePipelineSummary(v.summary),
    observations: list(v.observations, value => {
      const o = object(value)
      if (o.synthetic !== true || o.namespace !== 'DEMO') throw new Error('Unexpected observation source')
      const session = typeof o.session_id === 'number' ? String(number(o.session_id)) : text(o.session_id)
      return { observation_id: text(o.observation_id), message_id: text(o.message_id), session_id: session,
        scenario: text(o.scenario), outcome: text(o.outcome), deployment_id: text(o.deployment_id),
        snapshot_hash: text(o.snapshot_hash), point: text(o.point) }
    }),
    transport: { pending: number(t.pending), retrying: number(t.retrying), dropped: number(t.dropped),
      seen: number(t.seen), not_monitored: number(t.not_monitored), last_error: text(t.last_error), heartbeat: text(t.heartbeat), source_state: text(t.source_state) },
    receiver_paused: flag(v.receiver_paused), received: number(v.received), can_deploy: flag(v.can_deploy), consumer_age_seconds: number(v.consumer_age_seconds),
  }
}
