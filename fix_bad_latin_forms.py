#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import lalib
from lalib import remove_macrons

def process_form(index, page, lemma, formind, formval, goodstem, badstem):
  pagetitle = unicode(page.title())

  def pagemsg(txt):
    msg("Page %s %s: form %s %s: %s" % (index, lemma, formind, formval, txt))

  notes = []
  parsed = blib.parse(page)
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)
    # la-suffix-form has its own format, don't handle
    if tn in lalib.la_nonlemma_headword_templates and tn != "la-suffix-form":
      headparam = "head"
      head = getparam(t, headparam)
      if not head:
        headparam = "1"
        head = getparam(t, headparam)
      if remove_macrons(head) != pagetitle:
        if head.startswith(badstem):
          t.add(headparam, goodstem + head[len(badstem):])
          notes.append("correct stem %s -> %s in {{%s}}" % (
            badstem, goodstem, tn))
        else:
          pagemsg("WARNING: Head %s not same as page title and doesn't begin with bad stem %s: %s" % (
            head, badstem, unicode(t)))
    elif tn in la_infl_of_templates:
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
        if remove_macrons(head) != pagetitle:
          if head.startswith(badstem):
            t.add(headparam, goodstem + head[len(badstem):])
            t.add(altparam, "")
            notes.append("correct stem %s -> %s in {{%s|la}}" % (
              badstem, goodstem, tn))
          else:
            pagemsg("WARNING: Head %s not same as page title and doesn't begin with bad stem %s: %s" % (
              head, badstem, unicode(t)))
        elif alt:
          t.add(headparam, head)
          t.add(altparam, "")
          notes.append("move alt text to link text in {{%s|la}}" % tn)
    if origt != unicode(t):
      pagemsg("Replaced %s with %s" % (origt, unicode(t)))
  return unicode(parsed), notes

def process_page(index, pos, lemma, goodstem, badstem, infl, save, verbose):
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
      return process_form(index, page, lemma, formind, form, goodstem, badstem)
    blib.do_edit(pywikibot.Page(site, remove_macrons(formval)), formind, handler, save=save, verbose=verbose)

parser = blib.create_argparser(u"Fix up bad Latin forms")
parser.add_argument('--declfile', help="File containing pos, lemma, goodstem, badstem, infl.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if not args.declfile:
  raise ValueError("--declfile required")
lines = [x.strip() for x in codecs.open(args.declfile, "r", "utf-8")]
for index, line in blib.iter_items(lines, start, end):
  if "!!!" in line:
    pos, lemma, goodstem, badstem, infl = re.split("!!!", line)
  else:
    pos, lemma, goodstem, badstem, infl = re.split(" ", line, 2)
  process_page(index, pos, lemma, goodstem, badstem, args.save, args.verbose)
