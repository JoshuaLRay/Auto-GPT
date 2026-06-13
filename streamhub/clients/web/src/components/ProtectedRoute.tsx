import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'

// ProtectedRoute gates a route on a valid session, waiting for the startup
// token check before deciding so we don't flash the login page.
export function ProtectedRoute({ children }: { children: ReactNode }) {
  const { token, ready } = useAuth()
  if (!ready) return <div className="centered">Loading…</div>
  if (!token) return <Navigate to="/login" replace />
  return <>{children}</>
}
