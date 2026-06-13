import type { LibraryItem, PlaybackDecision, Progress, User } from '../types'

// Empty base => same origin (the Vite dev proxy forwards /api to the server).
// Set VITE_API_BASE to point a production build at a remote server.
const base = (import.meta.env.VITE_API_BASE as string | undefined) ?? ''

interface RequestOptions extends RequestInit {
  token?: string
}

async function request<T>(path: string, opts: RequestOptions = {}): Promise<T> {
  const headers = new Headers(opts.headers)
  if (opts.token) headers.set('Authorization', `Bearer ${opts.token}`)
  if (opts.body && !headers.has('Content-Type')) headers.set('Content-Type', 'application/json')

  const res = await fetch(base + path, { ...opts, headers })
  if (!res.ok) {
    let message = res.statusText
    try {
      const body = (await res.json()) as { error?: string }
      if (body.error) message = body.error
    } catch {
      // non-JSON error body; keep statusText
    }
    throw new Error(message)
  }
  if (res.status === 204) return undefined as T
  return (await res.json()) as T
}

export const api = {
  login: (username: string, password: string) =>
    request<{ token: string; user: User }>('/api/auth/login', {
      method: 'POST',
      body: JSON.stringify({ username, password }),
    }),

  me: (token: string) => request<User>('/api/me', { token }),

  listItems: (token: string, type?: string) =>
    request<{ items: LibraryItem[] }>(`/api/items${type ? `?type=${encodeURIComponent(type)}` : ''}`, { token }),

  getItem: (token: string, id: string) => request<LibraryItem>(`/api/items/${id}`, { token }),

  playbackInfo: (token: string, id: string) =>
    request<{ itemId: string; decision: PlaybackDecision }>(`/api/items/${id}/playback-info`, { token }),

  getProgress: (token: string, id: string) => request<Progress>(`/api/items/${id}/progress`, { token }),

  setProgress: (token: string, id: string, positionSeconds: number) =>
    request<void>(`/api/items/${id}/progress`, {
      method: 'PUT',
      token,
      body: JSON.stringify({ positionSeconds }),
    }),

  scan: (token: string) => request<{ status: string }>('/api/library/scan', { method: 'POST', token }),

  // HLS entry point. The token is passed as a query param because the <video>/
  // hls.js segment fetches can't set an Authorization header.
  streamUrl: (id: string, token: string) =>
    `${base}/api/items/${id}/hls.m3u8?token=${encodeURIComponent(token)}`,
}
