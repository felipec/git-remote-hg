RM ?= rm -f

T = $(wildcard *.t)
TEST_DIRECTORY := $(CURDIR)

export TEST_DIRECTORY

all: test

test: $(T)
	$(MAKE) clean

$(T):
	$(SHELL) $@ $(TEST_OPTS)

clean:
	$(RM) -r 'trash directory'.* test-results

.PHONY: all test $(T) clean
