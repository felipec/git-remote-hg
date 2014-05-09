prefix := $(HOME)

all:

test:
	$(MAKE) -C test

D = $(DESTDIR)

install:
	install -D -m 755 git-remote-hg \
		$(D)$(prefix)/bin/git-reinremote-hg

.PHONY: all test
