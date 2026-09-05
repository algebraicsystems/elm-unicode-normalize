import jinja2
import re
from collections import defaultdict
from itertools import groupby

##
## PARSE UNICODE DATA
##

canonical_mappings = {}
compatible_mappings = {}
combining_classes = defaultdict(set)
canonical_compositions = defaultdict(dict)
non_starters = set()


with open("UnicodeData.txt", "r") as f:
    for line in f:
        fields = line.strip().split(";")

        code = int(fields[0], 16)
        ccc = int(fields[3]) if fields[3] else 0
        mapping = fields[5]

        if ccc != 0:
            combining_classes[ccc].add(code)
            non_starters.add(code)

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
    if len(decomposed) >= 2 and (code in non_starters or decomposed[0] in non_starters):
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
## BUILD COMBINING CLASS RANGES
##

combining_class_singles = {}
combining_class_ranges = {}

for ccc in combining_classes:
    ranges = []
    for _, group in groupby(
        enumerate(sorted(combining_classes[ccc])), lambda pair: pair[1] - pair[0]
    ):
        group_list = [val for _, val in group]
        if group_list[0] != group_list[-1]:
            ranges.append((group_list[0], group_list[-1]))
        else:
            combining_class_singles[group_list[0]] = ccc

    if ranges:
        combining_class_ranges[ccc] = ranges


##
## RENDER ELM MODULE
##

def elm_unicode_char(value):
    return f"'\\u{{{value:04X}}}'"

def elm_unicode_string(values):
    return "\"" + "".join(f"\\u{{{value:04X}}}" for value in values) + "\""

env = jinja2.Environment(loader=jinja2.FileSystemLoader('templates'))
env.filters['elm_unicode_char'] = elm_unicode_char
env.filters['elm_unicode_string'] = elm_unicode_string

template = env.get_template("Internal.elm.j2")

full_canonical_mappings = {
    c: recursive_canonical_decompose(c) for c in canonical_mappings
}

full_compatible_mappings = {
    c: recursive_compatible_decompose(c)
    for c in canonical_mappings | compatible_mappings
}

for c in canonical_mappings:
    if full_compatible_mappings.get(c) == full_canonical_mappings[c]:
        del full_compatible_mappings[c]

content = template.render(
    canonical_mappings=full_canonical_mappings,
    compatible_mappings=full_compatible_mappings,
    combining_class_singles=combining_class_singles,
    combining_class_ranges=combining_class_ranges,
    canonical_compositions=canonical_compositions,
)

with open("src/Unicode/Normalize/Internal.elm", "w") as f:
    f.write(content)
