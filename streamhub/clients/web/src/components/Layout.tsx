import { useState } from 'react'
import type { ReactNode } from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { api } from '../api/client'

// Layout is the app shell: brand, search, admin scan, logout.
export function Layout({ children }: { children: ReactNode }) {
  const { user, token, logout } = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [query, setQuery] = useState(searchParams.get('q') ?? '')
  const [scanMsg, setScanMsg] = useState('')

  function submitSearch(e: React.FormEvent) {
    e.preventDefault()
    navigate(query ? `/?q=${encodeURIComponent(query)}` : '/')
  }

  async function triggerScan() {
    if (!token) return
    setScanMsg('Scanning…')
    try {
      await api.scan(token)
      setScanMsg('Scan started')
    } catch (err) {
      setScanMsg(err instanceof Error ? err.message : 'Scan failed')
    }
    setTimeout(() => setScanMsg(''), 4000)
  }

  return (
    <div className="app">
      <header className="topbar">
        <Link to="/" className="brand">
          Stream<span>Hub</span>
        </Link>
        <form className="search" onSubmit={submitSearch}>
          <input
            type="search"
            placeholder="Search your library…"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </form>
        <div className="actions">
          {user?.isAdmin && (
            <button className="ghost" onClick={triggerScan} title="Rescan the library">
              {scanMsg || 'Scan'}
            </button>
          )}
          <span className="user">{user?.username}</span>
          <button className="ghost" onClick={logout}>
            Sign out
          </button>
        </div>
      </header>
      <main className="content">{children}</main>
    </div>
  )
}
