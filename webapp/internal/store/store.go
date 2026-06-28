// Package store persists TV credentials to a JSON file so pairing survives
// container restarts (the homelab mounts a volume at CONFIG_PATH).
package store

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sync"

	"ambilighthue/webapp/internal/tv"
)

// Store is a thread-safe, file-backed credentials store.
type Store struct {
	path string
	mu   sync.RWMutex
}

// New returns a Store backed by the given file path. The file need not exist.
func New(path string) *Store {
	return &Store{path: path}
}

// Get returns the stored credentials, or ok=false if none are configured.
func (s *Store) Get() (tv.Credentials, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	data, err := os.ReadFile(s.path)
	if err != nil {
		return tv.Credentials{}, false
	}
	var c tv.Credentials
	if err := json.Unmarshal(data, &c); err != nil {
		return tv.Credentials{}, false
	}
	if c.TVIP == "" || c.Username == "" || c.Password == "" {
		return tv.Credentials{}, false
	}
	return c, true
}

// Save atomically writes the credentials to disk.
func (s *Store) Save(c tv.Credentials) error {
	s.mu.Lock()
	defer s.mu.Unlock()
	if dir := filepath.Dir(s.path); dir != "" {
		if err := os.MkdirAll(dir, 0o755); err != nil {
			return err
		}
	}
	data, err := json.MarshalIndent(c, "", "  ")
	if err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}

// Clear removes the stored credentials.
func (s *Store) Clear() error {
	s.mu.Lock()
	defer s.mu.Unlock()
	err := os.Remove(s.path)
	if err != nil && !errors.Is(err, fs.ErrNotExist) {
		return err
	}
	return nil
}
