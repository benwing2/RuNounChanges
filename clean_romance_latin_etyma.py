#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from lalib import remove_macrons

MACRON = u"\u0304" # macron =  ̄

latin_langcodes = ["la", "CL.", "LL.", "ML.", "VL.", "EL.", "NL.", "la-cla", "la-lat", "la-med", "la-vul", "la-ecc", "la-new"]

es_suffixes_to_latin_etym_suffixes = [
  ("a", "a", None, [("am$", "a")]),
  ("dad", u"tās", u"tātem", [(u"t[āa]tis$", u"tātem")]),
  ("tud", u"tūs", u"tūtem", [(u"t[ūu]tis$", u"tūtem")]),
  ("able", u"ābilis", None, [(u"[āa]bilem$", u"ābilis")]),
  ("ble", u"bilis", None, [("bilem$", "bilis")]),
  ("ante", u"āns", "antem", [("antis$", "antem")]),
  ("ente", u"ēns", "entem", [("entis$", "entem")]),
  (u"ación", u"ātiō", u"ātiōnem", [(u"[āa]ti[ōo]nis$", u"ātiōnem")]),
  (u"ción", u"tiō", u"tiōnem", [(u"ti[ōo]nis$", u"tiōnem")]),
  (u"ión", u"iō", u"iōnem", [(u"i[ōo]nis$", u"iōnem")]),
  ("o", "us", None, [("um$", "us")]),
  ("o", "um", None, []),
  ("ar", u"āris", None, [(u"[aā]rem$", u"āris")]),
  ("ar", u"ō", u"āre", []),
  ("ar", "or", u"ārī", []),
  ("ecer", u"ēscō", u"ēscere", []),
  ("ecer", u"ēscor", u"ēscī", []),
  ("er", u"eō", u"ēre", []),
  ("er", "eor", u"ērī", []),
  # Don't like -ĕre or -īre verbs because potentially either could produce an -ir or -ecer verb, so we wouldn't
  # be able to confidently extend '-iō' into either '-ere' or '-īre'.
]

deny_list_canonicalize_suffix = {
  "elephas",
  "stabilis",
  "datio",
  "circumdatio",
  "ratio",
  "satio",
  "facio", # otherwise we get faciāre as etymon
  "sus", # otherwise sūs -> sus
}

latin_etymon_should_match = "(m|[aei]r[ei]|i)$"

def self_canonicalize_latin_term(term):
  term = unicodedata.normalize("NFC", re.sub("([AEIOUYaeiouy])(n[sf])", r"\1" + MACRON + r"\2", term))
  if term not in ["modo", "ego"]:
    term = re.sub("o$", u"ō", term)
  return term

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    m = re.search("^===*([^=]*)=*==\n$", subsections[k - 1])
    subsectitle = m.group(1)
    if not subsectitle.startswith("Etymology"):
      continue

    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn in ["bor", "inh", "der", "bor+", "inh+", "der+", "uder", "ubor", "unadapted borrowing", "lbor",
          "learned borrowing", "slbor", "semi-learned borrowing"]:
        if getp("1") != args.langcode:
          pagemsg("WARNING: Wrong language code in etymology template: %s" % unicode(t))
          continue
        if getp("2") not in latin_langcodes:
          continue
        lemma = getp("3")
        if not lemma:
          continue
        alt = getp("4")
        if ", " in alt:
          altparts = alt.split(", ")
          if len(altparts) > 2:
            pagemsg("WARNING: Saw more than two parts in comma-separated etymon alt text '%s': %s" %
              (alt, unicode(t)))
            continue
          alt_lemma, alt_form = altparts
          if remove_macrons(lemma) != remove_macrons(alt_lemma):
            pagemsg("WARNING: In etymology template, Latin lemma %s doesn't match alt text lemma %s: %s" %
                (lemma, alt_lemma, unicode(t)))
            continue
          t.add("3", alt_lemma)
          t.add("4", alt_form)
          notes.append("split alt param '%s' in {{%s}} into Latin lemma and non-lemma etymon" % (alt, tn))

        # move duplicative lemma to lemma slot
        lemma = getp("3")
        alt = getp("4")
        if remove_macrons(alt) == remove_macrons(lemma):
          notes.append("move duplicative Latin lemma %s from 4= to 3=" % alt)
          rmparam(t, "4")
          t.add("3", alt)

        # now try to add some long vowels
        lemma = getp("3")
        alt = getp("4")
        if remove_macrons(lemma) in deny_list_canonicalize_suffix:
          pagemsg("WARNING: Skipping lemma %s because in deny_list_canonicalize_suffix, review manually: %s" %
            (lemma, unicode(t)))
          continue
        if remove_macrons(alt) == remove_macrons(lemma):
          notes.append("move duplicative Latin lemma %s from 4= to 3=" % alt)
          rmparam(t, "4")
          t.add("3", alt)
        else:
          for romance_suffix, latin_lemma_suffix, latin_form_suffix, latin_subs in es_suffixes_to_latin_etym_suffixes:
            if pagetitle.endswith(romance_suffix):
              if remove_macrons(lemma).endswith(remove_macrons(latin_lemma_suffix)):
                if latin_form_suffix:
                  if alt:
                    for refrom, reto in latin_subs:
                      newalt = re.sub(refrom, reto, alt)
                      if newalt != alt:
                        notes.append("canonicalize Latin non-lemma etymon %s -> %s" % (alt, newalt))
                        alt = newalt
                    if not remove_macrons(alt).endswith(remove_macrons(latin_form_suffix)):
                      pagemsg("WARNING: Canonicalized Latin non-lemma etymon %s doesn't match expected suffix %s: %s" %
                        (alt, latin_form_suffix, unicode(t)))
                    else:
                      newalt = alt[:-len(latin_form_suffix)] + latin_form_suffix
                      if newalt != alt:
                        notes.append("add missing long vowels in suffix -%s to Latin non-lemma etymon %s" %
                          (latin_form_suffix, alt))
                        alt = newalt
                    t.add("4", alt)
                  else:
                    alt = lemma[:-len(latin_lemma_suffix)] + latin_form_suffix
                    notes.append("add presumably correct Latin non-lemma etymon %s for lemma %s" %
                      (alt, lemma))
                    t.add("4", alt)
                else:
                  if alt:
                    for refrom, reto in latin_subs:
                      newalt = re.sub(refrom, reto, alt)
                      if newalt != alt:
                        notes.append("canonicalize Latin non-lemma etymon %s -> %s" % (alt, newalt))
                        alt = newalt
                    if remove_macrons(alt) == remove_macrons(lemma):
                      # We may e.g. canonicalize -am to -a, making the non-lemma etymon duplicative.
                      notes.append("move duplicative Latin lemma %s from 4= to 3=" % alt)
                      rmparam(t, "4")
                      t.add("3", alt)
                    else:
                      pagemsg("WARNING: Should be no Latin non-lemma etymon for lemma %s but saw %s: %s" %
                        (lemma, alt, unicode(t)))
                  elif remove_macrons(lemma).endswith(remove_macrons(latin_lemma_suffix)):
                    newlemma = lemma[:-len(latin_lemma_suffix)] + latin_lemma_suffix
                    if newlemma != lemma:
                      notes.append("add missing long vowels in suffix -%s to Latin lemma %s" %
                        (latin_lemma_suffix, lemma))
                      lemma = newlemma
                      t.add("3", lemma)

                # Once we've seen the appropriage Romance and Latin suffixes, don't process further.
                break

        # make sure etymon in the right form
        lemma = getp("3")
        alt = getp("4")
        if alt and not re.search(latin_etymon_should_match, remove_macrons(alt)):
          pagemsg("WARNING: Latin non-lemma etymon %s doesn't look like accusative or infinitive: %s" %
            (alt, unicode(t)))

        # self-canonicalize lemma or etymon
        lemma = getp("3")
        alt = getp("4")
        if alt:
          newalt = self_canonicalize_latin_term(alt)
          if alt != newalt:
            notes.append("self-canonicalize Latin non-lemma etymon %s -> %s" % (alt, newalt))
            alt = newalt
            t.add("4", alt)
        elif lemma:
          newlemma = self_canonicalize_latin_term(lemma)
          if lemma != newlemma:
            notes.append("self-canonicalize Latin lemma %s -> %s" % (lemma, newlemma))
            lemma = newlemma
            t.add("3", lemma)

    subsections[k] = unicode(parsed)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Clean up Latin etyma in Romance etymologies", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langcode", required=True, help="Language code of language to do")
parser.add_argument("--langname", required=True, help="Language name of language to do")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_cats=["%s verbs" % args.langname])
