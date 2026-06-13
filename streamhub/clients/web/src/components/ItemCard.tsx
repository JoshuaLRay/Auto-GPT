import { Link } from 'react-router-dom'
import type { LibraryItem } from '../types'

// ItemCard is a single poster tile in the library grid.
export function ItemCard({ item }: { item: LibraryItem }) {
  return (
    <Link to={`/items/${item.id}`} className="card">
      <div className="poster">
        {item.posterUrl ? (
          <img src={item.posterUrl} alt={item.title} loading="lazy" />
        ) : (
          <div className="poster-fallback">{item.title.charAt(0).toUpperCase()}</div>
        )}
      </div>
      <div className="card-title" title={item.title}>
        {item.title}
      </div>
      {item.year ? <div className="card-sub">{item.year}</div> : null}
    </Link>
  )
}
