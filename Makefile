UNICODE_VERSION := 17.0.0
BASE_URL := https://www.unicode.org/Public/$(UNICODE_VERSION)/ucd


.PHONY: all
all: src/Unicode/Normalize/Internal.elm


UnicodeData.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

CompositionExclusions.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

NormalizationTest.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@


src/Unicode/Normalize:
	mkdir src/Unicode/Normalize

.venv:
	poetry install


src/Unicode/Normalize/Internal.elm: generate.py UnicodeData.txt CompositionExclusions.txt | src/Unicode/Normalize .venv
	poetry run python generate.py
