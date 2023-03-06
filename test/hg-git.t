#!/bin/bash
#
# Copyright (c) 2012 Felipe Contreras
#
# Base commands from hg-git tests:
# https://bitbucket.org/durin42/hg-git/src
#

# shellcheck disable=SC2016,SC2034,SC2086,SC2164,SC1091

test_description='Test remote-hg output compared to hg-git'

. ./test-lib.sh

if ! test_have_prereq PYTHON
then
	skip_all='skipping remote-hg tests; python not available'
	test_done
fi

if ! python -c 'import mercurial' > /dev/null 2>&1
then
	skip_all='skipping remote-hg tests; mercurial not available'
	test_done
fi

if python -c 'import hggit' > /dev/null 2>&1
then
	hggit=hggit
elif python -c 'import hgext.git' > /dev/null 2>&1
then
	hggit=hgext.git
else
	skip_all='skipping remote-hg tests; hg-git not available'
	test_done
fi

# clone to a git repo with git
git_clone_git () {
	git clone -q "hg::$1" $2 &&
	(
	cd $2 &&
	git checkout master &&
	{ git branch -D default || true ;}
	)
}

# clone to an hg repo with git
hg_clone_git () {
	(
	hg init $2 &&
	hg -R $2 bookmark -i master &&
	cd $1 &&
	git push -q "hg::../$2" 'refs/tags/*:refs/tags/*' 'refs/heads/*:refs/heads/*'
	) &&

	(cd $2 && hg -q update)
}

# clone to a git repo with hg
git_clone_hg () {
	(
	git init -q $2 &&
	cd $1 &&
	hg bookmark -i -f -r tip master &&
	{ hg -q push -r master ../$2 || true ;}
	)
}

# clone to an hg repo with hg
hg_clone_hg () {
	hg -q clone $1 $2
}

# push an hg repo with git
hg_push_git () {
	(
	cd $2
	git checkout -q -b tmp &&
	git fetch -q "hg::../$1" 'refs/tags/*:refs/tags/*' 'refs/heads/*:refs/heads/*' &&
	git branch -D default &&
	git checkout -q '@{-1}' &&
	{ git branch -q -D tmp 2> /dev/null || true ;}
	)
}

# push an hg git repo with hg
hg_push_hg () {
	(
	cd $1 &&
	{ hg -q push ../$2 || true ;}
	)
}

hg_log () {
	hg -R $1 log --debug -r 'sort(tip:0, date)' |
		sed -e '/tag: *default/d' -e 's/[0-9]\+:\([0-9a-f]\{40\}\)/\1/'
}

git_log () {
	git -C $1 fast-export --branches
}

setup () {
	cat > "$HOME"/.hgrc <<-EOF
	[ui]
	username = A U Thor <author@example.com>
	[defaults]
	commit = -d "0 0"
	tag = -d "0 0"
	[extensions]
	$hggit =
	[git]
	debugextrainmessage = 1
	EOF

	cat > "$HOME"/.gitconfig <<-EOF
	[remote-hg]
		hg-git-compat = true
		track-branches = false
	EOF

	export HGEDITOR=true
	export HGMERGE=true

	export GIT_AUTHOR_DATE="2007-01-01 00:00:00 +0230"
	export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
}

setup

# save old function
eval "old_$(declare -f test_expect_success)"

test_expect_success () {
	old_test_expect_success "$1" "
	test_when_finished \"rm -rf gitrepo* hgrepo*\" && $2"
}

test_expect_success 'rename' '
	(
	hg init hgrepo1 &&
	cd hgrepo1 &&
	echo alpha > alpha &&
	hg add alpha &&
	hg commit -m "add alpha" &&
	hg mv alpha beta &&
	hg commit -m "rename alpha to beta"
	) &&

	for x in hg git
	do
		git_clone_$x hgrepo1 gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&
		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'executable bit' '
	(
	git init -q gitrepo &&
	cd gitrepo &&
	echo alpha > alpha &&
	chmod 0644 alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	chmod 0755 alpha &&
	git add alpha &&
	git commit -m "set executable bit" &&
	chmod 0644 alpha &&
	git add alpha &&
	git commit -m "clear executable bit"
	) &&

	for x in hg git
	do
		(
		hg_clone_$x gitrepo hgrepo-$x &&
		cd hgrepo-$x &&
		hg_log . &&
		hg manifest -r 1 -v &&
		hg manifest -v
		) > "output-$x" &&

		git_clone_$x hgrepo-$x gitrepo2-$x &&
		git_log gitrepo2-$x > "log-$x"
	done &&

	test_cmp output-hg output-git &&
	test_cmp log-hg log-git
'

test_expect_success 'symlink' '
	(
	git init -q gitrepo &&
	cd gitrepo &&
	echo alpha > alpha &&
	git add alpha &&
	git commit -m "add alpha" &&
	ln -s alpha beta &&
	git add beta &&
	git commit -m "add beta"
	) &&

	for x in hg git
	do
		(
		hg_clone_$x gitrepo hgrepo-$x &&
		cd hgrepo-$x &&
		hg_log . &&
		hg manifest -v
		) > "output-$x" &&

		git_clone_$x hgrepo-$x gitrepo2-$x &&
		git_log gitrepo2-$x > "log-$x"
	done &&

	test_cmp output-hg output-git &&
	test_cmp log-hg log-git
'

test_expect_success 'merge conflict 1' '
	(
	hg init hgrepo1 &&
	cd hgrepo1 &&
	echo A > afile &&
	hg add afile &&
	hg ci -m "origin" &&

	echo B > afile &&
	hg ci -m "A->B" -d "1 0" &&

	hg up -r0 &&
	echo C > afile &&
	hg ci -m "A->C" -d "2 0" &&

	hg merge -r1 &&
	echo C > afile &&
	hg resolve -m afile &&
	hg ci -m "merge to C" -d "3 0"
	) &&

	for x in hg git
	do
		git_clone_$x hgrepo1 gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&
		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'merge conflict 2' '
	(
	hg init hgrepo1 &&
	cd hgrepo1 &&
	echo A > afile &&
	hg add afile &&
	hg ci -m "origin" &&

	echo B > afile &&
	hg ci -m "A->B" -d "1 0" &&

	hg up -r0 &&
	echo C > afile &&
	hg ci -m "A->C" -d "2 0" &&

	hg merge -r1 || true &&
	echo B > afile &&
	hg resolve -m afile &&
	hg ci -m "merge to B" -d "3 0"
	) &&

	for x in hg git
	do
		git_clone_$x hgrepo1 gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&
		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'converged merge' '
	(
	hg init hgrepo1 &&
	cd hgrepo1 &&
	echo A > afile &&
	hg add afile &&
	hg ci -m "origin" &&

	echo B > afile &&
	hg ci -m "A->B" -d "1 0" &&

	echo C > afile &&
	hg ci -m "B->C" -d "2 0" &&

	hg up -r0 &&
	echo C > afile &&
	hg ci -m "A->C" -d "3 0" &&

	hg merge -r2 || true &&
	hg ci -m "merge" -d "4 0"
	) &&

	for x in hg git
	do
		git_clone_$x hgrepo1 gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&
		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'encoding' '
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

	for x in hg git
	do
		hg_clone_$x gitrepo hgrepo-$x &&
		git_clone_$x hgrepo-$x gitrepo2-$x &&

		HGENCODING=utf-8 hg_log hgrepo-$x > "hg-log-$x" &&
		git_log gitrepo2-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'file removal' '
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

	for x in hg git
	do
		(
		hg_clone_$x gitrepo hgrepo-$x &&
		cd hgrepo-$x &&
		hg_log . &&
		hg manifest -r 3 &&
		hg manifest
		) > "output-$x" &&

		git_clone_$x hgrepo-$x gitrepo2-$x &&
		git_log gitrepo2-$x > "log-$x"
	done &&

	test_cmp output-hg output-git &&
	test_cmp log-hg log-git
'

test_expect_success 'git tags' '
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

	for x in hg git
	do
		hg_clone_$x gitrepo hgrepo-$x &&
		hg_log hgrepo-$x > "log-$x"
	done &&

	test_cmp log-hg log-git
'

test_expect_success 'hg author' '
	for x in hg git
	do
		(
		git init -q gitrepo-$x &&
		cd gitrepo-$x &&

		echo alpha > alpha &&
		git add alpha &&
		git commit -m "add alpha" &&
		git checkout -q -b not-master
		) &&

		(
		hg_clone_$x gitrepo-$x hgrepo-$x &&
		cd hgrepo-$x &&

		hg co master &&
		echo beta > beta &&
		hg add beta &&
		hg commit -u "test" -m "add beta" &&

		echo gamma >> beta &&
		hg commit -u "test <test@example.com> (comment)" -m "modify beta" &&

		echo gamma > gamma &&
		hg add gamma &&
		hg commit -u "<test@example.com>" -m "add gamma" &&

		echo delta > delta &&
		hg add delta &&
		hg commit -u "name<test@example.com>" -m "add delta" &&

		echo epsilon > epsilon &&
		hg add epsilon &&
		hg commit -u "name <test@example.com" -m "add epsilon" &&

		echo zeta > zeta &&
		hg add zeta &&
		hg commit -u " test " -m "add zeta" &&

		echo eta > eta &&
		hg add eta &&
		hg commit -u "test < test@example.com >" -m "add eta" &&

		echo theta > theta &&
		hg add theta &&
		hg commit -u "test >test@example.com>" -m "add theta" &&

		echo iota > iota &&
		hg add iota &&
		hg commit -u "test <test <at> example <dot> com>" -m "add iota"
		) &&

		hg_push_$x hgrepo-$x gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&

		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'hg branch' '
	for x in hg git
	do
		(
		git init -q gitrepo-$x &&
		cd gitrepo-$x &&

		echo alpha > alpha &&
		git add alpha &&
		git commit -q -m "add alpha" &&
		git checkout -q -b not-master
		) &&

		(
		hg_clone_$x gitrepo-$x hgrepo-$x &&

		cd hgrepo-$x &&
		hg -q co master &&
		hg mv alpha beta &&
		hg -q commit -m "rename alpha to beta" &&
		hg branch gamma | grep -v "permanent and global" &&
		hg -q commit -m "started branch gamma"
		) &&

		hg_push_$x hgrepo-$x gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&

		hg_log hgrepo2-$x > "hg-log-$x" &&
		git_log gitrepo-$x > "git-log-$x"
	done &&

	test_cmp hg-log-hg hg-log-git &&
	test_cmp git-log-hg git-log-git
'

test_expect_success 'hg tags' '
	for x in hg git
	do
		(
		git init -q gitrepo-$x &&
		cd gitrepo-$x &&

		echo alpha > alpha &&
		git add alpha &&
		git commit -m "add alpha" &&
		git checkout -q -b not-master
		) &&

		(
		hg_clone_$x gitrepo-$x hgrepo-$x &&

		cd hgrepo-$x &&
		hg co master &&
		hg tag alpha
		) &&

		hg_push_$x hgrepo-$x gitrepo-$x &&
		hg_clone_$x gitrepo-$x hgrepo2-$x &&

		(
		git --git-dir=gitrepo-$x/.git tag -l &&
		hg_log hgrepo2-$x &&
		cat hgrepo2-$x/.hgtags
		) > "output-$x"
	done &&

	test_cmp output-hg output-git
'

test_done
