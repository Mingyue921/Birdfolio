import { Link } from 'react-router-dom'
import { ArrowIcon, CameraIcon, ChartIcon, CheckIcon, LeafIcon, MapIcon, ShieldIcon, SparkIcon } from '../components/Icons'

export function HomePage() {
  return <>
    <section className="hero page-section">
      <div className="hero-copy reveal">
        <span className="eyebrow"><SparkIcon size={16}/> 华为云 AI 创新应用</span>
        <h1>看见一只鸟，<br/><em>读懂一场相遇。</em></h1>
        <p>Birdfolio Cloud 用多模态 AI 缩小识别范围，再由你完成最终确认。照片、地点、季节与观察感受，从此沉淀为可信的自然档案。</p>
        <div className="button-row"><Link className="button primary" to="/identify">开始 AI 识鸟 <ArrowIcon/></Link><Link className="button ghost" to="/about">了解技术架构</Link></div>
        <div className="trust-row"><span><CheckIcon size={17}/>AI 只给候选</span><span><CheckIcon size={17}/>确认后才记录</span><span><CheckIcon size={17}/>敏感位置降精度</span></div>
      </div>
      <div className="hero-visual reveal delay">
        <div className="sun-disc"/><div className="bird-orbit"><span className="bird-silhouette">⌁</span></div>
        <div className="specimen-card"><span>候选界面示意</span><b>白鹭</b><i>Ardea alba</i><div className="score-ring">Top<small>3</small></div></div>
        <div className="floating-note note-one"><MapIcon size={18}/><span>地点与季节<br/><b>辅助校验</b></span></div>
        <div className="floating-note note-two"><ShieldIcon size={18}/><span>稀有鸟类<br/><b>位置保护</b></span></div>
      </div>
    </section>
    <section className="page-section flow-section">
      <div className="section-heading"><span className="eyebrow">完整闭环</span><h2>AI 不是答案，是观察的起点</h2><p>从照片到结构化记录，关键决定始终掌握在用户手中。</p></div>
      <div className="flow-grid">
        <article><span className="step">01</span><CameraIcon/><h3>上传照片</h3><p>浏览器压缩图片并清除 EXIF，原始元数据不会进入识别请求。</p></article>
        <article><span className="step">02</span><SparkIcon/><h3>生成候选</h3><p>华为云多模态模型返回 Top 3 与可见辨识依据。</p></article>
        <article><span className="step">03</span><CheckIcon/><h3>人工确认</h3><p>结合地点、季节与栖息地复核，不把模型猜测当作事实。</p></article>
        <article><span className="step">04</span><ChartIcon/><h3>沉淀记录</h3><p>确认后生成观察，实时更新个人物种与时间趋势。</p></article>
      </div>
    </section>
    <section className="page-section value-band">
      <div><LeafIcon size={36}/><h2>为公众观鸟与自然教育而设计</h2></div>
      <p>降低入门门槛，也保留科学观察所需的谨慎。Birdfolio 让识别、记录、地图、统计和手账成为一个连续体验。</p>
      <Link className="text-link" to="/about">查看产品边界 <ArrowIcon/></Link>
    </section>
  </>
}
