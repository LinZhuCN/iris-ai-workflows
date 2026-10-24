import type { ReactNode } from 'react'
import { ArrowUpRight, CircleCheck, FlaskConical, Info } from 'lucide-react'
import { Card, CardContent, CardHeader, CardTitle } from './ui/card'
import { Button } from './ui/button'
import { cn } from '@/lib/utils'

export function Status({ children, tone = 'neutral' }: {
  children: ReactNode
  tone?: 'neutral' | 'success' | 'warning' | 'danger' | 'info'
}) {
  return <span className={cn('status', `status-${tone}`)}><span className="status-dot" />{children}</span>
}

export function PageHeading({ eyebrow, title, description, action }: {
  eyebrow: string; title: string; description: string; action?: ReactNode
}) {
  return <div className="page-heading">
    <div><div className="eyebrow">{eyebrow}</div><h1>{title}</h1><p>{description}</p></div>
    <div className="heading-actions">{action}</div>
  </div>
}

export function Panel({ title, children, action, className }: {
  title: string; children: ReactNode; action?: ReactNode; className?: string
}) {
  return <Card className={cn('panel', className)}>
    <CardHeader className="panel-header"><CardTitle className="panel-title">{title}</CardTitle>{action}</CardHeader>
    <CardContent>{children}</CardContent>
  </Card>
}

export function PreviewNote({ children }: { children?: ReactNode }) {
  return <div className="preview-note"><Info size={15} /><span>{children ?? 'Interactive UI preview. Actions stay in this browser session; no IRIS instance or model is called.'}</span></div>
}

export function EmptyState({ title, children }: { title: string; children: ReactNode }) {
  return <div className="empty-state"><FlaskConical size={32} /><h3>{title}</h3><p>{children}</p></div>
}

export function Stat({ label, value, note, accent, icon }: {
  label: string; value: string; note: string; accent?: boolean; icon: ReactNode
}) {
  return <Card className={cn('stat-card', accent && 'stat-accent')}><CardContent>
    <div className="stat-label">{label}<span>{icon}</span></div>
    <div className="stat-value">{value}</div><div className="stat-note">{note}</div>
  </CardContent></Card>
}

export function LinkButton({ to, children }: { to: string; children: ReactNode }) {
  return <Button asChild variant="ghost" size="sm"><a href={to}>{children}<ArrowUpRight size={14} /></a></Button>
}

export function Steps({ labels, current }: { labels: string[]; current: number }) {
  return <ol className="steps">{labels.map((label, i) => <li key={label} className={i <= current ? 'step-active' : ''}>
    <span>{i < current ? <CircleCheck size={16} /> : i + 1}</span>{label}
  </li>)}</ol>
}
