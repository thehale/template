#!/usr/bin/env bats
# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

setup() {
	REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	PUBLISH="$REPO/bin/publish"

	unset "${!GIT_@}"
	unset CI
	unset GITHUB_TOKEN

	cd "${BATS_TEST_TMPDIR:?}"

	git init --quiet --initial-branch main workstation
	cd workstation
	git config user.email "release@example.com"
	git config user.name "Release"

	mkdir bin
	passing_checks
	stub_release_tools
	matching_module

	git add --all
	git commit --quiet --message "Release"
	git tag --annotate v1.0.0 --message "v1.0.0"

	git init --quiet --bare --initial-branch main ../origin.git
	git remote add origin ../origin.git
	git --git-dir ../origin.git fetch --quiet "$PWD" 'refs/*:refs/*'
}

passing_checks() {
	printf '#!/usr/bin/env bash\nexit 0\n' >bin/ci
	chmod +x bin/ci
}

matching_module() {
	printf 'module %s\n\ngo 1.26.8\n' "../origin" >go.mod
}

stub_release_tools() {
	mkdir --parents ../stubs
	stub goreleaser 'echo "goreleaser $*"'
	stub gh 'echo "gh $*"'
	PATH="$(cd .. && pwd)/stubs:$PATH"
}

stub() {
	printf '#!/usr/bin/env bash\n%s\n' "$2" >"../stubs/$1"
	chmod +x "../stubs/$1"
}

origin_tags() {
	git --git-dir ../origin.git tag --list
}

@test "builds the binaries when asked to rehearse, uploading nothing" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH" --dry-run

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = '' ]
	[[ "$output" == *"goreleaser release --clean --skip=publish"* ]]
}

@test "pushes the tag, then uploads the binaries" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH"

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = 'v1.0.0' ]
	[[ "$output" == *"goreleaser release --clean"* ]]
	[[ "$output" != *"--skip=publish"* ]]
}

@test "refuses a workstation that cannot reach GitHub" {
	stub gh 'exit 1'

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"Nothing here can reach GitHub"* ]]
	[[ "$output" == *"    gh auth login"* ]]
}

@test "succeeds when origin already carries the tag" {
	run "$PUBLISH"

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = 'v1.0.0' ]
}

@test "refuses to run under automation" {
	export CI=true

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"CI publishes nothing"* ]]
	[[ "$output" != *"    "* ]]
}

@test "refuses an argument it does not take" {
	run "$PUBLISH" --force

	[ "$status" -eq 1 ]
	[[ "$output" == *"--dry-run"* ]]
	[[ "$output" == *"    bin/publish --dry-run"* ]]
}

@test "refuses a checkout whose checks fail" {
	printf '#!/usr/bin/env bash\nexit 1\n' >bin/ci

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"bin/ci failed"* ]]
	[[ "$output" == *"    bin/ci --fix  # NOTE: not every problem is autofixable"* ]]
}

@test "refuses a branch that is not main" {
	git checkout --quiet -b topic

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"A release is published from main"* ]]
	[[ "$output" == *"    git switch main"* ]]
}

@test "refuses a dirty working tree" {
	echo "scratch" >notes.md

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"working tree has changes"* ]]
	[[ "$output" == *"    git add . && git stash"* ]]
}

@test "refuses a commit carrying no release tag" {
	git tag --delete v1.0.0

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"no vX.Y.Z tag"* ]]
	[[ "$output" == *"    git tag vX.Y.Z"* ]]
}

@test "refuses a module path that points away from origin" {
	git remote set-url origin https://github.com/someone/else

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"origin serves github.com/someone/else"* ]]
	[[ "$output" == *"    go mod edit -module github.com/someone/else"* ]]
}

@test "refuses a branch origin has never seen" {
	git --git-dir ../origin.git update-ref --no-deref -d refs/heads/main

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"origin has no main"* ]]
	[[ "$output" == *"    git push origin main"* ]]
}

@test "refuses a branch origin knows at another commit" {
	git commit --quiet --allow-empty --message "Ahead"
	git tag --annotate --force v1.0.0 --message "v1.0.0"

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"origin/main is a different commit"* ]]
	[[ "$output" == *"    git push origin main"* ]]
}

@test "refuses a tag origin disagrees about" {
	git --git-dir ../origin.git tag --delete v1.0.0
	git --git-dir ../origin.git tag v1.0.0 HEAD

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"already carries a different v1.0.0"* ]]
	[[ "$output" == *"    git ls-remote origin refs/tags/v1.0.0"* ]]
	[ "$(origin_tags)" = 'v1.0.0' ]
}
