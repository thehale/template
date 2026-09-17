// Copyright (c) Joseph Hale, 2026
// SPDX-License-Identifier: MPL-2.0

package main

import (
	"fmt"

	"github.com/thehale/package/internal/greeting"
)

func main() {
	fmt.Println(greeting.For("World"))
}
