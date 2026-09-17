// Copyright (c) Joseph Hale, 2026
// SPDX-License-Identifier: MPL-2.0

package greeting

import "fmt"

func For(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}
