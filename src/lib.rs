// Copyright (c) Joseph Hale, 2026
// SPDX-License-Identifier: MPL-2.0

pub fn greeting(name: &str) -> String {
	format!("Hello, {name}!")
}

#[cfg(test)]
mod tests {
	use super::*;

	#[test]
	fn greets_by_name() {
		assert_eq!(greeting("Alice"), "Hello, Alice!");
	}
}
