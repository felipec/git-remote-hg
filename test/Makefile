RM ?= rm -f

T = main.t bidi.t
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
