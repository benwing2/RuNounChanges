#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

templates_to_convert = [
  "der-top", "der-top3", "der-top4", "der-top5",
  "rel-top", "rel-top3", "rel-top4", "rel-top5",
]
template_bottoms = ["der-bottom", "rel-bottom"]
other_template_bottoms = ["col-bottom", "bottom"]

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  parsed = blib.parse_text(text)
  top_t = None
  top_tn = None
  top_title = None
  top_ncol = None
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in templates_to_convert:
      if top_t:
        pagemsg("WARNING: Saw {{%s}} nested within {{%s}}" % (tn, top_tn))
        continue
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn != "1":
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
      top_ncol = tn[-1]
      if not re.search("^[0-9]$", top_ncol):
        top_ncol = "2"
      def getp(param):
        return getparam(t, param)
      title = getp("1")
      m = re.search(r"""^[Tt]erms (?:which are )?(derived from|derived using|related to|etymologically related to|coordinate to|coordinate with) (?:or featuring |the verbal noun )?['"]*%s['"]*\.*$""" % re.escape(pagetitle), title)
      if m:
        title_typ = m.group(1)
        title_typ_to_abbrev = {
          "derived from": "der",
          "derived using": "der",
          "related to": "rel",
          "etymologically related to": "rel",
          "coordinate to": "cot",
          "coordinate with": "cot",
        }
        top_title = title_typ_to_abbrev[title_typ]
        pagemsg("Abbreviated '%s' to '%s'" % (title, top_title))
      if not m:
        m = re.search(r"""^Compounds with ['"]*%s['"]*\.*$""" % re.escape(pagetitle), title)
        if m:
          top_title = "com"
          pagemsg("Abbreviated '%s' to '%s'" % (title, top_title))
      if not m:
        if title:
          pagemsg("Unable to abbreviate '%s'" % title)
          top_title = title
        else:
          top_title = tn[0:3]
      top_t = t
      top_tn = tn
    elif tn in other_template_bottoms:
      if top_tn:
        pagemsg("WARNING: Saw template bottom %s mismatched to template top %s" % (tn, top_tn))
        top_t = None
        top_tn = None
      continue
    elif tn in template_bottoms:
      if not top_tn:
        pagemsg("WARNING: Saw stray template bottom %s" % tn)
        continue
      if top_tn[0:3] != tn[0:3]:
        pagemsg("WARNING: Saw template bottom %s mismatched to template top %s" % (tn, top_tn))
        top_t = None
        top_tn = None
        continue
      must_continue = False
      for param in t.params:
        pn = pname(param)
        pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, str(param.value), str(t)))
        must_continue = True
        break
      if must_continue:
        continue
      origt = str(t)
      blib.set_template_name(t, "col-bottom")
      orig_top_t = str(top_t)
      blib.set_template_name(top_t, "col-top")
      top_t.add("1", top_ncol)
      top_t.add("2", top_title)
      pagemsg("Replaced <%s> with <%s> and <%s> with <%s>" % (orig_top_t, str(top_t), origt, str(t)))
      notes.append("convert %s to %s per [[WT:RFDO#remove lesser-used column templates]]" % (orig_top_t, str(top_t)))
      top_t = None
      top_tn = None

  return str(parsed), notes

parser = blib.create_argparser("Convert {{der-top*}}/{{rel-top*}} to {{col-top}}, cleaning up titles", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(
  args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:%s" % t for t in templates_to_convert]
)
