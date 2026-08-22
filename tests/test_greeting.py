# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

import package


def test_greeting():
    assert package.greeting("Alice") == "Hello, Alice!"
