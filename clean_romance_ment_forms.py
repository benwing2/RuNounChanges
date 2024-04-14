#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from blib import ParseException

def process_text_on_page(pageindex, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageindex, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  saw_affix_template_with_ment = False

  def fix_up_section(secbody, etym_level):
    nonlocal saw_affix_template_with_ment
    subsections, subsections_by_header, subsection_headers, subsection_levels = blib.split_text_into_subsections(
        secbody, pagemsg)
    etymsec_text = " for Etymology %s" % etym_level if etym_level else ""
    if "Noun" in subsections_by_header and "Adverb" in subsections_by_header:
      pagemsg("WARNING: Saw both noun and adverb sections%s, skipping" % etymsec_text)
      return secbody
    if "Noun" in subsections_by_header:
      id = "nominal"
      pagemsg("Inferred id=nominal%s based on existing Noun section" % etymsec_text)
    elif "Adverb" in subsections_by_header:
      id = "adverbial"
      pagemsg("Inferred id=adverbial%s based on existing Adverb section" % etymsec_text)
    else:
      pagemsg("WARNING: Didn't see either noun or adverb sections%s, skipping" %  etymsec_text)
      return secbody

    if etym_level > 0:
      subsec_index = 0
    elif "Etymology" in subsections_by_header:
      msg("subsections_by_header: " + repr(subsections_by_header["Etymology"]))
      if len(subsections_by_header["Etymology"]) > 1:
        pagemsg("WARNING: Saw multiple Etymology sections, skipping")
        return secbody
      else:
        subsec_index = subsections_by_header["Etymology"][0]
    else:
      return secbody

    parsed = blib.parse_text(subsections[subsec_index])
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn in ["af", "affix", "suf", "suffix"]:
        is_suffix = tn in ["suf", "suffix"]
        numbered = blib.fetch_param_chain(t, "2")
        for affix_index, affix in enumerate(numbered):
          if affix == "-ment" or is_suffix and affix == "ment" or affix.startswith("-ment<") or is_suffix and affix.startswith("ment<"):
            saw_affix_template_with_ment = True
            id_param = "id%s" % ("" if affix_index == 0 else str(affix_index + 1))
            existing_id = getp(id_param)
            if existing_id:
              if existing_id == id:
                pagemsg("Skipping %s with %s=%s%s already" % (str(t), id_param, existing_id, etymsec_text))
              else:
                pagemsg("WARNING: Skipping %s with %s=%s%s, different from desired '%s'" % (
                  str(t), id_param, existing_id, etymsec_text, id))
              continue

          if affix == "-ment" or is_suffix and affix == "ment":
            new_affix = "%s<id:%s>" % (affix, id)
            pagemsg("Replacing %s=%s with %s=%s in %s%s" % (
              affix_index + 2, affix, affix_index + 2, new_affix, str(t), etymsec_text))
            notes.append("replace %s=%s with %s=%s in {{%s|%s}}%s" % (
              affix_index + 2, affix, affix_index + 2, new_affix, tn, getp("1"), etymsec_text))
            t.add(str(affix_index + 2), new_affix)
          elif affix.startswith("-ment<") or is_suffix and affix.startswith("ment<"):
            try:
              inlinemod = blib.parse_inline_modifier(affix)
            except e as ParseException:
              pagemsg("WARNING: Unable to parse inline modifier spec %s" % affix)
              continue
            affix_id = inlinemod.get_modifier("id")
            if affix_id is not None:
              if affix_id == id:
                pagemsg("Skipping %s with <id:%s>%s already" % (str(t), affix_id, etymsec_text))
              else:
                pagemsg("WARNING: Skipping %s with <id:%s>%s, different from desired '%s'" % (
                  str(t), affix_id, etymsec_text, id))
              continue
            inlinemod.set_modifier("id", id)
            new_affix = inlinemod.reconstruct_param()
            pagemsg("Replacing %s=%s with %s=%s in %s%s" % (
              affix_index + 2, affix, affix_index + 2, new_affix, str(t), etymsec_text))
            notes.append("replace %s=%s with %s=%s in {{%s|%s}}%s" % (
              affix_index + 2, affix, affix_index + 2, new_affix, tn, getp("1"), etymsec_text))
            t.add(str(affix_index + 2), new_affix)
    subsections[subsec_index] = str(parsed)
    return "".join(subsections)

  if "==Etymology 1==" not in secbody:
    secbody = fix_up_section(secbody, 0)
  else:
    etym_sections = re.split("(^===Etymology [0-9]+===\n)", secbody, 0, re.M)
    for k in range(2, len(etym_sections), 2):
      etym_sections[k] = fix_up_section(etym_sections[k], k // 2)
    secbody = "".join(etym_sections)

  if not saw_affix_template_with_ment:
    pagemsg("WARNING: Didn't see {{af}}/{{affix}} or {{suf}}/{{suffix}} template with -ment, category might be specified some other way")

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes
  return text, notes

parser = blib.create_argparser("Add <id:nominal> or <id:verbal> to {{af}} or {{affix}} etymology as appropriate for Gallo-Romance terms ending in -ment", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langname", help="Name of language whose section to fetch; required unless --partial-page is given.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                          default_cats=args.langname and ["%s terms suffixed with -ment" % args.langname] or None)
