#!/bin/sh

. ./sharness.sh

test_set_prereq PYTHON

GIT_VERSION=$(git --version)
GIT_MAJOR=$(expr "$GIT_VERSION" : '[^0-9]*\([0-9]*\)')
GIT_MINOR=$(expr "$GIT_VERSION" : '[^0-9]*[0-9]*\.\([0-9]*\)')
test "$GIT_MAJOR" -ge 2 && test_set_prereq GIT_2_0

GIT_AUTHOR_EMAIL=author@example.com
GIT_AUTHOR_NAME='A U Thor'
GIT_COMMITTER_EMAIL=committer@example.com
GIT_COMMITTER_NAME='C O Mitter'
export GIT_AUTHOR_EMAIL GIT_AUTHOR_NAME
export GIT_COMMITTER_EMAIL GIT_COMMITTER_NAME
