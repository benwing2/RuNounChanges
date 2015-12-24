#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up short adjective forms when possible, canonicalizing existing
# 'inflection of' and converting raw inflection to 'inflection of'

import pywikibot, re, sys, codecs, argparse
from collections import Counter

import blib
from blib import getparam, rmparam, msg, site

import rulib as ru
import runounlib as runoun

def process_page(index, page, save, verbose, nowarn=False):
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

  found_participle = False
  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in xrange(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      subsections = re.split("(^===.*===\n)", sections[j], 0, re.M)
      for k in xrange(2, len(subsections), 2):
        # Try to canonicalize existing 'inflection of'
        parsed = blib.parse_text(subsections[k])
        for t in parsed.filter_templates():
          gloss3 = True
          tname = unicode(t.name)
          if tname == "ru-participle of":
            found_participle = True
          elif tname == "present active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["pres", "act"]
          elif tname == "past active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["past", "act"]
          elif tname == "present active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["pres", "act"]
          elif tname == "past active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["past", "act"]
          elif tname == "inflection of" and getparam(t, "lang") == "ru":
            gloss3 = False
            # Fetch the numbered params starting with 3
            numbered_params = []
            for i in xrange(3,20):
              numbered_params.append(getparam(t, str(i)))
            while len(numbered_params) > 0 and not numbered_params[-1]:
              del numbered_params[-1]
            # Now canonicalize
            numparamstr = "/".join(numbered_params)
            canon_params = []
            while True:
              m = re.search(r"^(pres|past)(?:/(perfective|imperfective))?/(act|actv|pass|pasv)/(?:part|ptcp)$", numparamstr)
              if m:
                canon_params = [m.group(1)]
                if m.group(2):
                  canon_params.append({"imperfective":"impfv", "perfective":"pfv"}[m.group(2)])
                break
              break
          if canon_params:
            found_participle = True
            origt = unicode(t)
            origname = unicode(t.name)
            t.name = "ru-participle of"
            # Fetch param 1 and param 2, and non-numbered params except lang=.
            param1 = getparam(t, "1")
            param2 = getparam(t, "2")
            non_numbered_params = []
            for param in t.params:
              pname = unicode(param.name)
              if not re.search(r"^[0-9]+$", pname) and pname != "lang":
                non_numbered_params.append((pname, param.value))
            # Convert 3rd parameter to gloss= if called for
            if gloss3:
              gloss = getparam(t, "3")
              if gloss:
                non_numbered_params.append(("gloss", gloss))
            # Erase all params.
            del t.params[:]
            # Put back param 1 and param 2, then the replacements for the
            # higher params, then the non-numbered params.
            t.add("1", param1)
            t.add("2", param2)
            for i, param in enumerate(canon_params):
              t.add(str(i+3), param)
            for name, value in non_numbered_params:
              t.add(name, value)
            newt = unicode(t)
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("replaced '%s' with %s" % (origname, "/".join(canon_params)))
          if found_participle:
            if "Verb" in subsections[k-1]:
              origsubsec = subsections[k-1]
              subsections[k-1] = re.sub("Verb", "Participle", subsections[k-1])
              pagemsg("Replaced %s with %s" % (origsubsec.replace("\n", r"\n"),
                subsections[k-1].replace("\n", r"\n")))
              notes.append("set section header to Participle")
        for t in parsed.filter_templates():
          if unicode(t.name) == "head" and getparam(t, "1") == "ru":
            origt = unicode(t)
            t.add("2", "participle")
            newt = unicode(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("set headword part of speech to 'participle'")
        subsections[k] = unicode(parsed)
      sections[j] = "".join(subsections)

  new_text = "".join(sections)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    # Group identical notes together and append the number of such identical
    # notes if > 1
    # 1. Count items in notes[] and return a key-value list in descending order
    notescount = Counter(notes).most_common()
    # 2. Recreate notes
    def fmt_key_val(key, val):
      if val == 1:
        return "%s" % key
      else:
        return "%s (%s)" % (key, val)
    notes = [fmt_key_val(x, y) for x, y in notescount]

    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

  if not notes and not found_participle and not nowarn:
    pagemsg("WARNING: No participles found")

parser = blib.create_argparser(u"Add 'inflection of' for raw short adjective forms and canonicalize existing 'inflection of'")
args = parser.parse_args()
start, end = blib.get_args(args.start, args.end)

for category in ["Russian participles", "Russian present active participles", "Russian present passive participles", "Russian past active participles", "Russian past passive participles"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose)

for category in ["Russian non-lemma forms"]:
  msg("Processing category: %s" % category)
  for i, page in blib.cat_articles(category, start, end):
    process_page(i, page, args.save, args.verbose, nowarn=True)
