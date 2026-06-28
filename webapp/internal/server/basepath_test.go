package server

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"testing/fstest"

	"ambilighthue/webapp/internal/store"
	"ambilighthue/webapp/internal/tv"
)

// testFrontend is a minimal in-memory frontend with the templated assets the
// base-path handlers read (index + manifest + sw).
var testFrontend = fstest.MapFS{
	"index.html":           {Data: []byte("<!DOCTYPE html><html><body>app<!--BASE_PATH--></body></html>")},
	"manifest.webmanifest": {Data: []byte(`{"name":"Ambilight","start_url":".","scope":"."}`)},
	"sw.js":                {Data: []byte("// sw")},
	"app.js":               {Data: []byte("// app")},
}

func TestNormalizeBasePath(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"", ""},
		{"/", ""},
		{"ambilight", "/ambilight"},
		{"/ambilight", "/ambilight"},
		{"/ambilight/", "/ambilight"},
		{"ambilight/", "/ambilight"},
		{"//ambilight//", "/ambilight"},
		{"/a/b/", "/a/b"},
	}
	for _, c := range cases {
		if got := normalizeBasePath(c.in); got != c.want {
			t.Errorf("normalizeBasePath(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func newTestServerWithBase(t *testing.T, base string) *Server {
	t.Helper()
	st := store.New(filepath.Join(t.TempDir(), "config.json"))
	s := NewWithBasePath(&fakeTV{state: tv.PowerOn}, st, "", base)
	s.static = testFrontend
	return s
}

func TestRouting_WithBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "/ambilight")

	// Health under base path.
	w := do(t, s, http.MethodGet, "/ambilight/api/health", "")
	if w.Code != http.StatusOK {
		t.Fatalf("health under base: status %d", w.Code)
	}

	// An API route under base path.
	w = do(t, s, http.MethodGet, "/ambilight/api/state", "")
	if w.Code != http.StatusOK {
		t.Fatalf("state under base: status %d body %s", w.Code, w.Body)
	}

	// Index served under base path.
	w = do(t, s, http.MethodGet, "/ambilight/", "")
	if w.Code != http.StatusOK {
		t.Fatalf("index under base: status %d", w.Code)
	}
	if !strings.Contains(w.Body.String(), "<html") && !strings.Contains(w.Body.String(), "<!DOCTYPE") {
		t.Errorf("index not served under base, body: %s", w.Body.String())
	}

	// Paths WITHOUT the base prefix must not resolve.
	w = do(t, s, http.MethodGet, "/api/health", "")
	if w.Code == http.StatusOK {
		t.Errorf("/api/health should not be served when base path is set, got %d", w.Code)
	}
}

func TestRouting_WithoutBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "")

	w := do(t, s, http.MethodGet, "/api/health", "")
	if w.Code != http.StatusOK {
		t.Fatalf("health: status %d", w.Code)
	}
	w = do(t, s, http.MethodGet, "/api/state", "")
	if w.Code != http.StatusOK {
		t.Fatalf("state: status %d", w.Code)
	}
	w = do(t, s, http.MethodGet, "/", "")
	if w.Code != http.StatusOK {
		t.Fatalf("index: status %d", w.Code)
	}
}

func TestIndexInjectsBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "/ambilight")
	w := do(t, s, http.MethodGet, "/ambilight/", "")
	body := w.Body.String()
	if !strings.Contains(body, `window.BASE_PATH = "/ambilight"`) {
		t.Errorf("index does not inject base path, body: %s", body)
	}

	// Empty base path injects empty string and still serves.
	s2 := newTestServerWithBase(t, "")
	w2 := do(t, s2, http.MethodGet, "/", "")
	if !strings.Contains(w2.Body.String(), `window.BASE_PATH = ""`) {
		t.Errorf("index does not inject empty base path, body: %s", w2.Body.String())
	}
}

func TestManifestScopeReflectsBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "/ambilight")
	w := do(t, s, http.MethodGet, "/ambilight/manifest.webmanifest", "")
	if w.Code != http.StatusOK {
		t.Fatalf("manifest: status %d", w.Code)
	}
	if ct := w.Header().Get("Content-Type"); ct != "application/manifest+json" {
		t.Errorf("manifest content-type = %q, want application/manifest+json", ct)
	}
	var m map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &m); err != nil {
		t.Fatalf("manifest not valid JSON: %v\n%s", err, w.Body)
	}
	if m["scope"] != "/ambilight/" {
		t.Errorf("scope = %v, want /ambilight/", m["scope"])
	}
	if m["start_url"] != "/ambilight/" {
		t.Errorf("start_url = %v, want /ambilight/", m["start_url"])
	}
}

func TestManifestScopeRootWhenNoBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "")
	w := do(t, s, http.MethodGet, "/manifest.webmanifest", "")
	if w.Code != http.StatusOK {
		t.Fatalf("manifest: status %d", w.Code)
	}
	var m map[string]any
	if err := json.Unmarshal(w.Body.Bytes(), &m); err != nil {
		t.Fatalf("manifest not valid JSON: %v\n%s", err, w.Body)
	}
	if m["scope"] != "/" {
		t.Errorf("scope = %v, want /", m["scope"])
	}
	if m["start_url"] != "/" {
		t.Errorf("start_url = %v, want /", m["start_url"])
	}
}

func TestServiceWorkerServedUnderBasePath(t *testing.T) {
	s := newTestServerWithBase(t, "/ambilight")
	w := do(t, s, http.MethodGet, "/ambilight/sw.js", "")
	if w.Code != http.StatusOK {
		t.Fatalf("sw.js under base: status %d", w.Code)
	}

	s2 := newTestServerWithBase(t, "")
	w2 := do(t, s2, http.MethodGet, "/sw.js", "")
	if w2.Code != http.StatusOK {
		t.Fatalf("sw.js at root: status %d", w2.Code)
	}
}

// withForwardedPrefix uses Caddy's header. Routing is still driven by env base
// path; this only verifies the server tolerates the header without breaking.
func TestForwardedPrefixHeaderTolerated(t *testing.T) {
	s := newTestServerWithBase(t, "/ambilight")
	r := httptest.NewRequest(http.MethodGet, "/ambilight/api/health", nil)
	r.Header.Set("X-Forwarded-Prefix", "/ambilight")
	w := httptest.NewRecorder()
	s.Handler().ServeHTTP(w, r)
	if w.Code != http.StatusOK {
		t.Fatalf("health with forwarded-prefix: status %d", w.Code)
	}
}
