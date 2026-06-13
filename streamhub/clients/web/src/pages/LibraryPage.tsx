import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { api } from '../api/client'
import type { LibraryItem } from '../types'
import { Layout } from '../components/Layout'
import { ItemCard } from '../components/ItemCard'

export function LibraryPage() {
  const { token } = useAuth()
  const [searchParams] = useSearchParams()
  const query = (searchParams.get('q') ?? '').toLowerCase()

  const [items, setItems] = useState<LibraryItem[]>([])
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    if (!token) return
    let cancelled = false
    setLoading(true)
    api
      .listItems(token)
      .then((res) => {
        if (!cancelled) setItems(res.items)
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Could not load library')
      })
      .finally(() => {
        if (!cancelled) setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [token])

  const filtered = useMemo(
    () => (query ? items.filter((i) => i.title.toLowerCase().includes(query)) : items),
    [items, query],
  )

  return (
    <Layout>
      {loading && <p className="muted">Loading library…</p>}
      {error && <p className="error">{error}</p>}
      {!loading && !error && filtered.length === 0 && (
        <div className="empty">
          <p>No media found{query ? ' for that search' : ''}.</p>
          {!query && <p className="muted">Add files to your media folder and run a scan.</p>}
        </div>
      )}
      <div className="grid">
        {filtered.map((item) => (
          <ItemCard key={item.id} item={item} />
        ))}
      </div>
    </Layout>
  )
}
