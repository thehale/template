# Copyright (c) 2026 Joseph Hale
# SPDX-License-Identifier: MPL-2.0

import package


def test_greeting():
    assert package.greeting("Alice") == "Hello, Alice!"
