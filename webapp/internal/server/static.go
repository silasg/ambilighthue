package server

import (
	"bytes"
	"io"
	"io/fs"
	"time"
)

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

func (memDir) Stat() (fs.FileInfo, error)     { return memInfo{name: ".", dir: true}, nil }
func (memDir) Read([]byte) (int, error)       { return 0, io.EOF }
func (memDir) Close() error                   { return nil }
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
