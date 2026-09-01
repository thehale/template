#!/usr/bin/env bash
# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0
#
# Usage: bin/bashlike.sh

set -euo pipefail

EXCLUDED_DIRECTORIES=(
	vendor
)

main() {
	list_repo_files | select_bash_files | omit_excluded_paths
}

list_repo_files() {
	comm -23 <(list_nonignored_files) <(list_deleted_files)
}

list_nonignored_files() {
	git ls-files --cached --others --exclude-standard | sort -u
}

list_deleted_files() {
	git ls-files --deleted | sort -u
}

select_bash_files() {
	local files
	files="$(cat)"

	{
		printf '%s\n' "$files" | select_by_extension
		printf '%s\n' "$files" | select_by_shebang
	} | sort -u
}

select_by_extension() {
	sed --regexp-extended --quiet '/\.(sh|bash)$/ p'
}

select_by_shebang() {
	xargs --no-run-if-empty sed --separate --quiet '1 { /^#!.*[ /]bash$/ F }'
}

omit_excluded_paths() {
	local pattern
	pattern="$(printf '(^|/)%s/|' "${EXCLUDED_DIRECTORIES[@]}")"
	sed --regexp-extended "\%${pattern%|}%d"
}

main "$@"
