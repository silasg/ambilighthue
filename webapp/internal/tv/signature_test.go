package tv

import "testing"

// Known vector derived from the Swift app logic in AmbilightTvPairingInProgress.swift:
//   toSign = pin + timestamp
//   key    = base64decode("oEC9Uhg5xbg566mpYPjhoWUwFtFAwTFoTW1By0vaOD4=")
//   result = base64(HMAC-SHA1(key, toSign))
func TestCreateSignature_KnownVector(t *testing.T) {
	got, err := createSignature("1234", 55285)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := "bXdZt4HCmVLFSOs1su26z1NUkS4="
	if got != want {
		t.Fatalf("signature mismatch\n got: %q\nwant: %q", got, want)
	}
}

func TestCreateSignature_OrderIsPinThenTimestamp(t *testing.T) {
	// Sanity: swapping order must produce a different signature, proving we
	// sign pin+timestamp (Swift) and NOT timestamp+pin (pylips).
	a, _ := createSignature("1234", 55285)
	b, _ := createSignatureRaw("552851234")
	if a == b {
		t.Fatal("pin+timestamp and timestamp+pin produced same signature")
	}
}
