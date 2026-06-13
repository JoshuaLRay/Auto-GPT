package metadata

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"time"
)

// TMDB enriches movie metadata using The Movie Database API. It is optional:
// when no API key is configured, NewTMDB returns nil and callers fall back to
// filename-derived data.
type TMDB struct {
	apiKey string
	http   *http.Client
}

// NewTMDB returns a TMDB client, or nil if apiKey is empty.
func NewTMDB(apiKey string) *TMDB {
	if apiKey == "" {
		return nil
	}
	return &TMDB{apiKey: apiKey, http: &http.Client{Timeout: 10 * time.Second}}
}

// Result is the enriched data TMDB can supply for a movie.
type Result struct {
	Title     string
	Year      *int
	Overview  string
	PosterURL string
}

// SearchMovie looks up a movie by title (and optional year). A nil result with
// nil error means "no confident match" — the caller keeps its filename data.
func (t *TMDB) SearchMovie(ctx context.Context, title string, year *int) (*Result, error) {
	q := url.Values{}
	q.Set("api_key", t.apiKey)
	q.Set("query", title)
	if year != nil {
		q.Set("year", fmt.Sprintf("%d", *year))
	}
	endpoint := "https://api.themoviedb.org/3/search/movie?" + q.Encode()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	resp, err := t.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("tmdb search: status %d", resp.StatusCode)
	}

	var body struct {
		Results []struct {
			Title       string `json:"title"`
			Overview    string `json:"overview"`
			PosterPath  string `json:"poster_path"`
			ReleaseDate string `json:"release_date"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil {
		return nil, err
	}
	if len(body.Results) == 0 {
		return nil, nil
	}

	top := body.Results[0]
	res := &Result{Title: top.Title, Overview: top.Overview}
	if top.PosterPath != "" {
		res.PosterURL = "https://image.tmdb.org/t/p/w500" + top.PosterPath
	}
	if len(top.ReleaseDate) >= 4 {
		if y, err := parseYear(top.ReleaseDate[:4]); err == nil {
			res.Year = &y
		}
	}
	return res, nil
}

func parseYear(s string) (int, error) {
	var y int
	_, err := fmt.Sscanf(s, "%d", &y)
	return y, err
}
