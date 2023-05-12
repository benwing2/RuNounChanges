#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Czech", pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  parsed = blib.parse_text(secbody)

  headword_template = None
  col_auto_template = None
  col_auto_items_to_keep = []
  adjs = []
  dems = []
  fdems = []
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["cs-noun", "cs-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple cs-noun or cs-proper noun templates %s and %s" %
          (unicode(headword_template), unicode(t)))
      headword_template = t
      col_auto_template = None
      col_auto_items_to_keep = []
      adjs = blib.fetch_param_chain(t, "adj")
      dems = blib.fetch_param_chain(t, "dem")
      fdems = blib.fetch_param_chain(t, "fdem")
      for param in t.params:
        pn = pname(param)
        if re.search("^(adj|dem|fdem)[0-9]*_qual$", pn):
          pagemsg("WARNING: Saw qualifier for adj, dem or fdem: %s=%s" % (pn, unicode(param.value)))
          return
    elif tn == "col-auto":
      if getparam(t, "1") != "cs":
        pagemsg("WARNING: Wrong language for {{col-auto}}: %s" % unicode(t))
        return
      if not headword_template:
        pagemsg("WARNING: Encountered {{col-auto|cs}} without preceding headword template: %s" % unicode(t))
        return
      col_auto_items = blib.fetch_param_chain(t, "2")
      def add_item(item, itemlist, listparam):
        if item[0:2].lower() != pagetitle[0:2].lower():
          pagemsg("WARNING: Saw apparent %s %s but first two chars %s don't agree with pagename: %s" %
              (listparam, item, item[0:2], unicode(t)))
          col_auto_items_to_keep.append(item)
        else:
          if item not in itemlist:
            itemlist.append(item)
      for item in col_auto_items:
        if re.search(u"ký$", item) and item[0].islower():
          add_item(item, adjs, "adj")
        elif re.search("(ec|an)$", item) and item[0].isupper():
          add_item(item, dems, "dem")
        elif re.search("ka$", item) and item[0].isupper():
          add_item(item, fdems, "fdem")
        elif re.search("ko$", item):
          pagemsg("Skipping apparent region item %s: %s" % (item, unicode(t)))
          col_auto_items_to_keep.append(item)
        elif re.search("tina$", item):
          pagemsg("Skipping apparent language item %s: %s" % (item, unicode(t)))
          col_auto_items_to_keep.append(item)
        else:
          pagemsg("WARNING: Unrecognized item %s, needs manual handling: %s" % (item, unicode(t)))
          col_auto_items_to_keep.append(item)
      if len(col_auto_items) > len(col_auto_items_to_keep):
        if adjs:
          blib.set_param_chain(headword_template, adjs, "adj")
        if dems:
          blib.set_param_chain(headword_template, dems, "dem")
        if fdems:
          blib.set_param_chain(headword_template, fdems, "fdem")
        notes.append("move %s {{col-auto|cs}} item(s) to headword" %
          (len(col_auto_items) - len(col_auto_items_to_keep)))
        if col_auto_items_to_keep:
          blib.set_param_chain(t, col_auto_items_to_keep, "2")
          notes.append("keeping %s of %s original item(s) in {{col-auto|cs}}" %
            (len(col_auto_items_to_keep), len(col_auto_items)))
          secbody = unicode(parsed)
        else:
          secbody = unicode(parsed)
          newtext, changed = blib.replace_in_text(secbody, unicode(t) + "\n", "", pagemsg, abort_if_warning=True)
          if not changed:
            return
          notes.append("remove all %s item(s) from {{col-auto|cs}}" % len(col_auto_items))
          secbody = newtext
          newtext, changed = blib.replace_in_text(secbody, "===+(Derived|Related) terms===+\n\n", "", pagemsg,
            is_re = True)
          if changed:
            notes.append("remove now empty Czech 'Derived/Related terms' section")
            secbody = newtext
          parsed = blib.parse_text(secbody)

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Copy related adjectives, demonyms and female demonyms from {{col-auto}} to headword template",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
