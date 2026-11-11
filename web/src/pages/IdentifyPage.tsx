import { useMemo, useRef, useState } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { CameraIcon, CheckIcon, ShieldIcon, SparkIcon } from '../components/Icons'
import { StatePanel } from '../components/StatePanel'
import { api, friendlyApiError } from '../services/api'
import { compressImage } from '../services/image'
import { useSession } from '../services/session'
import type { IdentificationCandidate, IdentificationResult } from '../types'

type Stage = 'idle' | 'preparing' | 'uploading' | 'identifying' | 'result' | 'confirming' | 'done'

const habitats = ['湿地', '林地', '城市公园', '农田', '海岸', '其他']

function score(value: number) { return `${Math.round(Math.max(0, Math.min(1, value || 0)) * 100)}%` }

export function IdentifyPage() {
  const { session, loginDemo } = useSession()
  const queryClient = useQueryClient()
  const inputRef = useRef<HTMLInputElement>(null)
  const [stage, setStage] = useState<Stage>('idle')
  const [preview, setPreview] = useState('')
  const [dataUrl, setDataUrl] = useState('')
  const [result, setResult] = useState<IdentificationResult | null>(null)
  const [selected, setSelected] = useState('')
  const [error, setError] = useState('')
  const [placeName, setPlaceName] = useState('福州')
  const [habitat, setHabitat] = useState('湿地')
  const [observedAt, setObservedAt] = useState(() => new Date().toISOString().slice(0, 16))

  const busy = ['preparing', 'uploading', 'identifying', 'confirming'].includes(stage)
  const selectedCandidate = useMemo(() => result?.candidates.find(item => item.speciesId === selected), [result, selected])

  async function chooseFile(file?: File) {
    if (!file) return
    setError(''); setResult(null); setSelected(''); setStage('preparing')
    try {
      const compressed = await compressImage(file)
      setPreview(compressed.previewUrl); setDataUrl(compressed.dataUrl); setStage('idle')
    } catch (cause) {
      setStage('idle')
      setError(cause instanceof Error && cause.message === 'FILE_TOO_LARGE' ? '图片超过 20MB，请先缩小后重试。' : '无法读取这张图片，请选择有效的 JPEG、PNG 或 WebP 文件。')
    }
  }

  async function identify() {
    if (!dataUrl) { inputRef.current?.click(); return }
    setError('')
    try {
      if (!session) { setStage('uploading'); await loginDemo() }
      setStage('uploading')
      const uploaded = await api.uploadImage(dataUrl)
      setStage('identifying')
      const next = await api.identify({ mediaId: uploaded.mediaId, placeName: placeName.trim(), observedAt: new Date(observedAt).toISOString(), habitat })
      setResult(next); setSelected(next.candidates[0]?.speciesId || ''); setStage('result')
      if (!next.candidates.length) setError(next.warning || '模型没有返回可靠候选，请更换主体更清晰的照片。')
    } catch (cause) { setStage('idle'); setError(friendlyApiError(cause)) }
  }

  async function confirm() {
    if (!result || !selectedCandidate) return
    setStage('confirming'); setError('')
    try {
      await api.confirm(result.requestId, selectedCandidate.speciesId, {
        speciesId: selectedCandidate.speciesId,
        speciesName: selectedCandidate.name,
        observedAt: new Date(observedAt).toISOString(),
        placeName: placeName.trim(), habitat, fuzzyLocation: true, updatedAt: Date.now(),
      })
      await queryClient.invalidateQueries({ queryKey: ['observations'] })
      setStage('done')
    } catch (cause) { setStage('result'); setError(friendlyApiError(cause)) }
  }

  return <section className="page-section inner-page identify-page">
    <div className="section-heading left"><span className="eyebrow"><SparkIcon size={16}/> AI Bird Identification</span><h1>从一张照片，开始一次可信观察</h1><p>模型只提供候选；你确认之前，系统不会创建观察记录。</p></div>
    <div className="identify-layout">
      <div className="upload-panel card">
        <input ref={inputRef} className="visually-hidden" type="file" accept="image/jpeg,image/png,image/webp" onChange={event => void chooseFile(event.target.files?.[0])}/>
        <button className={`drop-zone ${preview ? 'has-image' : ''}`} onClick={() => inputRef.current?.click()} disabled={busy}>
          {preview ? <img src={preview} alt="待识别鸟类预览"/> : <><span className="upload-icon"><CameraIcon size={34}/></span><b>选择鸟类照片</b><small>JPEG / PNG / WebP，最大 20MB</small></>}
          {stage === 'preparing' && <span className="image-overlay">正在压缩并清除 EXIF…</span>}
        </button>
        <div className="privacy-note"><ShieldIcon size={19}/><span>图片在浏览器中缩放至最长边 1600px，并通过 Canvas 重绘清除 EXIF。</span></div>
        <div className="form-grid">
          <label><span>观察时间</span><input type="datetime-local" value={observedAt} onChange={event => setObservedAt(event.target.value)}/></label>
          <label><span>粗粒度地点</span><input value={placeName} maxLength={80} onChange={event => setPlaceName(event.target.value)} placeholder="例如：福州湿地"/></label>
          <label><span>栖息环境</span><select value={habitat} onChange={event => setHabitat(event.target.value)}>{habitats.map(item => <option key={item}>{item}</option>)}</select></label>
        </div>
        <button className="button primary wide" onClick={() => void identify()} disabled={busy || !observedAt || !placeName.trim()}>{busy ? `${stage === 'identifying' ? '华为云 MaaS 正在分析' : '正在准备图片'}…` : '获取 AI 候选'}</button>
        {!session && <p className="form-hint">首次体验将创建隔离的 24 小时临时账号。</p>}
      </div>

      <div className="result-panel">
        {error && <StatePanel title="本次识别未完成" tone="error">{error}</StatePanel>}
        {!result && !error && <div className="empty-result card"><SparkIcon size={34}/><h2>候选结果会显示在这里</h2><p>系统会结合照片、观察时间、地点和栖息环境，最多返回三个候选。</p></div>}
        {result && result.candidates.length > 0 && <>
          <div className="result-meta"><div><span className="eyebrow">Top {result.candidates.length}</span><h2>请结合现场特征确认</h2></div><div className="provider-badge">{result.provider || (result.mode === 'provider' ? 'AI Provider' : 'Unavailable')} · {result.cacheHit ? '缓存命中' : `${result.elapsedMs || 0}ms`}</div></div>
          {Number(result.candidates[0]?.finalScore || 0) < 0.55 && <StatePanel title="低置信度，需要重点复核">最高候选不足 55%，建议查看相似种或改用更清晰照片。</StatePanel>}
          <div className="candidate-list">{result.candidates.map((candidate, index) => <CandidateCard key={candidate.speciesId} candidate={candidate} rank={index + 1} selected={selected === candidate.speciesId} onSelect={() => setSelected(candidate.speciesId)}/>)}</div>
          {result.warning && <p className="warning-copy">{result.warning}</p>}
          <button className="button primary wide" disabled={!selectedCandidate || stage === 'confirming' || stage === 'done'} onClick={() => void confirm()}>{stage === 'confirming' ? '正在生成观察…' : stage === 'done' ? '观察记录已生成' : '确认候选并生成观察'}</button>
          {stage === 'done' && <StatePanel title="记录成功" tone="success" action={<a className="text-link" href="/observations">查看观察记录</a>}>统计已同步更新，位置以模糊精度保存。</StatePanel>}
        </>}
      </div>
    </div>
  </section>
}

function CandidateCard({ candidate, rank, selected, onSelect }: { candidate: IdentificationCandidate; rank: number; selected: boolean; onSelect: () => void }) {
  return <button className={`candidate-card ${selected ? 'selected' : ''}`} onClick={onSelect} aria-pressed={selected}>
    <span className="candidate-rank">{rank}</span><div className="candidate-main"><div><h3>{candidate.name}</h3><i>{candidate.scientificName || '学名待人工核对'}</i></div><strong>{score(candidate.finalScore)}</strong></div>
    <div className="score-bars"><span><i style={{ width: score(candidate.modelScore) }}/><small>模型 {score(candidate.modelScore)}</small></span><span><i style={{ width: score(candidate.contextScore) }}/><small>环境 {score(candidate.contextScore)}</small></span></div>
    <ul>{candidate.reasons.slice(0, 3).map(reason => <li key={reason}><CheckIcon size={15}/>{reason}</li>)}</ul>
  </button>
}
