#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

remove_stress = {
  u"á": "a",
  u"é": "e",
  u"í": "i",
  u"ó": "o",
  u"ú": "u",
}

add_stress = {
  "a": u"á",
  "e": u"é",
  "i": u"í",
  "o": u"ó",
  "u": u"ú",
}

TEMPCHAR = u"\uFFF1"

def add_ending_to_plurals(plurals, ending):
  retval = []
  for pl in plurals:
    if type(ending) is list:
      for en in ending:
        retval.append(pl + en)
    else:
      retval.append(pl + ending)
  return retval

def make_plural(singular, special=None):
  if special == "first":
    m = re.search("^(.*?)( .*)$", singular)
    if not m:
      return None
    first, rest = m.groups()
    first_plural = make_plural(first)
    if first_plural is None:
      return None
    return add_ending_to_plurals(first_plural, rest)
  elif special == "second":
    m = re.search("^(.+? )(.+?)( .*)$", singular)
    if not m:
      return None
    first, second, rest = m.groups()
    second_plural = make_plural(second)
    if second_plural is None:
      return None
    return add_ending_to_plurals(add_ending_to_plurals([first], second_plural), rest)
  elif special == "first-last":
    m = re.search("^(.*?)( .* )(.*?)$", singular)
    if not m:
      m = re.search("^(.*?)( )(.*)$", singular)
    if not m:
      return None
    first, middle, last = m.groups()
    first_plural = make_plural(first)
    if first_plural is None:
      return None
    last_plural = make_plural(last)
    if last_plural is None:
      return None
    return add_ending_to_plurals(add_ending_to_plurals(first_plural, middle), last_plural)
  
  # ends in unstressed vowel or á, é, ó
  if re.search(u"[aeiouáéó]$", singular):
    return [singular + "s"]
  
  # ends in í or ú
  if re.search(u"[íú]$", singular):
    return [singular + "s", singular + "es"]
  
  # ends in a vowel + z
  if re.search(u"[aeiouáéíóú]z$", singular):
    return [re.sub("z$", "ces", singular)]
  
  # ends in tz
  if re.search("tz$", singular):
    return [singular]

  vowels = []
  # Replace qu before e or i so that the u isn't counted as a vowel.
  modified_singular = re.sub("qu([ie])", TEMPCHAR + r"\1", singular)
  for m in re.finditer(u"([aeiouáéíóú])", modified_singular):
    vowels.append(m.group(1))
  
  # ends in s or x with more than 1 syllable, last syllable unstressed
  if len(vowels) >= 2 and re.search("[sx]$", singular) and re.search("[aeiou]", vowels[-1]):
    return [singular]
  
  # ends in l, r, n, d, z, or j with 3 or more syllables, accented on third to last syllable
  if len(vowels) >= 3 and re.search("[lrndzj]$", singular) and re.search(u"[áéíóú]", vowels[-3]):
    return [singular]
  
  # ends in a stressed vowel + consonant
  if re.search(u"[áéíóú][^aeiouáéíóú]$", singular):
    return [re.sub("(.)(.)$", lambda m: remove_stress[m.group(1)] + m.group(2) + "es", singular)]
  
  # ends in a vowel + y, l, r, n, d, j, s, x
  if re.search("[aeiou][ylrndjsx]$", singular):
    # two or more vowels: add stress mark to plural
    if len(vowels) >= 2 and re.search("n$", singular):
      m = re.search("^(.*)[aeiou]([^aeiou]*[aeiou][nl])$", modified_singular)
      if m:
        before_stress, after_stress = m.groups()
        stress = add_stress.get(vowels[-2], None)
        if stress:
          return [re.sub(TEMPCHAR, "qu", before_stress + stress + after_stress + "es")]
    
    return [singular + "es"]
  
  # ends in a vowel + ch
  if re.search("[aeiou]ch$", singular):
    return [singular + "es"]
  
  # ends in two consonants
  if re.search(u"[^aeiouáéíóú][^aeiouáéíóú]$", singular):
    return [singular + "s"]
  
  # ends in a vowel + consonant other than l, r, n, d, z, j, s, or x
  if re.search("[aeiou][^aeioulrndzjsx]$", singular):
    return [singular + "s"]

  return None

def make_feminine(form, special=None):
  if special == "first":
    m = re.search("^(.*?)( .*)$", form)
    if not m:
      return None
    first, rest = m.groups()
    return make_feminine(first) + rest
  elif special == "second":
    m = re.search("^(.+? )(.+?)( .*)$", form)
    if not m:
      return None
    first, second, rest = m.groups()
    return first + make_feminine(second) + rest
  elif special == "first-last":
    m = re.search("^(.*?)( .* )(.*?)$", form)
    if not m:
      m = re.search("^(.*?)( )(.*)$", form)
    if not m:
      return None
    first, middle, last = m.groups()
    return make_feminine(first) + middle + make_feminine(last)

  if form.endswith("o"):
    return form[:-1] + "a"
  
  def make_stem(form):
    return re.sub(
      "^(.+)(.)(.)$",
      lambda m: m.group(1) + remove_stress.get(m.group(2), m.group(2)) + m.group(3),
      form
    )
  
  if re.search(u"([áíó]n|[éí]s|[dtszx]or)$", form):
    # holgazán, comodín, bretón (not común); francés, kirguís (not mandamás);
    # volador, agricultor, defensor, avizor, flexor (not posterior, bicolor, mayor, mejor, menor, peor)
    return make_stem(form) + "a"

  return form

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "es-adj" not in text and "es-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "es-noun" and args.remove_redundant_noun_args:
      origt = unicode(t)
      head = getparam(t, "head") or pagetitle
      if not getparam(t, "2") and (getparam(t, "pl2") or getparam(t, "pl3")):
        pagemsg("WARNING: Saw pl2= or pl3= without 2=: %s" % unicode(t))
        continue
      ms = blib.fetch_param_chain(t, "m", "m")
      space_in_m = False
      for m in ms:
        if " " in m:
          space_in_m = True
      mpls = blib.fetch_param_chain(t, "mpl", "mpl")
      if space_in_m and not mpls:
        pagemsg("WARNING: Space in m=%s and old default noun algorithm applying" % ",".join(ms))
      fs = blib.fetch_param_chain(t, "f", "f")
      fpls = blib.fetch_param_chain(t, "fpl", "fpl")
      space_in_f = False
      for f in fs:
        if " " in f:
          space_in_f = True
      fpls = blib.fetch_param_chain(t, "fpl", "fpl")
      if space_in_f and not fpls:
        pagemsg("WARNING: Space in f=%s and old default noun algorithm applying" % ",".join(fs))
      pls = blib.fetch_param_chain(t, "2", "pl")
      if not pls:
        if " " in head:
          pagemsg("WARNING: Space in headword and old default noun algorithm applying")
        continue
      pls_with_def = []
      defpl = make_plural(head, "noun")
      if not defpl:
        continue
      if len(defpl) > 1:
        if set(pls) == set(defpl):
          pls_with_def = ["+"]
        elif set(pls) < set(defpl):
          pagemsg("WARNING: pls=%s subset of defpls=%s, replacing with default" % (",".join(pls), ",".join(defpl)))
          pls_with_def = ["+"]
        else:
          pls_with_def = pls
      else:
        for pl in pls:
          if pl == defpl[0]:
            pls_with_def.append("+")
          else:
            pls_with_def.append(pl)

      actual_special = None
      for special in ["first", "second", "first-last"]:
        special_pl = make_plural(head, special)
        if special_pl is None:
          continue
        if len(special_pl) > 1 and set(pls) < set(special_pl):
          pagemsg("WARNING: for special=%s, pls=%s subset of special_pl=%s, allowing" % (
            special, ",".join(pls), ",".join(special_pl)))
          actual_special = special
          break
        if set(pls) == set(special_pl):
          pagemsg("Found special=%s with special_pl=%s" % (special, ",".join(special_pl)))
          actual_special = special
          break

      if actual_special:
        notes.append("replace plural%s %s with *%s in {{es-noun}}" % (
          "s" if len(pls) > 1 else "", ",".join(pls), actual_special))
        blib.set_param_chain(t, ["*" + actual_special], "2", "pl")
      elif pls_with_def == ["+"]:
        notes.append("remove redundant plural%s %s from {{es-noun}}" % ("s" if len(pls) > 1 else "", ",".join(pls)))
        blib.remove_param_chain(t, "2", "pl")
      elif pls_with_def != pls:
        notes.append("replace default plural %s with '+' in {{es-noun}}" % ",".join(defpl))
        blib.set_param_chain(t, pls_with_def, "2", "pl")

      fs = blib.fetch_param_chain(t, "f", "f")
      if fs:
        deff = make_feminine(head)
        fs_with_def = ["+" if f == deff else f for f in fs]
        if fs_with_def != fs:
          notes.append("replace default feminine %s with '+' in {{es-noun}}" % deff)
          blib.set_param_chain(t, fs_with_def, "f", "f")

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

    if tn == "es-noun" and args.make_multiword_plural_explicit:
      origt = unicode(t)
      head = getparam(t, "head") or pagetitle
      def expand_text(tempcall):
        return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
      if " " in head and not getparam(t, "2"):
        g = getparam(t, "1")
        if not g.endswith("-p"):
          explicit_pl = expand_text("{{#invoke:es-headword|make_plural_noun|%s|%s|true}}" % (
            blib.remove_links(head), g))
          if not explicit_pl:
            pagemsg("WARNING: Unable to add explicit plural to multiword noun, make_plural_noun returned an empty string")
            continue
          plurals = explicit_pl.split(",")
          blib.set_param_chain(t, plurals, "2", "pl")
          notes.append("add explicit plural to multiword noun")
      ms = blib.fetch_param_chain(t, "m", "m")
      space_in_m = False
      for m in ms:
        if " " in m:
          space_in_m = True
      mpls = blib.fetch_param_chain(t, "mpl", "mpl")
      if space_in_m and not mpls:
        mpls = []
        for m in ms:
          explicit_pl = expand_text("{{#invoke:es-headword|make_plural_noun|%s|m|true}}" % (
            blib.remove_links(m)))
          if not explicit_pl:
            pagemsg("WARNING: Unable to add explicit plural to m=%s, make_plural_noun returned an empty string" % m)
            continue
          this_mpls = explicit_pl.split(",")
          mpls.extend(this_mpls)
        blib.set_param_chain(t, mpls, "mpl", "mpl")
        notes.append("add explicit plural to m=%s" % ",".join(ms))
      fs = blib.fetch_param_chain(t, "f", "f")
      fpls = blib.fetch_param_chain(t, "fpl", "fpl")
      space_in_f = False
      for f in fs:
        if " " in f:
          space_in_f = True
      fpls = blib.fetch_param_chain(t, "fpl", "fpl")
      if space_in_f and not fpls:
        fpls = []
        for f in fs:
          explicit_pl = expand_text("{{#invoke:es-headword|make_plural_noun|%s|f|true}}" % (
            blib.remove_links(f)))
          if not explicit_pl:
            pagemsg("WARNING: Unable to add explicit plural to f=%s, make_plural_noun returned an empty string" % f)
            continue
          this_fpls = explicit_pl.split(",")
          fpls.extend(this_fpls)
        blib.set_param_chain(t, fpls, "fpl", "fpl")
        notes.append("add explicit plural to f=%s" % ",".join(fs))
      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))

    if tn == "es-adj":
      origt = unicode(t)
      deff = make_feminine(pagetitle)
      defmpl = make_plural(pagetitle)
      fs = []
      fullfs = []
      f = getparam(t, "f") or pagetitle
      fullfs.append(f)
      if f == deff:
        f = "+"
      fs.append(f)
      f2 = getparam(t, "f2")
      if f2:
        fullfs.append(f2)
        if f2 == deff:
          f2 == "+"
        fs.append(f2)
      mpls = []
      mpl = getparam(t, "mpl") or getparam(t, "pl") or pagetitle + "s"
      mpls.append(mpl)
      mpl2 = getparam(t, "mpl2") or getparam(t, "pl2")
      if mpl2:
        mpls.append(mpl2)
      fullmpls = mpls
      # should really check for subsequence but it never occurs
      if mpls == defmpl:
        mpls = ["+"]
      deffpl = [x for f in fullfs for x in make_plural(f)]
      fpls = []
      fpl = getparam(t, "fpl") or getparam(t, "pl") or (getparam(t, "f") or pagetitle) + "s"
      fpls.append(fpl)
      fpl2 = getparam(t, "fpl2") or getparam(t, "pl2")
      if fpl2:
        fpls.append(fpl2)
      fullfpls = fpls
      # should really check for subsequence but it never occurs
      if fpls == deffpl:
        fpls = ["+"]
      actual_special = None
      for special in ["first", "second", "first-last"]:
        deff = make_feminine(pagetitle, special)
        if deff is None:
          continue
        defmpl = make_plural(pagetitle, special)
        deffpl = make_plural(deff, special)
        deff = [deff]
        if fullfs == deff and fullmpls == defmpl and fullfpls == deffpl:
          actual_special = special
          break

      head = getparam(t, "head")

      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["head", "f", "f2", "pl", "pl2", "mpl", "mpl2", "fpl", "fpl2"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, unicode(param.value), unicode(t)))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      if head:
        t.add("head", head)
      if fullfs == [pagetitle] and fullmpls == [pagetitle] and fullfpls == [pagetitle]:
        blib.set_template_name(t, "es-adj-inv")
      elif actual_special:
        t.add("sp", actual_special)
      else:
        if fs != ["+"]:
          blib.set_param_chain(t, fs, "f", "f")

        if mpls == fpls and ("+" not in mpls or defmpl == deffpl):
          # masc and fem pl the same
          if mpls != ["+"]:
            blib.set_param_chain(t, mpls, "pl", "pl")
        else:
          if mpls != ["+"]:
            blib.set_param_chain(t, mpls, "mpl", "mpl")
          if fpls != ["+"]:
            blib.set_param_chain(t, fpls, "fpl", "fpl")

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        notes.append("convert {{es-adj}} to new format")
      else:
        pagemsg("No changes to %s" % unicode(t))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{es-adj}} templates to new format or remove redundant args in {{es-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--remove-redundant-noun-args", action="store_true")
parser.add_argument("--make-multiword-plural-explicit", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_redundant_noun_args:
  default_refs=["Template:es-noun"]
else:
  default_refs=["Template:es-adj"]

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
