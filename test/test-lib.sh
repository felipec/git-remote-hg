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
