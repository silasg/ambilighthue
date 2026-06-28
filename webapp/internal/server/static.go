package server

import (
	"bytes"
	"encoding/json"
	"io"
	"io/fs"
	"net/http"
	"strings"
	"time"
)

// scopePath is the base path in directory form for use as a PWA scope/start_url.
// Root ("") becomes "/", "/ambilight" becomes "/ambilight/".
func (s *Server) scopePath() string {
	if s.basePath == "" {
		return "/"
	}
	return s.basePath + "/"
}

// handleIndex serves index.html with a small <script> injecting window.BASE_PATH
// so the SPA can build API URLs under the sub-path. The injection is inserted
// just before app.js loads (it relies on a placeholder the embedded file marks).
func (s *Server) handleIndex(w http.ResponseWriter, r *http.Request) {
	data, err := fs.ReadFile(s.frontendFS(), "index.html")
	if err != nil {
		http.Error(w, "index not found", http.StatusNotFound)
		return
	}
	inject := `<script>window.BASE_PATH = ` + jsonString(s.basePath) + `;</script>`
	html := string(data)
	if strings.Contains(html, basePathPlaceholder) {
		html = strings.Replace(html, basePathPlaceholder, inject, 1)
	} else {
		// Fallback (e.g. the test fallback FS): inject before </body> or </head>.
		html = injectBefore(html, inject)
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = io.WriteString(w, html)
}

// handleManifest serves the web app manifest with scope/start_url rewritten to
// reflect the base path so the installed PWA is scoped to the sub-path.
func (s *Server) handleManifest(w http.ResponseWriter, r *http.Request) {
	data, err := fs.ReadFile(s.frontendFS(), "manifest.webmanifest")
	if err != nil {
		http.Error(w, "manifest not found", http.StatusNotFound)
		return
	}
	var m map[string]any
	if err := json.Unmarshal(data, &m); err != nil {
		http.Error(w, "manifest invalid", http.StatusInternalServerError)
		return
	}
	m["scope"] = s.scopePath()
	m["start_url"] = s.scopePath()
	out, err := json.Marshal(m)
	if err != nil {
		http.Error(w, "manifest encode", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/manifest+json")
	_, _ = w.Write(out)
}

// basePathPlaceholder is the marker in index.html where the BASE_PATH script is
// injected. Keeping it explicit avoids brittle string matching on real markup.
const basePathPlaceholder = "<!--BASE_PATH-->"

func injectBefore(html, inject string) string {
	for _, marker := range []string{"</body>", "</head>"} {
		if i := strings.Index(html, marker); i >= 0 {
			return html[:i] + inject + html[i:]
		}
	}
	return inject + html
}

func jsonString(v string) string {
	b, _ := json.Marshal(v)
	return string(b)
}

// staticFS is the embedded PWA filesystem, set once at startup via SetStaticFS
// from the main package (which owns the //go:embed directive). Tests that don't
// set it get a tiny built-in fallback so handler tests stay self-contained.
var staticFS fs.FS

// SetStaticFS registers the embedded frontend filesystem.
func SetStaticFS(f fs.FS) { staticFS = f }

func (s *Server) frontendFS() fs.FS {
	if s.static != nil {
		return s.static
	}
	if staticFS != nil {
		return staticFS
	}
	return fallbackFS{}
}

// fallbackFS is a tiny read-only FS serving a single index.html. It exists only
// so the server is usable (and testable) without an embedded frontend.
type fallbackFS struct{}

var fallbackIndex = []byte("<!DOCTYPE html><html><body>ambilighthue</body></html>")

func (fallbackFS) Open(name string) (fs.File, error) {
	switch name {
	case ".":
		return &memDir{}, nil
	case "index.html":
		return &memFile{Reader: bytes.NewReader(fallbackIndex), name: "index.html", size: int64(len(fallbackIndex))}, nil
	default:
		return nil, &fs.PathError{Op: "open", Path: name, Err: fs.ErrNotExist}
	}
}

type memFile struct {
	*bytes.Reader
	name string
	size int64
}

func (f *memFile) Stat() (fs.FileInfo, error) { return memInfo{name: f.name, size: f.size}, nil }
func (f *memFile) Close() error               { return nil }

type memDir struct{}

func (memDir) Stat() (fs.FileInfo, error) { return memInfo{name: ".", dir: true}, nil }
func (memDir) Read([]byte) (int, error)   { return 0, io.EOF }
func (memDir) Close() error               { return nil }
func (memDir) ReadDir(int) ([]fs.DirEntry, error) {
	return []fs.DirEntry{memEntry{}}, nil
}

type memEntry struct{}

func (memEntry) Name() string               { return "index.html" }
func (memEntry) IsDir() bool                { return false }
func (memEntry) Type() fs.FileMode          { return 0 }
func (memEntry) Info() (fs.FileInfo, error) { return memInfo{name: "index.html"}, nil }

type memInfo struct {
	name string
	size int64
	dir  bool
}

func (i memInfo) Name() string { return i.name }
func (i memInfo) Size() int64  { return i.size }
func (i memInfo) Mode() fs.FileMode {
	if i.dir {
		return fs.ModeDir | 0o555
	}
	return 0o444
}
func (i memInfo) ModTime() time.Time { return time.Time{} }
func (i memInfo) IsDir() bool        { return i.dir }
func (i memInfo) Sys() any           { return nil }
