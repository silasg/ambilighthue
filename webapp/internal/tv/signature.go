package tv

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/base64"
	"fmt"
)

// secretKey is the exact HMAC key from the working Swift app
// (AmbilightTvPairingInProgress.swift). It is base64-encoded here and decoded
// before use. NOTE: this deliberately differs from pylips' secret key — this is
// the one proven to work against the user's TV.
const secretKey = "oEC9Uhg5xbg566mpYPjhoWUwFtFAwTFoTW1By0vaOD4="

// createSignature reproduces AmbilightTvPairingInProgress.createSignature:
// base64( HMAC-SHA1( key, utf8(pin + timestamp) ) ).
func createSignature(pin string, timestamp int) (string, error) {
	return createSignatureRaw(fmt.Sprintf("%s%d", pin, timestamp))
}

func createSignatureRaw(toSign string) (string, error) {
	key, err := base64.StdEncoding.DecodeString(secretKey)
	if err != nil {
		return "", fmt.Errorf("decode secret key: %w", err)
	}
	mac := hmac.New(sha1.New, key)
	mac.Write([]byte(toSign))
	return base64.StdEncoding.EncodeToString(mac.Sum(nil)), nil
}
