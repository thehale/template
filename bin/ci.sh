#!/usr/bin/env bash
# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

set -euo pipefail

results=""

function main() {
	if [[ "${1:-}" == "--fix" ]]; then
		check "Bash: Shebang" "bin/bashlike.sh | bin/shebang.sh --fix '#!/usr/bin/env bash'"
		check "Bash: Format" "bin/bashlike.sh | xargs shfmt --write"
		check "License" "bin/lawyer.sh --fix"
	else
		check "Bash: Shebang" "bin/bashlike.sh | bin/shebang.sh '#!/usr/bin/env bash'"
		check "Bash: Syntax" "bin/bashlike.sh | xargs -n1 bash -n"
		check "Bash: Lint" "bin/bashlike.sh | xargs shellcheck --external-sources"
		check "Bash: Format" "bin/bashlike.sh | xargs shfmt --diff"
		check "License" "bin/lawyer.sh"
	fi

	summarize
}

function check() {
	local exit_code=0
	local name="$1"
	local cmd="$2"

	echo -e "\n$(yellow "==>") $(blue "$name") $(grey "$cmd")\n"
	set +e
	(eval "$cmd")
	exit_code=$?
	set -e

	if [ $exit_code -ne 0 ]; then
		results+="$(red "FAIL") $exit_code $(blue "$name") $(grey "$cmd")\n"
	else
		results+="$(green "PASS") $exit_code $(blue "$name") $(grey "$cmd")\n"
	fi
}

function summarize() {
	echo -e "\n$(yellow "==> Summary <==")\n\n$results"
	if [[ "$results" == *"FAIL"* ]]; then
		echo "Some checks failed. Please review the summary above."
		exit 1
	else
		echo "All checks passed successfully!"
		exit 0
	fi
}

function green() {
	echo -e "\033[32m$1\033[0m"
}

function red() {
	echo -e "\033[31m$1\033[0m"
}

function yellow() {
	echo -e "\033[33m$1\033[0m"
}

function blue() {
	echo -e "\033[34m$1\033[0m"
}

function grey() {
	echo -e "\033[90m$1\033[0m"
}

main "$@"
