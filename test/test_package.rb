# frozen_string_literal: true

# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

require "test_helper"

class TestPackage < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Package::VERSION
  end

  def test_it_does_something_useful
    assert true
  end
end
