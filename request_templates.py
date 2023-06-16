#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from blib import msg

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
  ("rfaccents", {
    "desc": "Request for accents",
    "cat": ["Requests for accents in LANG {{{2}}} entries"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfaspect", {
    "desc": "Request for aspect",
    "cat": ["Requests for aspect in LANG {{{2}}} entries"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfc", {
    "desc": "Request for cleanup",
    "cat": [
      ("Requests for cleanup in LANG entries", "if |lang= is present and either main, Citations, Transwiki or Reconstruction namespaces"),
      ("Requests for cleanup/Others", "if not main, Citations, Transwiki or Reconstruction namespaces"),
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
  ("rfc-pron-n", {
    "desc": "Request for cleanup of 'Pronunciation N' headers (bot-added)",
    "cat": [
      "LANGCODE:Entries with Pronunciation n headers",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfc-sense", {
    "desc": "Request for cleanup of sense",
    "cat": [
      "Requests for cleanup in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfclarify", {
    "desc": "Request for clarification of definition",
    "cat": [
      "Requests for clarification of definitions in LANG entries",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfd-redundant", {
    "desc": "Request for deletion of redundant sense",
    "cat": [
      "Requests for deletion",
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfd-sense", {
    "desc": "Request for deletion of sense",
    "cat": [
      "Requests for deletion in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfdate", {
    "desc": "Request for date in quote",
    "cat": ["Requests for date"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfdatek", {
    "desc": "Request for quote date and details",
    "cat": ["Requests for date/{{{2}}}"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfex", {
    "desc": "Request for usage example for sense",
    "cat": [
      "Requests for example sentences in LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfform", {
    "desc": "Request for particular form in an inflected form",
    "lang1": "req", "langlang": "no"
  }),
  ("rfgender", {
    "desc": "Request for gender",
    "cat": ["Requests for gender in LANG entries"],
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
  ("rfm", {
    "desc": "Request for move, merger or split",
    "cat": [
      ("Requests for moves, mergers and splits", "in all namespaces"),
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfp-old", {
    "desc": "Request for pronunciation of obsolete terms",
    "cat": [
      "Requests for pronunciation in LANG entries",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfquote", {
    "desc": "Request for quote",
    "cat": [
      "Requests for quotations in LANG",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfquote-sense", {
    "desc": "Request for quote for sense",
    "cat": [
      "Requests for quotations in LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfref", {
    "desc": "Request for references",
    "cat": [
      "Requests for references for LANG terms",
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rfscript", {
    "desc": "Request for script",
    "cat": [
      ("Requests for native script for LANG terms", "if |sc= and |usex= not specified"),
      ("Requests for {{{sc}}} script for LANG terms", "if |sc= but not |usex= specified"),
      ("Requests for native script in LANG usage examples", "if |usex= but not |sc= specified"),
      ("Requests for {{{sc}}} script in LANG usage examples", "if |sc= and |usex= specified"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("rftone", {
    "desc": "Request for tone",
    "cat": ["Requests for tone in LANG {{{2}}} entries"],
    "lang1": "req", "langlang": "no"
  }),
  ("rftranslit", {
    "desc": "Request for transliteration",
    "cat": ["Requests for transliteration of LANG terms"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfv-etym", {
    "desc": "Request for verification of etymology",
    "cat": ["Requests for references for etymologies in LANG entries"],
    "lang1": "req", "langlang": "no"
  }),
  ("rfv-pron", {
    "desc": "Request for verification of pronunciation",
    "cat": [
      "Requests for references for pronunciation in LANG entries",
      "Tea room",
      "Requests for attention concerning LANG",
    ],
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
  ("rfv-sense", {
    "desc": "Request for verification of sense",
    "cat": [
      "Requests for verification in LANG entries",
      ("Entries needing topical attention", "if |topic= is present"),
      ("rfd with topic", "if |topic= is present, in all namespaces"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("t-needed", {
    "desc": "Request for translation",
    "cat": [
      ("Requests for translations into LANG", "if |usex= not specified"),
      ("Requests for translations of LANG usage examples", "if |usex= specified"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("tea room", {
    "desc": "Entry being discussed in the Tea Room",
    "cat": [
      "Tea room",
      "Requests for attention concerning LANG",
      ("Entries needing topical attention", "if |topic= is present"),
    ],
    "lang1": "req", "langlang": "no"
  }),
  ("tea room sense", {
    "desc": "Sense being discussed in the Tea Room",
    "cat": [
      "Tea room",
      ("Entries needing topical attention", "if |topic= is present"),
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
  ("rfc-header", {
    "desc": "Request for cleanup of non-standard header (bot-added)",
    "cat": [
      "Entries with non-standard headers",
      ("Entries needing topical attention", "if |topic= is present"),
      "Requests for attention concerning LANG",
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
  ("rfdef", {
    "desc": "Request for definition",
    "cat": [
      "Requests for definitions in LANG entries",
    ],
    "lang1": "req", "langlang": "depwarn"
  }),
  ("rfe", {
    "desc": "Request for etymology",
    "aliases": ["rfelite"],
    "cat": [
      "Requests for etymologies in LANG entries",
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
  ("rfquotek", {
    "desc": "Request for quote esp. for Webster's 1913 entries",
    "cat": [
      "Requests for quotation/{{{2}}}",
      "Requests for quotations in LANG",
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
  ("look", {
    "desc": "Input needed",
    "cat": [
      "Input needed",
      ("Entries needing topical attention", "if |topic= is present"),
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
  ("rft2", {
    "desc": "Template to generate a {{temp|tea room}} invocation (substitutable)",
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
  ("tbot entry", {
    "desc": "Request for clean of Tbot stub translation entry (bot-added)",
    "cat": [
      "Tbot entries {{{4}}} {{{3}}}",
      "Tbot entries ({{{1}}})",
    ],
    "lang1": "no", "langlang": "no"
  }),
  ("Webster 1913", {
    "desc": "Note of incorporation of text from 1913 Webster dictionary",
    "lang1": "no", "langlang": "no"
  }),
]

request_template_map = dict(request_templates)

if __name__ == "__main__":
  for template in sorted(request_template_map.keys()):
    msg("Template:%s" % template)
