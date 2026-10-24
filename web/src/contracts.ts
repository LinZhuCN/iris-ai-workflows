export type TaskState = 'queued' | 'running' | 'completed' | 'failed' | 'blocked'
export type EventState = 'open' | 'in_review' | 'needs_information' | 'resolved' | 'ignored'
export type ReviewOutcome =
  | 'potential_risk'
  | 'no_finding_in_observed_scope'
  | 'insufficient_evidence'
export type ResourceState = 'draft' | 'tested' | 'published' | 'retired'
export type DeploymentState = 'approved' | 'preparing' | 'activating' | 'active' | 'unknown' | 'failed'
export type EventKind = 'Privacy risk' | 'Business failure' | 'Evidence gap' | 'Technical failure'
export interface MonitorEvent {
  id: string
  title: string
  kind: EventKind
  pipeline: string
  component: string
  severity: 'High' | 'Medium' | 'Low'
  state: EventState
  taskState: TaskState
  time: string
  summary: string
}
export interface ApiErrorBody {
  code: string
  message: string
  request_id: string
}
export interface PageResult<T> {
  items: T[]
  next_cursor: string | null
}
export interface RuleDraft {
  target: string
  mode: 'monitoring' | 'sampling' | 'demo_enforcement'
  conditions: { field: string; op: 'eq' | 'in' | 'exists'; value: string | string[] | boolean }[]
  action: 'create_event' | 'trigger_agent' | 'set_sampling_rate' | 'hold_for_review'
}

// Deployment requires a target receipt, not just a locally approved version.
export function deploymentConfirmed(desired: string, loaded: string | null, state: DeploymentState) {
  return state === 'active' && desired === loaded
}

export function canPublishAgent(state: ResourceState, testedDigest: string | null, digest: string) {
  return state === 'tested' && testedDigest === digest
}
