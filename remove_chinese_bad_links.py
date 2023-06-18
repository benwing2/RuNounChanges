#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  retval = blib.find_modifiable_lang_section(text, "Chinese", pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  m = re.search(r"\A(.*?)(\n*)\Z", secbody, re.S)
  secbody, secbody_finalnl = m.groups()
  secbody += "\n\n"

  notes = []

  new_secbody = secbody
  new_secbody = re.sub(r"^\* http://www\.trade\.gov\.bt/administration/mktbriefs/10\.pdf\n", "", new_secbody, 0, re.M)
  new_secbody = re.sub(r"^\* http://www\.koreantk\.com/en/m_sta/med_stat_search\.jsp\?searchGbn=statis\n", "", new_secbody, 0, re.M)
  new_secbody = re.sub(r"^\* http://www1\.dict\.li/?\n", "", new_secbody, 0, re.M)
  new_secbody = re.sub(r"^\* http://www1\.dict\.li/ and ", "* ", new_secbody, 0, re.M)
  if new_secbody != secbody:
    notes.append("remove bad Chinese links (see [[Wiktionary:Grease pit/2019/September#Requesting bot help]])")
    secbody = new_secbody
  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  subsections_to_delete = []
  for k in range(1, len(subsections), 2):
    if (subsections[k] in ["===References===\n", "====References====\n"] and
        not subsections[k + 1].strip()):
      subsections_to_delete.append(k)
  if subsections_to_delete:
    for k in reversed(subsections_to_delete):
      del subsections[k:k + 2]
    notes.append("remove empty References section")

  secbody = "".join(subsections)
  sections[j] = secbody.rstrip("\n") + secbody_finalnl + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Remove bad Chinese references and resulting empty References section",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True)
