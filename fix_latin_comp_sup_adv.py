#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, msg, site

import lalib

def find_head_comp_sup(pagetitle, pagemsg):
  page = pywikibot.Page(site, pagetitle)
  text = str(page.text)
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    if tname(t) == "la-adv":
      head = getparam(t, "1")
      comp = getparam(t, "comp") or getparam(t, "2")
      sup = getparam(t, "sup") or getparam(t, "3")
      if not comp or not sup:
        for suff in ["iter", "nter", "ter", "er", u"iē", u"ē", "im", u"ō"]:
          m = re.search("^(.*?)%s$" % suff, head)
          if m:
            stem = m.group(1)
            if suff == "nter":
              stem += "nt"
            default_comp = stem + "ius"
            default_sup = stem + u"issimē"
            break
        else:
          pagemsg("WARNING: Didn't recognize ending of adverb headword %s" % head)
          return head, comp, sup
        comp = comp or default_comp
        sup = sup or default_sup
      return head, comp, sup
  return None, None, None

def process_page(page, index, parsed):
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

  subsections = re.split("(^===[^=\n]*===\n)", secbody, 0, re.M)

  for k in range(2, len(subsections), 2):
    if "==Adverb==" in subsections[k - 1]:
      parsed = blib.parse_text(subsections[k])
      posdeg = None
      compt = None
      supt = None
      for t in parsed.filter_templates():
        if tname(t) == "comparative of":
          if compt:
            pagemsg("WARNING: Saw multiple {{comparative of}}: %s and %s" % (
              str(compt), str(t)))
          else:
            compt = t
            posdeg = blib.remove_links(getparam(t, "1"))
            if not posdeg:
              pagemsg("WARNING: Didn't see positive degree in {{comparative of}}: %s" % str(t))
        elif tname(t) == "superlative of":
          if supt:
            pagemsg("WARNING: Saw multiple {{superlative of}}: %s and %s" % (
              str(supt), str(t)))
          else:
            supt = t
            posdeg = blib.remove_links(getparam(t, "1"))
            if not posdeg:
              pagemsg("WARNING: Didn't see positive degree in {{superlative of}}: %s" % str(t))
      if compt and supt:
        pagemsg("WARNING: Saw both comparative and superlative, skipping: %s and %s" % (
          str(compt), str(supt)))
        continue
      if not compt and not supt:
        pagemsg("WARNING: Didn't see {{comparative of}} or {{superlative of}} in section %s" %
          k)
        continue
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["la-adv-comp", "la-adv-sup"]:
          pagemsg("Already saw fixed headword: %s" % str(t))
          break
        if tn == "head":
          if not getparam(t, "1") == "la":
            pagemsg("WARNING: Saw wrong language in {{head}}: %s" % str(t))
          else:
            pos = getparam(t, "2")
            head = blib.remove_links(getparam(t, "head")) or pagetitle
            if pos not in ["adverb", "adverbs",
                "adverb form", "adverb forms",
                "adverb comparative form", "adverb comparative forms",
                "adverb superlative form", "adverb superlative forms",
            ]:
              pagemsg("WARNING: Unrecognized part of speech '%s': %s" % (
                pos, str(t)))
            else:
              real_head, real_comp, real_sup = find_head_comp_sup(lalib.remove_macrons(posdeg), pagemsg)
              if real_head:
                if lalib.remove_macrons(real_head) != lalib.remove_macrons(posdeg):
                  pagemsg("WARNING: Can't replace positive degree %s with %s because they differ when macrons are removed" % (
                    posdeg, real_head))
                else:
                  pagemsg("Using real positive degree %s instead of %s" % (
                    real_head, posdeg))
                  inflt = compt or supt
                  origt = str(inflt)
                  inflt.add("1", real_head)
                  pagemsg("Replaced %s with %s" % (origt, str(inflt)))
              if compt:
                newname = "la-adv-comp"
                infldeg = "comparative"
                if real_comp and real_comp != "-":
                  if lalib.remove_macrons(real_comp) != lalib.remove_macrons(head):
                    pagemsg("WARNING: Can't replace comparative degree %s with %s because they differ when macrons are removed" % (
                      head, real_comp))
                  else:
                    pagemsg("Using real comparative degree %s instead of %s" % (
                      real_comp, head))
                    head = real_comp
                else:
                  pagemsg("WARNING: Couldn't retrieve real comparative for positive degree %s" % real_head)
              else:
                newname = "la-adv-sup"
                infldeg = "superlative"
                if real_sup and real_sup != "-":
                  if lalib.remove_macrons(real_sup) != lalib.remove_macrons(head):
                    pagemsg("WARNING: Can't replace superlative degree %s with %s because they differ when macrons are removed" % (
                      head, real_sup))
                  else:
                    pagemsg("Using real superlative degree %s instead of %s" % (
                      real_sup, head))
                    head = real_sup
                else:
                  pagemsg("WARNING: Couldn't retrieve real superlative for positive degree %s" % real_head)
              origt = str(t)
              rmparam(t, "head")
              rmparam(t, "2")
              rmparam(t, "1")
              blib.set_template_name(t, newname)
              t.add("1", head)
              pagemsg("Replaced %s with %s" % (origt, str(t)))
              notes.append("replace {{head|la|...}} with {{%s}} and fix up positive/%s" %
                  (newname, infldeg))

      subsections[k] = str(parsed)

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Fix headword of Latin comparative and superlative adverbs",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page,
    default_cats=["Latin comparative adverbs", "Latin superlative adverbs"],
    edit=True)
