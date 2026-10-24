import { useState, type ReactNode } from 'react'
import {
  Activity, ArrowDownRight, ArrowLeft, ArrowRight, ArrowUpRight, BookOpen,
  Bot, CheckCircle2, ChevronRight, Clock3, Database,
  FileText, FlaskConical, GitBranch, Layers, LockKeyhole,
  Plus, Search, Server, ShieldAlert, ShieldCheck, Sparkles, Timer, Workflow,
} from 'lucide-react'
import { Button } from './components/ui/button'
import { Input } from './components/ui/input'
import { Textarea } from './components/ui/textarea'
import { Tabs, TabsList, TabsTrigger, TabsContent } from './components/ui/tabs'
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle, DialogFooter } from './components/ui/dialog'
import { PageHeading, Panel, PreviewNote, Stat, Status, LinkButton, Steps } from './components/platform'
import { events as initialEvents, pipelines } from './fixtures'
import { cn } from './lib/utils'

function TrafficChart() {
  const values = [30, 42, 36, 58, 47, 32, 39, 55, 74, 56, 48, 65, 89, 74, 61, 80, 93, 72, 59, 68, 85, 98, 76, 65]
  return <div className="traffic-chart">
    <div className="chart-key"><span><i className="key-primary" /> Observations</span><span><i className="key-muted" /> Selected for review</span></div>
    <div className="chart-area"><div className="chart-axis"><span>1,000</span><span>750</span><span>500</span><span>250</span><span>0</span></div>
      <div className="bar-plot" role="img" aria-label="Synthetic hourly observation volumes, with sampled review counts; not live data">
        {[0, 1, 2, 3].map(i => <div className="chart-grid" style={{ bottom: `${i * 25}%` }} key={i} />)}
        {values.map((value, i) => <div className="bar-group" key={i}><div className="chart-bar" style={{ height: `${value}%` }} /><div className="chart-bar-small" style={{ height: `${value * .16}%` }} /></div>)}
      </div>
    </div><div className="chart-labels"><span>00:00</span><span>04:00</span><span>08:00</span><span>12:00</span><span>16:00</span><span>20:00</span></div>
  </div>
}

export function Overview() {
  return <>
    <PageHeading eyebrow="YOUR OPERATIONS, IN FOCUS" title="Overview" description="A clear view of your data flows. Evidence behind every decision."
      action={<><span className="date-filter"><Clock3 size={14} />Oct 15, 2026 · UTC</span><Button asChild><a href="/demo"><FlaskConical />Explore demo</a></Button></>} />
    <div className="stats-grid">
      <Stat label="Observed messages" value="12,484" note="Across 3 synthetic pipelines" icon={<Activity size={17} />} />
      <Stat label="Selected for review" value="128" note="1.03% effective sample rate" icon={<Layers size={17} />} />
      <Stat label="Completed reviews" value="124" note="3 pending · 1 retrieval failure" icon={<CheckCircle2 size={17} />} />
      <Stat label="Open events" value="3" note="2 need attention · 1 evidence gap" accent icon={<ShieldAlert size={17} />} />
    </div>
    <div className="overview-main-grid">
      <Panel title="Data flow activity" action={<span className="subtle">Last 24 hours · preview</span>}><TrafficChart /></Panel>
      <Panel title="Review outcomes" action={<ShieldCheck size={17} className="subtle" />}>
        <div className="outcome-wrap"><div className="donut"><div><strong>124</strong><span>completed</span></div></div>
          <div className="outcome-caption">Scoped findings, not compliance certification.</div></div>
        <div className="outcome-legend">
          <div><span><i className="legend-dot dot-indigo" />No finding in scope</span><strong>112</strong></div>
          <div><span><i className="legend-dot dot-amber" />Potential risk</span><strong>8</strong></div>
          <div><span><i className="legend-dot dot-slate" />Insufficient evidence</span><strong>4</strong></div>
        </div>
      </Panel>
    </div>
    <div className="overview-bottom-grid">
      <Panel title="Events needing attention" action={<LinkButton to="/events">View all events</LinkButton>}>
        <div className="event-summary-list">{initialEvents.slice(0, 3).map(event => <a href={`/events/${event.id}`} className="event-summary" key={event.id}>
          <div className={cn('event-icon', event.kind === 'Privacy risk' ? 'event-icon-risk' : event.kind === 'Business failure' ? 'event-icon-failure' : 'event-icon-gap')}>
            {event.kind === 'Privacy risk' ? <ShieldAlert size={19} /> : event.kind === 'Business failure' ? <Timer size={19} /> : <FileText size={19} />}
          </div><div className="event-summary-text"><strong>{event.title}</strong><span>{event.pipeline} <span className="inline-dot">·</span> {event.id} <span className="inline-dot">·</span> {event.time}</span></div>
          <Status tone={event.severity === 'High' ? 'danger' : 'warning'}>{event.severity}</Status><ChevronRight size={15} className="subtle" />
        </a>)}</div>
      </Panel>
      <Panel title="Platform readiness" action={<span className="preview-label">ILLUSTRATIVE</span>}>
        <div className="readiness-row"><span className="readiness-icon"><Server size={18} /></span><div><strong>IRIS demo instance</strong><span>Connector and discovery preview</span></div><Status tone="neutral">Not live</Status></div>
        <div className="readiness-row"><span className="readiness-icon"><BookOpen size={18} /></span><div><strong>HIPAA knowledge</strong><span>23 MB prepared text · 2,195 records</span></div><Status tone="warning">Not indexed</Status></div>
        <div className="readiness-row"><span className="readiness-icon"><Bot size={18} /></span><div><strong>Agent workspace</strong><span>2 template concepts available</span></div><Status tone="info">Preview</Status></div>
      </Panel>
    </div>
    <Panel title="Pipeline workspace" action={<LinkButton to="/pipelines">Explore pipelines</LinkButton>}>
      <div className="pipeline-cards">{pipelines.map((p, i) => <a href={`/pipelines/${i + 1}`} className="pipeline-card" key={p.name}>
        <div className="pipeline-card-top"><div className="pipeline-symbol"><GitBranch size={20} /></div><Status tone={p.status === 'Monitoring' ? 'success' : 'warning'}>{p.status}</Status></div>
        <h3>{p.name}</h3><p>{p.route}</p><div className="pipeline-meta"><span><Bot size={13} />{p.agent}</span><ArrowUpRight size={15} /></div>
      </a>)}</div>
    </Panel>
  </>
}

export function EventsPage({ path }: { path: string }) {
  const [events, setEvents] = useState(initialEvents)
  const [query, setQuery] = useState(() => new URLSearchParams(location.search).get('q') ?? '')
  const [filter, setFilter] = useState('All events')
  const [opinion, setOpinion] = useState('')
  const [saved, setSaved] = useState('')
  const [investigation, setInvestigation] = useState(false)
  const [ignoreOpen, setIgnoreOpen] = useState(false)
  const [reason, setReason] = useState('')
  const id = path.split('/')[2]
  const event = events.find(item => item.id === id)
  const filtered = events.filter(item =>
    `${item.title} ${item.id} ${item.pipeline}`.toLowerCase().includes(query.toLowerCase()) &&
    (filter === 'All events' || item.kind === filter))
  const updateQuery = (value: string) => {
    setQuery(value)
    const url = new URL(location.href)
    if (value) url.searchParams.set('q', value)
    else url.searchParams.delete('q')
    history.replaceState(null, '', url)
  }
  if (id && !event) return <><PageHeading eyebrow="OPERATIONS" title="Event not found" description="This preview has only the listed synthetic events." /><LinkButton to="/events">Back to events</LinkButton></>
  if (event) return <>
    <a href="/events" className="back-link"><ArrowLeft size={15} />All events</a>
    <PageHeading eyebrow={`${event.id} / SYNTHETIC OBSERVATION`} title={event.title} description={`${event.pipeline} · ${event.component} · before_send`}
      action={<><Button variant="outline" onClick={() => setIgnoreOpen(true)}>Ignore event</Button><Button onClick={() => setInvestigation(true)}><Sparkles />Preview investigation</Button></>} />
    <div className="detail-status"><Status tone={event.state === 'ignored' ? 'neutral' : 'warning'}>{event.state.replaceAll('_', ' ')}</Status><Status tone={event.taskState === 'failed' ? 'danger' : 'success'}>Analysis {event.taskState}</Status><span>Synthetic message · 2026-10-15 {event.time} UTC</span></div>
    <div className="investigation-grid">
      <Panel title="Observed facts" action={<Database size={17} className="subtle" />}>
        <div className="facts-list">{[
          ['Purpose', event.kind === 'Evidence gap' ? 'Unknown' : 'Analytics'],
          ['Recipient', 'ANALYTICS-SAFE-HARBOR'], ['Observation', 'Before send'],
          ['MRN category', 'Present'], ['Field location', 'patient.identifier'],
          ['Raw value', 'Not included'], ['Evidence reference', 'evref_demo_42'],
          ['Detector version', 'synthetic-v1'],
        ].map(([label, value]) => <div key={label}><span>{label}</span><strong>{value}</strong></div>)}</div>
        <div className="callout"><LockKeyhole size={15} />Only approved categories and references are shown. Raw values are not sent to a remote model.</div>
      </Panel>
      <Panel title="Investigation" action={<Status tone="info">Example report</Status>}>
        <div className="report-agent"><div className="agent-icon"><Bot size={20} /></div><div><strong>Privacy Sentinel</strong><span>Configuration concept · no model call</span></div></div>
        <Status tone={event.kind === 'Technical failure' ? 'danger' : 'warning'}>{event.kind === 'Technical failure' ? 'Review unavailable' : event.kind === 'Evidence gap' ? 'Insufficient evidence' : 'Potential risk'}</Status>
        <h3 className="report-heading">What was observed</h3><p className="body-copy">{event.summary}</p>
        <h3 className="report-heading">Suggested next steps</h3>
        <ul className="report-list"><li>Verify the recipient purpose and applicable sharing policy.</li><li>Inspect the transformation at the outbound observation point.</li><li>Confirm the claimed de-identification path with an authorized reviewer.</li></ul>
        <div className="policy-check"><ShieldCheck size={16} /><span>IRIS validation is planned. This example is not an executed policy check.</span></div>
      </Panel>
      <Panel title="Source references" action={<BookOpen size={16} className="subtle" />}>
        <div className="source-card"><div className="source-type">REGULATION SNAPSHOT</div><h3>45 CFR § 164.514</h3><p>Other requirements relating to uses and disclosures of protected health information.</p><Status>eCFR · 2026-10-13</Status>
          <div className="source-excerpt">Preview reference to de-identification requirements. No retrieved excerpt or Agent citation is claimed in this UI.</div>
          <a href="https://www.ecfr.gov/on/2026-10-13/title-45/section-164.514" target="_blank" rel="noreferrer">Open official source<ArrowUpRight size={14} /></a>
        </div><div className="callout">Source availability does not establish legal applicability or a completed compliance review.</div>
      </Panel>
    </div>
    <div className="two-columns">
      <Panel title="Handling opinion" action={<span className="subtle">Human decision</span>}>
        <label htmlFor="opinion" className="field-label">Describe your assessment or proposed constraint</label>
        <Textarea id="opinion" value={opinion} onChange={e => setOpinion(e.target.value)} placeholder="For this analytics recipient, residual MRNs should require manual review…" rows={4} />
        <div className="form-actions"><Button variant="outline" disabled={!opinion.trim()} onClick={() => setSaved(opinion)}>Save preview opinion</Button>
          <Button asChild disabled={!saved}>{saved ? <a href="/rules/new"><Sparkles />Preview rule draft</a> : <span>Save an opinion first</span>}</Button></div>
        {saved && <p role="status" className="success-note">Saved in this preview session only. No rule or Production was changed.</p>}
      </Panel>
      <Panel title="Event timeline"><div className="timeline">
        {['Synthetic observation received', 'Example analysis attached', 'Awaiting human review'].map((text, i) => <div key={text}><span className="timeline-dot" /><div><strong>{text}</strong><span>{['14:32:08', '14:32:11', 'Now'][i]} · illustrative</span></div></div>)}
        {saved && <div><span className="timeline-dot" /><div><strong>Preview opinion saved</strong><span>No backend write</span></div></div>}
      </div></Panel>
    </div>
    <PreviewNote />
    <Dialog open={ignoreOpen} onOpenChange={setIgnoreOpen}><DialogContent><DialogHeader><DialogTitle>Ignore this event</DialogTitle><DialogDescription>Affects only this synthetic event in memory. It does not suppress future events.</DialogDescription></DialogHeader>
      <label htmlFor="ignore-reason" className="field-label">Reason</label><Textarea id="ignore-reason" value={reason} onChange={e => setReason(e.target.value)} />
      <DialogFooter><Button variant="outline" onClick={() => setIgnoreOpen(false)}>Cancel</Button><Button disabled={!reason.trim()} onClick={() => {
        setEvents(items => items.map(item => item.id === event.id ? { ...item, state: 'ignored' } : item)); setIgnoreOpen(false)
      }}>Ignore in preview</Button></DialogFooter>
    </DialogContent></Dialog>
    <Dialog open={investigation} onOpenChange={setInvestigation}><DialogContent><DialogHeader><DialogTitle>Investigate with an Agent</DialogTitle><DialogDescription>Preview the intended interaction. Live analysis is not connected.</DialogDescription></DialogHeader>
      <div className="selection-card"><Bot /><div><strong>Privacy Sentinel</strong><p>privacy_review · HIPAA knowledge · approved fact tools</p></div><CheckCircle2 size={18} /></div>
      <div className="callout">A real investigation will create a new Run, retain previous reports, and may incur model charges.</div><Button disabled>Run investigation · backend not connected</Button>
    </DialogContent></Dialog>
  </>
  return <>
    <PageHeading eyebrow="OPERATIONS" title="Events" description="One workspace for anomalies, privacy findings and human decisions."
      action={<Status tone="info">Synthetic examples</Status>} />
    <div className="mini-stats"><span><strong>4</strong> Total examples</span><span><i className="legend-dot dot-amber" /><strong>3</strong> Awaiting action</span><span><i className="legend-dot dot-indigo" /><strong>1</strong> In review</span></div>
    <Panel title="Event inbox" action={<span className="subtle">No live collector connected</span>}>
      <div className="table-toolbar"><div className="search-field"><Search size={16} /><Input aria-label="Search events" value={query} onChange={e => updateQuery(e.target.value)} placeholder="Search events or pipelines…" /></div>
        <select aria-label="Filter event type" value={filter} onChange={e => setFilter(e.target.value)}><option>All events</option><option>Privacy risk</option><option>Business failure</option><option>Evidence gap</option><option>Technical failure</option></select></div>
      <div className="table-scroll"><table><thead><tr><th>Event</th><th>Pipeline</th><th>Severity</th><th>Status</th><th>Analysis</th><th>Time · UTC</th><th><span className="sr-only">Open</span></th></tr></thead>
        <tbody>{filtered.map(event => <tr key={event.id}><td><a className="table-title" href={`/events/${event.id}`}>{event.title}</a><span className="table-subtitle">{event.id} · {event.kind}</span></td><td>{event.pipeline}<span className="table-subtitle">{event.component}</span></td><td><Status tone={event.severity === 'High' ? 'danger' : event.severity === 'Medium' ? 'warning' : 'neutral'}>{event.severity}</Status></td><td className="capitalize">{event.state.replaceAll('_', ' ')}</td><td><Status tone={event.taskState === 'failed' ? 'danger' : 'success'}>{event.taskState}</Status></td><td className="mono subtle">{event.time}</td><td><a href={`/events/${event.id}`} aria-label={`Open ${event.id}`}><ArrowUpRight size={16} /></a></td></tr>)}</tbody>
      </table></div>{!filtered.length && <div className="empty-state"><Search /><h3>No matching events</h3><p>Try a different query or event type.</p></div>}
      <div className="table-footer"><span>{filtered.length} synthetic events</span><span>Preview dataset · no pagination required</span></div>
    </Panel><PreviewNote />
  </>
}

export function AgentPage({ path }: { path: string }) {
  const [purpose, setPurpose] = useState('Review analytics exports for residual identifiers. Use HIPAA evidence, distinguish missing context from risk, and recommend human checks.')
  const [template, setTemplate] = useState('Privacy / security review')
  const [knowledge, setKnowledge] = useState(true)
  const [generated, setGenerated] = useState(false)
  const [step, setStep] = useState(0)
  const creating = path.includes('/new') || path.includes('/privacy-sentinel')
  if (!creating) return <>
    <PageHeading eyebrow="AI RESOURCES" title="Agents" description="Purpose-built intelligence. Explicit tools, knowledge and boundaries."
      action={<Button asChild><a href="/agents/new"><Plus />Create Agent</a></Button>} />
    <div className="resource-grid">
      {[{ name: 'Privacy Sentinel', template: 'privacy_review', text: 'Review outbound data with scoped facts and HIPAA source references.', kb: 'HIPAA knowledge', href: '/agents/privacy-sentinel' },
        { name: 'Workflow Investigator', template: 'diagnosis', text: 'Explain processing failures with evidence and actionable investigation steps.', kb: 'No knowledge binding', href: '/agents/new' }].map(agent => <Panel key={agent.name} title={agent.name} action={<div className="agent-icon"><Bot size={21} /></div>}>
          <Status tone="info">Template preview</Status><p className="resource-description">{agent.text}</p><div className="resource-tags"><span>{agent.template}</span><span><BookOpen size={12} />{agent.kb}</span></div>
          <div className="resource-card-footer"><span className="subtle">Not published</span><LinkButton to={agent.href}>View configuration</LinkButton></div>
        </Panel>)}
    </div><PreviewNote />
  </>
  return <>
    <a href="/agents" className="back-link"><ArrowLeft size={15} />All Agents</a>
    <PageHeading eyebrow="AGENT STUDIO" title="Create an Agent" description="Describe the purpose. Review its capabilities before it touches a workflow." action={<Status>Configuration preview</Status>} />
    <Steps labels={['Purpose', 'Configuration', 'Test', 'Publish', 'Bind']} current={step} />
    <div className="builder-grid"><Panel title={generated ? 'Configuration preview' : 'What should your Agent do?'} action={<Sparkles size={18} className="text-indigo-500" />}>
      {!generated ? <>
        <label className="field-label" htmlFor="purpose">Purpose in natural language</label><Textarea id="purpose" rows={5} value={purpose} onChange={e => setPurpose(e.target.value)} />
        <label className="field-label" htmlFor="template">Supported template</label><select id="template" value={template} onChange={e => setTemplate(e.target.value)}><option>Privacy / security review</option><option>Failure diagnosis</option></select>
        <label className="checkbox-field"><input type="checkbox" checked={knowledge} onChange={e => setKnowledge(e.target.checked)} /><span><strong>Include knowledge</strong><small>HIPAA prepared corpus · not yet indexed</small></span><BookOpen size={18} /></label>
        <div className="form-actions"><Button disabled={!purpose.trim()} onClick={() => { setGenerated(true); setStep(1) }}><Sparkles />Preview configuration layout</Button></div>
        <p className="subtle text-xs mt-3">Uses a fixed UI example, not LLM generation. Your text is not sent anywhere.</p>
      </> : <>
        <div className="callout"><FlaskConical size={17} />Fixed template illustration — no Agent has been generated or saved.</div>
        <div className="facts-list"><div><span>Template</span><strong>{template}</strong></div><div><span>Knowledge</span><strong>{knowledge ? 'HIPAA · index required' : 'None selected'}</strong></div><div><span>Model</span><strong>Not configured</strong></div><div><span>Output</span><strong>{template.startsWith('Privacy') ? 'Scoped review result' : 'Candidate causes and evidence'}</strong></div><div><span>Permissions</span><strong>Read-only, task-bound</strong></div></div>
        <h3 className="report-heading">Requested purpose</h3><p className="body-copy">{purpose}</p>
        <h3 className="report-heading">Allowed capabilities</h3><div className="code-tags"><code>ReadBoundFacts</code><code>ReadPipelineContext</code>{knowledge && <code>SearchBoundKnowledge</code>}</div>
        <div className="form-actions"><Button variant="outline" onClick={() => { setGenerated(false); setStep(0) }}><ArrowLeft />Edit purpose</Button><Button onClick={() => setStep(2)}>Preview test step<ArrowRight /></Button></div>
        {step === 2 && <div className="callout mt-4"><LockKeyhole size={16} />Live tests and publishing remain disabled until the platform API, model and required index are ready.</div>}
      </>}
    </Panel><div><Panel title="Designed with boundaries"><div className="boundary-list">
      {[['Explicit purpose', 'One supported template, a visible configuration.'], ['Scoped knowledge', 'Only selected, approved index versions.'], ['Read-only tools', 'No arbitrary code or Production modification.'], ['Test before publishing', 'A changed configuration invalidates old tests.']].map(([title, text]) => <div key={title}><ShieldCheck size={18} /><div><strong>{title}</strong><p>{text}</p></div></div>)}
    </div></Panel><div className="callout mt-4">Publishing and binding are separate actions. A draft never starts monitoring a pipeline.</div></div></div>
    <PreviewNote />
  </>
}

export function KnowledgePage() {
  const [query, setQuery] = useState('')
  return <>
    <PageHeading eyebrow="AI RESOURCES" title="Knowledge" description="Ground decisions in traceable sources, not unverified answers." action={<Button disabled title="Import API is not connected"><Plus />Import knowledge</Button>} />
    <div className="knowledge-hero"><div className="knowledge-book"><BookOpen size={33} /></div><div><div className="eyebrow">PREPARED RELEASE CORPUS</div><h2>HIPAA & supporting guidance</h2><p>Official evidence, clearly separated from summaries and historical context.</p></div><Status tone="warning">Not indexed</Status></div>
    <div className="stats-grid"><Stat label="Prepared text" value="23.00 MB" note="Original binary archive stays local" icon={<FileText size={17} />} /><Stat label="Source records" value="2,195" note="Self-contained release package" icon={<Layers size={17} />} /><Stat label="Default-scope records" value="715" note="Normative, technical & orientation" icon={<ShieldCheck size={17} />} /><Stat label="Active index" value="—" note="AI Hub ingestion not implemented" icon={<Database size={17} />} /></div>
    <Tabs defaultValue="sources"><TabsList><TabsTrigger value="sources">Sources & scopes</TabsTrigger><TabsTrigger value="index">Index builds</TabsTrigger><TabsTrigger value="search">Retrieval test</TabsTrigger></TabsList>
      <TabsContent value="sources"><Panel title="Corpus organization" action={<span className="subtle">Prepared package metadata</span>}>
        <div className="table-scroll"><table><thead><tr><th>Scope</th><th>Purpose</th><th>Records</th><th>Default retrieval</th></tr></thead><tbody>
          {[['Normative', 'Regulation snapshots and selected HHS guidance', '682', true], ['Technical', 'Selected HHS / NIST implementation guidance', '27', true], ['Orientation', 'Non-authoritative LLM briefs', '5', true], ['Organization policy', 'Synthetic demonstration policy', '1', true], ['Historical', 'Historical final-rule explanations', '72', false], ['Unreviewed', 'Archived cases, proposals and other materials', '1,408', false]].map(([scope, purpose, records, included]) => <tr key={String(scope)}><td className="font-medium">{scope}</td><td className="subtle">{purpose}</td><td className="mono">{records}</td><td><Status tone={included ? 'info' : 'neutral'}>{included ? 'Included' : 'Excluded'}</Status></td></tr>)}
        </tbody></table></div><div className="callout">“Normative” is a retrieval role, not a declaration that every passage is currently binding law. Applicability requires review.</div>
      </Panel></TabsContent>
      <TabsContent value="index"><Panel title="Index lifecycle"><Steps labels={['Validate', 'Prepare', 'Embed', 'Verify', 'Activate']} current={0} /><div className="empty-state"><Database size={32} /><h3>No index has been built</h3><p>The text package is ready. Embedding and source-isolated retrieval will be verified before import.</p><Button disabled>Build index · backend not connected</Button></div></Panel></TabsContent>
      <TabsContent value="search"><Panel title="Test retrieval"><label htmlFor="retrieval-query" className="field-label">Synthetic question</label><Input id="retrieval-query" placeholder="When does the treatment exception apply?" value={query} onChange={e => setQuery(e.target.value)} /><div className="form-actions"><Button disabled>Search · no active index</Button></div><PreviewNote>Retrieval is disabled. No example answer is presented as a retrieved result.</PreviewNote></Panel></TabsContent>
    </Tabs>
  </>
}

export function RulesPage({ path }: { path: string }) {
  const [tab, setTab] = useState('definition')
  const detail = path !== '/rules'
  if (!detail) return <>
    <PageHeading eyebrow="OPERATIONS" title="Rules" description="Turn reviewed decisions into explicit, testable constraints." action={<Button asChild><a href="/rules/new"><Plus />Preview rule draft</a></Button>} />
    <div className="three-columns">{[
      { icon: <ShieldAlert />, title: 'Monitoring', text: 'Create an event or invoke an approved Agent. No impact on business delivery.' },
      { icon: <Layers />, title: 'Sampling', text: 'Versioned review coverage for one explicit observation point.' },
      { icon: <LockKeyhole />, title: 'Demo enforcement', text: 'A preinstalled local Gate can hold synthetic messages for review.' },
    ].map(item => <Panel key={item.title} title={item.title} action={item.icon}><p className="body-copy">{item.text}</p></Panel>)}</div>
    <Panel title="Rule workspace"><div className="rule-row"><div className="event-icon event-icon-risk"><ShieldCheck size={21} /></div><div><a className="table-title" href="/rules/analytics-mrn">Require review for residual MRN</a><span className="table-subtitle">Analytics Export · before_send · single target</span></div><Status>Draft example</Status><LinkButton to="/rules/analytics-mrn">Inspect rule</LinkButton></div></Panel><PreviewNote />
  </>
  return <>
    <a href="/rules" className="back-link"><ArrowLeft size={15} />All rules</a>
    <PageHeading eyebrow="CONSTRAINT STUDIO" title="Require review for residual MRN" description="One explicit target. A visible condition. No arbitrary generated code." action={<Status>Draft example</Status>} />
    <Steps labels={['Define', 'Validate', 'Test', 'Approve', 'Activate']} current={0} />
    <div className="builder-grid"><Panel title="Rule definition" action={<ShieldCheck size={19} className="text-indigo-500" />}>
      <Tabs value={tab} onValueChange={setTab}><TabsList><TabsTrigger value="definition">Readable rule</TabsTrigger><TabsTrigger value="schema">Structured form</TabsTrigger><TabsTrigger value="tests">Test plan</TabsTrigger></TabsList>
        <TabsContent value="definition">
          <div className="rule-block"><span className="source-type">TARGET</span><strong>Demo / DEMO / Analytics Export</strong><span>Observation point: before_send</span></div>
          <div className="rule-flow"><div><span className="rule-keyword">WHEN</span><p>Recipient is <code>ANALYTICS-SAFE-HARBOR</code></p><p>AND identifier category <code>MRN</code> is present</p></div><ArrowDownRight className="subtle" /><div><span className="rule-keyword">THEN</span><p>Hold the synthetic message for human review</p><Status tone="warning">Demo Gate only</Status></div></div>
          <div className="callout">This is a proposed organization constraint, not a universal HIPAA rule. A monitored business flow is not blocked unless an approved Gate is explicitly installed.</div>
        </TabsContent>
        <TabsContent value="schema"><pre className="json-preview">{JSON.stringify({ schema_version: 1, target: 'demo/analytics/before_send', mode: 'demo_enforcement', conditions: [{ field: 'recipient', op: 'eq', value: 'ANALYTICS-SAFE-HARBOR' }, { field: 'identifier.MRN.present', op: 'eq', value: true }], action: 'hold_for_review' }, null, 2)}</pre></TabsContent>
        <TabsContent value="tests"><div className="test-case"><FlaskConical /><span>Residual MRN present</span><Status>Expected: hold</Status></div><div className="test-case"><FlaskConical /><span>MRN absent, known facts</span><Status>Expected: no match</Status></div><div className="test-case"><FlaskConical /><span>Identifier fact unknown</span><Status tone="warning">Expected: evidence gap</Status></div><PreviewNote>These are test specifications, not executed test results.</PreviewNote></TabsContent>
      </Tabs>
      <div className="form-actions"><Button variant="outline" onClick={() => setTab('tests')}>View planned tests</Button><Button disabled>Validate · backend not connected</Button></div>
    </Panel><div><Panel title="Deployment truth"><div className="facts-list"><div><span>Platform approval</span><strong>Not approved</strong></div><div><span>Desired bundle</span><strong>None</strong></div><div><span>Target loaded bundle</span><strong>Unknown</strong></div><div><span>Target confirmation</span><strong>Not received</strong></div><div><span>Effect verified</span><strong>Not tested</strong></div></div><div className="callout"><LockKeyhole size={16} />Saving or approving a rule is not evidence that it is active in a Production.</div></Panel><Panel title="Release safeguards" className="mt-5"><ul className="report-list"><li>Actual positive, negative and unknown tests.</li><li>Approval pinned to the exact rule hash.</li><li>Target validation and atomic version switch.</li><li>Explicit acknowledgement and rollback.</li></ul></Panel></div></div>
    <PreviewNote />
  </>
}

export function ResourcePage({ section, path }: { section: string; path: string }) {
  const [selectedNode, setSelectedNode] = useState('Transform')
  const descriptions: Record<string, string> = {
    Instances: 'Discover active Productions through a controlled, authorized Connector.',
    Pipelines: 'Understand the path, observation points and coverage of each data flow.',
    Runs: 'Trace observable actions, evidence and versions. Not hidden model reasoning.',
    Settings: 'Explicit configuration, permissions and runtime boundaries.',
    'Synthetic demo': 'Walk through the platform story without touching a live Production.',
  }
  let content: ReactNode
  if (section === 'Pipelines') content = path.split('/')[2] ? <Panel title="Analytics Export · topology preview" action={<Status>Not live</Status>}>
    <div className="topology">{['Source', 'Transform', 'Policy Gate', 'Analytics'].map((name, i) => <div className="topology-part" key={name}><button onClick={() => setSelectedNode(name)} className={cn('topology-node', selectedNode === name && 'selected-node')}><Workflow size={23} /><strong>{name}</strong><span>{name === 'Policy Gate' ? 'Demo enforcement' : 'Synthetic component'}</span></button>{i < 3 && <ArrowRight size={20} className="subtle shrink-0" />}</div>)}</div>
    <div className="node-detail"><Status tone="info">Selected: {selectedNode}</Status><p>This is a layout illustration. Connector discovery and component state are not connected.</p></div>
  </Panel> : <Panel title="Pipeline inventory"><div className="pipeline-cards">{pipelines.map((p, i) => <a className="pipeline-card" href={`/pipelines/${i + 1}`} key={p.name}><div className="pipeline-symbol"><GitBranch size={22} /></div><h3>{p.name}</h3><p>{p.route}</p><div className="pipeline-meta"><span>{p.point}</span><ArrowUpRight size={16} /></div></a>)}</div></Panel>
  else if (section === 'Instances') content = <><div className="resource-grid"><Panel title="IRIS demo instance" action={<Server size={21} />}><Status tone="info">Connection concept</Status><div className="facts-list"><div><span>Namespace</span><strong>DEMO · proposed, not created</strong></div><div><span>Connector</span><strong>Not installed</strong></div><div><span>Discovery snapshot</span><strong>None</strong></div><div><span>Credential</span><strong>Not configured</strong></div></div><Button disabled>Discover · Connector required</Button></Panel><Panel title="Controlled onboarding"><Steps labels={['Connect', 'Discover', 'Plan', 'Approve']} current={0} /><p className="body-copy">Read-only discovery does not grant deployment privileges. Production changes require a validated plan and explicit approval.</p></Panel></div><PreviewNote>No instance was registered and no remote Production was queried by this page.</PreviewNote></>
  else if (section === 'Runs') content = <Panel title="Execution workspace"><div className="table-scroll"><table><thead><tr><th>Run concept</th><th>Capability</th><th>Status</th><th>Model usage</th></tr></thead><tbody>{[['Knowledge preparation', 'Organize approved source metadata'], ['Agent configuration', 'Generate within supported templates'], ['Event investigation', 'Read facts and retrieve evidence'], ['Rule drafting', 'Produce a constrained declaration']].map(([title, text]) => <tr key={title}><td className="font-medium">{title}</td><td className="subtle">{text}</td><td><Status>Not executed</Status></td><td>Unknown</td></tr>)}</tbody></table></div><div className="callout">A deterministic job is not reported as a model run. No example trace here is claimed as an actual execution.</div></Panel>
  else if (section === 'Settings') content = <div className="two-columns"><Panel title="Preview environment"><div className="facts-list"><div><span>Mode</span><strong>UI fixture preview</strong></div><div><span>Frontend</span><strong>Shadcn Admin / React</strong></div><div><span>Backend connection</span><strong>Not enabled</strong></div><div><span>Production changes</span><strong>None</strong></div></div></Panel><Panel title="Governance"><div className="boundary-list">{['Secrets configured outside the browser', 'Object-level authorization in the API', 'Explicit approval before deployment', 'Audit retained for each version and action'].map(text => <div key={text}><ShieldCheck size={18} /><p>{text}</p></div>)}</div><Button disabled>Save · API not connected</Button></Panel></div>
  else content = <><div className="demo-hero"><div className="eyebrow">THE PLATFORM STORY</div><h2>From observation to<br /><span>an evidence-backed action.</span></h2><p>Explore the intended workflow. Every production-changing action remains disabled in this preview.</p><Button asChild><a href="/events/EV-1042">Explore example event<ArrowRight /></a></Button></div><div className="three-columns">{[['01', 'Ground the Agent', 'Import HIPAA, review source scopes, and publish an explicit Agent configuration.', '/knowledge'], ['02', 'Investigate an event', 'Review the observed facts, investigate with an Agent, and record a human opinion.', '/events/EV-1042'], ['03', 'Strengthen a constraint', 'Inspect a proposed rule, test it, approve a precise version and verify target activation.', '/rules/analytics-mrn']].map(([number, title, text, href]) => <Panel key={number} title={title} action={<span className="step-number">{number}</span>}><p className="body-copy">{text}</p><LinkButton to={href}>Explore preview</LinkButton></Panel>)}</div></>
  return <><PageHeading eyebrow={section === 'Synthetic demo' ? 'GUIDED EXPERIENCE' : 'WORKSPACE'} title={section} description={descriptions[section] ?? ''} action={<Status tone="info">UI preview</Status>} />{content}</>
}
