import { useRef, useState } from 'react'
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
  const [uploadMsg, setUploadMsg] = useState('')
  const fileInputRef = useRef<HTMLInputElement>(null)

  function submitSearch(e: React.FormEvent) {
    e.preventDefault()
    navigate(query ? `/?q=${encodeURIComponent(query)}` : '/')
  }

  async function handleUpload(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    e.target.value = '' // allow re-selecting the same file later
    if (!file || !token) return
    setUploadMsg('Uploading 0%')
    try {
      await api.upload(token, file, (pct) => setUploadMsg(`Uploading ${pct}%`))
      setUploadMsg('Processing…')
      // Full reload so the freshly indexed item shows up in the library grid.
      window.location.assign('/')
    } catch (err) {
      setUploadMsg(err instanceof Error ? err.message : 'Upload failed')
      setTimeout(() => setUploadMsg(''), 5000)
    }
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
            <>
              <input
                ref={fileInputRef}
                type="file"
                accept="video/*"
                hidden
                onChange={handleUpload}
              />
              <button
                className="ghost"
                onClick={() => fileInputRef.current?.click()}
                title="Upload a video"
              >
                {uploadMsg || 'Upload'}
              </button>
              <button className="ghost" onClick={triggerScan} title="Rescan the library">
                {scanMsg || 'Scan'}
              </button>
            </>
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
