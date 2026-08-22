# Download the UCD files required for normalization.

UNICODE_VERSION := 17.0.0
BASE_URL := https://www.unicode.org/Public/$(UNICODE_VERSION)/ucd


.PHONY: all
all: UnicodeData.txt CompositionExclusions.txt NormalizationTest.txt


UnicodeData.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

CompositionExclusions.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

NormalizationTest.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@
