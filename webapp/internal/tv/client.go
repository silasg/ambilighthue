// Package tv implements the minimal Philips JointSpace (Android TV) protocol
// needed to pair with a TV and toggle its ambilight ("HueLamp") power.
//
// It is a direct, dependency-free port of the working Swift app
// (ambilighthue/AmbilightTv.swift et al). All requests go over HTTPS on the
// host given by the caller, with TLS verification DISABLED because the TV
// presents a self-signed certificate. HTTP Digest authentication is
// implemented in digest.go (Go's net/http has no built-in digest client).
package tv

import (
	"bytes"
	"crypto/rand"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"strings"
	"time"
)

// Power is the ambilight power state.
type Power string

const (
	PowerOn      Power = "on"
	PowerOff     Power = "off"
	PowerUnknown Power = "unknown"
)

// Credentials are the persisted result of a successful pairing.
type Credentials struct {
	TVIP     string `json:"tvIp"`
	Username string `json:"username"` // the deviceId
	Password string `json:"password"` // the auth_key
}

// PairingInProgress holds the state between StartPairing and ConfirmPairing.
type PairingInProgress struct {
	TVIP      string `json:"tvIp"`
	DeviceID  string `json:"deviceId"`
	AuthKey   string `json:"authKey"`
	Timestamp int    `json:"timestamp"`
}

// Client talks to a TV. It is safe for concurrent use.
type Client struct {
	http *http.Client
}

// NewClient returns a Client with a TLS config that skips verification
// (required for the TV's self-signed cert).
func NewClient() *Client {
	return &Client{
		http: &http.Client{
			Timeout: 10 * time.Second,
			Transport: &http.Transport{
				TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, //nolint:gosec // TV uses self-signed cert
			},
		},
	}
}

const appName = "AmilightHue"

func deviceBlock(deviceID string) map[string]any {
	return map[string]any{
		"device_name": "heliotrope",
		"device_os":   "Android",
		"app_name":    appName,
		"type":        "native",
		"app_id":      "app.id",
		"id":          deviceID,
	}
}

func createDeviceID() (string, error) {
	const charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
	b := make([]byte, 16)
	for i := range b {
		n, err := rand.Int(rand.Reader, big.NewInt(int64(len(charset))))
		if err != nil {
			return "", err
		}
		b[i] = charset[n.Int64()]
	}
	return string(b), nil
}

// StartPairing performs POST /6/pair/request and returns the pairing state.
func (c *Client) StartPairing(host string) (PairingInProgress, error) {
	deviceID, err := createDeviceID()
	if err != nil {
		return PairingInProgress{}, err
	}
	body := map[string]any{
		"scope":  []string{"read", "write", "control"},
		"device": deviceBlock(deviceID),
	}
	resp, err := c.do(http.MethodPost, host, "/6/pair/request", body, nil)
	if err != nil {
		return PairingInProgress{}, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return PairingInProgress{}, fmt.Errorf("pair/request: status %d: %s", resp.StatusCode, data)
	}
	var pr struct {
		ErrorID   string `json:"error_id"`
		AuthKey   string `json:"auth_key"`
		Timestamp int    `json:"timestamp"`
	}
	if err := json.Unmarshal(data, &pr); err != nil {
		return PairingInProgress{}, fmt.Errorf("pair/request decode: %w", err)
	}
	if pr.ErrorID != "SUCCESS" {
		return PairingInProgress{}, fmt.Errorf("pair/request failed: %s", pr.ErrorID)
	}
	return PairingInProgress{
		TVIP:      host,
		DeviceID:  deviceID,
		AuthKey:   pr.AuthKey,
		Timestamp: pr.Timestamp,
	}, nil
}

// ConfirmPairing performs the digest-authenticated POST /6/pair/grant. On
// success (empty/204 body) it returns the Credentials to persist.
func (c *Client) ConfirmPairing(p PairingInProgress, pin string) (Credentials, error) {
	sig, err := createSignature(pin, p.Timestamp)
	if err != nil {
		return Credentials{}, err
	}
	body := map[string]any{
		"auth": map[string]any{
			"auth_AppId":     "1",
			"pin":            pin,
			"auth_timestamp": p.Timestamp,
			"auth_signature": sig,
		},
		"device": deviceBlock(p.DeviceID),
	}
	creds := Credentials{TVIP: p.TVIP, Username: p.DeviceID, Password: p.AuthKey}
	resp, err := c.doDigest(http.MethodPost, creds, "/6/pair/grant", body)
	if err != nil {
		return Credentials{}, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent && resp.StatusCode != http.StatusResetContent {
		return Credentials{}, fmt.Errorf("pair/grant: status %d: %s", resp.StatusCode, data)
	}
	return creds, nil
}

// GetState performs the digest-authenticated GET /6/HueLamp/power.
func (c *Client) GetState(creds Credentials) (Power, error) {
	resp, err := c.doDigest(http.MethodGet, creds, "/6/HueLamp/power", nil)
	if err != nil {
		return PowerUnknown, err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		return PowerUnknown, fmt.Errorf("HueLamp/power GET: status %d: %s", resp.StatusCode, data)
	}
	var body struct {
		Power string `json:"power"`
	}
	if err := json.Unmarshal(data, &body); err != nil {
		return PowerUnknown, fmt.Errorf("HueLamp/power decode: %w", err)
	}
	switch body.Power {
	case "On":
		return PowerOn, nil
	case "Off":
		return PowerOff, nil
	default:
		return PowerUnknown, nil
	}
}

// SetState performs the digest-authenticated POST /6/HueLamp/power.
func (c *Client) SetState(creds Credentials, p Power) error {
	value := "Off"
	if p == PowerOn {
		value = "On"
	}
	resp, err := c.doDigest(http.MethodPost, creds, "/6/HueLamp/power", map[string]any{"power": value})
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	data, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
		return fmt.Errorf("HueLamp/power POST: status %d: %s", resp.StatusCode, data)
	}
	return nil
}

// baseURL builds the https URL. If host already contains a port (used in tests
// and when a caller pre-formats it) it is used as-is; otherwise :1926 (the
// JointSpace port) is appended.
func baseURL(host string) string {
	host = strings.TrimSpace(host)
	host = strings.TrimPrefix(host, "https://")
	host = strings.TrimSuffix(host, "/")
	if !strings.Contains(host, ":") {
		host += ":1926"
	}
	return "https://" + host
}

func (c *Client) do(method, host, path string, body any, headers map[string]string) (*http.Response, error) {
	var rdr io.Reader
	if body != nil {
		b, err := json.Marshal(body)
		if err != nil {
			return nil, err
		}
		rdr = bytes.NewReader(b)
	}
	req, err := http.NewRequest(method, baseURL(host)+path, rdr)
	if err != nil {
		return nil, err
	}
	if body != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	return c.http.Do(req)
}

// doDigest performs the two-step digest handshake: an initial unauthenticated
// request to obtain the challenge, then a retry with the Authorization header.
func (c *Client) doDigest(method string, creds Credentials, path string, body any) (*http.Response, error) {
	// Marshal once so the body can be replayed on the second request.
	var raw []byte
	if body != nil {
		var err error
		raw, err = json.Marshal(body)
		if err != nil {
			return nil, err
		}
	}

	first, err := c.doRaw(method, creds.TVIP, path, raw, "")
	if err != nil {
		return nil, err
	}
	if first.StatusCode != http.StatusUnauthorized {
		// No auth required (unlikely) — return as-is.
		return first, nil
	}
	wwwAuth := first.Header.Get("WWW-Authenticate")
	io.Copy(io.Discard, first.Body)
	first.Body.Close()

	ch, err := parseChallenge(wwwAuth)
	if err != nil {
		return nil, fmt.Errorf("digest challenge: %w", err)
	}
	cnonce, err := randomHex(8)
	if err != nil {
		return nil, err
	}
	const nc = "00000001"
	authz := buildAuthorizationHeader(ch, creds.Username, creds.Password, method, path, cnonce, nc)
	return c.doRaw(method, creds.TVIP, path, raw, authz)
}

func (c *Client) doRaw(method, host, path string, raw []byte, authz string) (*http.Response, error) {
	var rdr io.Reader
	if raw != nil {
		rdr = bytes.NewReader(raw)
	}
	req, err := http.NewRequest(method, baseURL(host)+path, rdr)
	if err != nil {
		return nil, err
	}
	if raw != nil {
		req.Header.Set("Content-Type", "application/json")
	}
	if authz != "" {
		req.Header.Set("Authorization", authz)
	}
	return c.http.Do(req)
}

func randomHex(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	const hexdigits = "0123456789abcdef"
	out := make([]byte, n*2)
	for i, v := range b {
		out[i*2] = hexdigits[v>>4]
		out[i*2+1] = hexdigits[v&0x0f]
	}
	return string(out), nil
}
