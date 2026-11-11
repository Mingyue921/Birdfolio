import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import ReactECharts from 'echarts-for-react'
import { ChartIcon, LeafIcon, MapIcon } from '../components/Icons'
import { LoadingBlock, StatePanel } from '../components/StatePanel'
import { api, friendlyApiError } from '../services/api'
import { useSession } from '../services/session'

export function DashboardPage() {
  const { session, loginDemo } = useSession()
  const query = useQuery({ queryKey: ['observations'], queryFn: api.observations, enabled: Boolean(session) })
  const model = useMemo(() => {
    const rows = query.data || []; const months = new Map<string, number>(); const places = new Map<string, number>()
    rows.forEach(row => {
      const date = new Date(String(row.observedAt || row.date || row.createdAt || ''))
      const month = Number.isNaN(date.getTime()) ? '待补充' : `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`
      months.set(month, (months.get(month) || 0) + 1)
      const place = String(row.placeName || row.locationName || '未填写'); places.set(place, (places.get(place) || 0) + 1)
    })
    return { total: rows.length, species: new Set(rows.map(row => String(row.speciesId || row.speciesName || row.name || '')).filter(Boolean)).size, months: [...months.entries()].sort(), places: [...places.entries()].sort((a, b) => b[1] - a[1]).slice(0, 6) }
  }, [query.data])
  const option = { color: ['#2f6a50'], grid: { left: 34, right: 18, top: 26, bottom: 32 }, xAxis: { type: 'category', data: model.months.map(item => item[0]), axisLine: { lineStyle: { color: '#c9d5cc' } } }, yAxis: { type: 'value', minInterval: 1, splitLine: { lineStyle: { color: '#edf1ee' } } }, tooltip: { trigger: 'axis' }, series: [{ type: 'bar', data: model.months.map(item => item[1]), barMaxWidth: 42, itemStyle: { borderRadius: [8, 8, 0, 0] } }] }
  return <section className="page-section inner-page">
    <div className="section-heading left"><span className="eyebrow">Personal Dashboard</span><h1>把相遇汇成长期的自然观察</h1><p>数据由当前账号的真实观察在浏览器端聚合，不展示虚构增长率。</p></div>
    {!session && <StatePanel title="需要演示会话" action={<button className="button primary" onClick={() => void loginDemo()}>快捷进入</button>}>进入后查看两条明确标注的种子观察及你新增的记录。</StatePanel>}
    {query.isLoading && <LoadingBlock label="正在生成统计…"/>}
    {query.isError && <StatePanel title="统计加载失败" tone="error">{friendlyApiError(query.error)}</StatePanel>}
    {session && query.data && <>
      <div className="metric-grid"><article><ChartIcon/><span>观察次数</span><b>{model.total}</b></article><article><LeafIcon/><span>记录鸟种</span><b>{model.species}</b></article><article><MapIcon/><span>观察地区</span><b>{model.places.length}</b></article></div>
      <div className="dashboard-grid"><article className="chart-card card"><div><span className="eyebrow">Time Trend</span><h2>月度观察趋势</h2></div>{model.months.length ? <ReactECharts option={option} style={{ height: 320 }}/>: <p className="muted">确认一次观察后生成趋势。</p>}</article>
      <article className="place-card card"><span className="eyebrow">Places</span><h2>粗粒度地点</h2>{model.places.length ? <ol>{model.places.map(([name, count]) => <li key={name}><span>{name}</span><b>{count}</b></li>)}</ol> : <p className="muted">暂无地点数据。</p>}<small>敏感物种和社区内容不展示精确坐标。</small></article></div>
    </>}
  </section>
}
