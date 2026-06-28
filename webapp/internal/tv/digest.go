package tv

import (
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"regexp"
	"strings"
)

// challenge holds the fields of a WWW-Authenticate: Digest challenge that we
// need. We support only the minimal subset the Philips JointSpace endpoints
// use: realm, nonce, qop=auth, optional opaque. Algorithm is MD5.
type challenge struct {
	realm  string
	nonce  string
	qop    string
	opaque string
}

var challengeFieldRe = regexp.MustCompile(`(\w+)=(?:"([^"]*)"|([^,]*))`)

// parseChallenge parses a "Digest ..." WWW-Authenticate header value.
func parseChallenge(header string) (challenge, error) {
	header = strings.TrimSpace(header)
	if !strings.HasPrefix(strings.ToLower(header), "digest") {
		return challenge{}, fmt.Errorf("not a Digest challenge: %q", header)
	}
	rest := strings.TrimSpace(header[len("Digest"):])
	var c challenge
	for _, m := range challengeFieldRe.FindAllStringSubmatch(rest, -1) {
		key := strings.ToLower(m[1])
		val := m[2]
		if val == "" {
			val = m[3]
		}
		switch key {
		case "realm":
			c.realm = val
		case "nonce":
			c.nonce = val
		case "qop":
			// qop may be a comma-separated list; we only do "auth".
			if strings.Contains(val, "auth") {
				c.qop = "auth"
			} else {
				c.qop = val
			}
		case "opaque":
			c.opaque = val
		}
	}
	if c.nonce == "" {
		return challenge{}, fmt.Errorf("digest challenge missing nonce: %q", header)
	}
	return c, nil
}

func md5hex(s string) string {
	sum := md5.Sum([]byte(s))
	return hex.EncodeToString(sum[:])
}

// digestResponse computes the RFC 2617 response value for qop=auth, algorithm MD5.
func digestResponse(c challenge, user, pass, method, uri, cnonce, nc string) string {
	ha1 := md5hex(fmt.Sprintf("%s:%s:%s", user, c.realm, pass))
	ha2 := md5hex(fmt.Sprintf("%s:%s", method, uri))
	return md5hex(fmt.Sprintf("%s:%s:%s:%s:%s:%s", ha1, c.nonce, nc, cnonce, c.qop, ha2))
}

// buildAuthorizationHeader builds the Authorization header value to send back.
func buildAuthorizationHeader(c challenge, user, pass, method, uri, cnonce, nc string) string {
	resp := digestResponse(c, user, pass, method, uri, cnonce, nc)
	var b strings.Builder
	fmt.Fprintf(&b, `Digest username="%s", realm="%s", nonce="%s", uri="%s", `, user, c.realm, c.nonce, uri)
	fmt.Fprintf(&b, `qop=%s, nc=%s, cnonce="%s", response="%s", algorithm=MD5`, c.qop, nc, cnonce, resp)
	if c.opaque != "" {
		fmt.Fprintf(&b, `, opaque="%s"`, c.opaque)
	}
	return b.String()
}
