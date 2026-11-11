import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { AppShell } from './components/AppShell'
import { HomePage } from './pages/HomePage'

const IdentifyPage = lazy(() => import('./pages/IdentifyPage').then(module => ({ default: module.IdentifyPage })))
const ObservationsPage = lazy(() => import('./pages/ObservationsPage').then(module => ({ default: module.ObservationsPage })))
const DashboardPage = lazy(() => import('./pages/DashboardPage').then(module => ({ default: module.DashboardPage })))
const AboutPage = lazy(() => import('./pages/AboutPage').then(module => ({ default: module.AboutPage })))

export default function App() {
  return (
    <Suspense fallback={<div className="loading-block page-section"><span className="spinner"/><span>正在打开页面…</span></div>}><Routes>
      <Route element={<AppShell />}>
        <Route index element={<HomePage />} />
        <Route path="identify" element={<IdentifyPage />} />
        <Route path="observations" element={<ObservationsPage />} />
        <Route path="dashboard" element={<DashboardPage />} />
        <Route path="about" element={<AboutPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes></Suspense>
  )
}
