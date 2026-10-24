import type { MonitorEvent } from './contracts'

export const events: MonitorEvent[] = [
  { id: 'EV-1042', title: 'Residual identifier in analytics export', kind: 'Privacy risk', pipeline: 'Analytics Export', component: 'Analytics.Outbound', severity: 'High', state: 'open', taskState: 'completed', time: '14:32:08', summary: 'An MRN category was detected before sending to the synthetic analytics recipient. The route requires Safe Harbor review; this is a potential risk, not a legal determination.' },
  { id: 'EV-1041', title: 'Destination response timed out', kind: 'Business failure', pipeline: 'Lab Results', component: 'Lab.Delivery', severity: 'Medium', state: 'in_review', taskState: 'completed', time: '14:29:46', summary: 'The synthetic destination did not respond within its configured timeout. The business outcome and diagnosis status are tracked independently.' },
  { id: 'EV-1040', title: 'Recipient purpose requires verification', kind: 'Evidence gap', pipeline: 'Clinical Exchange', component: 'Clinical.Router', severity: 'Medium', state: 'needs_information', taskState: 'completed', time: '14:24:12', summary: 'Recipient purpose could not be established. Identifier presence alone is not sufficient to infer a violation.' },
  { id: 'EV-1039', title: 'Knowledge retrieval unavailable', kind: 'Technical failure', pipeline: 'Analytics Export', component: 'Privacy.Reviewer', severity: 'Low', state: 'open', taskState: 'failed', time: '14:18:03', summary: 'A simulated retrieval error prevented review. No no-risk outcome was recorded.' },
]

export const pipelines = [
  { name: 'Analytics Export', route: 'Source → Transform → Policy Gate → Analytics', point: 'before_send', observations: '6,240', coverage: '98.4%', status: 'Needs attention', agent: 'Privacy Sentinel', icon: 'analytics' },
  { name: 'Clinical Exchange', route: 'Source → Clinical Router → Treatment Partner', point: 'before_send', observations: '4,812', coverage: '100%', status: 'Monitoring', agent: 'Privacy Sentinel', icon: 'clinical' },
  { name: 'Lab Results', route: 'Lab Source → Validation → Delivery', point: 'send_result', observations: '1,432', coverage: '99.1%', status: 'Needs attention', agent: 'Workflow Investigator', icon: 'lab' },
]
