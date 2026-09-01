#!/usr/bin/env bats
# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

setup() {
	REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"

	cd "${BATS_TEST_TMPDIR:?}"
	git init --quiet .
}

track() {
	git add --intent-to-add "$@"
}

@test "selects a file by its .sh extension" {
	printf 'echo hi\n' >script.sh
	track script.sh

	run "$REPO/bin/bashlike"

	[ "$output" = 'script.sh' ]
}

@test "selects a file by its .bash extension" {
	printf 'echo hi\n' >script.bash
	track script.bash

	run "$REPO/bin/bashlike"

	[ "$output" = 'script.bash' ]
}

@test "selects an extensionless file by its bash shebang" {
	printf '#!/usr/bin/env bash\n' >tool
	track tool

	run "$REPO/bin/bashlike"

	[ "$output" = 'tool' ]
}

@test "skips a file whose shebang is not bash" {
	printf '#!/usr/bin/env python3\n' >tool
	track tool

	run "$REPO/bin/bashlike"

	[ "$output" = '' ]
}

@test "skips a file with no extension and no shebang" {
	printf 'plain text\n' >notes
	track notes

	run "$REPO/bin/bashlike"

	[ "$output" = '' ]
}

@test "lists a file once when both extension and shebang match" {
	printf '#!/usr/bin/env bash\n' >script.sh
	track script.sh

	run "$REPO/bin/bashlike"

	[ "$output" = 'script.sh' ]
}

@test "includes an untracked file" {
	printf 'echo hi\n' >script.sh

	run "$REPO/bin/bashlike"

	[ "$output" = 'script.sh' ]
}

@test "omits a gitignored file" {
	printf 'echo hi\n' >script.sh
	printf 'script.sh\n' >.gitignore

	run "$REPO/bin/bashlike"

	[ "$output" = '' ]
}

@test "omits a file deleted from the worktree" {
	printf 'echo hi\n' >gone.sh
	git add gone.sh
	git -c user.email=t@t -c user.name=t commit --quiet -m init
	rm gone.sh

	run "$REPO/bin/bashlike"

	[ "$output" = '' ]
}

@test "omits vendored files at any depth" {
	mkdir -p vendor deep/vendor/lib
	printf 'echo hi\n' >vendor/script.sh
	printf 'echo hi\n' >deep/vendor/lib/script.sh
	printf 'echo hi\n' >kept.sh
	track vendor/script.sh deep/vendor/lib/script.sh kept.sh

	run "$REPO/bin/bashlike"

	[ "$output" = 'kept.sh' ]
}

@test "keeps a path that merely contains the word vendor" {
	mkdir -p vendored
	printf 'echo hi\n' >vendored/script.sh
	track vendored/script.sh

	run "$REPO/bin/bashlike"

	[ "$output" = 'vendored/script.sh' ]
}

@test "outputs nothing in an empty repo" {
	run "$REPO/bin/bashlike"

	[ "$output" = '' ]
}

@test "sorts its output" {
	printf 'echo hi\n' >b.sh
	printf 'echo hi\n' >a.sh
	track a.sh b.sh

	run "$REPO/bin/bashlike"

	[ "$output" = "$(printf 'a.sh\nb.sh')" ]
}
