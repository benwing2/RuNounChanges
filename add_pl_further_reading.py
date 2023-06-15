#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Polish", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  # Add missing space between * and { in case of {{R:pl:WSJP}} or {{R:pl:PWN}} directly after * without space
  newsecbody = re.sub("^\*\{", "* {", secbody, 0, re.M)
  if newsecbody != secbody:
    notes.append("add missing space after bullet *")
    secbody = newsecbody

  # Remove trailing spaces to avoid issues with spaces after {{R:pl:WSJP}} or {{R:pl:PWN}}
  newsecbody = re.sub(" *\n", "\n", secbody)
  if newsecbody != secbody:
    notes.append("remove extraneous trailing spaces")
    secbody = newsecbody

  # See if there are definition lines that do not contain {{surname}}, {{given name}}, {{verbal noun of}},
  # {{inflection of}} and {{infl of}}.
  lines = secbody.split("\n")
  saw_good_defn_line = False
  bad_templates = ["surname", "given name", "verbal noun of", "inflection of", "infl of"]
  for line in lines:
    if line.startswith("#") and not re.search(r"\{\{(%s)\|pl[|}]" % "|".join(bad_templates), line):
      saw_good_defn_line = True
  if not saw_good_defn_line:
    saw_bad_templates = []
    for bad_template in bad_templates:
      if re.search(r"\{\{%s\|pl[|}]" % bad_template, secbody):
        saw_bad_templates.append(bad_template)
    if saw_bad_templates:
      pagemsg("Skipping page because saw no good definition lines, and saw %s" % (
        " and ".join("{{%s|pl}}" % bad_template for bad_template in saw_bad_templates)))
    else:
      pagemsg("WARNING: Skipping page because saw no good definition lines; didn't see any of %s" % (
        ", ".join("{{%s|pl}}" % bad_template for bad_template in bad_templates)))
    return

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)
    
  # Check for templates in sections outside of 'Further reading'
  for k in range(2, len(subsections), 2):
    if not re.search("^==+Further reading==+\n", subsections[k - 1]):
      if "{{R:pl:WSJP}}" in subsections[k] or "{{R:pl:PWN}}" in subsections[k]:
        if re.search("^==+References==+\n", subsections[k - 1]):
          pagemsg("WARNING: Saw {{R:pl:WSJP}} or {{R:pl:PWN}} in %s section, can't handle" % subsections[k - 1].strip())
          return
        else:
          pagemsg("WARNING: Saw {{R:pl:WSJP}} or {{R:pl:PWN}} in %s section, need to review manually" % subsections[k - 1].strip())

  # Check for References or Further reading already present
  for k in range(2, len(subsections), 2):
    if re.search("^==+Further reading==+\n", subsections[k - 1]):
      newsubsecval = "===Further reading===\n"
      if subsections[k - 1] != newsubsecval:
        for l in range(k + 2, len(subsections), 2):
          if not re.search("^===Anagrams===\n", subsections[l - 1]):
            pagemsg("WARNING: Saw level > 3 Further reading and a following non-Anagrams section %s, can't handle"
                % subsections[l - 1].strip())
            return
        notes.append("replaced %s with level-3 %s" % (subsections[k - 1].strip(), newsubsecval.strip()))
        subsections[k - 1] = newsubsecval
      newsubsec = re.sub(r"^(\* \{\{R:pl:PWN\}\}\n)(.*)(\* \{\{R:pl:WSJP\}\}\n)", r"\3\1\2", subsections[k],
          0, re.M | re.S)
      if newsubsec != subsections[k]:
        notes.append("standardize order of ===Further reading=== with {{R:pl:WSJP}} followed by {{R:pl:PWN}} followed by anything else")
        subsections[k] = newsubsec
      else:
        has_wsjp = "{{R:pl:WSJP}}" in subsections[k]
        has_pwn = "{{R:pl:PWN}}" in subsections[k]
        if has_wsjp and not has_pwn:
          newsubseck = subsections[k].replace("* {{R:pl:WSJP}}\n", "* {{R:pl:WSJP}}\n* {{R:pl:PWN}}\n")
          if newsubseck == subsections[k]:
            pagemsg("WARNING: Unable to add {{R:pl:PWN}} after {{R:pl:WSJP}}")
          else:
            subsections[k] = newsubseck
            notes.append("add {{R:pl:PWN}} to Polish lemma in ===Further reading===")
        elif has_pwn and not has_wsjp:
          newsubseck = subsections[k].replace("* {{R:pl:PWN}}\n", "* {{R:pl:WSJP}}\n* {{R:pl:PWN}}\n")
          if newsubseck == subsections[k]:
            pagemsg("WARNING: Unable to add {{R:pl:WSJP}} before {{R:pl:PWN}}")
          else:
            subsections[k] = newsubseck
            notes.append("add {{R:pl:WSJP}} to Polish lemma in ===Further reading===")
        elif has_wsjp and has_pwn:
          pagemsg("Already has {{R:pl:WSJP}} and {{R:pl:PWN}}")
        else:
          subsections[k] = "* {{R:pl:WSJP}}\n* {{R:pl:PWN}}\n" + subsections[k]
          notes.append("add {{R:pl:WSJP}} and {{R:pl:PWN}} to Polish lemma in ===Further reading===")
      break
  else: # no break
    k = len(subsections) - 1
    while k >= 2 and re.search(r"==\s*Anagrams\s*==", subsections[k - 1]):
      k -= 2
    if k < 2:
      pagemsg("WARNING: No lemma or non-lemma section")
      return
    subsections[k + 1:k + 1] = ["===Further reading===\n* {{R:pl:WSJP}}\n* {{R:pl:PWN}}\n\n"]
    notes.append("add new ===Further reading=== section to Polish lemma with {{R:pl:WSJP}} and {{R:pl:PWN}}")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add {{R:pl:WSJP}} and {{R:pl:PWN}} to Polish 'Further reading' sections",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["Polish lemmas"], edit=True, stdin=True)

blib.elapsed_time()
