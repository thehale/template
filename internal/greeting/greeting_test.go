// Copyright (c) Joseph Hale, 2026
// SPDX-License-Identifier: MPL-2.0

package greeting_test

import (
	"testing"

	"github.com/thehale/package/internal/greeting"
)

func TestFor(t *testing.T) {
	want := "Hello, Alice!"
	got := greeting.For("Alice")

	if got != want {
		t.Errorf("greeting.For(\"Alice\") = %q, want %q", got, want)
	}
}
