#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname

deny_list_pages = {
  "Charta 77",
  "Dana",
  "Jana",
  "Bohdana",
  "Zdena",
  "Anna",
  "Denisa",
  "Charta",
  u"Beáta",
  "Anglie",
  "Masaryk",
  "Stalin",
  "Lenin",
  "Napoleon",
  u"Platón",
  u"Československo",
  "Pluto",
  "Ptolemaios",
  u"Epikúros",
  "Rus",
  u"Prométheus",
  "Konfucius",
  u"Aristotelés",
  u"Erós",
  "Miroslav",
  "Marx",
  "Styx",
  u"Bohyně",
  u"Clintonová",
  u"Jidáš",
}

deny_list_items = {
  u"biblistický",
  u"československý",
  "Polka",
  "Berounka",
  u"Olomoucký kopec",
  u"archimedovský",
  u"sisyfovský",
}

allow_list_items = [
  ("Skyth", "dem"),
  (u"Gruzín", "dem"),
  ("Kazach", "dem"),
  ("Uzbek", "dem"),
  (u"Tádžik", "dem"),
  ("Turkmen", "dem"),
  ("Kyrgyz", "dem"),
  ("Turek", "dem"),
  (u"Turkyně", "fdem"),
  ("Sas", "dem"),
  ("Srb", "dem"),
  (u"Šváb", "dem"),
  (u"Švéd", "dem"),
  (u"Polák", "dem"),
  ("Mongol", "dem"),
  (u"Španěl", "dem"),
  (u"Slovák", "dem"),
  ("Fin", "dem"),
  ("Rumun", "dem"),
  (u"Dán", "dem"),
  ("Ir", "dem"),
  (u"Švýcar", "dem"),
  ("Bulhar", "dem"),
  (u"Maďar", "dem"),
  ("Nor", "dem"),
  ("Branibor", "dem"),
  ("Chorvat", "dem"),
  ("Skot", "dem"),
  ("Rus", "dem"),
  (u"Bělorus", "dem"),
  ("Valach", "dem"),
  (u"Lotyš", "dem"),
]
allow_list_items = dict(allow_list_items)

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if pagetitle in deny_list_pages:
    pagemsg("Skipping page because in deny_list_pages")
    return

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

  col_auto_templates_to_remove = []

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["cs-noun", "cs-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple cs-noun or cs-proper noun templates %s and %s" %
          (str(headword_template), str(t)))
      headword_template = t
      col_auto_template = None
      col_auto_items_to_keep = []
      adjs = blib.fetch_param_chain(t, "adj")
      dems = blib.fetch_param_chain(t, "dem")
      fdems = blib.fetch_param_chain(t, "fdem")
      for param in t.params:
        pn = pname(param)
        if re.search("^(adj|dem|fdem)[0-9]*_qual$", pn):
          pagemsg("WARNING: Saw qualifier for adj, dem or fdem: %s=%s" % (pn, str(param.value)))
          return
    elif tn == "col-auto":
      if getparam(t, "1").strip() != "cs":
        pagemsg("WARNING: Wrong language for {{col-auto}}: %s" % str(t))
        continue
      if not headword_template:
        pagemsg("WARNING: Encountered {{col-auto|cs}} without preceding headword template: %s" % str(t))
        continue
      col_auto_items = blib.fetch_param_chain(t, "2")
      for item in col_auto_items:
        origitem = item
        item = item.strip()
        def add_item(itemlist, listparam):
          if item in deny_list_items:
            pagemsg("Not removing item %s because in deny_list_items" % item)
            col_auto_items_to_keep.append(origitem)
          elif item[0:2].lower() != pagetitle[0:2].lower():
            pagemsg("WARNING: Saw apparent %s %s but first two chars %s don't agree with pagename: %s" %
                (listparam, item, item[0:2], str(t)))
            col_auto_items_to_keep.append(origitem)
          else:
            if item not in itemlist:
              itemlist.append(item)
        if item in allow_list_items:
          itemtype = allow_list_items[item]
          pagemsg("Moving item %s of type '%s' because in allow_list_items" % (item, itemtype))
          itemlist = (
            adjs if itemtype == "adj" else
            dems if itemtype == "dem" else
            fdems if itemtype == "fdem" else
            None
          )
          assert(itemlist is not None)
          if item not in itemlist:
            itemlist.append(item)
        elif re.search(u"ký$", item) and item[0].islower():
          add_item(adjs, "adj")
        elif re.search("(ec|an)$", item) and item[0].isupper():
          add_item(dems, "dem")
        elif re.search("ka$", item) and item[0].isupper():
          add_item(fdems, "fdem")
        elif re.search("ko$", item):
          pagemsg("Skipping apparent region item %s: %s" % (item, str(t)))
          col_auto_items_to_keep.append(origitem)
        elif re.search("tina$", item):
          pagemsg("Skipping apparent language item %s: %s" % (item, str(t)))
          col_auto_items_to_keep.append(origitem)
        else:
          pagemsg("WARNING: Unrecognized item %s, needs manual handling: %s" % (item, str(t)))
          col_auto_items_to_keep.append(origitem)
      if len(col_auto_items) > len(col_auto_items_to_keep):
        if adjs:
          blib.set_param_chain(headword_template, adjs, "adj")
        if dems:
          blib.set_param_chain(headword_template, dems, "dem")
        if fdems:
          blib.set_param_chain(headword_template, fdems, "fdem")
        items_to_move = []
        for item in col_auto_items:
          if item not in col_auto_items_to_keep:
            items_to_move.append("[[" + item + "]]")
        notes.append("move {{col-auto|cs}} item(s) %s to headword" % ",".join(items_to_move))
        if col_auto_items_to_keep:
          blib.set_param_chain(t, col_auto_items_to_keep, "2")
          notes.append("keep %s of %s original item(s) in {{col-auto|cs}}" %
            (len(col_auto_items_to_keep), len(col_auto_items)))
        else:
          col_auto_templates_to_remove.append((str(t), len(col_auto_items)))

  secbody = str(parsed)
  if col_auto_templates_to_remove:
    for col_auto_template_to_remove, num_items in col_auto_templates_to_remove:
      newtext, changed = blib.replace_in_text(secbody, col_auto_template_to_remove + "\n", "", pagemsg, abort_if_warning=True)
      if not changed:
        return
      notes.append("remove all %s item(s) from {{col-auto|cs}}" % num_items)
      secbody = newtext
      newtext, changed = blib.replace_in_text(secbody, "===+(Derived|Related) terms===+\n\n", "", pagemsg,
        is_re = True)
      if changed:
        notes.append("remove now empty Czech 'Derived/Related terms' section")
        secbody = newtext

  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Copy related adjectives, demonyms and female demonyms from {{col-auto}} to headword template",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
