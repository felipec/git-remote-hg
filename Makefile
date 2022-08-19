prefix := $(HOME)

bindir := $(prefix)/bin
mandir := $(prefix)/share/man/man1

all: doc

doc: doc/git-remote-hg.1

test:
	$(MAKE) -C test

doc/git-remote-hg.1: doc/git-remote-hg.txt
	asciidoctor -b manpage $<

clean:
	$(RM) doc/git-remote-hg.1

D = $(DESTDIR)

install:
	install -d -m 755 $(D)$(bindir)/
	install -m 755 git-remote-hg $(D)$(bindir)/git-remote-hg

install-doc: doc
	install -d -m 755 $(D)$(mandir)/
	install -m 644 doc/git-remote-hg.1 $(D)$(mandir)/git-remote-hg.1

.PHONY: all test install install-doc clean
