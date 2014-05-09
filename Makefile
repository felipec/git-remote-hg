prefix := $(HOME)

all:

doc: doc/git-remote-hg.1

test:
	$(MAKE) -C test

doc/git-remote-hg.1: doc/git-remote-hg.txt
	a2x -d manpage -f manpage $<

D = $(DESTDIR)

install:
	install -D -m 755 git-remote-hg \
		$(D)$(prefix)/bin/git-reinremote-hg

install-doc: doc
	install -D -m 644 doc/git-remote-hg.1 \
		$(D)$(prefix)/share/man/man1/git-remote-hg.1

.PHONY: all test
