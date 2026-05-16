package software

import (
	"context"
	"log/slog"
	"sync"
	"time"

	"github.com/google/go-github/v76/github"
	"golang.org/x/sync/errgroup"
)

type RepositorySummary struct {
	Name        string
	Description string
	Thumbnail   string
	Topics      []string
	Languages   map[string]int
}

// Service fetches and caches GitHub repository data.
type Service struct {
	client *github.Client
	user   string

	cacheMu    sync.RWMutex
	cachedData []RepositorySummary
	cacheReady bool
	cacheCond  *sync.Cond
}

// NewService creates a Service that fetches repositories for the given GitHub user.
func NewService(user string) *Service {
	return &Service{
		client:    github.NewClient(nil),
		user:      user,
		cacheCond: sync.NewCond(&sync.Mutex{}),
	}
}

// GetAllRepositorySummaries returns a channel that delivers cached repository data.
// Blocks until data is available if the initial fetch has not yet completed.
func (s *Service) GetAllRepositorySummaries(ctx context.Context) <-chan []RepositorySummary {
	ch := make(chan []RepositorySummary, 1)
	go func() {
		defer close(ch)

		s.cacheCond.L.Lock()
		for !s.cacheReady {
			s.cacheCond.Wait()
		}
		s.cacheCond.L.Unlock()

		s.cacheMu.RLock()
		data := s.cachedData
		s.cacheMu.RUnlock()

		select {
		case ch <- data:
		case <-ctx.Done():
		}
	}()
	return ch
}

// StartBackgroundRefresh fetches GitHub data immediately and then on the given interval.
// Blocks until ctx is cancelled.
func (s *Service) StartBackgroundRefresh(ctx context.Context, interval time.Duration) {
	slog.InfoContext(ctx, "fetching initial software data")
	if err := s.fetchAndCache(ctx); err != nil {
		slog.ErrorContext(ctx, "initial software data fetch failed", "error", err)
	}

	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			slog.InfoContext(ctx, "stopping software data refresh")
			return
		case <-ticker.C:
			slog.InfoContext(ctx, "refreshing software data")
			if err := s.fetchAndCache(ctx); err != nil {
				slog.ErrorContext(ctx, "software data refresh failed", "error", err)
			}
		}
	}
}

func (s *Service) fetchAndCache(ctx context.Context) error {
	allRepos, err := s.listRepositoriesForUser(ctx)
	if err != nil {
		return err
	}

	var repos []*github.Repository
	for _, repo := range allRepos {
		if !repo.GetFork() {
			repos = append(repos, repo)
		}
	}

	summaries := make([]RepositorySummary, len(repos))
	g, ctx := errgroup.WithContext(ctx)
	for i, repo := range repos {
		g.Go(func() error {
			thumbnail, err := s.getThumbnailForRepository(ctx, repo.GetOwner().GetLogin(), repo.GetName())
			if err != nil {
				return err
			}

			languages, err := s.listLanguagesForRepository(ctx, repo.GetOwner().GetLogin(), repo.GetName())
			if err != nil {
				return err
			}

			summaries[i] = RepositorySummary{
				Name:        repo.GetName(),
				Description: repo.GetDescription(),
				Thumbnail:   thumbnail,
				Topics:      repo.Topics,
				Languages:   languages,
			}
			return nil
		})
	}

	if err := g.Wait(); err != nil {
		return err
	}

	s.cacheMu.Lock()
	s.cachedData = summaries
	s.cacheMu.Unlock()

	s.cacheCond.L.Lock()
	s.cacheReady = true
	s.cacheCond.Broadcast()
	s.cacheCond.L.Unlock()

	return nil
}
