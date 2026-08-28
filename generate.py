import re
from collections import defaultdict
from jinja2 import Template

##
## PARSE UNICODE DATA
##

canonical_mappings = {}
compatible_mappings = {}
combining_classes = {}
canonical_compositions = defaultdict(dict)


with open("UnicodeData.txt", "r") as f:
    for line in f:
        fields = line.strip().split(";")

        code = int(fields[0], 16)
        ccc = int(fields[3]) if fields[3] else 0
        mapping = fields[5]

        if ccc != 0:
            combining_classes[code] = ccc

        if mapping:
            if match := re.fullmatch(r"<[a-zA-Z]*>(.*)", mapping):
                decomposed = match.group(1).strip().split(" ")
                compatible_mappings[code] = tuple(map(lambda s: int(s, 16), decomposed))
            else:
                decomposed = mapping.strip().split(" ")
                canonical_mappings[code] = tuple(map(lambda s: int(s, 16), decomposed))

##
## PARSE COMPOSITION EXCLUSIONS
##

composition_exclusions = set()


with open("CompositionExclusions.txt", "r") as f:
    for line in f:
        content = line.split("#", 1)[0].strip()
        if content:
            composition_exclusions.add(int(content, 16))

##
## ADD DERIVED COMPOSITION EXCLUSIONS
##

for code, decomposed in canonical_mappings.items():
    if len(decomposed) >= 2 and (
        code in combining_classes or decomposed[0] in combining_classes
    ):
        composition_exclusions.add(code)

##
## BUILD CANONICAL COMPOSITIONS
##

for code, decomposed in canonical_mappings.items():
    if code in composition_exclusions:
        continue
    if len(decomposed) == 2:
        canonical_compositions[decomposed[0]][decomposed[1]] = code

##
## BUILD RECURSIVE DECOMPOSITIONS
##


def recursive_canonical_decompose(code):
    if code in canonical_mappings:
        return [
            final
            for mapped in canonical_mappings[code]
            for final in recursive_canonical_decompose(mapped)
        ]
    else:
        return [code]


def recursive_compatible_decompose(code):
    if code in canonical_mappings:
        return [
            final
            for mapped in canonical_mappings[code]
            for final in recursive_compatible_decompose(mapped)
        ]
    elif code in compatible_mappings:
        return [
            final
            for mapped in compatible_mappings[code]
            for final in recursive_compatible_decompose(mapped)
        ]
    else:
        return [code]


##
## RENDER ELM MODULE
##


with open("templates/Internal.elm.j2", "r") as f:
    template = Template(f.read())

full_canonical_mappings = {
    c: recursive_canonical_decompose(c) for c in canonical_mappings
}

full_compatible_mappings = {
    c: recursive_compatible_decompose(c) for c in canonical_mappings | compatible_mappings
}

for c in canonical_mappings:
    if full_compatible_mappings.get(c) == full_canonical_mappings[c]:
        del full_compatible_mappings[c]

content = template.render(
    canonical_mappings=full_canonical_mappings,
    compatible_mappings=full_compatible_mappings,
    combining_classes=combining_classes,
    canonical_compositions=canonical_compositions,
)

with open("src/Unicode/Normalize/Internal.elm", "w") as f:
    f.write(content)
