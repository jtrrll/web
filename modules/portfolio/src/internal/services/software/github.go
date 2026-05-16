package software

import (
	"context"
	"fmt"
	"net/http"
	"strings"

	"github.com/google/go-github/v76/github"
	"golang.org/x/net/html"
)

func (s *Service) getRenderedReadmeForRepository(ctx context.Context, owner string, repo string) (string, error) {
	readme, _, err := s.client.Repositories.GetReadme(ctx, owner, repo, nil)
	if err != nil {
		return "", fmt.Errorf("fetching README: %w", err)
	}

	content, err := readme.GetContent()
	if err != nil {
		return "", fmt.Errorf("decoding README content: %w", err)
	}

	rendered, _, err := s.client.Markdown.Render(ctx, content, &github.MarkdownOptions{
		Mode:    "gfm",
		Context: fmt.Sprintf("%s/%s", owner, repo),
	})
	if err != nil {
		return "", fmt.Errorf("rendering README markdown: %w", err)
	}

	rendered = rewriteRelativeURLs(rendered, owner, repo)

	return rendered, nil
}

// rewriteRelativeURLs rewrites relative and root-relative URLs in rendered HTML
// to point to the correct GitHub raw/blob content.
func rewriteRelativeURLs(htmlContent string, owner string, repo string) string {
	rawBase := fmt.Sprintf("https://raw.githubusercontent.com/%s/%s/HEAD/", owner, repo)
	blobBase := fmt.Sprintf("https://github.com/%s/%s/blob/HEAD/", owner, repo)

	doc, err := html.Parse(strings.NewReader(htmlContent))
	if err != nil {
		return htmlContent
	}

	var rewrite func(*html.Node)
	rewrite = func(n *html.Node) {
		if n.Type == html.ElementNode {
			switch n.Data {
			case "img":
				for i, attr := range n.Attr {
					if attr.Key == "src" {
						n.Attr[i].Val = resolveURL(attr.Val, rawBase, owner, repo)
					}
				}
			case "a":
				for i, attr := range n.Attr {
					if attr.Key == "href" {
						n.Attr[i].Val = resolveURL(attr.Val, blobBase, owner, repo)
					}
				}
			case "p":
				stripBadgeBrs(n)
			}
		}
		for c := n.FirstChild; c != nil; c = c.NextSibling {
			rewrite(c)
		}
	}
	rewrite(doc)

	var buf strings.Builder
	if err := html.Render(&buf, doc); err != nil {
		return htmlContent
	}

	// html.Render wraps in <html><head></head><body>...</body></html>
	// Extract just the body content.
	result := buf.String()
	if start := strings.Index(result, "<body>"); start != -1 {
		result = result[start+len("<body>"):]
	}
	if end := strings.LastIndex(result, "</body>"); end != -1 {
		result = result[:end]
	}
	return result
}

func resolveURL(href string, base string, owner string, repo string) string {
	// Skip absolute URLs, anchors, and data URIs
	if strings.HasPrefix(href, "http://") || strings.HasPrefix(href, "https://") ||
		strings.HasPrefix(href, "#") || strings.HasPrefix(href, "data:") ||
		strings.HasPrefix(href, "mailto:") {
		return href
	}

	// Root-relative URLs from GitHub's renderer (e.g., /jtrrll/snekcheck/blob/HEAD/...)
	prefix := fmt.Sprintf("/%s/%s/", owner, repo)
	if strings.HasPrefix(href, prefix) {
		return "https://github.com" + href
	}

	// Other root-relative URLs
	if strings.HasPrefix(href, "/") {
		return "https://github.com" + href
	}

	// Relative URLs (e.g., "./demo.gif" or "docs/foo.md")
	clean := strings.TrimPrefix(href, "./")
	return base + clean
}

// stripBadgeBrs removes <br> elements from a <p> that contains only badge links
// (links whose sole child is an <img>). This prevents badges from stacking vertically.
func stripBadgeBrs(p *html.Node) {
	// Check if this paragraph contains only badge links, <br>s, and whitespace text.
	hasBadge := false
	for c := p.FirstChild; c != nil; c = c.NextSibling {
		switch {
		case c.Type == html.ElementNode && c.Data == "a" && isImageOnlyLink(c):
			hasBadge = true
		case c.Type == html.ElementNode && c.Data == "br":
			// ok
		case c.Type == html.TextNode && strings.TrimSpace(c.Data) == "":
			// whitespace text node, ok
		default:
			return
		}
	}

	if !hasBadge {
		return
	}

	// Remove all <br> nodes
	var toRemove []*html.Node
	for c := p.FirstChild; c != nil; c = c.NextSibling {
		if c.Type == html.ElementNode && c.Data == "br" {
			toRemove = append(toRemove, c)
		}
	}
	for _, br := range toRemove {
		p.RemoveChild(br)
	}
}

func isImageOnlyLink(a *html.Node) bool {
	imgCount := 0
	for c := a.FirstChild; c != nil; c = c.NextSibling {
		switch {
		case c.Type == html.ElementNode && c.Data == "img":
			imgCount++
		case c.Type == html.TextNode && strings.TrimSpace(c.Data) == "":
			// whitespace, ok
		default:
			return false
		}
	}
	return imgCount > 0
}

func (s *Service) getThumbnailForRepository(ctx context.Context, owner string, repo string) (string, error) {
	url := fmt.Sprintf("https://github.com/%s/%s", owner, repo)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", fmt.Errorf("creating request: %w", err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("fetching repo page: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("unexpected status: %s", resp.Status)
	}

	tokenizer := html.NewTokenizer(resp.Body)
	for {
		switch tokenizer.Next() {
		case html.ErrorToken:
			if tokenizer.Err() != nil {
				return "", fmt.Errorf("parsing HTML: %w", tokenizer.Err())
			}
			return "", fmt.Errorf("og:image not found")
		case html.StartTagToken, html.SelfClosingTagToken:
			token := tokenizer.Token()
			if token.Data != "meta" {
				continue
			}

			var prop, content string
			for _, attr := range token.Attr {
				switch attr.Key {
				case "property":
					prop = attr.Val
				case "content":
					content = attr.Val
				}
			}

			if prop == "og:image" && content != "" {
				return content, nil
			}
		case html.EndTagToken:
			t := tokenizer.Token()
			if t.Data == "head" {
				return "", fmt.Errorf("og:image not found in <head>")
			}
		}
	}
}

func (s *Service) listRepositoriesForUser(ctx context.Context) ([]*github.Repository, error) {
	repos, _, err := s.client.Repositories.ListByUser(ctx, s.user, &github.RepositoryListByUserOptions{Sort: "pushed", Type: "sources"})
	return repos, err
}

func (s *Service) listLanguagesForRepository(ctx context.Context, owner string, repo string) (map[string]int, error) {
	languages, _, err := s.client.Repositories.ListLanguages(ctx, owner, repo)
	if err != nil {
		return nil, err
	}
	return languages, nil
}
