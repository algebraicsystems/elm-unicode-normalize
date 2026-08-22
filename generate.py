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


ELM_MODULE_TEMPLATE = """
module Unicode.Normalize.Internal exposing
    ( canonicalDecomposition
    , compatibleDecomposition
    , combiningClass
    , canonicalComposition
    )

canonicalDecomposition : Int -> List Int
canonicalDecomposition code =
    case code of
{%- for code in canonical_mappings %}
        {{ code }} -> [ {{ canonical_mappings[code] | join(', ') }} ]
{%- endfor %}
        _ -> [ code ]

compatibleDecomposition : Int -> List Int
compatibleDecomposition code =
    case code of
{%- for code in compatible_mappings %}
        {{ code }} -> [ {{ compatible_mappings[code] | join(', ') }} ]
{%- endfor %}
        _ -> [ code ]

combiningClass : Int -> Int
combiningClass code =
    case code of
{%- for code in combining_classes %}
        {{ code }} -> {{ combining_classes[code] }}
{%- endfor %}
        _ -> 0

canonicalComposition : Int -> Int -> Maybe Int
canonicalComposition code1 code2 =
    case code1 of
{%- for code1 in canonical_compositions %}
        {{ code1 }} -> case code2 of
{%- for code2 in canonical_compositions[code1] %}
            {{ code2 }} -> Just {{ canonical_compositions[code1][code2] }}
{%- endfor %}
            _ -> Nothing
{%- endfor %}
        _ -> Nothing
"""

template = Template(ELM_MODULE_TEMPLATE)
content = template.render(
    canonical_mappings={
        c: recursive_canonical_decompose(c) for c in canonical_mappings
    },
    compatible_mappings={
        c: recursive_compatible_decompose(c)
        for c in canonical_mappings | compatible_mappings
    },
    combining_classes=combining_classes,
    canonical_compositions=canonical_compositions,
)

with open("src/Unicode/Normalize/Internal.elm", "w") as f:
    f.write(content)
