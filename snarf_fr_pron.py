#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from collections import defaultdict

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "French", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  has_etym_sections = "==Etymology 1==" in secbody
  saw_pronun_section_at_top = False
  split_pronun_sections = False
  saw_pronun_section_this_etym_section = False
  saw_existing_pron = False
  saw_existing_pron_this_etym_section = False

  etymsection = "top" if has_etym_sections else "all"
  etymsections_to_first_subsection = {}
  etymsections_to_raw_msgs = defaultdict(list)
  if etymsection == "top":
    after_etym_1 = False
    for k in range(2, len(subsections), 2):
      if "==Etymology 1==" in subsections[k - 1]:
        after_etym_1 = True
      if "==Pronunciation==" in subsections[k - 1]:
        if after_etym_1:
          split_pronun_sections = True
        else:
          saw_pronun_section_at_top = True
      m = re.search("==Etymology ([0-9]*)==", subsections[k - 1])
      if m:
        etymsections_to_first_subsection[int(m.group(1))] = k

  msgs = []

  def append_msg(txt):
    if txt not in msgs:
      msgs.append(txt)

  for k in range(2, len(subsections), 2):
    msgs = []
    def check_missing_pronun(etymsection):
      if split_pronun_sections and not saw_existing_pron_this_etym_section:
        pagemsg("WARNING: Missing pronunciations in etym section %s" % etymsection)
        append_msg("MISSING_PRONUN")
        append_msg("NEW_DEFAULTED")
        if etymsections_to_raw_msgs[etymsection]:
          append_msg("EXISTING_RAW: %s" % ",".join(etymsections_to_raw_msgs[etymsection]))
        pagemsg("<respelling> %s: + <end> %s" % (etymsection, " ".join(msgs)))

      #pagemsg("<respelling> %s: %s <end> %s" % ("top" if has_etym_sections else "all",
      #  " ".join(x.replace(" ", "_") for x in respellings), " ".join(msgs)))

    m = re.search("==Etymology ([0-9]*)==", subsections[k - 1])
    if m:
      if etymsection != "top":
        check_missing_pronun(etymsection)
      etymsection = m.group(1)
      saw_pronun_section_this_etym_section = False
      saw_existing_pron_this_etym_section = False
    if "==Pronunciation " in subsections[k - 1]:
      pagemsg("WARNING: Saw Pronunciation N section header: %s" % subsections[k - 1].strip())
    if "==Pronunciation==" in subsections[k - 1]:
      if saw_pronun_section_this_etym_section:
        pagemsg("WARNING: Saw two Pronunciation sections under etym section %s" % etymsection)
      if saw_pronun_section_at_top and etymsection != "top":
        pagemsg("WARNING: Saw Pronunciation sections both at top and in etym section %s" % etymsection)
      saw_pronun_section_this_etym_section = True
      parsed = blib.parse_text(subsections[k])

      respellings = []
      prev_fr_IPA_t = None
      prev_fr_pr_t = None
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "fr-IPA":
          saw_existing_pron = True
          saw_existing_pron_this_etym_section = True
          if prev_fr_IPA_t:
            pronun_lines = re.findall(r"^.*\{\{fr-IPA.*$", subsections[k], re.M)
            pagemsg("WARNING: Saw multiple {{fr-IPA}} templates in a single Pronunciation section: %s" %
              " ||| ".join(pronun_lines))
            must_continue = True
            break
          prev_fr_IPA_t = t
          this_respellings = []
          saw_pronun = False
          last_numbered_param = 0
          for param in t.params:
            pn = pname(param)
            pv = str(param.value).strip().replace("_", r"\u").replace(" ", "_")
            if re.search("^[0-9]+$", pn):
              last_numbered_param += 1
              saw_pronun = True
              pv = pv or "+"
              if pv == "+":
                append_msg("EXISTING_DEFAULTED")
                this_respellings.append("+")
              else:
                append_msg("EXISTING")
                this_respellings.append(pv)
            else:
              this_respellings.append("%s=%s" % (pn, pv))
          if not saw_pronun:
            append_msg("EXISTING_DEFAULTED")
            this_respellings.append("+")
          respellings.extend(this_respellings)
        if tn == "IPA" and getparam(t, "1") == "fr":
          pagemsg("Saw raw: %s" % str(t))
          etymsections_to_raw_msgs[etymsection].append(str(t))
        if tn == "fr-pr":
          saw_existing_pron = True
          saw_existing_pron_this_etym_section = True
          if prev_fr_pr_t:
            pronun_lines = re.findall(r"^.*\{\{fr-pr.*$", subsections[k], re.M)
            pagemsg("WARNING: Saw multiple {{fr-pr}} templates in a single Pronunciation section: %s" %
              " ||| ".join(pronun_lines))
            must_continue = True
            break
          prev_fr_pr_t = t
          this_respellings = []
          saw_pronun = False
          for param in t.params:
            pn = pname(param)
            pv = str(param.value).strip().replace("_", r"\u").replace(" ", "_")
            if re.search("^[0-9]+$", pn):
              saw_pronun = True
              append_msg("EXISTING")
              pv = pv or "+"
              this_respellings.append(pv)
            else:
              this_respellings.append("%s=%s" % (pn, pv))
          if not saw_pronun:
            append_msg("EXISTING_DEFAULTED")
            this_respellings.append("+")
          respellings.extend(this_respellings)
      if must_continue:
        continue

      if args.include_defns and etymsection not in ["top", "all"]:
        first_etym_subsec = etymsections_to_first_subsection.get(int(etymsection), None)
        next_etym_subsec = etymsections_to_first_subsection.get(1 + int(etymsection), None)
        if first_etym_subsec is None:
          pagemsg("WARNING: Internal error: Unknown first etym section for =Etymology %s=" % etymsection)
        else:
          if next_etym_subsec is None:
            next_etym_subsec = len(subsections)
          defns = blib.find_defns("".join(subsections[first_etym_subsec:next_etym_subsec]), "fr")
          append_msg("defns: %s" % ";".join(defns))

      if respellings:
        if etymsections_to_raw_msgs[etymsection]:
          append_msg("EXISTING_RAW: %s" % ",".join(etymsections_to_raw_msgs[etymsection]))
        pagemsg("<respelling> %s: %s <end> %s" % (etymsection, " ".join(respellings), " ".join(msgs)))

  check_missing_pronun(etymsection)
  if not saw_existing_pron:
    if args.include_defns and has_etym_sections:
      for etymsec in sorted(list(etymsections_to_first_subsection.keys())):
        msgs = []
        append_msg("NEW_DEFAULTED")
        if etymsections_to_raw_msgs[etymsec]:
          append_msg("EXISTING_RAW: %s" % ",".join(etymsections_to_raw_msgs[etymsec]))
        first_etym_subsec = etymsections_to_first_subsection[etymsec]
        next_etym_subsec = etymsections_to_first_subsection.get(1 + etymsec, None)
        if next_etym_subsec is None:
          next_etym_subsec = len(subsections)
        append_msg("NEW_DEFAULTED")
        defns = blib.find_defns("".join(subsections[first_etym_subsec:next_etym_subsec]), "fr")
        append_msg("defns: %s" % ";".join(defns))
        respellings = ["+"]
        pagemsg("<respelling> %s: %s <end> %s" % (etymsec, " ".join(respellings), " ".join(msgs)))
    else:
      if etymsections_to_raw_msgs:
        pagemsg("etymsections_to_raw_msgs: %s" % etymsections_to_raw_msgs)
      etymsec = "top" if has_etym_sections else "all"
      msgs = []
      append_msg("NEW_DEFAULTED")
      if etymsections_to_raw_msgs[etymsec]:
        append_msg("EXISTING_RAW: %s" % ",".join(etymsections_to_raw_msgs[etymsec]))
      respellings = ["+"]
      pagemsg("<respelling> %s: %s <end> %s" % (etymsec, " ".join(respellings), " ".join(msgs)))

if __name__ == "__main__":
  parser = blib.create_argparser("Snarf French pronunciations for fixing", include_pagefile=True, include_stdin=True)
  parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
  parser.add_argument("--include-defns", action="store_true", help="Include defns of snarfed terms (helps with multi-etym sections).")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
