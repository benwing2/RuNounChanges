#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

canonicalize_tags = {
  "active": "act",
  "passive": "pass",
  "adverbial": "adv",
  "perfective": "pfv",
  "imperfective": "impfv",
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)
  headt = None
  last_headt = None
  last_partpos = None
  last_origt = None
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "head" and getp("1") == "ru" and getp("2") == "participle":
      if headt:
        pagemsg("WARNING: Saw two {{head|ru|participle}} templates %s and %s without intervening {{ru-participle of}}, using the second one"
          % (str(headt), str(t)))
      headt = t
      last_headt = t
      last_partpos = None
    elif tn == "ru-participle of":
      if not headt and not last_headt:
        pagemsg("WARNING: Saw {{ru-participle of}} without preceding head template: %s" % str(t))
        return
      lemma = getp("1")
      altform = getp("2")
      tags = blib.fetch_param_chain(t, "3")
      tr = getp("tr")
      gloss = getp("gloss") or getp("t")
      pos = getp("pos")
      if len(tags) < 2:
        pagemsg("WARNING: Too few arguments (%s) to {{ru-participle of}}: %s" % (len(tags), str(t)))
        return
      tags = [canonicalize_tags.get(tag, tag) for tag in tags]

      must_continue = False
      for param in t.params:
        ok = False
        pn = pname(param)
        if re.search("^[0-9]+$", pn):
          ok = True
        elif pn in ["tr", "gloss", "t", "pos"]:
          ok = True
        if not ok:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, str(param.value), str(t)))
          must_continue = True
          break
      if must_continue:
        continue
     
      part_tense = None
      part_voice = None
      if "pres" in tags:
        part_tense = "present"
      elif "past" in tags:
        part_tense = "past"
      else:
        pagemsg("WARNING: Can't extract participle tense from {{ru-participle of}}: %s" % str(t))
        return
      if "act" in tags:
        part_voice = "active"
      elif "pass" in tags:
        part_voice = "passive"
      elif "adv" in tags:
        part_voice = "adverbial"
      else:
        pagemsg("WARNING: Can't extract participle voice from {{ru-participle of}}: %s" % str(t))
        return
      partpos = "%s %s participle" % (part_tense, part_voice)

      origt = str(t)
      del t.params[:]
      t.add("1", "ru")
      t.add("2", lemma)
      t.add("3", altform)
      for i, tag in enumerate(tags):
        t.add(str(i + 4), tag)
      if tr:
        t.add("tr", tr)
      if gloss:
        t.add("t", gloss)
      if pos:
        t.add("pos", pos)
      blib.set_template_name(t, "participle of")

      if not headt and last_headt:
        # We saw another {{ru-participle of}} after a preceding one without an intervening {{ru-articiple of}}.
        # This is OK as long as the headword participle POS is the same.
        if last_partpos == partpos:
          pagemsg("Saw two {{ru-participle of}} without intervening {{head}}, OK since participle POS's are the same: %s and %s"
            % (last_origt, origt))
        else:
          pagemsg("WARNING: Saw two {{ru-participle of}} without intervening {{head}} and different participle POS's %s and %s: %s and %s"
            % (last_partpos, partpos, last_origt, origt))
          return
      else:
        headt.add("2", partpos)
        notes.append("convert {{%s}} to {{%s|ru}} and make headword POS '%s'" % (tn, tname(t), partpos))
        last_headt = headt
        headt = None
      last_partpos = partpos
      last_origt = origt

  text = str(parsed)
  return text, notes

parser = blib.create_argparser("Convert {{ru-participle of}} to {{participle of|ru}}, making headword POS more specific",
                               include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
