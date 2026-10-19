#!/usr/bin/env bats
# Copyright (c) 2026 Joseph Hale
# SPDX-License-Identifier: MPL-2.0

setup() {
	unset "${!GIT_@}"
	copy_template "${BATS_TEST_TMPDIR:?}/project"
	commit_template
}

copy_template() {
	mkdir "$1"
	rsync -a --exclude .git --exclude target "$BATS_TEST_DIRNAME/../../" "$1/"
	cd "$1"
	export MISE_TRUSTED_CONFIG_PATHS="$PWD"
}

commit_template() {
	export GIT_AUTHOR_NAME="Project" GIT_AUTHOR_EMAIL="project@example.com"
	export GIT_COMMITTER_NAME="Project" GIT_COMMITTER_EMAIL="project@example.com"
	git init --quiet
	git config user.name "Project"
	git add --all
	git commit --quiet --message "Initial"
}

@test "names the project it is given" {
	run "$PWD/bin/init" --name widget

	[ "$status" -eq 0 ]
	grep -q '^# Widget$' README.md
	! grep -q 'bin/init --name my-package' README.md
}

@test "points the license badge at a github.com repository" {
	"$PWD/bin/init" --name widget --repository https://github.com/acme/widget

	grep -q 'badgen.net/github/license/acme/widget' README.md
	grep -q 'github.com/acme/widget/blob/main/LICENSE' README.md
}

@test "names the chosen license on the badge" {
	"$PWD/bin/init" --name widget --repository https://github.com/acme/widget --license MIT

	grep -q '\[!\[License: MIT\](' README.md
}

@test "drops the license badge for a repository that is not on github.com" {
	"$PWD/bin/init" --name widget --repository https://gitlab.com/acme/widget

	! grep -q 'badgen.net/github/license' README.md
}

@test "reads the repository from origin" {
	git remote add origin git@github.com:acme/widget.git

	"$PWD/bin/init" --name widget

	grep -q 'badgen.net/github/license/acme/widget' README.md
}

@test "ignores an origin that names another repository" {
	git remote add origin git@github.com:thehale/template.git
	stub_gh 'echo acme'

	"$PWD/bin/init" --name widget

	grep -q 'badgen.net/github/license/acme/widget' README.md
	! grep -q 'thehale/template' README.md
}

@test "takes the user gh is logged in as with no origin" {
	stub_gh 'echo acme'

	"$PWD/bin/init" --name widget

	grep -q 'badgen.net/github/license/acme/widget' README.md
}

@test "falls back to thehale with no origin and gh logged out" {
	stub_gh 'exit 1'

	"$PWD/bin/init" --name widget

	grep -q 'badgen.net/github/license/thehale/widget' README.md
}

stub_gh() {
	mkdir "$BATS_TEST_TMPDIR/stubs"
	printf '#!/usr/bin/env bash\n%s\n' "$1" >"$BATS_TEST_TMPDIR/stubs/gh"
	chmod +x "$BATS_TEST_TMPDIR/stubs/gh"
	PATH="$BATS_TEST_TMPDIR/stubs:$PATH"
}

@test "refuses to start without an owner" {
	export GIT_CONFIG_GLOBAL=/dev/null
	git config --unset user.name

	run "$PWD/bin/init" --name widget

	[ "$status" -eq 1 ]
	[[ "$output" == *"    bin/init --owner"* ]]
	[ -z "$(git status --porcelain)" ]
}

@test "sets the owner" {
	"$PWD/bin/init" --name widget --owner "Acme Corp"

	grep -q -- '--copyright-owner "Acme Corp"' bin/copyright
	grep -q '^Copyright (c) [0-9]\{4\} Acme Corp, All Rights Reserved$' README.md
}

@test "accepts a different license" {
	"$PWD/bin/init" --name widget --license MIT

	grep -q -- '--license MIT' bin/copyright
	[ "$(head -n 1 LICENSE)" = 'MIT License' ]
}

@test "runs the package step with the answers" {
	write_package_step

	git add --all
	git commit --quiet --message "Add a package step"

	run "$PWD/bin/init" --name widget --owner "Acme Corp" --repository https://github.com/acme/widget --license MIT

	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/package-env")" = "widget
Acme Corp
https://github.com/acme/widget
MIT" ]
	[ ! -e bin/.init ]
}

write_package_step() {
	mkdir -p bin/.init
	cat >bin/.init/package <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n%s\n%s\n%s\n' "\$PACKAGE_NAME" "\$PACKAGE_OWNER" "\$PACKAGE_REPOSITORY" "\$PACKAGE_LICENSE" >"$BATS_TEST_TMPDIR/package-env"
EOF
	chmod +x bin/.init/package
}

@test "activates lines marked for init" {
	printf '\t# init: echo active\n' >>bin/ci
	git add --all
	git commit --quiet --message "Mark a line for init"

	"$PWD/bin/init" --name widget

	grep -q '^	echo active$' bin/ci
	[ -x bin/ci ]
}

@test "removes itself" {
	"$PWD/bin/init" --name widget

	[ ! -e bin/init ]
	[ ! -e bin/.tests/init.bats ]
	[ ! -e .github/workflows/init.yml ]
}

@test "commits everything it generated" {
	local template
	template="$(git rev-parse HEAD)"

	run "$PWD/bin/init" --name widget

	[ "$status" -eq 0 ]
	[ -z "$(git status --porcelain)" ]
	[ "$(git log -1 --format=%B)" = "Scaffold widget

From template commit $template" ]
}

@test "refuses a dirty working tree" {
	echo "scratch" >notes.md

	run "$PWD/bin/init" --name widget

	[ "$status" -eq 1 ]
	[[ "$output" == *"working tree has changes"* ]]
	[[ "$output" == *"    "* ]]
}

@test "refuses a license it does not know" {
	run "$PWD/bin/init" --name widget --license not-a-license

	[ "$status" -eq 1 ]
	[[ "$output" == *"not-a-license"* ]]
	[ ! -e Cargo.toml ]
}

@test "refuses an argument it does not take" {
	run "$PWD/bin/init" --force

	[ "$status" -eq 1 ]
	[[ "$output" == *"Usage"* ]]
}

@test "leaves the files it rewrites passing their checks" {
	"$PWD/bin/init" --name widget --owner "Acme Corp" --repository https://gitlab.com/acme/widget --license MIT

	bin/copyright
	bin/markdownlint
}
