import { useEffect, useState } from 'react'
import { Link, useParams } from 'react-router-dom'
import { useAuth } from '../auth/AuthContext'
import { api } from '../api/client'
import type { LibraryItem, PlaybackDecision } from '../types'
import { Layout } from '../components/Layout'
import { formatClock, formatDuration } from '../util/format'

export function DetailPage() {
  const { id } = useParams<{ id: string }>()
  const { token } = useAuth()
  const [item, setItem] = useState<LibraryItem | null>(null)
  const [decision, setDecision] = useState<PlaybackDecision | null>(null)
  const [resume, setResume] = useState(0)
  const [error, setError] = useState('')

  useEffect(() => {
    if (!token || !id) return
    let cancelled = false
    Promise.all([api.getItem(token, id), api.playbackInfo(token, id), api.getProgress(token, id)])
      .then(([it, pb, prog]) => {
        if (cancelled) return
        setItem(it)
        setDecision(pb.decision)
        setResume(prog.positionSeconds || 0)
      })
      .catch((err) => {
        if (!cancelled) setError(err instanceof Error ? err.message : 'Could not load item')
      })
    return () => {
      cancelled = true
    }
  }, [token, id])

  if (error) return <Layout><p className="error">{error}</p></Layout>
  if (!item) return <Layout><p className="muted">Loading…</p></Layout>

  return (
    <Layout>
      <div className="detail">
        <div className="detail-poster">
          {item.posterUrl ? (
            <img src={item.posterUrl} alt={item.title} />
          ) : (
            <div className="poster-fallback large">{item.title.charAt(0).toUpperCase()}</div>
          )}
        </div>
        <div className="detail-info">
          <h1>{item.title}</h1>
          <div className="detail-meta">
            {item.year ? <span>{item.year}</span> : null}
            {item.durationSeconds ? <span>{formatDuration(item.durationSeconds)}</span> : null}
            {item.height ? <span>{item.height}p</span> : null}
            {item.videoCodec ? <span>{item.videoCodec.toUpperCase()}</span> : null}
          </div>
          {item.overview && <p className="overview">{item.overview}</p>}

          <div className="detail-actions">
            <Link className="play-button" to={`/items/${item.id}/play`}>
              ▶ Play
            </Link>
            {resume > 1 && (
              <Link className="resume-button" to={`/items/${item.id}/play?resume=1`}>
                Resume from {formatClock(resume)}
              </Link>
            )}
          </div>

          {decision && (
            <p className="playback-note muted">
              {decision.directPlay ? 'Direct play' : 'Transcoding'} — {decision.reason}
            </p>
          )}
        </div>
      </div>
    </Layout>
  )
}
