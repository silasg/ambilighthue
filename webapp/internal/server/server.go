// Package server exposes the REST API and serves the embedded PWA. The REST
// surface is intentionally small and predictable so it is trivial to drive from
// Apple Shortcuts.
package server

import (
	"encoding/json"
	"io/fs"
	"net/http"
	"strings"
	"sync"

	"ambilighthue/webapp/internal/store"
	"ambilighthue/webapp/internal/tv"
)

// TVClient is the subset of the TV protocol the server needs. Defining it as an
// interface lets handler tests inject a fake.
type TVClient interface {
	StartPairing(host string) (tv.PairingInProgress, error)
	ConfirmPairing(p tv.PairingInProgress, pin string) (tv.Credentials, error)
	GetState(c tv.Credentials) (tv.Power, error)
	SetState(c tv.Credentials, p tv.Power) error
}

// Server holds dependencies and in-memory pairing state.
type Server struct {
	tv       TVClient
	store    *store.Store
	apiToken string
	basePath string // normalized; "" for root, otherwise e.g. "/ambilight"

	mu      sync.Mutex
	pairing *tv.PairingInProgress // in-progress pairing, if any

	static fs.FS // optional override for the embedded frontend (used by tests)
}

// New constructs a Server. apiToken may be empty to disable token checks.
func New(client TVClient, st *store.Store, apiToken string) *Server {
	return NewWithBasePath(client, st, apiToken, "")
}

// NewWithBasePath constructs a Server served under a sub-path (for reverse-proxy
// hosting). basePath is normalized: an empty value keeps root behavior, while
// e.g. "ambilight" or "/ambilight/" both become "/ambilight".
func NewWithBasePath(client TVClient, st *store.Store, apiToken, basePath string) *Server {
	return &Server{tv: client, store: st, apiToken: apiToken, basePath: normalizeBasePath(basePath)}
}

// normalizeBasePath ensures a single leading slash and no trailing slash. An
// empty (or "/") input yields "" so the app keeps serving from root unchanged.
func normalizeBasePath(p string) string {
	p = strings.Trim(p, "/")
	if p == "" {
		return ""
	}
	// Collapse any empty internal segments from inputs like "//a//b//".
	parts := strings.Split(p, "/")
	out := parts[:0]
	for _, seg := range parts {
		if seg != "" {
			out = append(out, seg)
		}
	}
	return "/" + strings.Join(out, "/")
}

// Handler returns the configured http.Handler (router + middleware). When a base
// path is set, all routes are mounted under it (e.g. "/ambilight/api/health")
// and requests to the bare base path redirect to its trailing-slash form.
func (s *Server) Handler() http.Handler {
	inner := s.withToken(s.routes())
	if s.basePath == "" {
		return inner
	}

	mux := http.NewServeMux()
	// StripPrefix lets the inner handlers keep using root-relative paths
	// ("/api/...", "/") regardless of where the app is mounted.
	mux.Handle(s.basePath+"/", http.StripPrefix(s.basePath, inner))
	// Redirect the bare prefix ("/ambilight") to its directory form.
	mux.Handle(s.basePath, http.RedirectHandler(s.basePath+"/", http.StatusMovedPermanently))
	return mux
}

// routes builds the inner router with all API and static routes at root-relative
// paths. It is mounted at the base path (if any) by Handler.
func (s *Server) routes() http.Handler {
	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/health", s.handleHealth)
	mux.HandleFunc("GET /api/state", s.handleState)
	mux.HandleFunc("POST /api/power", s.handlePower)
	mux.HandleFunc("POST /api/on", s.handleOn)
	mux.HandleFunc("POST /api/off", s.handleOff)
	mux.HandleFunc("POST /api/pair/start", s.handlePairStart)
	mux.HandleFunc("POST /api/pair/confirm", s.handlePairConfirm)
	mux.HandleFunc("POST /api/pair/reset", s.handlePairReset)

	// Templated static assets: the manifest scope/start_url and the index's
	// injected BASE_PATH depend on where the app is mounted.
	mux.HandleFunc("GET /manifest.webmanifest", s.handleManifest)
	mux.HandleFunc("GET /index.html", s.handleIndex)
	mux.HandleFunc("GET /{$}", s.handleIndex)

	mux.Handle("/", http.FileServerFS(s.frontendFS()))

	return mux
}

// withToken enforces the optional shared-secret API token on /api/* routes
// (health excluded). The token may be supplied via X-API-Token header or
// `token` query param for Shortcuts convenience.
func (s *Server) withToken(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if s.apiToken == "" || r.URL.Path == "/api/health" || !isAPI(r.URL.Path) {
			next.ServeHTTP(w, r)
			return
		}
		got := r.Header.Get("X-API-Token")
		if got == "" {
			got = r.URL.Query().Get("token")
		}
		if got != s.apiToken {
			writeJSON(w, http.StatusUnauthorized, map[string]string{"error": "invalid or missing API token"})
			return
		}
		next.ServeHTTP(w, r)
	})
}

func isAPI(path string) bool {
	return len(path) >= 4 && path[:4] == "/api"
}

func (s *Server) handleHealth(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

func (s *Server) handleState(w http.ResponseWriter, _ *http.Request) {
	creds, ok := s.store.Get()
	if !ok {
		writeJSON(w, http.StatusOK, stateResponse{Power: string(tv.PowerUnknown), Configured: false})
		return
	}
	power, err := s.tv.GetState(creds)
	if err != nil {
		writeJSON(w, http.StatusOK, stateResponse{Power: string(tv.PowerUnknown), Configured: true, Error: err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, stateResponse{Power: string(power), Configured: true})
}

func (s *Server) handlePower(w http.ResponseWriter, r *http.Request) {
	value := r.URL.Query().Get("power")
	if value == "" {
		var body struct {
			Power string `json:"power"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		value = body.Power
	}
	power, err := parsePower(value)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	s.setPower(w, power)
}

func (s *Server) handleOn(w http.ResponseWriter, _ *http.Request)  { s.setPower(w, tv.PowerOn) }
func (s *Server) handleOff(w http.ResponseWriter, _ *http.Request) { s.setPower(w, tv.PowerOff) }

func (s *Server) setPower(w http.ResponseWriter, power tv.Power) {
	creds, ok := s.store.Get()
	if !ok {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "TV not paired; call /api/pair/start first"})
		return
	}
	if err := s.tv.SetState(creds, power); err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, stateResponse{Power: string(power), Configured: true})
}

func (s *Server) handlePairStart(w http.ResponseWriter, r *http.Request) {
	var body struct {
		TVIP string `json:"tvIp"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.TVIP == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "tvIp is required"})
		return
	}
	p, err := s.tv.StartPairing(body.TVIP)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
		return
	}
	s.mu.Lock()
	s.pairing = &p
	s.mu.Unlock()
	writeJSON(w, http.StatusOK, map[string]string{"status": "pairing started; enter the PIN shown on the TV"})
}

func (s *Server) handlePairConfirm(w http.ResponseWriter, r *http.Request) {
	var body struct {
		PIN string `json:"pin"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.PIN == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "pin is required"})
		return
	}
	s.mu.Lock()
	p := s.pairing
	s.mu.Unlock()
	if p == nil {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "no pairing in progress; call /api/pair/start first"})
		return
	}
	creds, err := s.tv.ConfirmPairing(*p, body.PIN)
	if err != nil {
		writeJSON(w, http.StatusBadGateway, map[string]string{"error": err.Error()})
		return
	}
	if err := s.store.Save(creds); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	s.mu.Lock()
	s.pairing = nil
	s.mu.Unlock()
	writeJSON(w, http.StatusOK, map[string]string{"status": "paired successfully"})
}

func (s *Server) handlePairReset(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	s.pairing = nil
	s.mu.Unlock()
	if err := s.store.Clear(); err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "pairing reset"})
}

type stateResponse struct {
	Power      string `json:"power"`
	Configured bool   `json:"configured"`
	Error      string `json:"error,omitempty"`
}

func parsePower(v string) (tv.Power, error) {
	switch v {
	case "on", "On", "ON":
		return tv.PowerOn, nil
	case "off", "Off", "OFF":
		return tv.PowerOff, nil
	default:
		return tv.PowerUnknown, errPower
	}
}

var errPower = &powerError{}

type powerError struct{}

func (*powerError) Error() string { return `power must be "on" or "off"` }

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
