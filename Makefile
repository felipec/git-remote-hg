prefix := $(HOME)

all:

doc: doc/git-remote-hg.1

test:
	$(MAKE) -C test

doc/git-remote-hg.1: doc/git-remote-hg.txt
	a2x -d manpage -f manpage $<

D = $(DESTDIR)

install:
	install -d -m 755 $(D)$(prefix)/bin
	install -m 755 git-remote-hg \
		$(D)$(prefix)/bin/git-remote-hg

install-doc: doc
	install -d -m 755 $(D)$(prefix)/share/man/man1
	install -m 644 doc/git-remote-hg.1 \
		$(D)$(prefix)/share/man/man1/git-remote-hg.1

.PHONY: all test
