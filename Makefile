UNICODE_VERSION := 17.0.0
BASE_URL := https://www.unicode.org/Public/$(UNICODE_VERSION)/ucd


.PHONY: all
all: src/Unicode/Normalize/Internal.elm

.PHONY: format
format: | node_modules .venv
	poetry run black --target-version=py312 generate.py generate-tests.py
	pnpm run format

.PHONY: review
review: | node_modules
	pnpm run review

.PHONY: test
test: tests/TestNormalize.elm | node_modules
	pnpm run test


UnicodeData.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

CompositionExclusions.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@

NormalizationTest.txt:
	curl -fsSL -o $@ $(BASE_URL)/$@


src/Unicode/Normalize:
	mkdir src/Unicode/Normalize

tests:
	mkdir tests

node_modules:
	pnpm install

.venv:
	poetry install --with=dev


src/Unicode/Normalize/Internal.elm: generate.py templates/Internal.elm.j2 UnicodeData.txt CompositionExclusions.txt | src/Unicode/Normalize .venv
	poetry run python generate.py

tests/TestNormalize.elm: generate-tests.py templates/TestNormalize.elm.j2 NormalizationTest.txt | tests .venv
	poetry run python generate-tests.py
