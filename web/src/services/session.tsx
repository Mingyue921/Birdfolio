import { createContext, useContext, useMemo, useState, type ReactNode } from 'react'
import { api, readSession, storeSession } from './api'
import type { Session } from '../types'

interface SessionContextValue {
  session: Session | null
  loginDemo: () => Promise<void>
  logoutLocal: () => void
}

const SessionContext = createContext<SessionContextValue | null>(null)

export function SessionProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(() => readSession())
  const value = useMemo<SessionContextValue>(() => ({
    session,
    loginDemo: async () => { const next = await api.demoSession(); storeSession(next); setSession(next) },
    logoutLocal: () => { storeSession(null); setSession(null) },
  }), [session])
  return <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
}

export function useSession() {
  const context = useContext(SessionContext)
  if (!context) throw new Error('SessionProvider is missing')
  return context
}
