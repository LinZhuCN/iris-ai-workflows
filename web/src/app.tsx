import { useEffect, useState } from 'react'
import {
  Activity, ArrowUpRight, BookOpen, Bot, Boxes, ChevronRight,
  CircleHelp, Command, FlaskConical, GitBranch, LayoutDashboard,
  ListFilter, Moon, ScrollText, Server, Settings, ShieldCheck, Sparkles, Sun,
} from 'lucide-react'
import {
  SidebarProvider, Sidebar, SidebarHeader, SidebarContent, SidebarFooter,
  SidebarGroup, SidebarGroupLabel, SidebarMenu, SidebarMenuItem, SidebarMenuButton,
  SidebarInset, SidebarTrigger, SidebarRail, useSidebar,
} from './components/ui/sidebar'
import { Button } from './components/ui/button'
import { Status } from './components/platform'
import { ResourcePage } from './pages'
import { LiveKnowledgePage } from './knowledge-page'
import { LiveMonitorPage } from './monitor-page'
import { LiveAgentPage } from './agent-page'
import { LiveOperationsPage } from './operations-page'
import { LiveRulePage } from './rule-page'
import { LiveGovernancePage } from './governance-page'
import { LiveDeclarationsPage } from './declarations-page'
import { WorkspaceAuth } from './auth'
import { ProductionsPage } from './productions-page'
import { OrganizationsPage } from './organizations-page'
import { DistributionDemoPage } from './distribution-demo-page'
import { M5DemoPage } from './m5-demo-page'

const groups = [
  { label: 'Workspace', items: [
    { label: 'Overview', href: '/overview', icon: LayoutDashboard },
    { label: 'Instances', href: '/instances', icon: Server },
    { label: 'Productions', href: '/pipelines', icon: GitBranch },
    { label: 'Organizations', href: '/organizations', icon: Boxes },
    { label: 'Data-use declarations', href: '/declarations', icon: ShieldCheck },
    { label: 'Legacy routes', href: '/governance', icon: GitBranch },
  ] },
  { label: 'Operations', items: [
    { label: 'Events', href: '/events', icon: ListFilter },
    { label: 'Rules', href: '/rules', icon: ShieldCheck },
  ] },
  { label: 'AI resources', items: [
    { label: 'Agents', href: '/agents', icon: Bot },
    { label: 'Knowledge', href: '/knowledge', icon: BookOpen },
    { label: 'Runs', href: '/runs', icon: ScrollText },
  ] },
]

function Navigation({ path, username }: { path: string; username: string }) {
  const { setOpenMobile, isMobile } = useSidebar()
  return <Sidebar collapsible="icon" variant="inset">
    <SidebarHeader className="brand-header">
      <a href="/overview" className="brand"><div className="brand-symbol"><Boxes size={23} /></div>
        <div className="brand-copy"><strong>IRIS Workflows</strong><span>AI monitoring platform</span></div>
      </a>
    </SidebarHeader>
    <SidebarContent>
      <div className="workspace-label"><span className="workspace-dot" />Demo workspace<span className="workspace-tag">LOCAL</span></div>
      {groups.map(group => <SidebarGroup key={group.label}>
        <SidebarGroupLabel>{group.label}</SidebarGroupLabel>
        <SidebarMenu>{group.items.map(item => <SidebarMenuItem key={item.href}>
          <SidebarMenuButton asChild tooltip={item.label} isActive={path.startsWith(item.href)}>
            <a href={item.href} onClick={() => { if (isMobile) setOpenMobile(false) }}>
              <item.icon /><span>{item.label}</span>
            </a>
          </SidebarMenuButton>
        </SidebarMenuItem>)}</SidebarMenu>
      </SidebarGroup>)}
    </SidebarContent>
    <SidebarFooter>
      <SidebarMenu>
        <SidebarMenuItem><SidebarMenuButton asChild tooltip="Synthetic demo" isActive={path.startsWith('/demo')}><a href="/demo"><FlaskConical /><span>Synthetic demo</span><Sparkles className="ml-auto" /></a></SidebarMenuButton></SidebarMenuItem>
        <SidebarMenuItem><SidebarMenuButton asChild tooltip="Fixed M5 onboarding" isActive={path === '/demo/m5'}><a href="/demo/m5"><FlaskConical /><span>M5 onboarding</span></a></SidebarMenuButton></SidebarMenuItem>
        <SidebarMenuItem><SidebarMenuButton asChild tooltip="Settings" isActive={path === '/settings'}><a href="/settings"><Settings /><span>Settings</span></a></SidebarMenuButton></SidebarMenuItem>
      </SidebarMenu>
      <div className="sidebar-footer-note"><div><span className="preview-pulse" />Local demo · P6</div><span>Real events + reviewed DEMO Gate</span></div>
      <div className="user-profile"><div className="avatar">{username.slice(0, 2).toUpperCase()}</div><div><strong>{username}</strong><span>Shared workspace sign-in</span></div><ChevronRight size={15} /></div>
    </SidebarFooter><SidebarRail />
  </Sidebar>
}

export function App() {
  const [path, setPath] = useState(location.pathname === '/' ? '/overview' : location.pathname)
  const [dark, setDark] = useState(() => localStorage.getItem('iris-theme') === 'dark' ||
    (!localStorage.getItem('iris-theme') && matchMedia('(prefers-color-scheme: dark)').matches))
  useEffect(() => {
    document.documentElement.classList.toggle('dark', dark)
    localStorage.setItem('iris-theme', dark ? 'dark' : 'light')
  }, [dark])
  useEffect(() => {
    const navigate = (event: MouseEvent) => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button !== 0) return
      const anchor = event.target instanceof Element ? event.target.closest('a') : null
      if (!anchor || anchor.origin !== location.origin || anchor.target || anchor.hash || anchor.hasAttribute('download')) return
      event.preventDefault()
      history.pushState(null, '', anchor.href)
      setPath(location.pathname)
      window.scrollTo(0, 0)
    }
    const pop = () => setPath(location.pathname)
    document.addEventListener('click', navigate)
    window.addEventListener('popstate', pop)
    return () => { document.removeEventListener('click', navigate); window.removeEventListener('popstate', pop) }
  }, [])
  const section = [...groups.flatMap(g => g.items), { label: 'Settings', href: '/settings' }, { label: 'M5 onboarding', href: '/demo/m5' }, { label: 'Synthetic demo', href: '/demo' }]
    .find(item => path.startsWith(item.href))?.label ?? 'Not found'
  useEffect(() => { document.title = `${section} · IRIS Workflows` }, [section])
  const distributionDemo = path === '/demo'
  const m5Demo = path === '/demo/m5'
  const organizations = path.startsWith('/organizations')
  const liveMonitor = ['/instances', '/pipelines'].some(p => path.startsWith(p)) || path === '/demo/legacy'
  const liveOperations = ['/overview', '/events', '/runs'].some(p => path.startsWith(p))
  return <WorkspaceAuth>{(session, signOut) => <SidebarProvider key={session.authorization}>
    <Navigation path={path} username={session.username} />
    <SidebarInset>
      <header className="topbar">
        <div className="topbar-left"><SidebarTrigger /><span className="topbar-divider" /><span className="breadcrumb">Workspace<ChevronRight size={14} /><strong>{section}</strong></span></div>
        <div className="topbar-right"><span className="environment"><span />Local environment</span>
          <Button variant="ghost" size="icon" aria-label={dark ? 'Use light theme' : 'Use dark theme'} onClick={() => setDark(!dark)}>{dark ? <Sun /> : <Moon />}</Button>
          <a className="help-link" href="/demo" aria-label="Open demo guide"><CircleHelp size={18} /></a>
          <span>{session.username}</span><Button variant="outline" onClick={signOut}>Sign out</Button>
        </div>
      </header>
      {m5Demo ? <div className="preview-banner"><FlaskConical size={15} /><strong>Fixed M5 onboarding</strong><span>M5-only profiles · Explicit enrollment and inspection · Fixed synthetic flow · Separately authorized 1 review / 2 model requests.</span></div> :
      distributionDemo || organizations ? <div className="preview-banner"><FlaskConical size={15} /><strong>Multi-organization synthetic demo</strong><span>Versioned profiles · Explicit local sends · Separately confirmed post-send AI audit · No automatic model charges.</span></div> :
      path.startsWith('/declarations') ? <div className="preview-banner"><FlaskConical size={15} /><strong>Live declaration workflow</strong><span>Propose, review, approve and explicitly run synthetic data; automatically capture actual use for a separately funded comparison.</span><Status tone="info">D5</Status></div> :
      <div className="preview-banner"><FlaskConical size={15} /><strong>{path.startsWith('/pipelines') ? 'Production observability' : path.startsWith('/governance') ? 'Live legacy route governance' : path.startsWith('/rules') ? 'Live reviewed DEMO Gate' : liveOperations ? 'Live event operations' : path.startsWith('/agents') ? 'Live AI Hub Agent factory' : liveMonitor ? 'Live DEMO Connector' : path.startsWith('/knowledge') ? 'Live Knowledge API' : 'UI Preview'}</strong><span>{path.startsWith('/pipelines') ? 'Choose active IRIS Productions, enroll read-only observation, and inspect isolated events and linked risk reviews. No automatic model charges.' : path.startsWith('/governance') ? 'Fixed-route baseline, exact registry approval and automatic budget-bounded background review. Use Data-use declarations for new proposals.' : path.startsWith('/rules') ? 'Manual bounded rules, exact approval and real source-effect verification. Local synthetic DEMO only; no model charges.' : liveOperations ? 'Real observations and persistent human review. Automatic model budget is zero; blocked reviews are not completed AI assessments.' : path.startsWith('/agents') ? 'Real versioned privacy reviewers and synthetic tests. Binding is recorded intent only; automatic monitoring is not connected.' : liveMonitor ? 'Real IRIS Production and observation transport; synthetic business data only. Reviewed enforcement has a separate Rules page.' : path.startsWith('/knowledge') ? 'Real local knowledge retrieval. Agent versions and DEMO monitoring have separate live pages.' : 'This page uses synthetic fixtures, not live monitoring metrics. Open Agents, Instances or Productions for real functionality.'}</span><Status tone="info">{path.startsWith('/pipelines') ? 'Productions' : path.startsWith('/governance') ? 'Routes · P6' : path.startsWith('/rules') ? 'P6' : liveOperations ? 'P5' : path.startsWith('/agents') ? 'P4' : liveMonitor ? 'P2' : 'P0 + P1'}</Status></div>}
      <main id="main-content">
        {m5Demo ? <M5DemoPage /> : distributionDemo ? <DistributionDemoPage /> : path.startsWith('/organizations') ? <OrganizationsPage /> : path.startsWith('/declarations') ? <LiveDeclarationsPage /> : path.startsWith('/governance') ? <LiveGovernancePage /> : liveOperations ? <LiveOperationsPage path={path} /> :
          path.startsWith('/agents') ? <LiveAgentPage /> : path.startsWith('/knowledge') ? <LiveKnowledgePage /> :
          path.startsWith('/rules') ? <LiveRulePage /> :
          path.startsWith('/pipelines') ? <ProductionsPage /> : liveMonitor ? <LiveMonitorPage path={path === '/demo/legacy' ? '/demo' : path} /> :
          path.startsWith('/settings') ? <ResourcePage section={section} path={path} /> :
          <div className="empty-state"><h1>Page not found</h1><a href="/overview">Back to overview</a></div>}
      </main>
      <footer className="page-footer"><span><Activity size={13} /> IRIS AI Hub Interoperability Workflows</span><span>{m5Demo ? 'Fixed synthetic M5 · Separate bounded AI consent' : distributionDemo || organizations ? 'Local synthetic distribution · Separate bounded AI consent' : path.startsWith('/declarations') ? 'Real proposal review · Explicit model consent' : path.startsWith('/governance') ? 'Automatic sidecar · Explicit background AI budget' : path.startsWith('/rules') ? 'Reviewed local Gate · No model calls' : liveOperations ? 'Real events · No automatic model charges' : path.startsWith('/agents') ? 'Real AI Hub · Explicit cost confirmation' : liveMonitor ? 'Real DEMO transport · AI summary is opt-in' : path.startsWith('/knowledge') ? 'Local embedding · No paid model calls' : 'Design preview · No model calls'} <ArrowUpRight size={12} /></span></footer>
    </SidebarInset>
    <a className="skip-link" href="#main-content"><Command size={14} />Skip to content</a>
  </SidebarProvider>}</WorkspaceAuth>
}
