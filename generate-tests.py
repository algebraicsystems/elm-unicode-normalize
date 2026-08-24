import re
from collections import defaultdict
from dataclasses import dataclass
from jinja2 import Template

##
## PARSE TEST DATA
##


@dataclass
class TestCase:
    source: tuple[int]
    nfc: tuple[int]
    nfd: tuple[int]
    nfkc: tuple[int]
    nfkd: tuple[int]


cases = []


def parse_field(field):
    return tuple(map(lambda s: int(s, 16), field.strip().split(" ")))


with open("NormalizationTest.txt", "r") as f:
    for line in f:
        no_comment = line.split("#", 1)[0].strip()
        if not no_comment or no_comment.startswith("@"):
            continue
        fields = no_comment.split(";")
        cases.append(
            TestCase(
                source=parse_field(fields[0]),
                nfc=parse_field(fields[1]),
                nfd=parse_field(fields[2]),
                nfkc=parse_field(fields[3]),
                nfkd=parse_field(fields[4]),
            )
        )


##
## RENDER ELM MODULE
##


def format_elm_string(codepoints):
    return '"' + "".join(f"\\u{{{code:05X}}}" for code in codepoints) + '"'


ELM_MODULE_TEMPLATE = """
module TestNormalize exposing (suite)

import Test exposing (Test)
import Expect

import Unicode.Normalize exposing (Form(..), normalize)

suite : Test
suite =
    Test.describe "Unicode.Normalize"
        [
{% for case in cases %}
            Test.test "Normalizes case {{ loop.index }} to NFC" <|
                \\() -> Expect.equal
                    (normalize NFC {{ format_elm_string(case.source) }})
                    {{ format_elm_string(case.nfc) }},
            Test.test "Normalizes case {{ loop.index }} to NFD" <|
                \\() -> Expect.equal
                    (normalize NFD {{ format_elm_string(case.source) }})
                    {{ format_elm_string(case.nfd) }},
            Test.test "Normalizes case {{ loop.index }} to NFKC" <|
                \\() -> Expect.equal
                    (normalize NFKC {{ format_elm_string(case.source) }})
                    {{ format_elm_string(case.nfkc) }},
            Test.test "Normalizes case {{ loop.index }} to NFKD" <|
                \\() -> Expect.equal
                    (normalize NFKD {{ format_elm_string(case.source) }})
                    {{ format_elm_string(case.nfkd) }}
{%- if not loop.last %},{% endif %}
{% endfor %}
        ]
"""

template = Template(ELM_MODULE_TEMPLATE)
content = template.render(cases=cases, format_elm_string=format_elm_string)

with open("tests/TestNormalize.elm", "w") as f:
    f.write(content)
