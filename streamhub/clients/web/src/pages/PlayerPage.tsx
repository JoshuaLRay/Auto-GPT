import { useEffect, useRef, useState } from 'react'
import { useNavigate, useParams, useSearchParams } from 'react-router-dom'
import Hls from 'hls.js'
import { useAuth } from '../auth/AuthContext'
import { api } from '../api/client'

const SAVE_INTERVAL_MS = 10_000

export function PlayerPage() {
  const { id } = useParams<{ id: string }>()
  const { token } = useAuth()
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const shouldResume = searchParams.get('resume') === '1'
  const videoRef = useRef<HTMLVideoElement>(null)
  const [error, setError] = useState('')

  useEffect(() => {
    const video = videoRef.current
    if (!video || !token || !id) return

    const url = api.streamUrl(id, token)
    let hls: Hls | undefined
    let cancelled = false
    let resumeAt = 0

    const start = () => {
      if (cancelled) return
      const seekAndPlay = () => {
        if (resumeAt > 1) video.currentTime = resumeAt
        void video.play().catch(() => {/* autoplay may be blocked; user can press play */})
      }
      if (Hls.isSupported()) {
        hls = new Hls()
        hls.loadSource(url)
        hls.attachMedia(video)
        hls.on(Hls.Events.MANIFEST_PARSED, seekAndPlay)
        hls.on(Hls.Events.ERROR, (_evt, data) => {
          if (data.fatal) setError(`Playback error: ${data.details}`)
        })
      } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        // Safari plays HLS natively.
        video.src = url
        video.addEventListener('loadedmetadata', seekAndPlay, { once: true })
      } else {
        setError('This browser cannot play HLS streams.')
      }
    }

    // Fetch resume position first (only if the user chose Resume), then start.
    if (shouldResume) {
      api
        .getProgress(token, id)
        .then((p) => {
          resumeAt = p.positionSeconds || 0
        })
        .catch(() => {/* default to 0 */})
        .finally(start)
    } else {
      start()
    }

    const save = () => {
      if (video.currentTime > 0) void api.setProgress(token, id, video.currentTime).catch(() => {})
    }
    const interval = window.setInterval(save, SAVE_INTERVAL_MS)

    return () => {
      cancelled = true
      window.clearInterval(interval)
      save() // persist position on unmount
      hls?.destroy()
    }
  }, [id, token, shouldResume])

  return (
    <div className="player">
      <button className="player-back" onClick={() => navigate(-1)} aria-label="Back">
        ← Back
      </button>
      {error && <div className="player-error">{error}</div>}
      <video ref={videoRef} controls className="player-video" />
    </div>
  )
}
