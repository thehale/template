// Copyright (c) 2026 Joseph Hale
// SPDX-License-Identifier: MPL-2.0

package greeting

import "fmt"

func For(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
