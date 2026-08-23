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
	stub_hatch

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

stub_hatch() {
	mkdir --parents ../stubs
	printf '#!/usr/bin/env bash\necho "hatch $*"\n' >../stubs/hatch
	chmod +x ../stubs/hatch
	PATH="$(cd .. && pwd)/stubs:$PATH"
}

origin_tags() {
	git --git-dir ../origin.git tag --list
}

@test "builds and rehearses the push when asked, uploading nothing" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH" --dry-run <<<"token"

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = '' ]
	[[ "$output" == *"hatch build"* ]]
	[[ "$output" != *"hatch publish"* ]]
}

@test "builds, pushes the tag, then uploads" {
	git --git-dir ../origin.git tag --delete v1.0.0

	run "$PUBLISH" <<<"token"

	[ "$status" -eq 0 ]
	[ "$(origin_tags)" = 'v1.0.0' ]
	[[ "$output" == *"hatch build"* ]]
	[[ "$output" == *"hatch publish"* ]]
}

@test "succeeds when origin already carries the tag" {
	run "$PUBLISH" <<<"token"

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
