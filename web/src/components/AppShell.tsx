import { useState } from 'react'
import { Link, NavLink, Outlet } from 'react-router-dom'
import { useSession } from '../services/session'
import { LeafIcon } from './Icons'

const links = [
  ['/', '首页'], ['/identify', 'AI 识鸟'], ['/observations', '观察记录'], ['/dashboard', '数据看板'], ['/about', '关于项目'],
]

export function AppShell() {
  const [open, setOpen] = useState(false)
  const { session, logoutLocal } = useSession()
  return <div className="app-shell">
    <header className="topbar">
      <Link className="brand" to="/" aria-label="Birdfolio 首页"><span className="brand-mark"><LeafIcon /></span><span>Birdfolio <b>Cloud</b></span></Link>
      <button className="menu-button" aria-label="切换导航" onClick={() => setOpen(value => !value)}>☰</button>
      <nav className={open ? 'nav open' : 'nav'} aria-label="主导航">
        {links.map(([path, label]) => <NavLink key={path} to={path} end={path === '/'} onClick={() => setOpen(false)}>{label}</NavLink>)}
      </nav>
      <div className="session-chip" title={session ? '临时会话已连接' : '尚未进入演示会话'}>
        <span className={session ? 'status-dot online' : 'status-dot'} />
        {session ? <button onClick={logoutLocal}>退出演示</button> : <span>访客</span>}
      </div>
    </header>
    <main><Outlet /></main>
    <footer>
      <div><span className="brand compact"><span className="brand-mark"><LeafIcon /></span>Birdfolio Cloud</span><p>让每一次与鸟类的相遇，都被认真识别与记录。</p></div>
      <div className="footer-meta"><span>AI 候选 · 人工确认</span><span>敏感位置保护</span><span>HarmonyOS + 华为云</span></div>
    </footer>
  </div>
}
