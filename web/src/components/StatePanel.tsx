import type { ReactNode } from 'react'

export function StatePanel({ title, children, action, tone = 'neutral' }: { title: string; children: ReactNode; action?: ReactNode; tone?: 'neutral' | 'error' | 'success' }) {
  return <div className={`state-panel ${tone}`}><div><strong>{title}</strong><div className="state-copy">{children}</div></div>{action}</div>
}

export function LoadingBlock({ label = '正在加载…' }: { label?: string }) {
  return <div className="loading-block"><span className="spinner" /><span>{label}</span></div>
}
