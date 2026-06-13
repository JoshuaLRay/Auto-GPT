// Package util holds small cross-cutting helpers.
package util

import (
	"crypto/rand"
	"encoding/hex"
)

// NewID returns a random 128-bit identifier as a hex string. Used for entity IDs.
func NewID() string { return randHex(16) }

// NewToken returns a random 256-bit unguessable token as a hex string. Used for
// session capability URLs.
func NewToken() string { return randHex(32) }

func randHex(n int) string {
	buf := make([]byte, n)
	if _, err := rand.Read(buf); err != nil {
		// crypto/rand failing is unrecoverable; panic surfaces it immediately.
		panic("util: cannot read random bytes: " + err.Error())
	}
	return hex.EncodeToString(buf)
}
