#!/bin/bash

test_description='Test topic extension'

. ./test-lib.sh

if ! python -c 'import hgext3rd.topic' > /dev/null 2>&1
then
	skip_all='topic extension not available'
	test_done
fi

check () {
	echo "$3" > expected &&
	git -C "$1" log --format='%s' -1 "$2" > actual &&
	test_cmp expected actual
}

setup () {
	cat > "$HOME"/.hgrc <<-EOF
	[ui]
	username = H G Wells <wells@example.com>
	[extensions]
	topic =
	EOF
}

setup

test_expect_success 'setup' '
	(
	hg init hgrepo &&
	cd hgrepo &&
	echo zero > content &&
	hg add content &&
	hg commit -m zero &&
	hg topic topic1 &&
	echo one > content &&
	hg commit -m one
	)
'

test_expect_success 'cloning' '
	git clone "hg::hgrepo" gitrepo &&
	check gitrepo origin/topics/default/topic1 one
'

test_expect_success 'pushing' '
	(
	cd gitrepo &&
	git checkout -b topics/default/topic2 &&
	echo two > content &&
	git commit -a -m two &&
	git push origin @
	) &&
	hg -R hgrepo log --template "{desc}\n" -r topic2 > actual &&
	echo two > expected &&
	test_cmp expected actual
'

test_done
