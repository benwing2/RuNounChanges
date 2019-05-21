#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Clean up use of macrons in Latin lemmas.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

demacron_mapper = {
  u'ā': 'a',
  u'ē': 'e',
  u'ī': 'i',
  u'ō': 'o',
  u'ū': 'u',
  u'ȳ': 'y',
  u'Ā': 'A',
  u'Ē': 'E',
  u'Ī': 'I',
  u'Ō': 'O',
  u'Ū': 'U',
  u'Ȳ': 'Y',
}

def remove_macrons(text):
  return re.sub(u'([āēīōūȳĀĒĪŌŪȲ])', lambda m: demacron_mapper[m.group(1)], text)

def process_page(index, page, pos, lemma, stem, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  for t in parsed.filter_templates():
    origt = unicode(t)
    tn = tname(t)

    def frob_stem(param, stem):
      val = getparam(t, param)
      no_macrons_val = remove_macrons(val)
      assert len(no_macrons_val) == len(val)
      if type(stem) is not list:
        stem = [stem]
      for st in stem:
        no_macrons_stem = remove_macrons(st)
        assert len(no_macrons_stem) == len(st)
        if no_macrons_val.startswith(no_macrons_stem):
          newval = st + val[len(st):]
          if newval != val:
            t.add(param, newval)
            pagemsg("Replaced %s with %s" % (origt, unicode(t)))
            notes.append("updated macrons in %s" % tn)
          break

    def frob_exact(param, newval):
      val = getparam(t, param)
      no_macrons_val = remove_macrons(val)
      assert len(no_macrons_val) == len(val)
      no_macrons_newval = remove_macrons(newval)
      assert len(no_macrons_newval) == len(newval)
      if no_macrons_val == no_macrons_newval:
        if newval != val:
          t.add(param, newval)
          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
          notes.append("updated macrons in %s" % tn)

    if tn == "la-IPA":
      frob_stem("1", stem)
    elif tn == "la-noun-form" and pos == "noun":
      frob_stem("1", stem)
    elif tn == "la-adj-form" and pos == "adj":
      frob_stem("1", stem)
    elif tn in ["la-perfect participle", "la-future participle",
        "la-verb-form", "la-part-form", "la-decl-1&2"] and pos == "verb":
      frob_stem("1", stem)
    elif tn == "inflection of":
      lang = getparam(t, "lang")
      if lang:
        lemma_param = "1"
        alt_param = "2"
      else:
        lang = getparam(t, "1")
        lemma_param = "2"
        alt_param = "3"
      if lang == "la":
        tlemma = getparam(t, lemma_param)
        talt = getparam(t, alt_param)
        if not talt:
          frob_exact(lemma_param, lemma)
        elif remove_macrons(tlemma) == remove_macrons(talt):
          t.add(lemma_param, talt)
          t.add(alt_param, "")
          notes.append("moved alt param in {{inflection of|la}} to lemma")
          frob_exact(lemma_param, lemma)
        else:
          pagemsg("WARNING: In %s, alt param != lemma param even aside from macrons" % origt)
          frob_exact(alt_param, lemma)

  return unicode(parsed), notes

parser = blib.create_argparser("Clean up usage of macrons in Latin non-lemma forms")
parser.add_argument("--direcfile", help="File containing directives of lemmas to process.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

direcfile = args.direcfile.decode("utf-8")
for line in codecs.open(direcfile, "r", "utf-8"):
  line = line.rstrip('\n')
  if line.startswith("#"):
    continue
  parts = line.split(" ")
  if len(parts) == 2:
    # noun or adjective
    pos, lemma = parts
    if pos == "n1":
      assert lemma.endswith("a")
      pos = "noun"
      stem = lemma[:-1]
    elif pos == "n2":
      assert lemma.endswith("us") or lemma.endswith("um")
      pos = "noun"
      stem = lemma[:-2]
    elif pos == "n3":
      pos = "noun"
      if lemma.endswith(u"tiō"):
        stem = lemma + "n"
      elif lemma.endswith("or"):
        stem = lemma[:-2] + u"ōr"
      elif lemma.endswith(u"īx"):
        stem = lemma[:-1] + "c"
      else:
        raise ValueError("Don't recognize n3 lemma %s" % lemma)
    elif pos == "n4":
      assert lemma.endswith("us")
      pos = "noun"
      stem = lemma[:-2]
    elif pos == "a1":
      assert lemma.endswith("us")
      pos = "adj"
      stem = lemma[:-2]
    elif pos == "a3":
      pos = "adj"
      if lemma.endswith("is"):
        stem = lemma[:-2]
      elif lemma.endswith("ior"):
        stem = [lemma[:-2] + "us", lemma[:-2] + u"ōr"]
      else:
        raise ValueError("Don't recognize a3 lemma %s" % lemma)
    else:
      raise ValueError("Don't recognize pos spec %s" % pos)
    def do_process_page(page, index, parsed):
      return process_page(index, page, pos, lemma, stem, args.save, args.verbose)
    for index, page in blib.references(remove_macrons(lemma), start, end):
      stems = stem
      if type(stems) is not list:
        stems = [stems]
      for st in stems:
        no_macrons_stem = remove_macrons(st)
        assert len(no_macrons_stem) == len(st)
        if unicode(page.title()).startswith(no_macrons_stem):
          blib.do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose)
          break
      else:
        # no break
        msg("Skipped %s for lemma %s because doesn't match stem(s) %s" % (
          unicode(page.title()), lemma, ", ".join(stems)))
  else:
    pos = "verb"
    stems_lemmas = []
    if len(parts) == 3:
      # deponent verb
      lemma, inf, supine = parts
      if not supine.startswith("*") and not supine.startswith("--"):
        assert supine.endswith("um")
        stems_lemmas.append((supine[:-2], supine[:-2] + "us", True))
        stems_lemmas.append((supine[:-2] + u"ūr", supine[:-2] + u"ūrus", True))
      m = re.search("^(.*?)[ei]?or$", lemma)
      assert m
      stems_lemmas.append((m.group(1), lemma, False))
    else:
      assert len(parts) == 4
      lemma, inf, perf, supine = parts
      if not supine.startswith("*") and not supine.startswith("--"):
        assert supine.endswith("um")
        stems_lemmas.append((supine[:-2], supine[:-2] + "us", True))
        stems_lemmas.append((supine[:-2] + u"ūr", supine[:-2] + u"ūrus", True))
      if not perf.startswith("*") and not perf.startswith("--"):
        assert perf.endswith(u"ī")
        stems_lemmas.append((perf[:-1], lemma, False))
      m = re.search(u"^(.*?)[ei]?ō$", lemma)
      assert m
      stems_lemmas.append((m.group(1), lemma, False))
    for stem, lemma, include_page in stems_lemmas:
      def do_process_page(page, index, parsed):
        return process_page(index, page, pos, lemma, stem, args.save, args.verbose)
      for index, page in blib.references(remove_macrons(lemma), start, end,
          include_page=include_page):
        no_macrons_stem = remove_macrons(stem)
        assert len(no_macrons_stem) == len(stem)
        if unicode(page.title()).startswith(no_macrons_stem):
          blib.do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose)
        else:
          msg("Skipped %s for lemma %s because doesn't match stem %s" % (
            unicode(page.title()), lemma, stem))
