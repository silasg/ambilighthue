package tv

import (
	"strings"
	"testing"
)

func TestParseChallenge(t *testing.T) {
	header := `Digest realm="r", nonce="abc", qop="auth", opaque="xyz"`
	c, err := parseChallenge(header)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.realm != "r" {
		t.Errorf("realm = %q, want r", c.realm)
	}
	if c.nonce != "abc" {
		t.Errorf("nonce = %q, want abc", c.nonce)
	}
	if c.qop != "auth" {
		t.Errorf("qop = %q, want auth", c.qop)
	}
	if c.opaque != "xyz" {
		t.Errorf("opaque = %q, want xyz", c.opaque)
	}
}

func TestParseChallenge_RejectsNonDigest(t *testing.T) {
	if _, err := parseChallenge(`Basic realm="r"`); err == nil {
		t.Fatal("expected error for non-Digest challenge")
	}
}

// Known vector computed with Python's hashlib (RFC 2617, qop=auth).
func TestDigestResponseValue(t *testing.T) {
	c := challenge{realm: "r", nonce: "abc", qop: "auth"}
	got := digestResponse(c, "dev", "pw", "POST", "/6/pair/grant", "deadbeef", "00000001")
	want := "c928b389832b557089272cd55d6251ef"
	if got != want {
		t.Fatalf("response = %q, want %q", got, want)
	}
}

func TestBuildAuthorizationHeader(t *testing.T) {
	c := challenge{realm: "r", nonce: "abc", qop: "auth", opaque: "xyz"}
	h := buildAuthorizationHeader(c, "dev", "pw", "POST", "/6/pair/grant", "deadbeef", "00000001")
	for _, want := range []string{
		`Digest `,
		`username="dev"`,
		`realm="r"`,
		`nonce="abc"`,
		`uri="/6/pair/grant"`,
		`qop=auth`,
		`nc=00000001`,
		`cnonce="deadbeef"`,
		`response="c928b389832b557089272cd55d6251ef"`,
		`opaque="xyz"`,
	} {
		if !strings.Contains(h, want) {
			t.Errorf("header missing %q\nfull header: %s", want, h)
		}
	}
}
