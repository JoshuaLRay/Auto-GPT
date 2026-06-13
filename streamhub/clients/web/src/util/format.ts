// formatDuration turns seconds into "1h 02m" or "12m" or "0:45".
export function formatDuration(seconds: number): string {
  if (!seconds || seconds < 0) return ''
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`
  if (m > 0) return `${m}m`
  return `0:${String(Math.floor(seconds)).padStart(2, '0')}`
}

// formatClock turns seconds into "h:mm:ss" / "m:ss" for resume labels.
export function formatClock(seconds: number): string {
  const s = Math.floor(seconds % 60)
  const m = Math.floor((seconds / 60) % 60)
  const h = Math.floor(seconds / 3600)
  const mm = String(m).padStart(2, '0')
  const ss = String(s).padStart(2, '0')
  return h > 0 ? `${h}:${mm}:${ss}` : `${m}:${ss}`
}
