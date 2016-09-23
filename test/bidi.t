#!/bin/sh
#
# Copyright (c) 2012 Felipe Contreras
#
# Base commands from hg-git tests:
# https://bitbucket.org/durin42/hg-git/src
#

test_description='Test bidirectionality of remote-hg'

test -n "$TEST_DIRECTORY" || TEST_DIRECTORY=$(dirname $0)/
. "$TEST_DIRECTORY"/test-lib.sh

if ! test_have_prereq PYTHON
then
	skip_all='skipping remote-hg tests; python not available'
	test_done
fi

if ! python2 -c 'import mercurial' > /dev/null 2>&1
then
	skip_all='skipping remote-hg tests; mercurial not available'
	test_done
fi

# clone to a git repo
git_clone () {
	git clone -q "hg::$1" $2
}

# clone to an hg repo
hg_clone () {
	(
	hg init $2 &&
	cd $1 &&
	git push -q "hg::../$2" 'refs/tags/*:refs/tags/*' 'refs/heads/*:refs/heads/*'
	) &&

	(cd $2 && hg -q update)
}

# push an hg repo
hg_push () {
	(
	cd $2
	git checkout -q -b tmp &&
	git fetch -q "hg::../$1" 'refs/tags/*:refs/tags/*' 'refs/heads/*:refs/heads/*' &&
	git checkout -q @{-1} &&
	git branch -q -D tmp 2> /dev/null || true
	)
}

hg_log () {
	hg -R $1 log --graph --debug
}

setup () {
	cat > "$HOME"/.hgrc <<-EOF &&
	[ui]
	username = A U Thor <author@example.com>
	[defaults]
	backout = -d "0 0"
	commit = -d "0 0"
	debugrawcommit = -d "0 0"
	tag = -d "0 0"
	[extensions]"
	graphlog =
	EOF
	git config --global remote-hg.hg-git-compat true
	git config --global remote-hg.track-branches true

	HGEDITOR=/usr/bin/true
	GIT_AUTHOR_DATE="2007-01-01 00:00:00 +0230"
	GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
	export HGEDITOR GIT_AUTHOR_DATE GIT_COMMITTER_DATE
}

setup

test_expect_success 'encoding' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&

	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add älphà" &&

	GIT_AUTHOR_NAME="tést èncödîng" &&
	export GIT_AUTHOR_NAME &&
	echo beta > beta &&
	git add beta &&
	git commit -m "add beta" &&

	echo gamma > gamma &&
	git add gamma &&
	git commit -m "add gämmâ" &&

	: TODO git config i18n.commitencoding latin-1 &&
	echo delta > delta &&
	git add delta &&
	git commit -m "add déltà"
	) &&

	hg_clone gitrepo hgrepo &&
	git_clone hgrepo gitrepo2 &&
	hg_clone gitrepo2 hgrepo2 &&

	HGENCODING=utf-8 hg_log hgrepo > expected &&
	HGENCODING=utf-8 hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_expect_success 'file removal' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&
	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	echo beta > beta &&
	git add beta &&
	git commit -m "add beta"
	mkdir foo &&
	echo blah > foo/bar &&
	git add foo &&
	git commit -m "add foo" &&
	git rm alpha &&
	git commit -m "remove alpha" &&
	git rm foo/bar &&
	git commit -m "remove foo/bar"
	) &&

	hg_clone gitrepo hgrepo &&
	git_clone hgrepo gitrepo2 &&
	hg_clone gitrepo2 hgrepo2 &&

	hg_log hgrepo > expected &&
	hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_expect_success 'git tags' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&
	git config receive.denyCurrentBranch ignore &&
	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	git tag alpha &&

	echo beta > beta &&
	git add beta &&
	git commit -m "add beta" &&
	git tag -a -m "added tag beta" beta
	) &&

	hg_clone gitrepo hgrepo &&
	git_clone hgrepo gitrepo2 &&
	hg_clone gitrepo2 hgrepo2 &&

	hg_log hgrepo > expected &&
	hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_expect_success 'git submodules' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&
	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	git tag alpha &&

    git init -q subrepo &&
    cd subrepo
	echo beta > beta &&
	git add beta &&
	git commit -m "add beta" &&

	cd .. &&
	git submodule add ./subrepo ext &&
	git commit -m "add submodule"
	) &&

	hg_clone gitrepo hgrepo &&
	git_clone hgrepo gitrepo2 &&
	hg_clone gitrepo2 hgrepo2 &&

	hg_log hgrepo > expected &&
	hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_expect_success 'hg branch' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&

	echo alpha > alpha &&
	git add alpha &&
	git commit -q -m "add alpha" &&
	git checkout -q -b not-master
	) &&

	(
	hg_clone gitrepo hgrepo &&

	cd hgrepo &&
	hg -q co default &&
	hg mv alpha beta &&
	hg -q commit -m "rename alpha to beta" &&
	hg branch gamma | grep -v "permanent and global" &&
	hg -q commit -m "started branch gamma"
	) &&

	hg_push hgrepo gitrepo &&
	hg_clone gitrepo hgrepo2 &&

	: Back to the common revision &&
	(cd hgrepo && hg checkout default) &&

	hg_log hgrepo > expected &&
	hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_expect_success 'hg tags' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	git init -q gitrepo &&
	cd gitrepo &&

	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	git checkout -q -b not-master
	) &&

	(
	hg_clone gitrepo hgrepo &&

	cd hgrepo &&
	hg co default &&
	hg tag alpha
	) &&

	hg_push hgrepo gitrepo &&
	hg_clone gitrepo hgrepo2 &&

	hg_log hgrepo > expected &&
	hg_log hgrepo2 > actual &&

	test_cmp expected actual
'

test_done
