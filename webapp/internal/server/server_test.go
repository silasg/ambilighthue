package server

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"

	"ambilighthue/webapp/internal/store"
	"ambilighthue/webapp/internal/tv"
)

// fakeTV implements TVClient for handler tests.
type fakeTV struct {
	state       tv.Power
	stateErr    error
	setErr      error
	pairing     tv.PairingInProgress
	startErr    error
	confirmErr  error
	confirmCred tv.Credentials
	lastSet     tv.Power
	lastConfirm string
}

func (f *fakeTV) StartPairing(host string) (tv.PairingInProgress, error) {
	if f.startErr != nil {
		return tv.PairingInProgress{}, f.startErr
	}
	f.pairing.TVIP = host
	return f.pairing, nil
}
func (f *fakeTV) ConfirmPairing(p tv.PairingInProgress, pin string) (tv.Credentials, error) {
	f.lastConfirm = pin
	if f.confirmErr != nil {
		return tv.Credentials{}, f.confirmErr
	}
	return f.confirmCred, nil
}
func (f *fakeTV) GetState(c tv.Credentials) (tv.Power, error) { return f.state, f.stateErr }
func (f *fakeTV) SetState(c tv.Credentials, p tv.Power) error {
	f.lastSet = p
	if f.setErr != nil {
		return f.setErr
	}
	f.state = p
	return nil
}

func newTestServer(t *testing.T, f *fakeTV, configured bool) (*Server, *store.Store) {
	t.Helper()
	st := store.New(filepath.Join(t.TempDir(), "config.json"))
	if configured {
		st.Save(tv.Credentials{TVIP: "1.2.3.4", Username: "u", Password: "p"})
	}
	return New(f, st, ""), st
}

func do(t *testing.T, s *Server, method, path, body string) *httptest.ResponseRecorder {
	t.Helper()
	var r *http.Request
	if body != "" {
		r = httptest.NewRequest(method, path, strings.NewReader(body))
		r.Header.Set("Content-Type", "application/json")
	} else {
		r = httptest.NewRequest(method, path, nil)
	}
	w := httptest.NewRecorder()
	s.Handler().ServeHTTP(w, r)
	return w
}

func TestHealth(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodGet, "/api/health", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
}

func TestState_NotConfigured(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodGet, "/api/state", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
	var resp map[string]any
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["configured"] != false {
		t.Errorf("configured = %v, want false", resp["configured"])
	}
	if resp["power"] != "unknown" {
		t.Errorf("power = %v, want unknown", resp["power"])
	}
}

func TestState_Configured(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{state: tv.PowerOn}, true)
	w := do(t, s, http.MethodGet, "/api/state", "")
	var resp map[string]any
	json.Unmarshal(w.Body.Bytes(), &resp)
	if resp["configured"] != true {
		t.Errorf("configured = %v, want true", resp["configured"])
	}
	if resp["power"] != "on" {
		t.Errorf("power = %v, want on", resp["power"])
	}
}

func TestPowerOn_Convenience(t *testing.T) {
	f := &fakeTV{}
	s, _ := newTestServer(t, f, true)
	w := do(t, s, http.MethodPost, "/api/on", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d body %s", w.Code, w.Body)
	}
	if f.lastSet != tv.PowerOn {
		t.Errorf("lastSet = %q, want on", f.lastSet)
	}
}

func TestPowerOff_Convenience(t *testing.T) {
	f := &fakeTV{}
	s, _ := newTestServer(t, f, true)
	do(t, s, http.MethodPost, "/api/off", "")
	if f.lastSet != tv.PowerOff {
		t.Errorf("lastSet = %q, want off", f.lastSet)
	}
}

func TestPower_JSONBody(t *testing.T) {
	f := &fakeTV{}
	s, _ := newTestServer(t, f, true)
	w := do(t, s, http.MethodPost, "/api/power", `{"power":"on"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("status %d body %s", w.Code, w.Body)
	}
	if f.lastSet != tv.PowerOn {
		t.Errorf("lastSet = %q, want on", f.lastSet)
	}
}

func TestPower_QueryParam(t *testing.T) {
	f := &fakeTV{}
	s, _ := newTestServer(t, f, true)
	w := do(t, s, http.MethodPost, "/api/power?power=off", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d body %s", w.Code, w.Body)
	}
	if f.lastSet != tv.PowerOff {
		t.Errorf("lastSet = %q, want off", f.lastSet)
	}
}

func TestPower_NotConfigured(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodPost, "/api/on", "")
	if w.Code != http.StatusConflict {
		t.Fatalf("status %d, want 409", w.Code)
	}
}

func TestPower_InvalidValue(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, true)
	w := do(t, s, http.MethodPost, "/api/power", `{"power":"banana"}`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", w.Code)
	}
}

func TestPairFlow_StartConfirmPersists(t *testing.T) {
	f := &fakeTV{
		pairing:     tv.PairingInProgress{DeviceID: "dev", AuthKey: "key", Timestamp: 1},
		confirmCred: tv.Credentials{TVIP: "9.9.9.9", Username: "dev", Password: "key"},
	}
	s, st := newTestServer(t, f, false)

	w := do(t, s, http.MethodPost, "/api/pair/start", `{"tvIp":"9.9.9.9"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("start status %d body %s", w.Code, w.Body)
	}

	w = do(t, s, http.MethodPost, "/api/pair/confirm", `{"pin":"4321"}`)
	if w.Code != http.StatusOK {
		t.Fatalf("confirm status %d body %s", w.Code, w.Body)
	}
	if f.lastConfirm != "4321" {
		t.Errorf("pin = %q, want 4321", f.lastConfirm)
	}
	if _, ok := st.Get(); !ok {
		t.Fatal("credentials not persisted after confirm")
	}
}

func TestPairConfirm_WithoutStart(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodPost, "/api/pair/confirm", `{"pin":"1"}`)
	if w.Code != http.StatusConflict {
		t.Fatalf("status %d, want 409", w.Code)
	}
}

func TestPairStart_MissingIP(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodPost, "/api/pair/start", `{}`)
	if w.Code != http.StatusBadRequest {
		t.Fatalf("status %d, want 400", w.Code)
	}
}

func TestPairReset_ClearsCreds(t *testing.T) {
	s, st := newTestServer(t, &fakeTV{}, true)
	w := do(t, s, http.MethodPost, "/api/pair/reset", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d", w.Code)
	}
	if _, ok := st.Get(); ok {
		t.Fatal("creds not cleared")
	}
}

func TestPairStart_TVError(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{startErr: errors.New("boom")}, false)
	w := do(t, s, http.MethodPost, "/api/pair/start", `{"tvIp":"1.1.1.1"}`)
	if w.Code != http.StatusBadGateway {
		t.Fatalf("status %d, want 502", w.Code)
	}
}

func TestAPIToken_RequiredWhenSet(t *testing.T) {
	st := store.New(filepath.Join(t.TempDir(), "c.json"))
	s := New(&fakeTV{}, st, "sekret")

	// Missing token -> 401
	w := do(t, s, http.MethodGet, "/api/state", "")
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("status %d, want 401", w.Code)
	}

	// Correct token -> ok
	r := httptest.NewRequest(http.MethodGet, "/api/state", nil)
	r.Header.Set("X-API-Token", "sekret")
	rec := httptest.NewRecorder()
	s.Handler().ServeHTTP(rec, r)
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d with token, want 200", rec.Code)
	}

	// Health is exempt from token.
	w = do(t, s, http.MethodGet, "/api/health", "")
	if w.Code != http.StatusOK {
		t.Fatalf("health status %d, want 200", w.Code)
	}
}

func TestStaticIndexServed(t *testing.T) {
	s, _ := newTestServer(t, &fakeTV{}, false)
	w := do(t, s, http.MethodGet, "/", "")
	if w.Code != http.StatusOK {
		t.Fatalf("status %d for /", w.Code)
	}
	if !strings.Contains(w.Body.String(), "<html") && !strings.Contains(w.Body.String(), "<!DOCTYPE") {
		t.Errorf("index.html not served, body: %s", w.Body.String()[:min(80, len(w.Body.String()))])
	}
}
