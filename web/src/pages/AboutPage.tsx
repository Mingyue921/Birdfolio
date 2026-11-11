import { ChartIcon, LeafIcon, ShieldIcon, SparkIcon } from '../components/Icons'

export function AboutPage() {
  return <section className="page-section inner-page">
    <div className="section-heading left"><span className="eyebrow">About Birdfolio</span><h1>让 AI 能力进入可信的观察流程</h1><p>比赛版本聚焦“识别候选—人工确认—观察沉淀”，不宣称模型可以替代专业判断。</p></div>
    <div className="architecture-card">
      <div className="arch-node client"><b>React Web / HarmonyOS</b><span>图片压缩、候选确认、离线记录</span></div><span className="arch-arrow">→</span>
      <div className="arch-node cloud"><b>华为云 ECS</b><span>Node.js API / Docker / HTTPS</span></div><span className="arch-arrow">→</span>
      <div className="arch-stack"><span>RDS PostgreSQL</span><span>DCS Redis</span><span>OBS 私有对象</span><span>MaaS 多模态</span></div>
    </div>
    <div className="principle-grid">
      <article><SparkIcon/><h3>可解释候选</h3><p>输出模型分数、上下文分数与照片可见特征，低置信度时明确要求复核。</p></article>
      <article><ShieldIcon/><h3>隐私优先</h3><p>浏览器侧移除 EXIF；社区和敏感物种不返回精确位置；原图不公开。</p></article>
      <article><ChartIcon/><h3>云边协同</h3><p>Web 提供可访问的云端体验，HarmonyOS 客户端保留离线记录、地图与手账能力。</p></article>
      <article><LeafIcon/><h3>自然教育</h3><p>把一次识别转化为长期观察档案，面向个人观鸟、校园活动和公众科普。</p></article>
    </div>
    <div className="disclosure"><strong>当前版本说明</strong><p>本页面是 ICT 创新赛演示版本。AI 结果仅供辅助判断；演示账号在 24 小时后清理。商业发布前仍需完成备案域名、法律复核与更大规模模型评测。</p></div>
  </section>
}
