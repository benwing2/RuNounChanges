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
  u'ă': 'a',
  u'ĕ': 'e',
  u'ĭ': 'i',
  u'ŏ': 'o',
  u'ŭ': 'u',
  # no composed breve-y
  u'Ă': 'A',
  u'Ĕ': 'E',
  u'Ĭ': 'I',
  u'Ŏ': 'O',
  u'Ŭ': 'U',
  # combining breve
  u'\u0306': '',
}

def remove_macrons(text):
  return re.sub(u'([āēīōūȳĀĒĪŌŪȲăĕĭŏŭĂĔĬŎŬ\u0306])', lambda m: demacron_mapper[m.group(1)], text)

def get_references(page, start, end, include_page=False):
  global args
  if args.dry_run:
    msg("Getting references to %s" % page)
    return []
  else:
    return blib.references(remove_macrons(page), start, end, include_page=include_page)

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
      if not getparam(t, "1"):
        if remove_macrons(lemma) != lemma:
          eccl = getparam(t, "eccl")
          rmparam(t, "eccl")
          t.add("1", lemma)
          if eccl:
            t.add("eccl", eccl)
          notes.append("add pronunciation to {{la-IPA}}")
      else:
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
parser.add_argument("--dry-run", help="Just show what would be checked, don't actually check references.", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

direcfile = args.direcfile.decode("utf-8")
for line in codecs.open(direcfile, "r", "utf-8"):
  line = line.rstrip('\n')
  if line.startswith("*"):
    line = line[1:]
    msg("Need to investigate: %s" % line)
  if line.startswith("#"):
    continue
  parts = line.split(" ")
  if len(parts) == 2 and parts[0] in ["adv", "phrase"]:
    pass
  elif len(parts) == 2 or len(parts) == 3 and parts[0] in ["n3", "a3"]:
    # noun or adjective
    if len(parts) == 3:
      pos, lemma, stem = parts
    else:
      pos, lemma = parts
      stem = None
    if pos == "n1":
      assert lemma.endswith("a")
      pos = "noun"
      stem = lemma[:-1]
    elif pos == "n2":
      assert lemma.endswith("us") or lemma.endswith("um")
      pos = "noun"
      if lemma.endswith("ius"):
        stem = [lemma[:-2], lemma[:-3] + u"ī"]
      else:
        stem = lemma[:-2]
    elif pos == "n3":
      pos = "noun"
      if stem:
        pass
      elif lemma.endswith(u"iō"):
        stem = lemma + "n"
      elif lemma.endswith("or"):
        stem = lemma[:-2] + u"ōr"
      elif lemma.endswith(u"īx"):
        stem = lemma[:-1] + "c"
      elif lemma.endswith(u"tās"):
        stem = lemma[:-1] + "t"
      elif lemma.endswith(u"ūdō"):
        stem = lemma[:-1] + "in"
      else:
        raise ValueError("Don't recognize n3 lemma %s" % lemma)
    elif pos == "n4":
      assert lemma.endswith("us")
      pos = "noun"
      stem = lemma[:-2]
    elif pos == "a1":
      assert lemma.endswith("us")
      pos = "adj"
      if lemma.endswith("ius"):
        stem = [lemma[:-2], lemma[:-3] + u"ī"]
      else:
        stem = lemma[:-2]
    elif pos == "a3":
      pos = "adj"
      if stem:
        pass
      elif lemma.endswith("is"):
        stem = lemma[:-2]
      elif lemma.endswith(u"āx"):
        stem = lemma[:-1] + "c"
      elif lemma.endswith("ior"):
        stem = [lemma[:-2] + "us", lemma[:-2] + u"ōr"]
      else:
        raise ValueError("Don't recognize a3 lemma %s" % lemma)
    else:
      raise ValueError("Don't recognize pos spec %s" % pos)
    def do_process_page(page, index, parsed):
      return process_page(index, page, pos, lemma, stem, args.save, args.verbose)
    for index, page in get_references(lemma, start, end):
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
      if lemma.startswith("*"):
        no_main = True
        lemma = lemma[1:]
      else:
        no_main = False
      # do the past passive and future active participles
      if not supine.startswith("*") and not supine.startswith("--"):
        assert supine.endswith("um")
        stems_lemmas.append((supine[:-2], supine[:-2] + "us", True))
        stems_lemmas.append((supine[:-2] + u"ūr", supine[:-2] + u"ūrus", True))
      if not no_main:
        # do the remaining two participles
        assert lemma.endswith(u"or") or lemma.endswith("itur")
        if inf.endswith(u"ārī"):
          short_part_stem = inf[:-3] + "a"
          long_part_stem = inf[:-2]
        elif inf.endswith(u"īrī"):
          short_part_stem = inf[:-3] + "ie"
          long_part_stem = inf[:-3] + u"iē"
        elif inf.endswith(u"ērī"):
          short_part_stem = inf[:-3] + "e"
          long_part_stem = inf[:-2]
        elif inf.endswith(u"ī") and lemma.endswith(u"iō"):
          short_part_stem = inf[:-1] + "ie"
          long_part_stem = inf[:-1] + u"iē"
        elif inf.endswith(u"ī") and lemma.endswith(u"it"):
          # impersonal -ī; don't know whether i-stem or not
          short_part_stem = [inf[:-1] + "e", inf[:-1] + "ie"]
          long_part_stem = [inf[:-1] + u"ē", inf[:-1] + u"iē"]
        else:
          assert inf.endswith(u"ī")
          short_part_stem = inf[:-1] + "e"
          long_part_stem = inf[:-1] + u"ē"
        if type(short_part_stem) is not list:
          short_part_stem = [short_part_stem]
        if type(long_part_stem) is not list:
          long_part_stem = [long_part_stem]
        for shstem, lostem in zip(short_part_stem, long_part_stem):
          stems_lemmas.append((shstem + "nt", lostem + "ns", True))
          stems_lemmas.append((shstem + "nd", shstem + "ndus", True))

        # do the present stem
        if lemma.endswith(u"or"):
          m = re.search(u"^(.*?)([ei]?)or$", lemma)
          assert m
          if inf.endswith(u"ārī"):
            stem = m.group(1) + m.group(2)
          else:
            stem = m.group(1)
        else:
          m = re.search(u"^(.*?)([āēīi])tur$", lemma)
          assert m
          stem = m.group(1)
        stems_lemmas.append((stem, lemma, False))

    else:
      assert len(parts) == 4
      lemma, inf, perf, supine = parts
      if lemma.startswith("*"):
        no_main = True
        lemma = lemma[1:]
      else:
        no_main = False
      # do the past passive and future active participles
      if not supine.startswith("*") and not supine.startswith("--"):
        assert supine.endswith("um")
        stems_lemmas.append((supine[:-2], supine[:-2] + "us", True))
        stems_lemmas.append((supine[:-2] + u"ūr", supine[:-2] + u"ūrus", True))
      # do the perfect stem
      if not perf.startswith("*") and not perf.startswith("--"):
        assert perf.endswith(u"ī") or perf.endswith("it")
        if perf.endswith(u"ī"):
          stems_lemmas.append((perf[:-1], lemma, False))
        else:
          # impersonal
          stems_lemmas.append((perf[:-2], lemma, False))
      if not no_main:
        # do the remaining two participles
        assert lemma.endswith(u"ō") or lemma.endswith("t")
        if inf.endswith(u"āre"):
          short_part_stem = inf[:-3] + "a"
          long_part_stem = inf[:-2]
        elif inf.endswith(u"īre") or inf.endswith("ere") and lemma.endswith(u"iō"):
          short_part_stem = inf[:-3] + "ie"
          long_part_stem = inf[:-3] + u"iē"
        elif inf.endswith(u"ere") and lemma.endswith(u"it"):
          # impersonal -ere; don't know whether i-stem or not
          short_part_stem = [inf[:-3] + "e", inf[:-3] + "ie"]
          long_part_stem = [inf[:-3] + u"ē", inf[:-3] + u"iē"]
        else:
          assert inf.endswith("ere") or inf.endswith(u"ēre")
          short_part_stem = inf[:-3] + "e"
          long_part_stem = inf[:-3] + u"ē"
        if type(short_part_stem) is not list:
          short_part_stem = [short_part_stem]
        if type(long_part_stem) is not list:
          long_part_stem = [long_part_stem]
        for shstem, lostem in zip(short_part_stem, long_part_stem):
          stems_lemmas.append((shstem + "nt", lostem + "ns", True))
          stems_lemmas.append((shstem + "nd", shstem + "ndus", True))

        # do the present stem
        if lemma.endswith(u"ō"):
          m = re.search(u"^(.*?)([ei]?)ō$", lemma)
          assert m
          if inf.endswith(u"āre"):
            stem = m.group(1) + m.group(2)
          else:
            stem = m.group(1)
        else:
          m = re.search(u"^(.*?)([aei])t$", lemma)
          assert m
          stem = m.group(1)
        stems_lemmas.append((stem, lemma, False))

    for stem, lemma, include_page in stems_lemmas:
      def do_process_page(page, index, parsed):
        return process_page(index, page, pos, lemma, stem, args.save, args.verbose)
      for index, page in get_references(lemma, start, end,
          include_page=include_page):
        no_macrons_stem = remove_macrons(stem)
        assert len(no_macrons_stem) == len(stem)
        if unicode(page.title()).startswith(no_macrons_stem):
          blib.do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose)
        else:
          msg("Skipped %s for lemma %s because doesn't match stem %s" % (
            unicode(page.title()), lemma, stem))
