#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, json

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site
import unicodedata

AC = u"\u0301"
GR = u"\u0300"

old_template_to_gender = {
  "sa-decl-noun-a-m": "m",
  u"sa-decl-noun-ā-f": "f",
  u"sa-decl-noun-ā": "f",
  "sa-decl-noun-a-n": "n",
  "sa-decl-noun-i-m": "m",
  "sa-decl-noun-i-f": "f",
  "sa-decl-noun-i-n": "n",
  "sa-decl-noun-u-m": "m",
  "sa-decl-noun-u-f": "f",
  "sa-decl-noun-u-n": "n",
  # u"sa-decl-noun-ū": "f", already converted, has mono=
  u"sa-decl-noun-ī": "f", # has mono=
  u"sa-decl-noun-ī-f": "f", # has mono=
  "sa-decl-noun-n-n": "n",
  # u"sa-decl-noun-ṛ1": "m", already converted, has r_stem_a=
  # u"sa-decl-noun-ās-m": "m", already converted
  # u"sa-decl-noun-ās-f": "f", already converted
  # "sa-decl-noun-as-n": "n", already converted
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if "sa-noun" not in text and "sa-decl-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  headt = None
  saw_decl = False

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    if tn == "sa-noun":
      pagemsg("Saw headt=%s" % str(t))
      if headt and not saw_decl:
        pagemsg("WARNING: Saw two {{sa-noun}} without {{sa-decl-noun}}: %s and %s" % (str(headt), str(t)))
      headt = t
      saw_decl = False
      continue

    if tn in ["sa-decl-noun", "sa-decl"]:
      pagemsg("WARNING: Saw raw {{%s}}: %s, headt=%s" % (tn, str(t), headt and str(headt) or None))
      continue

    if tn.startswith("sa-decl-noun-"):
      pagemsg("Saw declt=%s" % str(t))
      if not headt:
        pagemsg("WARNING: Saw {{%s}} without {{sa-noun}}: %s" % (tn, str(t)))
        continue
      saw_decl = True

      tr = getparam(headt, "tr")
      accented_tr = False
      if not tr:
        tr = expand_text("{{xlit|sa|%s}}" % pagetitle)
        pagemsg("WARNING: No translit in %s, using %s from pagetitle: declt=%s" % (str(headt), tr, str(t)))
      else:
        if "-" in tr:
          pagemsg("WARNING: Saw translit %s in head with hyphen: headt=%s, declt=%s" % (tr, str(headt), str(t)))
          tr = tr.replace("-", "")
        decomptr = unicodedata.normalize("NFD", tr).replace("s" + AC, u"ś")
        if AC not in decomptr and GR not in decomptr:
          pagemsg("WARNING: Saw translit %s in head without accent: headt=%s, declt=%s" % (tr, str(headt), str(t)))
        else:
          accented_tr = True
      genders = blib.fetch_param_chain(headt, "g")
      genders = [g.replace("-p", "").replace("bysense", "") for g in genders]
      genders = [g for gs in genders for g in (
        ["m", "f"] if gs in ["mf", "fm"] else ["m", "n"] if gs in ["mn", "nm"] else [gs]
      )]

      if tn in ["sa-decl-noun-m", "sa-decl-noun-f", "sa-decl-noun-n"]:
        tg = tn[-1]
        if tg not in genders:
          pagemsg("WARNING: Saw decl gender %s that disagrees with headword gender(s) %s: headt=%s, declt=%s" % (
            tg, ",".join(genders), str(headt), str(t)))
          continue

        decltr = getparam(t, "1")
        if not decltr:
          if not accented_tr:
            pagemsg("WARNING: No param in {{%s}}, replacing with unaccented tr %s from head or pagename: headt=%s, declt=%s" % (tn, tr, str(headt), str(t)))
            t.add("1", tr)
            notes.append("add (unaccented) translit %s to {{%s}}" % (tr, tn))
          else:
            pagemsg("WARNING: No param in {{%s}}, replacing with accented tr %s from head: headt=%s, declt=%s" % (tn, tr, str(headt), str(t)))
            t.add("1", tr)
            notes.append("add accented translit %s to {{%s}}" % (tr, tn))
        elif re.search(u"[\u0900-\u097F]", decltr): # translit is actually Devanagari
          if not accented_tr:
            pagemsg("WARNING: Devanagari in {{%s}}, replacing with unaccented tr %s from head or pagename: headt=%s, declt=%s" % (tn, tr, str(headt), str(t)))
            t.add("1", tr)
            notes.append("replace Devanagari in {{%s}} with (unaccented) translit %s" % (tr, tn))
          else:
            pagemsg("WARNING: Devanagari in {{%s}}, replacing with accented tr %s from head: headt=%s, declt=%s" % (tn, tr, str(headt), str(t)))
            t.add("1", tr)
            notes.append("replace Devanagari in {{%s}} with accented translit %s" % (tr, tn))
        else:
          decompdecltr = unicodedata.normalize("NFD", decltr).replace("s" + AC, u"ś")
          subbed = False
          if AC not in decompdecltr and GR not in decompdecltr:
            if accented_tr:
              pagemsg("WARNING: Saw translit %s in decl without accent, subbing accented tr %s from head: headt=%s, declt=%s" %
                  (decltr, tr, str(headt), str(t)))
              t.add("1", tr)
              notes.append("replace existing translit %s with accented translit %s in {{%s}}" % (decltr, tr, tn))
              subbed = True
            else:
              pagemsg("WARNING: Saw translit %s in decl without accent and unable to replace with accented tr from head: headt=%s, declt=%s" %
                  (decltr, str(headt), str(t)))
          if not subbed and "-" in decltr:
            pagemsg("WARNING: Saw translit %s in decl with hyphen: headt=%s, declt=%s" %
                (decltr, str(headt), str(t)))
            notes.append("remove hyphen from existing translit %s in {{%s}}" % (decltr, tn))
            decltr = decltr.replace("-", "")
            t.add("1", decltr)
            subbed = True
          stripped_decltr = decltr.strip()
          if "\n" not in decltr and stripped_decltr != decltr:
            pagemsg("WARNING: Saw translit '%s' in decl with extraneous space: headt=%s, declt=%s" %
                (decltr, str(headt), str(t)))
            notes.append("remove extraneous space from existing translit '%s' in {{%s}}" % (decltr, tn))
            decltr = stripped_decltr
            t.add("1", decltr)
            subbed = True
        continue

      if tn in [u"sa-decl-noun-ī", u"sa-decl-noun-ī-f"] and getparam(t, "mono"):
        pagemsg("WARNING: Saw mono=, skipping: headt=%s, declt=%s" % (str(headt), str(t)))
        continue

      if tn in old_template_to_gender:
        must_continue = False
        for param in t.params:
          pn = pname(param)
          if pn not in ["1", "2", "3", "4", "n"]:
            pagemsg("WARNING: Saw unknown param %s=%s in %s: headt=%s" % (pn, str(param.value), str(t),
              str(headt)))
            must_continue = True
            break
        if must_continue:
          continue

        g = old_template_to_gender[tn]
        if g not in genders:
          pagemsg("WARNING: Saw decl gender %s that disagrees with headword gender(s) %s: headt=%s, declt=%s" % (
            g, ",".join(genders), str(headt), str(t)))
          continue

        blib.set_template_name(t, "sa-decl-noun-%s" % g)
        rmparam(t, "n")
        rmparam(t, "4")
        rmparam(t, "3")
        rmparam(t, "2")
        t.add("1", tr)
        notes.append("convert {{%s}} to {{sa-decl-noun-%s}}" % (tn, g))
      else:
        pagemsg("WARNING: Saw unrecognized decl template: %s" % str(t))

    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))

  if headt:
    pagemsg("WARNING: Saw {{sa-noun}} without {{sa-decl-noun-*}}: %s" % str(headt))

  return str(parsed), notes

parser = blib.create_argparser("Convert old {{sa-decl-noun-*}} templates to new ones",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Sanskrit nouns"])
