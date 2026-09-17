#!/usr/bin/env bats
# Copyright (c) Joseph Hale, 2026
# SPDX-License-Identifier: MPL-2.0

setup() {
	REPO="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
	PUBLISH="$REPO/bin/publish"

	unset "${!GIT_@}"
	unset CI

	cd "${BATS_TEST_TMPDIR:?}"

	git init --quiet --initial-branch main workstation
	cd workstation
	git config user.email "release@example.com"
	git config user.name "Release"

	mkdir bin
	passing_checks

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

origin_tags() {
	git --git-dir ../origin.git tag --list
}

@test "rehearses the push when asked, leaving origin without the tag" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH" --dry-run

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = '' ]
	[[ "$output" == *"Rehearsing"* ]]
}

@test "pushes the tag" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH"

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = 'v1.0.0' ]
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
}

@test "refuses an argument it does not take" {
	run "$PUBLISH" --force

	[ "$status" -eq 1 ]
	[[ "$output" == *"--dry-run"* ]]
}

@test "refuses a checkout whose checks fail" {
	printf '#!/usr/bin/env bash\nexit 1\n' >bin/ci

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"bin/ci failed"* ]]
}

@test "refuses a branch that is not main" {
	git checkout --quiet -b topic

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"A release is published from main"* ]]
}

@test "refuses a dirty working tree" {
	echo "scratch" >notes.md

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"working tree has changes"* ]]
}

@test "refuses a commit carrying no release tag" {
	git tag --delete v1.0.0

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"no vX.Y.Z tag"* ]]
}

@test "refuses a branch origin has never seen" {
	git --git-dir ../origin.git update-ref --no-deref -d refs/heads/main

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"origin has no main"* ]]
}

@test "refuses a branch origin knows at another commit" {
	git commit --quiet --allow-empty --message "Ahead"
	git tag --annotate --force v1.0.0 --message "v1.0.0"

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"origin/main is a different commit"* ]]
}

@test "refuses a tag origin disagrees about" {
	git --git-dir ../origin.git tag --delete v1.0.0
	git --git-dir ../origin.git tag v1.0.0 HEAD

	run "$PUBLISH"

	[ "$status" -eq 1 ]
	[[ "$output" == *"already carries a different v1.0.0"* ]]
	[ "$(origin_tags)" = 'v1.0.0' ]
}
