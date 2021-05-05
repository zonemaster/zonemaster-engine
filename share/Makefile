# This is a wrapper for BSD Make (FreeBSD) to execute
# GNU Make (gmake) and the primary makefile GNUmakefile.

GNUMAKE?= gmake
FILES != ls *

# File targets should be evaluated by gmake.
.PHONY: all $(FILES)

all:
	@${GNUMAKE} $@

.DEFAULT:
	@${GNUMAKE} $@

