#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert head|fr|* templates to the appropriate template.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = unicode(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = unicode(t)
    name = unicode(t.name)
    if name == "head" and getparam(t, "1") == "fr":
      headtype = getparam(t, "2")
      if headtype == "noun":
        head = getparam(t, "head")
        g = getparam(t, "g")
        g2 = getparam(t, "g2")
        plural = ""
        if getparam(t, "3") == "plural":
          plural = getparam(t, "4")
        unrecognized_params = False
        for param in t.params:
          pname = unicode(param.name)
          if pname in ["1", "2", "head", "g", "g2", "sort"] or plural and pname in ["3", "4"]:
            pass
          else:
            unrecognized_params = True
            break
        if unrecognized_params:
          pagemsg("WARNING: Unrecognized parameters in %s, skipping"
              % unicode(t))
          continue
        if not g:
          pagemsg("WARNING: No gender given in %s, skipping" % unicode(t))
          continue
        rmparam(t, "4")
        rmparam(t, "3")
        rmparam(t, "2")
        rmparam(t, "1")
        rmparam(t, "head")
        rmparam(t, "g")
        rmparam(t, "g2")
        rmparam(t, "sort")
        t.name = "fr-noun"
        if head:
          t.add("head", head)
        t.add("1", g)
        if g2:
          t.add("g2", g2)
        if plural:
          t.add("2", plural)
      elif headtype in ["proper noun", "proper nouns"]:
        head = getparam(t, "head")
        g = getparam(t, "g")
        g2 = getparam(t, "g2")
        remove_3 = False
        if not g and getparam(t, "3") in ["m", "f", "m-p", "f-p"]:
          g = getparam(t, "3")
          remove_3 = True
        unrecognized_params = False
        for param in t.params:
          pname = unicode(param.name)
          if pname in ["1", "2", "head", "g", "g2", "sort"] or remove_3 and pname in ["3"]:
            pass
          else:
            unrecognized_params = True
            break
        if unrecognized_params:
          pagemsg("WARNING: Unrecognized parameters in %s, skipping"
              % unicode(t))
          continue
        if not g:
          pagemsg("WARNING: No gender given in %s, skipping" % unicode(t))
          continue
        rmparam(t, "3")
        rmparam(t, "2")
        rmparam(t, "1")
        rmparam(t, "head")
        rmparam(t, "g")
        rmparam(t, "g2")
        rmparam(t, "sort")
        t.name = "fr-proper noun"
        if head:
          t.add("head", head)
        t.add("1", g)
        if g2:
          t.add("g2", g2)
      elif headtype in ["adjective", "adjectives"]:
        if getparam(t, "3") in ["invariable", "invariant"]:
          params = dict((unicode(p.name), unicode(p.value)) for p in t.params)
          del params["1"]
          del params["2"]
          del params["3"]
          if getparam(t, "g") == "m" and getparam(t, "g2") == "f":
            del params["g"]
            del params["g2"]
          if not params:
            rmparam(t, "g2")
            rmparam(t, "g")
            rmparam(t, "3")
            rmparam(t, "2")
            rmparam(t, "1")
            t.name = "fr-adj"
            t.add("inv", "y")
          else:
            pagemsg("WARNING: Unrecognized parameters in %s, skipping" %
                unicode(t))
        else:
          pagemsg("WARNING: Unrecognized parameters in %s, skipping" %
              unicode(t))
      elif headtype in ["adjective form", "verb form", "verb forms",
          "interjection", "preposition", "prefix", "prefixes",
          "suffix", "suffixes", "proverb", "proverbs"]:
        head = getparam(t, "head")
        unrecognized_params = False
        for param in t.params:
          pname = unicode(param.name)
          if pname in ["1", "2", "head", "sort"]:
            pass
          else:
            unrecognized_params = True
            break
        if unrecognized_params:
          pagemsg("WARNING: Unrecognized parameters in %s, skipping"
              % unicode(t))
          continue
        rmparam(t, "sort")
        rmparam(t, "head")
        rmparam(t, "2")
        rmparam(t, "1")
        t.name = ("fr-adj-form" if headtype == "adjective form" else
            "fr-verb-form" if headtype in ["verb form", "verb forms"] else
            "fr-intj" if headtype == "interjection" else
            "fr-prep" if headtype == "preposition" else
            "fr-prefix" if headtype in ["prefix", "prefixes"] else
            "fr-suffix" if headtype in ["suffix", "suffixes"] else
            "fr-proverb")
        if head:
          t.add("head", head)

      newt = unicode(t)
      if origt != newt:
        pagemsg("Replacing %s with %s" % (origt, newt))
        notes.append("replaced {{head|fr|%s}} with {{%s}}" % (headtype,
          unicode(t.name)))

  newtext = unicode(parsed)
  if newtext != text:
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = newtext
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser("Convert head|fr|* to fr-*")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for cat in ["French nouns", "French proper nouns", "French pronouns", "French determiners", "French adjectives", "French verbs", "French participles", "French adverbs", "French prepositions", "French conjunctions", "French interjections", "French idioms", "French phrases", "French abbreviations", "French acronyms", "French initialisms", "French noun forms", "French proper noun forms", "French pronoun forms", "French determiner forms", "French verb forms", "French adjective forms", "French participle forms", "French proverbs", "French prefixes", "French suffixes", "French diacritical marks", "French punctuation marks"]:
  msg("Processing category: %s" % cat)
  for i, page in blib.cat_articles(cat, start, end):
    process_page(i, page, args.save, args.verbose)
