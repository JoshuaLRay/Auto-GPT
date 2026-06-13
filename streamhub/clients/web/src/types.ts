// Types mirror shared/openapi.yaml. Keep in sync with the server contract.

export interface User {
  id: string
  username: string
  isAdmin: boolean
  createdAt: number
}

export type ItemType = 'movie' | 'episode' | 'track' | 'album' | 'photo' | 'home_video'

export interface LibraryItem {
  id: string
  type: ItemType
  parentId?: string
  title: string
  sortTitle?: string
  year?: number
  overview?: string
  container?: string
  videoCodec?: string
  audioCodec?: string
  width?: number
  height?: number
  durationSeconds?: number
  sizeBytes?: number
  posterUrl?: string
  addedAt: number
  updatedAt: number
}

export interface PlaybackDecision {
  directPlay: boolean
  reason: string
  maxHeight?: number
}

export interface Progress {
  itemId: string
  positionSeconds: number
  updatedAt: number
}
