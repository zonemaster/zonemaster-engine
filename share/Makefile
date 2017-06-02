POFILES = $(wildcard *.po)
MOFILES := $(POFILES:.po=.mo)

%.mo: %.po
	@mkdir -p locale/$*/LC_MESSAGES
	@perl -e 'use Locale::Msgfmt; msgfmt({in => $$ARGV[0], out => $$ARGV[1]});' $< locale/$*/LC_MESSAGES/Zonemaster.mo
	@echo locale/$*/LC_MESSAGES/Zonemaster.mo

all: ${MOFILES}
	@echo
	@echo Remember to make sure all of the above names are in the
	@echo MANIFEST file, or they will not be installed.
	@echo
