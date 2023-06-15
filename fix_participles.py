#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up short adjective forms when possible, canonicalizing existing
# 'inflection of' and converting raw inflection to 'inflection of'

# FIXME:
#
# 1. When swapping participles with nouns/adjectives, don't do it for
#    adverbial participles

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

# Make sure there are two trailing newlines
def ensure_two_trailing_nl(text):
  return re.sub(r"\n*$", r"\n\n", text)

def process_page(page, index, parsed, nowarn=False):
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

  # Split off interwiki links at end
  m = re.match(r"^(.*?\n)(\n*(\[\[[a-z0-9_\-]+:[^\]]+\]\]\n*)*)$",
      page.text, re.S)
  if m:
    pagebody = m.group(1)
    pagetail = m.group(2)
  else:
    pagebody = page.text
    pagetail = ""

  sections = re.split("(^==[^=\n]+==\n)", pagebody, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Split off categories at end
      m = re.match(r"^(.*?\n)(\n*(\[\[Category:[^\]]+\]\]\n*)*)$",
          sections[j], re.S)
      if m:
        secbody = m.group(1)
        sectail = m.group(2)
      else:
        secbody = sections[j]
        sectail = ""

      subsections = re.split("(^===.*===\n)", secbody, 0, re.M)
      for k in range(2, len(subsections), 2):
        found_subsec_participle = False
        # Try to canonicalize existing 'inflection of'
        parsed = blib.parse_text(subsections[k])
        for t in parsed.filter_templates():
          gloss3 = True
          tname = unicode(t.name)
          canon_params = None
          if tname == "ru-participle of":
            found_participle = True
            found_subsec_participle = True
          elif tname == "present active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["pres", "act"]
          elif tname == "past active participle of" and getparam(t, "lang") == "ru":
            canon_params = ["past", "act"]
          elif tname == "present passive participle of" and getparam(t, "lang") == "ru":
            canon_params = ["pres", "pass"]
          elif tname == "past passive participle of" and getparam(t, "lang") == "ru":
            canon_params = ["past", "pass"]
          elif tname == "inflection of" and getparam(t, "lang") == "ru":
            gloss3 = False
            # Fetch the numbered params starting with 3
            numbered_params = []
            for i in range(3,20):
              numbered_params.append(getparam(t, str(i)))
            while len(numbered_params) > 0 and not numbered_params[-1]:
              del numbered_params[-1]
            # Now canonicalize
            numparamstr = "/".join(numbered_params)
            canon_params = []
            while True:
              m = re.search(r"^(pres|past)(?:/(perfective|imperfective|pfv|impfv))?/(act|actv|pass|pasv|adverbial|adv)/(?:part|ptcp)$", numparamstr)
              if m:
                canon_params = [m.group(1)]
                if m.group(2):
                  canon_params.append({"perfective":"pfv", "imperfective":"impfv", "pfv":"pfv", "impfv":"impfv"}[m.group(2)])
                canon_params.append({"act":"act", "actv":"act", "pass":"pass", "pasv":"pass", "adverbial":"adv", "adv":"adv"}[m.group(3)])
                break
              break
          if canon_params:
            found_participle = True
            found_subsec_participle = True
            origt = unicode(t)
            origname = unicode(t.name)
            t.name = "ru-participle of"
            # Fetch param 1 and param 2, and non-numbered params except lang=
            # and nocat=.
            param1 = getparam(t, "1")
            param2 = getparam(t, "2")
            non_numbered_params = []
            for param in t.params:
              pname = unicode(param.name)
              if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat"]:
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
            notes.append("replaced '%s' with 'ru-participle of/%s'" % (origname, "/".join(canon_params)))
        if found_subsec_participle:
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
      secbody = "".join(subsections)

      # Rearrange Participle and Noun/Adjective sections; repeat until no
      # change, in case we have both Noun and Adjective sections before the
      # Participle
      subsections = re.split("(^===[^=]*===\n)", secbody, 0, re.M)
      while True:
        rearranged = False
        for k in range(2, len(subsections), 2):
          if subsections[k-1] in ["===Noun===\n", "===Adjective===\n"] and k+1 < len(subsections) and subsections[k+1] == "===Participle===\n":
            tmp = subsections[k-1]
            subsections[k-1] = subsections[k+1]
            subsections[k+1] = tmp
            tmp = subsections[k]
            subsections[k] = ensure_two_trailing_nl(subsections[k+2])
            subsections[k+2] = tmp
            rearranged = True
            pagemsg("Swapped %s with %s" % (subsections[k+1].replace("\n", r"\n"), subsections[k-1].replace("\n", r"\n")))
            notes.append("swap Participle section with Noun/Adjective")
        if not rearranged:
          break
      sections[j] = "".join(subsections) + sectail

  new_text = "".join(sections) + pagetail

  if "Etymology 1" in new_text:
    pagemsg("WARNING: Multiple etymology sections, might need to manually fix up")

  new_new_text = re.sub(r"\[\[Category:Russian [a-z ]*participles]]", "", new_text)
  if new_text != new_new_text:
    pagemsg("Removed manual participle categories")
    notes.append("remove manual participle categories")
    new_text = new_new_text
  new_text = re.sub(r"\n\n\n+", "\n\n", new_text)

  if not notes and not found_participle and not nowarn:
    pagemsg("WARNING: No participles found")

  return new_text, notes

parser = blib.create_argparser("Canonicalize various participle definition lines and fix headword and section header",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

# FIXME! Won't quite work with --pagefile or --pages; will do them twice.
blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian participles", "Russian present active participles",
    "Russian present passive participles", "Russian past active participles",
    "Russian past passive participles"])

def process_page_nowarn(page, index, parsed):
  return process_page(page, index, parsed, nowarn=True)

blib.do_pagefile_cats_refs(args, start, end, process_page_nowarn, edit=True,
  default_cats=["Russian non-lemma forms"])
