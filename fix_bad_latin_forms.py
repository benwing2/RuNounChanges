#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib
from lalib import remove_macrons

def process_form(index, page, lemma, formind, formval, subs):
  pagetitle = str(page.title())

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  notes = []

  parsed = blib.parse(page)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    def fix_head(headparam, head, tn):
      for badstem, goodstem in subs:
        if head.startswith(badstem):
          newhead = goodstem + head[len(badstem):]
          t.add(headparam, newhead)
          notes.append("correct stem %s -> %s in {{%s}}" % (
            badstem, goodstem, tn))
          return newhead
      else:
        # no break
        pagemsg("WARNING: Head %s not same as page title and doesn't begin with bad stem %s: %s" % (
          head, " or ".join(badstem for badstem, goodstem in subs), str(t)))
        return False

    # la-suffix-form has its own format, don't handle
    if tn in lalib.la_nonlemma_headword_templates and tn != "la-suffix-form":
      headparam = "head"
      head = getparam(t, headparam)
      if not head:
        headparam = "1"
        head = getparam(t, headparam)
      if remove_macrons(head) != pagetitle:
        newhead = fix_head(headparam, head, tn)
        if newhead and remove_macrons(newhead) != pagetitle:
          pagemsg("WARNING: Replacement head %s not same as page title: %s" % (
            newhead, str(t)))
    elif tn in lalib.la_infl_of_templates:
      langparam = "lang"
      headparam = "1"
      altparam = "2"
      lang = getparam(t, langparam)
      if not lang:
        langparam = "1"
        headparam = "2"
        altparam = "3"
        lang = getparam(t, langparam)
      if lang == "la":
        link = getparam(t, headparam)
        alt = getparam(t, altparam)
        head = alt or link
        if remove_macrons(head) != remove_macrons(lemma):
          if subs:
            newhead = fix_head(headparam, head, tn + "|la")
            if newhead:
              t.add(altparam, "")
              if remove_macrons(newhead) != remove_macrons(lemma):
                pagemsg("WARNING: Replacement lemma %s not same as lemma %s: %s" % (
                  newhead, lemma, str(t)))
        else:
          if link != lemma or alt != "":
            t.add(headparam, lemma)
            t.add(altparam, "")
            notes.append("correct lemma and/or move alt text to link text in {{%s|la}}" % tn)
    if origt != str(t):
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  return str(parsed), notes

def process_page(index, pos, lemma, subs, infl, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, lemma, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, lemma, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, remove_macrons(lemma), pagemsg, verbose)

  pagemsg("Processing")

  args = lalib.generate_infl_forms(pos, infl, errandpagemsg, expand_text)
  if args is None:
    return

  forms_to_delete = []

  for key, form in args.iteritems():
    forms_to_delete.extend(form.split(","))

  for formind, form in blib.iter_items(forms_to_delete):
    def handler(page, formind, parsed):
      return process_form(index, page, lemma, formind, form, subs)
    blib.do_edit(pywikibot.Page(site, remove_macrons(form)), formind, handler, save=save, verbose=verbose)

parser = blib.create_argparser("Fix up bad Latin forms")
parser.add_argument('--declfile', help="File containing pos lemma bad:good,... infl", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for index, line in blib.iter_items_from_file(args.declfile, start, end):
  if "!!!" in line:
    pos, lemma, subs, infl = re.split("!!!", line)
  else:
    pos, lemma, subs, infl = re.split(" ", line, 4)
  subs = [] if subs == "-" else [x.split(":") for x in subs.split(",")]
  process_page(index, pos, lemma, subs, infl, args.save, args.verbose)
