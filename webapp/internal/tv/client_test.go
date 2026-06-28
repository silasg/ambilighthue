package tv

import (
	"crypto/md5"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"regexp"
	"strings"
	"testing"
)

// fakeTV is an httptest TLS server that emulates the Philips JointSpace
// endpoints we care about, including a minimal Digest-auth handshake.
type fakeTV struct {
	server   *httptest.Server
	host     string // host:port the client should talk to
	user     string // expected digest user (deviceId)
	pass     string // expected digest pass (auth_key)
	power    string // current power state returned by GET /HueLamp/power
	authKey  string // auth_key returned by /pair/request
	grantHit bool
	lastSig  string
}

const fakeRealm = "XTV"

func newFakeTV(t *testing.T) *fakeTV {
	t.Helper()
	f := &fakeTV{power: "Off", authKey: "secretauthkey"}
	mux := http.NewServeMux()

	mux.HandleFunc("/6/pair/request", func(w http.ResponseWriter, r *http.Request) {
		resp := map[string]any{
			"error_id":  "SUCCESS",
			"auth_key":  f.authKey,
			"timestamp": 55285,
		}
		json.NewEncoder(w).Encode(resp)
	})

	// Endpoints below require digest auth.
	digest := func(next func(http.ResponseWriter, *http.Request)) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			auth := r.Header.Get("Authorization")
			if auth == "" {
				w.Header().Set("WWW-Authenticate", fmt.Sprintf(`Digest realm="%s", nonce="testnonce", qop="auth"`, fakeRealm))
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			if !f.verifyDigest(r) {
				w.WriteHeader(http.StatusUnauthorized)
				return
			}
			next(w, r)
		}
	}

	mux.HandleFunc("/6/pair/grant", digest(func(w http.ResponseWriter, r *http.Request) {
		f.grantHit = true
		var body struct {
			Auth struct {
				Signature string `json:"auth_signature"`
			} `json:"auth"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		f.lastSig = body.Auth.Signature
		w.WriteHeader(http.StatusOK) // empty body = success
	}))

	mux.HandleFunc("/6/HueLamp/power", digest(func(w http.ResponseWriter, r *http.Request) {
		if r.Method == http.MethodGet {
			fmt.Fprintf(w, `{"power":"%s"}`, f.power)
			return
		}
		var body struct {
			Power string `json:"power"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		f.power = body.Power
		w.WriteHeader(http.StatusOK)
	}))

	f.server = httptest.NewTLSServer(mux)
	u, _ := url.Parse(f.server.URL)
	f.host = u.Host
	t.Cleanup(f.server.Close)
	return f
}

var reField = regexp.MustCompile(`(\w+)="?([^",]*)"?`)

func (f *fakeTV) verifyDigest(r *http.Request) bool {
	hdr := r.Header.Get("Authorization")
	fields := map[string]string{}
	for _, m := range reField.FindAllStringSubmatch(strings.TrimPrefix(hdr, "Digest "), -1) {
		fields[m[1]] = m[2]
	}
	h := func(s string) string { sum := md5.Sum([]byte(s)); return hex.EncodeToString(sum[:]) }
	ha1 := h(fmt.Sprintf("%s:%s:%s", f.user, fakeRealm, f.pass))
	ha2 := h(fmt.Sprintf("%s:%s", r.Method, fields["uri"]))
	want := h(fmt.Sprintf("%s:%s:%s:%s:%s:%s", ha1, fields["nonce"], fields["nc"], fields["cnonce"], fields["qop"], ha2))
	return want == fields["response"]
}

func TestStartPairing_SetsCredentialsFromResponse(t *testing.T) {
	f := newFakeTV(t)
	c := NewClient()
	p, err := c.StartPairing(f.host)
	if err != nil {
		t.Fatalf("StartPairing: %v", err)
	}
	if p.AuthKey != f.authKey {
		t.Errorf("authKey = %q, want %q", p.AuthKey, f.authKey)
	}
	if p.Timestamp != 55285 {
		t.Errorf("timestamp = %d, want 55285", p.Timestamp)
	}
	if len(p.DeviceID) != 16 {
		t.Errorf("deviceId length = %d, want 16", len(p.DeviceID))
	}
}

func TestConfirmPairing_SendsCorrectSignatureAndPersists(t *testing.T) {
	f := newFakeTV(t)
	c := NewClient()
	p, err := c.StartPairing(f.host)
	if err != nil {
		t.Fatalf("StartPairing: %v", err)
	}
	// fake TV must accept the digest creds the client will use.
	f.user, f.pass = p.DeviceID, p.AuthKey

	creds, err := c.ConfirmPairing(p, "1234")
	if err != nil {
		t.Fatalf("ConfirmPairing: %v", err)
	}
	if !f.grantHit {
		t.Fatal("grant endpoint not hit")
	}
	wantSig, _ := createSignature("1234", p.Timestamp)
	if f.lastSig != wantSig {
		t.Errorf("signature = %q, want %q", f.lastSig, wantSig)
	}
	if creds.TVIP != f.host || creds.Username != p.DeviceID || creds.Password != p.AuthKey {
		t.Errorf("unexpected creds: %+v", creds)
	}
}

func TestGetState_ParsesPower(t *testing.T) {
	f := newFakeTV(t)
	f.user, f.pass, f.power = "dev", "key", "On"
	c := NewClient()
	creds := Credentials{TVIP: f.host, Username: "dev", Password: "key"}
	state, err := c.GetState(creds)
	if err != nil {
		t.Fatalf("GetState: %v", err)
	}
	if state != PowerOn {
		t.Errorf("state = %q, want on", state)
	}
}

func TestSetState_PersistsOnTV(t *testing.T) {
	f := newFakeTV(t)
	f.user, f.pass = "dev", "key"
	c := NewClient()
	creds := Credentials{TVIP: f.host, Username: "dev", Password: "key"}
	if err := c.SetState(creds, PowerOn); err != nil {
		t.Fatalf("SetState: %v", err)
	}
	if f.power != "On" {
		t.Errorf("tv power = %q, want On", f.power)
	}
	state, _ := c.GetState(creds)
	if state != PowerOn {
		t.Errorf("state after set = %q, want on", state)
	}
}

func TestGetState_BadCredentialsErrors(t *testing.T) {
	f := newFakeTV(t)
	f.user, f.pass = "dev", "key"
	c := NewClient()
	creds := Credentials{TVIP: f.host, Username: "dev", Password: "wrong"}
	if _, err := c.GetState(creds); err == nil {
		t.Fatal("expected error for bad credentials")
	}
}

func TestDeviceIDIsAlphanumeric(t *testing.T) {
	id, err := createDeviceID()
	if err != nil {
		t.Fatal(err)
	}
	if len(id) != 16 {
		t.Fatalf("length %d", len(id))
	}
	for _, r := range id {
		if !((r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9')) {
			t.Fatalf("non-alphanumeric char %q in %q", r, id)
		}
	}
}

// ensure the test file's imports are all used
var _ = io.Discard
var _ = net.IPv4zero
