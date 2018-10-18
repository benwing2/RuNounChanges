#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru

def is_transitive_verb(pagename, pagemsg):
  page = pywikibot.Page(site, pagename)
  if not blib.try_repeatedly(lambda: page.exists(), pagemsg,
      "check page existence"):
    pagemsg("Page %s doesn't exist, not a transitive verb" % pagename)
    return False

  pagetext = unicode(page.text)

  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  # Go through each section in turn, looking for existing Russian section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == "Russian":
      parsed = blib.parse_text(sections[i])
      for t in parsed.filter_templates():
        if unicode(t.name) == "ru-verb":
          if getparam(t, "2") in ["impf", "pf", "both"]:
            pagemsg("Saw transitive verb: %s" % unicode(t))
            return True
          pagemsg("Saw intransitive verb: %s" % unicode(t))

  return False

def process_page(index, page, lemmas):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  pagetext = unicode(page.text)

  # Split into sections
  splitsections = re.split("(^==[^=\n]+==\n)", pagetext, 0, re.M)
  # Extract off pagehead and recombine section headers with following text
  pagehead = splitsections[0]
  sections = []
  for i in xrange(1, len(splitsections)):
    if (i % 2) == 1:
      sections.append("")
    sections[-1] += splitsections[i]

  # Go through each section in turn, looking for existing Russian section
  for i in xrange(len(sections)):
    m = re.match("^==([^=\n]+)==$", sections[i], re.M)
    if not m:
      pagemsg("Can't find language name in text: [[%s]]" % (sections[i]))
    elif m.group(1) == "Russian":
      if "==Etymology" in sections[i]:
        return
      parsed = blib.parse_text(sections[i])
      saw_verb = False
      saw_passive = False
      saw_bad_passive = False
      for t in parsed.filter_templates():
        if unicode(t.name) in ["passive of", "passive form of"]:
          saw_passive = True
      if not saw_passive and ("passive of" in sections[i] or
        "passive form of" in sections[i]):
        saw_bad_passive = True
      for t in parsed.filter_templates():
        if unicode(t.name) == "ru-verb":
          saw_verb = True
          saw_paired_verb = False
          printed_msg = False
          heads = blib.fetch_param_chain(t, "1", "head") or [pagetitle]
          refl = heads[0].endswith(u"ся") or heads[0].endswith(u"сь")
          if refl:
            m = re.search(u"^(.*)(с[яь])$", heads[0])
            assert m
            transverb_no_passive = (False if (saw_passive or saw_bad_passive)
              else is_transitive_verb(ru.remove_accents(m.group(1)), pagemsg))
            if (saw_passive or saw_bad_passive or transverb_no_passive):
              msg("%s %s+-%s no-etym active-passive%s%s" % (
                ",".join(heads), m.group(1), m.group(2),
                saw_bad_passive and " (saw-bad-passive)" or "",
                transverb_no_passive and " (missing-passive-decl)" or ""))
              continue
          if getparam(t, "2").startswith("impf"):
            pfs = blib.fetch_param_chain(t, "pf", "pf")
            for otheraspect in pfs:
              if heads[0][0:2] == otheraspect[0:2]:
                saw_paired_verb = True
            if saw_paired_verb:
              msg("%s %s no-etym paired-impf" % (",".join(heads), ",".join(pfs)))
              printed_msg = True
          if getparam(t, "2").startswith("pf"):
            prefixes = [
              u"взъ", u"вз", u"вс", u"возъ", u"воз", u"вос", u"вы́",
              u"въ", u"в",
              u"до", u"за", u"изъ", u"из", u"ис", u"на",
              u"объ", u"об", u"отъ", u"от", u"о",
              u"пере", u"подъ", u"под", u"по", u"предъ", u"пред", u"пре",
              u"при", u"про",
              u"разъ", u"раз", u"рас", u"съ", u"с", u"у"
            ]
            splits = []
            for prefix in prefixes:
              m = re.match("^(%s)(.*)$" % prefix, heads[0])
              if m:
                base = ru.remove_monosyllabic_accents(
                  re.sub(u"^ы", u"и", m.group(2))
                )
                if ru.remove_accents(base) in lemmas:
                  prefix = prefix.replace(u"ъ", "")
                  if m.group(1) == u"вы́":
                    splits.append("%s-+%s-NEED-ACCENT" % (prefix, base))
                  else:
                    splits.append("%s-+%s" % (prefix, base))
                elif ru.remove_accents("-" + base) in lemmas:
                  base = "-" + base
                  prefix = prefix.replace(u"ъ", "")
                  if m.group(1) == u"вы́":
                    splits.append("%s-+%s-NEED-ACCENT" % (prefix, base))
                  else:
                    splits.append("%s-+%s" % (prefix, base))
            if splits:
              msg("%s %s no-etym strip-prefix" % (",".join(heads), " or ".join(splits)))
              printed_msg = True
          if not printed_msg:
            msg("%s no-etym misc" % ",".join(heads))
      if not saw_verb:
        msg("%s no-etym misc" % pagetitle)

parser = blib.create_argparser("Find terms without declension")
parser.add_argument('--cats', default="Russian lemmas", help="Categories to do (can be comma-separated list)")
parser.add_argument('--refs', help="References to do (can be comma-separated list)")
parser.add_argument('--lemmafile', help="File of lemmas to process. May have accents.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lemmafile:
  lemmas = []
  if args.cats == "Russian verbs":
    for i, page in blib.cat_articles(args.cats):
      lemmas.append(page.title())
  for i, pagename in blib.iter_items([ru.remove_accents(x.strip()) for x in codecs.open(args.lemmafile, "r", "utf-8")]):
    page = pywikibot.Page(site, pagename)
    process_page(i, page, lemmas)
elif args.refs:
  for ref in re.split(",", args.refs):
    msg("Processing references to: %s" % ref)
    for i, page in blib.references(ref, start, end):
      process_page(i, page, [])
else:
  for cat in re.split(",", args.cats):
    msg("Processing category: %s" % cat)
    lemmas = []
    if cat == "Russian verbs":
      for i, page in blib.cat_articles(cat):
        lemmas.append(page.title())
    for i, page in blib.cat_articles(cat, start, end):
      process_page(i, page, lemmas)
