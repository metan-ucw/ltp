top_srcdir		?= ..

include $(top_srcdir)/include/mk/env_pre.mk
include $(top_srcdir)/include/mk/functions.mk

MAKE_TARGETS		:= metadata.json docparse metadata.html

INSTALL_DIR = metadata

docparse: data_storage.h

.PHONY: metadata.json

metadata.json: docparse
	./parse.sh > metadata.json

metadata.html: metadata.json
	./testinfo.pl metadata.json html > metadata.html

include $(top_srcdir)/include/mk/generic_leaf_target.mk
