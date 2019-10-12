#!/usr/bin/env python
# -*- coding: utf-8 -*-

from blib import msg

request_template_list = [
  # With <code>lang=</code> (no default; disables language-specific behavior)
  "rfc-header",
  "tea room",
  "beer",
  # Allows <code>1=</code> or <code>lang=</code> (no default; disables language-specific behavior)
  "rfc",
  # Error when the lang is missing
  "rfc-level",
  "rfdate",
  "rfgender",
  "rfscript",
  "rfscriptcat",
  "rfv-quote",
  "rftranslit",
  "t-needed",
  "rftrans", # alias of t-needed
  # With <code>1=</code> (accepts <code>lang=</code>, but issues a deprecation warning)
  "etystub",
  "rfap",
  "rfc-pron-n",
  "rfc-sense",
  "rfclarify",
  "rfd",
  "rfd-redundant",
  "rfd-sense",
  "rfdecl",
  "rfelite",
  "rfex",
  "rfform",
  "rfi",
  "rfinfl",
  "rfp",
  "rfp-old",
  "rfquote",
  "rfquote-sense",
  "rfref",
  "rfv",
  "rfv-etym",
  "rfv-pron",
  "rfv-sense",
  "tea room sense",
  # Allows <code>1=</code> or <code>lang=</code> (<code>1=</code> should be used in new uses)
  "rfdatek",
  "rfdef",
  "rfe",
  "rfm",
  "rfquotek",
  "attention",
  # Unclassified
  "ase-rfr",
  "copyvio suspected",
  "delete",
  "merge",
  "move",
  "rfc-auto",
  "rfexp",
  "rfm-sense",
  "MW1913Abbr",
  "no inline",
  "rfi0",
  "rf-sound example",
  "split",
  "rftaxon",
  "transtranslitreqboiler",
  "unblock",
  "USRegionDisputed",
  "rfqez",
  "rft2",
  # Cleanup templates
  "broken ref",
  "checksense",
  # "rfc-sense",
  "missing template",
  "Nuttall",
  "oed1923",
  # "rfc-auto",
  # "rfc-header",
  "stub entry",
  "tbot entry",
  "ttbc",
  "Webster 1913",
]

request_templates = [
  # Allows <code>1=</code> or <code>lang=</code> (no default; disables language-specific behavior)
  ("ttbc", {
    "desc": "Request for checking of translation (deprecated)",
    "cat": [
      ("Requests for review of LANG translations", "if valid lang code or name in |1="),
      ("Translations to be checked ({{1}}})", "if valid lang name in |1=; in all namespaces"),
      ("Translations to be checked (Undetermined)", "if |1= does not contain valid lang code or name; in all namespaces"),
      ("Language code is name/ttbc/unrecognised", "if |1= does not contain valid lang code or name; in all namespaces"),
    ],
    "lang1": "defund", "langlang": "no"
  }),
  # With <code>1=</code> (no default; disables language-specific behavior)
  ("rfscriptcat", {
    "desc": "Boiler for categories for entries where native script is requested",
    "cat": [
      ("LANG terms needing native script|SCRIPT", "if |1= and |sc= are present"),
      ("Terms needing native script by language", "if |1= but not |sc= are present"),
      ("LANG entry maintenance|terms needing native script", "if |1= but not |sc= are present"),
      ("Entry maintenance subcategories by language", "if |1= not present"),
    ],
    "lang1": "nodef", "langlang": "no"
  }),
  # Requires <code>1=</code> (error when the lang is missing)
  ("attention", {
    "aliases": ["attn"],
    "desc": "Request for attention",
    "cat": [
      "Requests for attention concerning LANG",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("beer", {
    "desc": "Entry being discussed in the Beer Parlour",
    "cat": [
      "Tea room",
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfc-level", {
    "desc": "Request for cleanup of entry with level or structure problems (bot-added)",
    "cat": [
      "Entries with level or structure problems",
      "Requests for attention concerning LANG",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfdate", {
    "desc": "Request for date in quote",
    "cat": ["Requests for date"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfdecl", {
    "desc": "Request for declension",
    "cat": [
      "Requests for inflections in LANG {{{2}}} entries",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfgender", {
    "desc": "Request for gender",
    "cat": ["LANG terms with incomplete gender"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfi", {
    "desc": "Request for image (photo or drawing)",
    "cat": [
      "Requests for images in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfinfl", {
    "desc": "Request for inflection",
    "cat": [
      "Requests for inflections in LANG {{{2}}} entries",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfscript", {
    "desc": "? (invokes module)",
    "cat": ["? (invokes module)"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfv-quote", {
    "desc": "Request for quote verification",
    "cat": [
      "Requests for quotation", 
      "Requests for quotations in LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rftranslit", {
    "desc": "Request for transliteration",
    "cat": ["LANG terms needing transliteration"],
    "lang1": "req", "langlang": "no"
  }),
  ("t-needed", {
    "aliases": ["rftrans"],
    "desc": "Request for translation",
    "cat": ["Requests for transliterations into LANG"],
    "lang1": "req", "langlang": "no"
  }),
  "transtranslitreqboiler",
    "desc": "Category boiler for requests for transliterations in translations from English",
    "cat": [
      ("LANG translations needing attention", "in all namespaces"),
      ("LANG terms needing attention", "in all namespaces"),
      ("Translations which need romanization", "in all namespaces"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("checksense", {
    "desc": "Request for allocation of synonyms/antonyms to senses",
    "cat": [
      "LANG terms needing to be assigned to a sense",
    ],
    "lang1": "req", "langlang": "no"
  }),
  # Requires <code>1=</code> (accepts <code>lang=</code>, but issues a deprecation warning)
  ("etystub", {
    "desc": "Request for expansion of etymology",
    "cat": ["Requests for expansion of etymologies in LANG entries"],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfap", {
    "desc": "Request for audio pronunciation",
    "cat": [
      "Requests for audio pronunciation in LANG entries",
      ("rfap with variety", "if |variety= is present, in all namespaces"),
      ("Requests for audio pronunciation from {{{variety}}} in LANG entries",
        "if |variety= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfc", {
    "desc": "Request for cleanup",
    "cat": [
      ("Requests for cleanup in LANG entries", "if |lang= is present and either main, Citations, Transwiki or Reconstruction namespaces"),
      ("Requests for cleanup/Others", "if not main, Citations, Transwiki or Reconstruction namespaces"),
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfc-header", {
    "desc": "Request for cleanup of non-standard header (bot-added)",
    "cat": [
      "Entries with non-standard headers",
      ("Entries needing topical attention", "if |topic= is present"),
      "Requests for attention concerning LANG",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfc-pron-n", {
    "desc": "Request for cleanup of 'Pronunciation N' headers (bot-added)",
    "cat": [
      "LANGCODE:Entries with Pronunciation n headers",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfc-sense", {
    "desc": "Request for cleanup of sense",
    "cat": [
      "Requests for cleanup in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfclarify", {
    "desc": "Request for clarification of definition",
    "cat": [
      "Requests for clarification of definitions in LANG entries",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfd", {
    "desc": "Request for deletion of entry",
    "cat": [
      ("Requests for deletion in LANG entries", "if in main, Citations, Transwiki or Reconstruction namespaces"),
      ("Requests for deletion/Others", "if not in main, Citations, Transwiki or Reconstruction namespaces"),
      ("rfd with topic", "if |topic= is present, in all namespaces"),
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfd-redundant", {
    "desc": "Request for deletion of redundant sense",
    "cat": [
      "Requests for deletion",
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfd-sense", {
    "desc": "Request for deletion of sense",
    "cat": [
      "Requests for deletion in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfdatek", {
    "desc": "Request for quote date and details",
    "cat": ["Requests for date/{{{2}}}"],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfelite", {
    "desc": "Request for etymology",
    "cat": [
      "Requests for etymologies in LANG entries",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfex", {
    "desc": "Request for usage example for sense",
    "cat": [
      "Requests for example sentences in LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfform", {
    "desc": "Request for particular form in an inflected form",
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfm", {
    "desc": "Request for move, merger or split",
    "cat": [
      ("Requests for moves, mergers and splits", "in all namespaces"),
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfp", {
    "desc": "Request for pronunciation",
    "cat": [
      "Requests for pronunciation in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfp-old", {
    "desc": "Request for pronunciation of obsolete terms",
    "cat": [
      "Requests for pronunciation in LANG entries",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfquote", {
    "desc": "Request for quote",
    "cat": [
      "Requests for quotations in LANG",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfquote-sense", {
    "desc": "Request for quote for sense",
    "cat": [
      "Requests for quotations in LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfquotek", {
    "desc": "Request for quote esp. for Webster's 1913 entries",
    "cat": [
      "Requests for quotation/{{{2}}}",
      "Requests for quotations in LANG",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfref", {
    "desc": "Request for references",
    "cat": [
      "Requests for references for LANG terms",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfv", {
    "desc": "Request for verification",
    "cat": [
      "Requests for verification in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfv-etym", {
    "desc": "Request for verification of etymology",
    "cat": [
      "Requests for references for etymologies in LANG entries",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfv-pron", {
    "desc": "Request for verification of pronunciation",
    "cat": [
      "Requests for references for pronunciation in LANG entries",
      "Tea room",
      "Requests for attention concerning LANG",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfv-sense", {
    "desc": "Request for verification of sense",
    "cat": [
      "Requests for verification in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
      ("rfd with topic", "if |topic= is present, in all namespaces"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("tea room", {
    "desc": "Entry being discussed in the Tea Room",
    "cat": [
      "Tea room",
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("tea room sense", {
    "desc": "Sense being discussed in the Tea Room",
    "cat": [
      "Tea room",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  # Requires <code>1=</code> or <code>lang=</code> (<code>1=</code> should be used in new uses)
  ("rfdef", {
    "desc": "Request for definition",
    "cat": [
      "Requests for definitions in LANG entries",
    ],
    "lang1": "req", "langlang": "dep"
  }),
  ("rfe", {
    "desc": "Request for etymology",
    "cat": [
      "Requests for etymologies in LANG entries",
    ],
    "lang1": "req", "langlang": "dep"
  }),
  # Doesn't have a language parameter
  ("ase-rfr", {
    "desc": "Request for renaming of an ASL (American Sign Language) entry",
    "cat": [
      "Requests for attention concerning LANG",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("copyvio suspected", {
    "desc": "Copyright violation suspected",
    "cat": [
      ("Copyright violations suspected", "in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("delete", {
    "aliases": ["d", "speedy"],
    "desc": "Request for speedy deletion",
    "cat": [
      ("Candidates for speedy deletion", "in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("merge", {
    "desc": "Request for merger",
    "cat": [
      ("Pages to be merged", "in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("move", {
    "desc": "Request for move",
    "cat": [
      ("Pages to be moved", "in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rfc-auto", {
    "desc": "Request for autoformat",
    "cat": [
      "Requests for autoformat",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rfexp", {
    "desc": "Request for expansion of appendix",
    "cat": [
      "Requests for expansion",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rfm-sense", {
    "desc": "Request for move, merger or split of sense",
    "cat": [
      "Requests for moves, mergers and splits",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("MW1913Abbr", {
    "desc": "Link to [[Wiktionary:Abbreviated Authorities in Webster]]",
    "lang1": "no", "langlang": "no"
  }),
  ("no inline", {
    "desc": "Request for inline citation",
    "cat": [
      "Entries needing inline citations",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rfi0", {
    "desc": "Request for photograph",
    "cat": [
      "Requests for photographs",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rf-sound example", {
    "desc": "Request for sound clip",
    "lang1": "no", "langlang": "no"
  }),
  ("split", {
    "desc": "Request for split",
    "cat": [
      ("Pages to be split", "in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rftaxon", {
    "desc": "Request for taxonomic name",
    "cat": [
      "Requests for taxonomic names",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("unblock", {
    "desc": "Request for unblock",
    "cat": [
      ("Requests for unblock", "if in User or User talk namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("USRegionDisputed", {
    "desc": "Disputing of US regional distribution for an English term",
    "cat": [
      "English terms with disputed US regional distribution",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rfqez", {
    "desc": "Request for quotation (substitutable)",
    "cat": [
      ("Requests for quotation by source", "in all namespaces"),
      ("Requests for quotation/{{{1}}}", "if |1= present; in all namespaces"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("rft2", {
    "desc": "Template to generate a {{tea room}} invocation (substitutable)",
    "lang1": "no", "langlang": "no"
  }),
  # Cleanup templates
  ("broken ref", {
    "desc": "Request for cleanup of broken ref",
    "cat": [
      ("{{{cat}}}", "if |cat= present; in all namespaces but MediaWiki"),
      ("Pages with incorrect ref formatting", "if |cat= not present; in all namespaces but MediaWiki"),
    ],
    "lang1": "no", "langlang": "no"
  }),
  # "rfc-sense",
  ("missing template", {
    "desc": "Request for template creation",
    "lang1": "no", "langlang": "no"
  }),
  ("Nuttall", {
    "desc": "Notice of incorporation of text from 1907 Nuttall Encyclopedia",
    "cat": [
      "Nuttall Encyclopedia",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("oed1923", {
    "desc": "Notice of incorporation of text from first-edition OED",
    "lang1": "no", "langlang": "no"
  }),
  # "rfc-auto",
  # "rfc-header",
  ("stub entry", {
    "desc": "Request for expansion of stub entry (bot-added)",
    "cat": [
      "Stub entries ({{{1}}})",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("tbot entry",
    "desc": "Request for clean of Tbot stub translation entry (bot-added)",
    "cat": [
      "Tbot entries {{{4}}} {{{3}}}",
      "Tbot entries ({{{1}}})",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("Webster 1913", {"lang1": "no", "langlang": "no"}),
]

request_template_map = dict(request_templates)

if __name__ == "__main__":
  for template in request_template_list:
    msg("Template:%s" % template)
