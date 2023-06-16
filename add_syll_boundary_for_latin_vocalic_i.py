#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

# WARNING: Not idempotent when both --add-dot-after-i and --convert-j is used.
# In general, --add-dot-after-i should be used before --convert-j.

prefixes = [
  "ab",
  "ad",
  "circum",
  "con",
  "dis",
  "ex",
  "in",
  "inter",
  "ob",
  "per",
  "sub",
  "subter",
  "super",
  ["trans", u"trāns"],
]

vowel_re = u"[aeiouyāēīōūȳăĕĭŏŭ]"

def process_page(page, index, add_dot_after_i, convert_j):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  text = str(page.text)
  origtext = text

  retval = lalib.find_latin_section(text, pagemsg)
  if retval is None:
    return None, None

  sections, j, secbody, sectail, has_non_latin = retval

  notes = []

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    if tname(t) == "la-IPA":
      param1 = getparam(t, "1") or pagetitle
      for prefix in prefixes:
        if type(prefix) is list:
          prefix, macron_prefix = prefix
        else:
          macron_prefix = prefix
        orig_param1 = param1
        if re.search("^%s[ij]" % macron_prefix, param1):
          if re.search(u"^%si%s" % (macron_prefix, vowel_re), param1) and add_dot_after_i:
            param1 = re.sub("^%si" % macron_prefix, "%si." % macron_prefix, param1)
            notes.append("add dot after i in {{la-IPA}} to force vocalic pronunciation")
          elif re.search("^%sj%s" % (macron_prefix, vowel_re), param1) and convert_j:
            param1 = re.sub("^%sj" % macron_prefix, "%si" % macron_prefix, param1)
            notes.append("convert j to i in {{la-IPA}} to match pagename; j no longer necessary to force consonantal pronunciation")
          if param1 != orig_param1:
            origt = str(t)
            # Fetch all params.
            params = []
            for param in t.params:
              pname = str(param.name)
              if pname.strip() not in ["1"]:
                params.append((pname, param.value, param.showkey))
            # Erase all params.
            del t.params[:]
            t.add("1", param1)
            # Put remaining parameters in order.
            for name, value, showkey in params:
              t.add(name, value, showkey=showkey, preserve_spacing=False)
            pagemsg("Replaced %s with %s" % (origt, str(t)))
          break
      else:
        # no break
        pagemsg("WARNING: Unable to match pronun template against any prefixes: %s" % str(t))

  secbody = str(parsed)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add syllabic boundary to {{la-IPA}} for vocalic i that would be interpreted as consonantal",
    include_pagefile=True)
parser.add_argument("--add-dot-after-i", help="Add dot after 'i' to make sure it's syllabic", action="store_true")
parser.add_argument("--convert-j", help="Convert 'j' back to 'i' after prefix", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

def page_needs_investigating(pagetitle):
  for prefix in prefixes:
    if type(prefix) is list:
      prefix = prefix[0]
    if re.search("^%si[aeiouy]" % prefix, pagetitle):
      return True
  return False

def do_process_page(page, index, parsed):
  return process_page(page, index, args.add_dot_after_i, args.convert_j)
blib.do_pagefile_cats_refs(args, start, end, do_process_page, default_refs=["Template:la-IPA"], edit=True,
    filter_pages=page_needs_investigating)
