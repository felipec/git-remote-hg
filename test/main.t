#!/bin/sh
#
# Copyright (c) 2012 Felipe Contreras
#
# Base commands from hg-git tests:
# https://bitbucket.org/durin42/hg-git/src
#

test_description='Test remote-hg'

test -n "$TEST_DIRECTORY" || TEST_DIRECTORY=$(dirname $0)/
. "$TEST_DIRECTORY"/test-lib.sh

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

check () {
	echo $3 > expected &&
	git --git-dir=$1/.git log --format='%s' -1 $2 > actual &&
	test_cmp expected actual
}

check_branch () {
	if test -n "$3"
	then
		echo $3 > expected &&
		hg -R $1 log -r $2 --template '{desc}\n' > actual &&
		test_cmp expected actual
	else
		hg -R $1 branches > out &&
		! grep $2 out
	fi
}

check_bookmark () {
	if test -n "$3"
	then
		echo $3 > expected &&
		hg -R $1 log -r "bookmark('$2')" --template '{desc}\n' > actual &&
		test_cmp expected actual
	else
		hg -R $1 bookmarks > out &&
		! grep $2 out
	fi
}

check_files () {
	git --git-dir=$1/.git ls-files > actual &&
	if test $# -gt 1
	then
		printf "%s\n" "$2" > expected
	else
		> expected
	fi &&
	test_cmp expected actual
}

check_push () {
	expected_ret=$1 ret=0 ref_ret=0

	shift
	git push origin "$@" 2> error
	ret=$?
	cat error

	while IFS=':' read branch kind
	do
		case "$kind" in
		'new')
			grep "^ \* \[new branch\] *${branch} -> ${branch}$" error || ref_ret=1
			;;
		'non-fast-forward')
			grep "^ ! \[rejected\] *${branch} -> ${branch} (non-fast-forward)$" error || ref_ret=1
			;;
		'fetch-first')
			grep "^ ! \[rejected\] *${branch} -> ${branch} (fetch first)$" error || ref_ret=1
			;;
		'forced-update')
			grep "^ + [a-f0-9]*\.\.\.[a-f0-9]* *${branch} -> ${branch} (forced update)$" error || ref_ret=1
			;;
		'')
			grep "^   [a-f0-9]*\.\.[a-f0-9]* *${branch} -> ${branch}$" error || ref_ret=1
			;;
		*)
			echo "BUG: wrong kind '$kind'" && return 3
			;;
		esac
		test $ref_ret -ne 0 && echo "match for '$branch' failed" && return 2
	done

	test $expected_ret -ne $ret && return 1

	return 0
}

setup () {
	cat > "$HOME"/.hgrc <<-EOF &&
	[ui]
	username = H G Wells <wells@example.com>
	[extensions]
	mq =
	EOF

	GIT_AUTHOR_DATE="2007-01-01 00:00:00 +0230" &&
	GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE" &&
	export GIT_COMMITTER_DATE GIT_AUTHOR_DATE
}

setup

test_expect_success 'setup' '
	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	)
'

test_expect_success 'cloning' '
	test_when_finished "rm -rf gitrepo*" &&
	git clone "hg::hgrepo" gitrepo &&
	check gitrepo HEAD zero
'

test_expect_success 'cloning with branches' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	cd hgrepo &&
	hg branch next &&
	echo next > content &&
	hg commit -m next
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check gitrepo origin/branches/next next
'

test_expect_success 'cloning with bookmarks' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	cd hgrepo &&
	hg checkout default &&
	hg bookmark feature-a &&
	echo feature-a > content &&
	hg commit -m feature-a
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check gitrepo origin/feature-a feature-a
'

test_expect_success 'update bookmark' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	cd hgrepo &&
	hg bookmark devel
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git checkout --quiet devel &&
	echo devel > content &&
	git commit -a -m devel &&
	git push --quiet
	) &&

	check_bookmark hgrepo devel devel
'

test_expect_success 'new bookmark' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git checkout --quiet -b feature-b &&
	echo feature-b > content &&
	git commit -a -m feature-b &&
	git push --quiet origin feature-b
	) &&

	check_bookmark hgrepo feature-b feature-b
'

# cleanup previous stuff
rm -rf hgrepo

author_test () {
	echo $1 >> content &&
	hg commit -u "$2" -m "add $1" &&
	echo "$3" >> ../expected
}

test_expect_success 'authors' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&

	touch content &&
	hg add content &&

	> ../expected &&
	author_test alpha "" "H G Wells <wells@example.com>" &&
	author_test beta "beta" "beta <unknown>" &&
	author_test gamma "gamma <test@example.com> (comment)" "gamma <test@example.com>" &&
	author_test delta "<delta@example.com>" "Unknown <delta@example.com>" &&
	author_test epsilon "epsilon<test@example.com>" "epsilon <test@example.com>" &&
	author_test zeta "zeta <test@example.com" "zeta <test@example.com>" &&
	author_test eta " eta " "eta <unknown>" &&
	author_test theta "theta < test@example.com >" "theta <test@example.com>" &&
	author_test iota "iota >test@example.com>" "iota <test@example.com>" &&
	author_test kappa "kappa < test <at> example <dot> com>" "kappa <unknown>" &&
	author_test lambda "lambda@example.com" "Unknown <lambda@example.com>" &&
	author_test mu "mu.mu@example.com" "Unknown <mu.mu@example.com>"
	) &&

	git clone "hg::hgrepo" gitrepo &&
	git --git-dir=gitrepo/.git log --reverse --format="%an <%ae>" > actual &&

	test_cmp expected actual
'

test_expect_success 'strip' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&

	echo one >> content &&
	hg add content &&
	hg commit -m one &&

	echo two >> content &&
	hg commit -m two
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd hgrepo &&
	hg strip 1 &&

	echo three >> content &&
	hg commit -m three &&

	echo four >> content &&
	hg commit -m four
	) &&

	(
	cd gitrepo &&
	git fetch &&
	git log --format="%s" origin/master > ../actual
	) &&

	hg -R hgrepo log --template "{desc}\n" > expected &&
	test_cmp actual expected
'

test_expect_success 'remote push with master bookmark' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero &&
	hg bookmark master &&
	echo one > content &&
	hg commit -m one
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	echo two > content &&
	git commit -a -m two &&
	git push
	) &&

	check_branch hgrepo default two
'

cat > expected <<\EOF
changeset:   0:6e2126489d3d
tag:         tip
user:        A U Thor <author@example.com>
date:        Mon Jan 01 00:00:00 2007 +0230
summary:     one

EOF

test_expect_success 'remote push from master branch' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	hg init hgrepo &&

	(
	git init gitrepo &&
	cd gitrepo &&
	git remote add origin "hg::../hgrepo" &&
	echo one > content &&
	git add content &&
	git commit -a -m one &&
	git push origin master
	) &&

	hg -R hgrepo log > actual &&
	cat actual &&
	test_cmp expected actual &&

	check_branch hgrepo default one
'

GIT_REMOTE_HG_TEST_REMOTE=1
export GIT_REMOTE_HG_TEST_REMOTE

test_expect_success 'remote cloning' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check gitrepo HEAD zero
'

test_expect_success 'moving remote clone' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	git clone "hg::hgrepo" gitrepo &&
	mv gitrepo gitrepo2 &&
	cd gitrepo2 &&
	git fetch
	)
'

test_expect_success 'remote update bookmark' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	cd hgrepo &&
	hg bookmark devel
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git checkout --quiet devel &&
	echo devel > content &&
	git commit -a -m devel &&
	git push --quiet
	) &&

	check_bookmark hgrepo devel devel
'

test_expect_success 'remote new bookmark' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git checkout --quiet -b feature-b &&
	echo feature-b > content &&
	git commit -a -m feature-b &&
	git push --quiet origin feature-b
	) &&

	check_bookmark hgrepo feature-b feature-b
'

test_expect_success 'remote push diverged' '
	test_when_finished "rm -rf gitrepo*" &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd hgrepo &&
	hg checkout default &&
	echo bump > content &&
	hg commit -m bump
	) &&

	(
	cd gitrepo &&
	echo diverge > content &&
	git commit -a -m diverged &&
	check_push 1 <<-\EOF
	master:non-fast-forward
	EOF
	) &&

	check_branch hgrepo default bump
'

test_expect_success 'remote update bookmark diverge' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	cd hgrepo &&
	hg checkout tip^ &&
	hg bookmark diverge
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd hgrepo &&
	echo "bump bookmark" > content &&
	hg commit -m "bump bookmark"
	) &&

	(
	cd gitrepo &&
	git checkout --quiet diverge &&
	echo diverge > content &&
	git commit -a -m diverge &&
	check_push 1 <<-\EOF
	diverge:fetch-first
	EOF
	) &&

	check_bookmark hgrepo diverge "bump bookmark"
'

test_expect_success 'remote new bookmark multiple branch head' '
	test_when_finished "rm -rf gitrepo*" &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git checkout --quiet -b feature-c HEAD^ &&
	echo feature-c > content &&
	git commit -a -m feature-c &&
	git push --quiet origin feature-c
	) &&

	check_bookmark hgrepo feature-c feature-c
'

# cleanup previous stuff
rm -rf hgrepo

test_expect_success 'fetch special filenames' '
	test_when_finished "rm -rf hgrepo gitrepo && LC_ALL=C" &&

	LC_ALL=en_US.UTF-8
	export LC_ALL

	(
	hg init hgrepo &&
	cd hgrepo &&

	echo test >> "æ rø" &&
	hg add "æ rø" &&
	echo test >> "ø~?" &&
	hg add "ø~?" &&
	hg commit -m add-utf-8 &&
	echo test >> "æ rø" &&
	hg commit -m test-utf-8 &&
	hg rm "ø~?" &&
	hg mv "æ rø" "ø~?" &&
	hg commit -m hg-mv-utf-8
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git -c core.quotepath=false ls-files > ../actual
	) &&
	echo "ø~?" > expected &&
	test_cmp expected actual
'

test_expect_success 'push special filenames' '
	test_when_finished "rm -rf hgrepo gitrepo && LC_ALL=C" &&

	mkdir -p tmp && cd tmp &&

	LC_ALL=en_US.UTF-8
	export LC_ALL

	(
	hg init hgrepo &&
	cd hgrepo &&

	echo one >> content &&
	hg add content &&
	hg commit -m one
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&

	echo test >> "æ rø" &&
	git add "æ rø" &&
	git commit -m utf-8 &&

	git push
	) &&

	(cd hgrepo &&
	hg update &&
	hg manifest > ../actual
	) &&

	printf "content\næ rø\n" > expected &&
	test_cmp expected actual
'

setup_big_push () {
	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero &&
	hg bookmark bad_bmark1 &&
	echo one > content &&
	hg commit -m one &&
	hg bookmark bad_bmark2 &&
	hg bookmark good_bmark &&
	hg bookmark -i good_bmark &&
	hg -q branch good_branch &&
	echo "good branch" > content &&
	hg commit -m "good branch" &&
	hg -q branch bad_branch &&
	echo "bad branch" > content &&
	hg commit -m "bad branch"
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd gitrepo &&
	echo two > content &&
	git commit -q -a -m two &&

	git checkout -q good_bmark &&
	echo three > content &&
	git commit -q -a -m three &&

	git checkout -q bad_bmark1 &&
	git reset --hard HEAD^ &&
	echo four > content &&
	git commit -q -a -m four &&

	git checkout -q bad_bmark2 &&
	git reset --hard HEAD^ &&
	echo five > content &&
	git commit -q -a -m five &&

	git checkout -q -b new_bmark master &&
	echo six > content &&
	git commit -q -a -m six &&

	git checkout -q branches/good_branch &&
	echo seven > content &&
	git commit -q -a -m seven &&
	echo eight > content &&
	git commit -q -a -m eight &&

	git checkout -q branches/bad_branch &&
	git reset --hard HEAD^ &&
	echo nine > content &&
	git commit -q -a -m nine &&

	git checkout -q -b branches/new_branch master &&
	echo ten > content &&
	git commit -q -a -m ten
	)
}

test_expect_success 'remote big push' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	setup_big_push

	(
	cd gitrepo &&

	check_push 1 --all <<-\EOF
	master
	good_bmark
	branches/good_branch
	new_bmark:new
	branches/new_branch:new
	bad_bmark1:non-fast-forward
	bad_bmark2:non-fast-forward
	branches/bad_branch:non-fast-forward
	EOF
	) &&

	check_branch hgrepo default one &&
	check_branch hgrepo good_branch "good branch" &&
	check_branch hgrepo bad_branch "bad branch" &&
	check_branch hgrepo new_branch &&
	check_bookmark hgrepo good_bmark one &&
	check_bookmark hgrepo bad_bmark1 one &&
	check_bookmark hgrepo bad_bmark2 one &&
	check_bookmark hgrepo new_bmark
'

test_expect_success 'remote big push fetch first' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	setup_big_push

	(
	cd hgrepo &&
	hg checkout bad_branch &&
	hg bookmark -f bad_bmark1 &&
	echo update_bmark > content &&
	hg commit -m "update bmark"
	) &&

	(
	cd gitrepo &&

	check_push 1 --all <<-\EOF &&
	master
	good_bmark
	bad_bmark1:fetch-first
	branches/bad_branch:fetch-first
	EOF

	git fetch &&

	check_push 1 --all <<-\EOF
	master
	good_bmark
	bad_bmark1:non-fast-forward
	branches/bad_branch:non-fast-forward
	EOF
	)
'

test_expect_success 'remote big push force' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	setup_big_push

	(
	cd gitrepo &&

	check_push 0 --force --all <<-\EOF
	master
	good_bmark
	branches/good_branch
	new_bmark:new
	branches/new_branch:new
	bad_bmark1:forced-update
	bad_bmark2:forced-update
	branches/bad_branch:forced-update
	EOF
	) &&

	check_branch hgrepo default four &&
	check_branch hgrepo good_branch eight &&
	check_branch hgrepo bad_branch nine &&
	check_branch hgrepo new_branch ten &&
	check_bookmark hgrepo good_bmark three &&
	check_bookmark hgrepo bad_bmark1 four &&
	check_bookmark hgrepo bad_bmark2 five &&
	check_bookmark hgrepo new_bmark six
'

test_expect_success 'remote big push dry-run' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	setup_big_push

	(
	cd gitrepo &&

	check_push 1 --dry-run --all <<-\EOF &&
	master
	good_bmark
	branches/good_branch
	new_bmark:new
	branches/new_branch:new
	bad_bmark1:non-fast-forward
	bad_bmark2:non-fast-forward
	branches/bad_branch:non-fast-forward
	EOF

	check_push 0 --dry-run master good_bmark new_bmark branches/good_branch branches/new_branch <<-\EOF
	master
	good_bmark
	branches/good_branch
	new_bmark:new
	branches/new_branch:new
	EOF
	) &&

	check_branch hgrepo default one &&
	check_branch hgrepo good_branch "good branch" &&
	check_branch hgrepo bad_branch "bad branch" &&
	check_branch hgrepo new_branch &&
	check_bookmark hgrepo good_bmark one &&
	check_bookmark hgrepo bad_bmark1 one &&
	check_bookmark hgrepo bad_bmark2 one &&
	check_bookmark hgrepo new_bmark
'

test_expect_success 'remote big push force dry-run' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	setup_big_push

	(
	cd gitrepo &&

	check_push 0 --force --dry-run --all <<-\EOF
	master
	good_bmark
	branches/good_branch
	new_bmark:new
	branches/new_branch:new
	bad_bmark1:forced-update
	bad_bmark2:forced-update
	branches/bad_branch:forced-update
	EOF
	) &&

	check_branch hgrepo default one &&
	check_branch hgrepo good_branch "good branch" &&
	check_branch hgrepo bad_branch "bad branch" &&
	check_branch hgrepo new_branch &&
	check_bookmark hgrepo good_bmark one &&
	check_bookmark hgrepo bad_bmark1 one &&
	check_bookmark hgrepo bad_bmark2 one &&
	check_bookmark hgrepo new_bmark
'

test_expect_success 'remote double failed push' '
	test_when_finished "rm -rf hgrepo gitrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero &&
	echo one > content &&
	hg commit -m one
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git reset --hard HEAD^ &&
	echo two > content &&
	git commit -a -m two &&
	test_expect_code 1 git push &&
	test_expect_code 1 git push
	)
'

test_expect_success 'clone remote with null bookmark, then push' '
	test_when_finished "rm -rf gitrepo* hgrepo*" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo a > a &&
	hg add a &&
	hg commit -m a &&
	hg bookmark -r null bookmark
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	check gitrepo HEAD a &&
	cd gitrepo &&
	git checkout --quiet -b bookmark &&
	git remote -v &&
	echo b > b &&
	git add b &&
	git commit -m b &&
	git push origin bookmark
	)
'

test_expect_success 'notes' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one &&
	echo two > content &&
	hg commit -m two
	) &&

	git clone "hg::hgrepo" gitrepo &&
	hg -R hgrepo log --template "{node}\n\n" > expected &&
	git --git-dir=gitrepo/.git log --pretty="tformat:%N" --notes=hg > actual &&
	test_cmp expected actual
'

test_expect_failure 'push updates notes' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd gitrepo &&
	echo two > content &&
	git commit -a -m two &&
	git push
	) &&

	hg -R hgrepo log --template "{node}\n\n" > expected &&
	git --git-dir=gitrepo/.git log --pretty="tformat:%N" --notes=hg > actual &&
	test_cmp expected actual
'

test_expect_success 'push bookmark without changesets' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(
	cd gitrepo &&
	echo two > content &&
	git commit -a -m two &&
	git push origin master &&
	git branch feature-a &&
	git push origin feature-a
	) &&

	check_bookmark hgrepo feature-a two
'

test_expect_unstable 'pull tags' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one
	) &&

	git clone "hg::hgrepo" gitrepo &&

	(cd hgrepo && hg tag v1.0) &&
	(cd gitrepo && git pull) &&

	echo "v1.0" > expected &&
	git --git-dir=gitrepo/.git tag > actual &&
	test_cmp expected actual
'

test_expect_success 'push merged named branch' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one &&
	hg branch feature &&
	echo two > content &&
	hg commit -m two &&
	hg update default &&
	echo three > content &&
	hg commit -m three
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git merge -m Merge -Xtheirs origin/branches/feature &&
	git push
	) &&

	cat > expected <<-EOF &&
	Merge
	three
	two
	one
	EOF
	hg -R hgrepo log --template "{desc}\n" > actual &&
	test_cmp expected actual
'

test_expect_success 'light tag sets author' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git tag v1.0 &&
	git push --tags
	) &&

	echo "C O Mitter <committer@example.com>" > expected &&
	hg -R hgrepo log --template "{author}\n" -r tip > actual &&
	test_cmp expected actual
'

test_expect_success 'push tag different branch' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one &&
	hg branch feature &&
	echo two > content &&
	hg commit -m two
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git branch &&
	git checkout branches/feature &&
	git tag v1.0 &&
	git push --tags
	) &&

	echo feature > expected &&
	hg -R hgrepo log --template="{branch}\n" -r tip > actual &&
	test_cmp expected actual
'

test_expect_success 'cloning a removed file works' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&

	echo test > test_file &&
	hg add test_file &&
	hg commit -m add &&

	hg rm test_file &&
	hg commit -m remove
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check_files gitrepo
'

test_expect_success 'cloning a file replaced with a directory' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&

	echo test > dir_or_file &&
	hg add dir_or_file &&
	hg commit -m add &&

	hg rm dir_or_file &&
	mkdir dir_or_file &&
	echo test > dir_or_file/test_file &&
	hg add dir_or_file/test_file &&
	hg commit -m replase
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check_files gitrepo "dir_or_file/test_file"
'

test_expect_success 'clone replace directory with a file' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&

	mkdir dir_or_file &&
	echo test > dir_or_file/test_file &&
	hg add dir_or_file/test_file &&
	hg commit -m add &&

	hg rm dir_or_file/test_file &&
	echo test > dir_or_file &&
	hg add dir_or_file &&
	hg commit -m add &&

	hg rm dir_or_file
	) &&

	git clone "hg::hgrepo" gitrepo &&
	check_files gitrepo "dir_or_file"
'

test_expect_success 'push annotated tag' '
	test_when_finished "rm -rf hgrepo gitrepo" &&

	(
	hg init hgrepo &&
	cd hgrepo &&
	echo one > content &&
	hg add content &&
	hg commit -m one
	) &&

	(
	git clone "hg::hgrepo" gitrepo &&
	cd gitrepo &&
	git tag -m "Version 1.0" v1.0 &&
	git push --tags
	) &&

	cat > expected <<-\EOF &&
	tip:Version 1.0:C O Mitter <committer@example.com>
	v1.0:one:H G Wells <wells@example.com>
	EOF

	hg -R hgrepo log --template "{tags}:{desc}:{author}\n" > actual &&

	test_cmp expected actual
'

test_expect_success 'timezone issues with negative offsets' '
	test_when_finished "rm -rf hgrepo gitrepo1 gitrepo2" &&

	hg init hgrepo &&

	(
	git clone "hg::hgrepo" gitrepo1 &&
	cd gitrepo1 &&
	echo two >> content &&
	git add content &&
	git commit -m two --date="2016-09-26 00:00:00 -0230" &&
	git push
	) &&

	git clone "hg::hgrepo" gitrepo2 &&

	git --git-dir=gitrepo1/.git log -1 --format="%ai" > expected &&
	git --git-dir=gitrepo2/.git log -1 --format="%ai" > actual &&
	test_cmp expected actual
'

test_done
