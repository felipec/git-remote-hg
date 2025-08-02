#!/bin/bash

: "${SHARNESS_TEST_SRCDIR:=$(cd "$(dirname "${BASH_SOURCE-$0}")" && pwd)}"
. "$SHARNESS_TEST_SRCDIR"/sharness.sh

if ! python -c 'import mercurial' > /dev/null 2>&1
then
	error 'mercurial not available'
fi

GIT_AUTHOR_EMAIL=author@example.com
GIT_AUTHOR_NAME='A U Thor'
GIT_COMMITTER_EMAIL=committer@example.com
GIT_COMMITTER_NAME='C O Mitter'
export GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME

unset XDG_CONFIG_HOME

test_set_prereq() {
	satisfied_prereq="$satisfied_prereq$1 "
}
satisfied_prereq=" "

if [[ $(uname -s) = MSYS* ]]; then
	test_set_prereq WIN
	export TEST_CMP='diff --strip-trailing-cr -u'
fi

test_cmp() {
	${TEST_CMP:-diff -u} "$@"
}

test_when_finished() {
	test_cleanup="{ $*
		} && (exit \"\$eval_ret\"); eval_ret=\$?; $test_cleanup"
}

test_expect_code() {
	want_code=$1
	shift
	"$@"
	exit_code=$?
	if test "$exit_code" = "$want_code"; then
		return 0
	fi

	echo >&2 "test_expect_code: command exited with $exit_code, we wanted $want_code $*"
	return 1
}

test_have_prereq() {
	prerequisite=$1

	case "$prerequisite" in
	!*)
		negative_prereq=t
		prerequisite=${prerequisite#!}
		;;
	*)
		negative_prereq=
	esac

	case "$satisfied_prereq" in
	*" $prerequisite "*)
		satisfied_this_prereq=t
		;;
	*)
		satisfied_this_prereq=
	esac

	case "$satisfied_this_prereq,$negative_prereq" in
	t,|,t)
		return 0
		;;
	esac

	return 1
}
