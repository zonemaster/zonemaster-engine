POFILES = $(wildcard *.po)
MOFILES := $(POFILES:.po=.mo)
POTFILE = Zonemaster-Engine.pot

.PHONY: all update-po extract-pot

all: ${MOFILES}
	@echo
	@echo Remember to make sure all of the above names are in the
	@echo MANIFEST file, or they will not be installed.
	@echo

update-po: extract-pot $(POFILES)

extract-pot:
	../util/extract_po.pl > $@

$(POTFILE): extract-pot

%.po: $(POTFILE)
	msgmerge --update --backup=none $(MSGMERGE_OPTS) $@ $(POTFILE)

%.mo: %.po
	@mkdir -p locale/$*/LC_MESSAGES
	@# It must be 'Zonemaster-Engine' because that is defined in "name" in Makefile.PL
	@perl -e 'use Locale::Msgfmt; msgfmt({in => $$ARGV[0], out => $$ARGV[1]});' $< locale/$*/LC_MESSAGES/Zonemaster-Engine.mo
	@echo locale/$*/LC_MESSAGES/Zonemaster-Engine.mo
