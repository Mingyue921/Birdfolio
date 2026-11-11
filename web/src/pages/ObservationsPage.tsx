import { useQuery } from '@tanstack/react-query'
import { Link } from 'react-router-dom'
import { CameraIcon, LeafIcon, MapIcon } from '../components/Icons'
import { LoadingBlock, StatePanel } from '../components/StatePanel'
import { api, friendlyApiError } from '../services/api'
import { useSession } from '../services/session'

function formatDate(value: unknown) {
  const date = new Date(String(value || ''))
  return Number.isNaN(date.getTime()) ? '时间待补充' : new Intl.DateTimeFormat('zh-CN', { dateStyle: 'medium', timeStyle: 'short' }).format(date)
}

export function ObservationsPage() {
  const { session, loginDemo } = useSession()
  const query = useQuery({ queryKey: ['observations'], queryFn: api.observations, enabled: Boolean(session) })
  return <section className="page-section inner-page">
    <div className="section-heading left"><span className="eyebrow">Observation Archive</span><h1>每一次确认，都沉淀为观察档案</h1><p>这里只展示当前临时账号的真实数据，不混入固定封面或其他体验者内容。</p></div>
    {!session && <StatePanel title="先进入隔离的演示会话" action={<button className="button primary" onClick={() => void loginDemo()}>快捷进入</button>}>临时账号有效 24 小时，数据与其他体验者隔离。</StatePanel>}
    {query.isLoading && <LoadingBlock label="正在读取观察记录…"/>}
    {query.isError && <StatePanel title="观察记录加载失败" tone="error" action={<button className="button ghost" onClick={() => void query.refetch()}>重试</button>}>{friendlyApiError(query.error)}</StatePanel>}
    {query.data?.length === 0 && <div className="empty-result card"><CameraIcon size={34}/><h2>还没有观察记录</h2><p>完成一次 AI 候选确认后，记录会出现在这里。</p><Link className="button primary" to="/identify">开始识鸟</Link></div>}
    <div className="observation-grid">{query.data?.map(item => <article className="observation-card" key={item.id}>
      <div className="observation-art"><LeafIcon size={32}/><span>{String(item.habitat || '自然观察')}</span></div>
      <div className="observation-copy"><span className="eyebrow">{formatDate(item.observedAt || item.date || item.createdAt)}</span><h2>{String(item.speciesName || item.name || item.speciesId || '鸟种待核对')}</h2><p><MapIcon size={16}/>{String(item.placeName || item.locationName || '地点未填写')}{item.fuzzyLocation !== false ? ' · 模糊位置' : ''}</p>{item.notes && <small>{String(item.notes)}</small>}</div>
    </article>)}</div>
  </section>
}
