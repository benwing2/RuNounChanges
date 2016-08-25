#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up noun forms when possible, canonicalizing existing 'inflection of'.
# In particular, we convert 'prep' to 'pre', shorten full forms to
# abbreviations, put lang=ru first, remove blank form codes, and rearrange
# form codes like s|gen to be gen|s.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = unicode(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Remove blank form codes and canonicalize position of lang=, tr=
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if unicode(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          origt = unicode(t)
          # Fetch the numbered params starting with 3, skipping blank ones
          numbered_params = []
          for i in xrange(3,20):
            val = getparam(t, str(i))
            if val:
              numbered_params.append(val)
          # Fetch param 1 and param 2, and non-numbered params except lang=
          # and nocat=.
          param1 = getparam(t, "1")
          param2 = getparam(t, "2")
          tr = getparam(t, "tr")
          nocat = getparam(t, "nocat")
          non_numbered_params = []
          for param in t.params:
            pname = unicode(param.name)
            if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat", "tr"]:
              non_numbered_params.append((pname, param.value))
          # Erase all params.
          del t.params[:]
          # Put back lang, param 1, tr, param 2, then the replacements for the
          # higher numbered params, then the non-numbered params.
          t.add("lang", "ru")
          t.add("1", param1)
          if tr:
            t.add("tr", tr)
          t.add("2", param2)
          for i, param in enumerate(numbered_params):
            t.add(str(i+3), param)
          for name, value in non_numbered_params:
            t.add(name, value)
          newt = unicode(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("removed any blank form codes and maybe rearranged lang=, tr=")
            if nocat:
              notes.append("removed nocat=")
      sections[j] = unicode(parsed)

      # Convert 'prep' to 'pre', etc.
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if unicode(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          for frm, to in [
              ("nominative", "nom"), ("accusative", "acc"),
              ("genitive", "gen"), ("dative", "dat"),
              ("instrumental", "ins"),
              ("prep", "pre"), ("prepositional", "pre"),
              ("vocative", "voc"), ("locative", "loc"), ("partitive", "par"),
              ("singular", "s"), ("(singular)", "s"),
              ("plural", "p"), ("(plural)", "p"),
              ("inanimate", "in"), ("animate", "an"),
              ]:
            origt = unicode(t)
            for i in xrange(3,20):
              val = getparam(t, str(i))
              if val == frm:
                t.add(str(i), to)
            newt = unicode(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("converted '%s' form code to '%s'" % (frm, to))
      sections[j] = unicode(parsed)

      # Rearrange order of s|gen, p|nom etc. to gen|s, nom|p etc.
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if unicode(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          if (getparam(t, "3") in ["s", "p"] and
              getparam(t, "4") in ["nom", "gen", "dat", "acc", "ins", "pre", "voc", "loc", "par"] and
              not getparam(t, "5")):
            origt = unicode(t)
            number = getparam(t, "3")
            case = getparam(t, "4")
            t.add("3", case)
            t.add("4", number)
            newt = unicode(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("converted '%s|%s' to '%s|%s'" %
                  (number, case, case, number))
      sections[j] = unicode(parsed)

  new_text = "".join(sections)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(blib.group_notes(notes))
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Canonicalize 'inflection of' for noun forms")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for category in ["Russian noun forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)
