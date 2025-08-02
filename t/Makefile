RM ?= rm -f

T = $(wildcard *.t)
SHARNESS_TEST_DIRECTORY := $(CURDIR)

export SHARNESS_TEST_DIRECTORY

all: test

test: $(T)
	$(MAKE) clean

$(T):
	./$@ $(TEST_OPTS)

clean:
	$(RM) -r 'trash directory'.* test-results

.PHONY: all test $(T) clean
