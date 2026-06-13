import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react'
import type { ReactNode } from 'react'
import { api } from '../api/client'
import type { User } from '../types'

interface AuthState {
  token: string | null
  user: User | null
  ready: boolean // true once we've checked any stored token
  login: (username: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthState | null>(null)
const STORAGE_KEY = 'streamhub.token'

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() => localStorage.getItem(STORAGE_KEY))
  const [user, setUser] = useState<User | null>(null)
  const [ready, setReady] = useState(false)

  // Validate a stored token on startup.
  useEffect(() => {
    if (!token) {
      setReady(true)
      return
    }
    let cancelled = false
    api
      .me(token)
      .then((u) => {
        if (!cancelled) setUser(u)
      })
      .catch(() => {
        if (!cancelled) {
          localStorage.removeItem(STORAGE_KEY)
          setToken(null)
          setUser(null)
        }
      })
      .finally(() => {
        if (!cancelled) setReady(true)
      })
    return () => {
      cancelled = true
    }
  }, [token])

  const login = useCallback(async (username: string, password: string) => {
    const { token: t, user: u } = await api.login(username, password)
    localStorage.setItem(STORAGE_KEY, t)
    setToken(t)
    setUser(u)
  }, [])

  const logout = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY)
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo<AuthState>(
    () => ({ token, user, ready, login, logout }),
    [token, user, ready, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
