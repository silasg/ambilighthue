package store

import (
	"path/filepath"
	"testing"

	"ambilighthue/webapp/internal/tv"
)

func TestLoad_MissingFileReturnsNotConfigured(t *testing.T) {
	s := New(filepath.Join(t.TempDir(), "config.json"))
	creds, ok := s.Get()
	if ok {
		t.Fatalf("expected not configured, got %+v", creds)
	}
}

func TestSaveThenLoad_RoundTrips(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	s := New(path)
	want := tv.Credentials{TVIP: "192.168.0.5", Username: "dev123", Password: "key456"}
	if err := s.Save(want); err != nil {
		t.Fatalf("Save: %v", err)
	}
	// Fresh store reading the same file should see the creds (survives restart).
	s2 := New(path)
	got, ok := s2.Get()
	if !ok {
		t.Fatal("expected configured")
	}
	if got != want {
		t.Fatalf("got %+v, want %+v", got, want)
	}
}

func TestClear_RemovesCredentials(t *testing.T) {
	path := filepath.Join(t.TempDir(), "config.json")
	s := New(path)
	s.Save(tv.Credentials{TVIP: "x", Username: "y", Password: "z"})
	if err := s.Clear(); err != nil {
		t.Fatalf("Clear: %v", err)
	}
	if _, ok := s.Get(); ok {
		t.Fatal("expected not configured after Clear")
	}
	s2 := New(path)
	if _, ok := s2.Get(); ok {
		t.Fatal("expected not configured after Clear (fresh store)")
	}
}
