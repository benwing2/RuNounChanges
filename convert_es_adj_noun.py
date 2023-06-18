#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import romance_utils

import blib
from blib import getparam, rmparam, tname, pname, msg, site

remove_stress = {
  "á": "a",
  "é": "e",
  "í": "i",
  "ó": "o",
  "ú": "u",
}

add_stress = {
  "a": "á",
  "e": "é",
  "i": "í",
  "o": "ó",
  "u": "ú",
}

prepositions = {
  "a ",
  "al ",
  "de ",
  "del ",
  "como ",
  "con ",
  "en ",
  "para ",
  "por ",
}

TEMPCHAR = "\uFFF1"

old_adj_template = "es-adj-old"
#old_adj_template = "es-adj"

def make_plural(form, special=None):
  retval = romance_utils.handle_multiword(form, special, make_plural, prepositions)
  if retval:
    return retval
  if special:
    return None
  
  # ends in unstressed vowel or á, é, ó
  if re.search("[aeiouáéó]$", form):
    return [form + "s"]
  
  # ends in í or ú
  if re.search("[íú]$", form):
    return [form + "s", form + "es"]
  
  # ends in a vowel + z
  if re.search("[aeiouáéíóú]z$", form):
    return [re.sub("z$", "ces", form)]
  
  # ends in tz
  if re.search("tz$", form):
    return [form]

  vowels = []
  # Replace qu before e or i so that the u isn't counted as a vowel.
  modified_form = re.sub("qu([ie])", TEMPCHAR + r"\1", form)
  for m in re.finditer("([aeiouáéíóú])", modified_form):
    vowels.append(m.group(1))
  
  # ends in s or x with more than 1 syllable, last syllable unstressed
  if len(vowels) >= 2 and re.search("[sx]$", form) and re.search("[aeiou]", vowels[-1]):
    return [form]
  
  # ends in l, r, n, d, z, or j with 3 or more syllables, accented on third to last syllable
  if len(vowels) >= 3 and re.search("[lrndzj]$", form) and re.search("[áéíóú]", vowels[-3]):
    return [form]
  
  # ends in a stressed vowel + consonant
  if re.search("[áéíóú][^aeiouáéíóú]$", form):
    return [re.sub("(.)(.)$", lambda m: remove_stress[m.group(1)] + m.group(2) + "es", form)]
  
  # ends in a vowel + y, l, r, n, d, j, s, x
  if re.search("[aeiou][ylrndjsx]$", form):
    # two or more vowels: add stress mark to plural
    if len(vowels) >= 2 and re.search("n$", form):
      m = re.search("^(.*)[aeiou]([^aeiou]*[aeiou][nl])$", modified_form)
      if m:
        before_stress, after_stress = m.groups()
        stress = add_stress.get(vowels[-2], None)
        if stress:
          return [re.sub(TEMPCHAR, "qu", before_stress + stress + after_stress + "es")]
    
    return [form + "es"]
  
  # ends in a vowel + ch
  if re.search("[aeiou]ch$", form):
    return [form + "es"]
  
  # ends in two consonants
  if re.search("[^aeiouáéíóú][^aeiouáéíóú]$", form):
    return [form + "s"]
  
  # ends in a vowel + consonant other than l, r, n, d, z, j, s, or x
  if re.search("[aeiou][^aeioulrndzjsx]$", form):
    return [form + "s"]

  return None

def make_feminine(form, special=None):
  retval = romance_utils.handle_multiword(form, special, make_feminine, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  if form.endswith("o"):
    return form[:-1] + "a"
  
  def make_stem(form):
    return re.sub(
      "^(.+)(.)(.)$",
      lambda m: m.group(1) + remove_stress.get(m.group(2), m.group(2)) + m.group(3),
      form
    )
  
  if re.search("([áíó]n|[éí]s|[dtszxñ]or|ol)$", form):
    # holgazán, comodín, bretón (not común); francés, kirguís (not mandamás);
    # volador, agricultor, defensor, avizor, flexor, señor (not posterior, bicolor, mayor, mejor, menor, peor);
    # español, mongol
    return make_stem(form) + "a"

  return form

def make_masculine(form, special=None):
  retval = romance_utils.handle_multiword(form, special, make_masculine, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  if form.endswith("dora"):
    return form[:-1]
  if form.endswith("a"):
    return form[:-1] + "o"
  return form

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if old_adj_template not in text and "es-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "es-noun" and args.remove_redundant_noun_args:
      origt = str(t)
      lemma = blib.remove_links(getparam(t, "head") or pagetitle)
      if not getparam(t, "2") and (getparam(t, "pl2") or getparam(t, "pl3")):
        pagemsg("WARNING: Saw pl2= or pl3= without 2=: %s" % str(t))
        continue
      g = getparam(t, "1")
      ms = blib.fetch_param_chain(t, "m", "m")
      space_in_m = False
      for m in ms:
        if " " in m:
          space_in_m = True
      mpls = blib.fetch_param_chain(t, "mpl", "mpl")
      if space_in_m and not mpls and not g.endswith("-p"):
        pagemsg("WARNING: Space in m=%s and old default noun algorithm applying" % ",".join(ms))
      fs = blib.fetch_param_chain(t, "f", "f")
      space_in_f = False
      for f in fs:
        if " " in f:
          space_in_f = True
      fpls = blib.fetch_param_chain(t, "fpl", "fpl")
      if space_in_f and not fpls and not g.endswith("-p"):
        pagemsg("WARNING: Space in f=%s and old default noun algorithm applying" % ",".join(fs))
      pls = blib.fetch_param_chain(t, "2", "pl")
      if not pls and not g.endswith("-p"):
        if " " in lemma:
          pagemsg("WARNING: Space in headword and old default noun algorithm applying")
        continue
      pls_with_def = []
      defpl = make_plural(lemma)
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
      for special in romance_utils.all_specials:
        special_pl = make_plural(lemma, special)
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

      if pls_with_def == ["+"]:
        notes.append("remove redundant plural%s %s from {{es-noun}}" % ("s" if len(pls) > 1 else "", ",".join(pls)))
        blib.remove_param_chain(t, "2", "pl")
      elif actual_special:
        notes.append("replace plural%s %s with +%s in {{es-noun}}" % (
          "s" if len(pls) > 1 else "", ",".join(pls), actual_special))
        blib.set_param_chain(t, ["+" + actual_special], "2", "pl")
      elif pls_with_def != pls:
        notes.append("replace default plural %s with '+' in {{es-noun}}" % ",".join(defpl))
        blib.set_param_chain(t, pls_with_def, "2", "pl")

      def handle_mf(mf, mf_full, make_mf):
        mfs = blib.fetch_param_chain(t, mf, mf)
        mfpls = blib.fetch_param_chain(t, mf + "pl", mf + "pl")
        if mfs and not any(x.startswith("+") for x in mfs):
          defmf = make_mf(lemma)
          if set(mfs) == {defmf}:
            defpls = make_plural(defmf)
            ok = False
            if not mfpls or set(mfpls) == set(defpls):
              ok = True
            elif set(mfpls) < set(defpls):
              pagemsg("WARNING: %pl=%s subset of default=%s, allowing" % (
                mf, ",".join(mfpls), ",".join(defpls)))
              ok = True
            if ok:
              notes.append("replace %s=%s with '+' in {{es-noun}}" % (mf, ",".join(mfs)))
              blib.set_param_chain(t, ["+"], mf, mf)
              blib.remove_param_chain(t, mf + "pl", mf + "pl")
              return
          actual_special = None
          for special in romance_utils.all_specials:
            special_mf = make_mf(lemma, special)
            if special_mf is None:
              continue
            if mfs == [special_mf]:
              pagemsg("Found special=%s with special_mf=%s" % (special, special_mf))
              actual_special = special
              break
          if actual_special:
            if not mfpls:
              pagemsg("WARNING: Explicit %s=%s matches special=%s but no %s plural" % (
                mf, ",".join(mfs), actual_special, mf_full))
            else:
              special_mfpl = make_plural(special_mf, actual_special)
              if special_mfpl:
                if len(special_mfpl) > 1 and set(mfpls) < set(special_mfpl):
                  pagemsg("WARNING: for %s=%s and special=%s, %spls=%s subset of special_%spl=%s, allowing" % (
                    mf, ",".join(mfs), actual_special, mf, ",".join(mfpls), mf, ",".join(special_mfpl)))
                elif set(mfpls) == set(special_mfpl):
                  pagemsg("Found %s=%s and special=%s, %spls=%s matches special_%spl" % (
                    mf, ",".join(mfs), actual_special, mf, ",".join(mfpls), mf))
                else:
                  pagemsg("WARNING: for %s=%s and special=%s, %spls=%s doesn't match special_%spl=%s" % (
                    mf, ",".join(mfs), actual_special, mf, ",".join(mfpls), mf, ",".join(special_mfpl)))
                  actual_special = None
            if actual_special:
              notes.append("replace explicit %s %s with special indicator '+%s' in {{es-noun}} and remove explicit %s plural" %
                  (mf_full, ",".join(mfs), actual_special, mf_full))
              blib.set_param_chain(t, ["+%s" % actual_special], mf, mf)
              blib.remove_param_chain(t, mf + "pl", mf + "pl")
          if not actual_special:
            defmf = make_mf(lemma)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              notes.append("replace default %s %s with '+' in {{es-noun}}" % (mf_full, defmf))
              blib.set_param_chain(t, mfs_with_def, mf, mf)
            if mfpls:
              defpl = [x for y in mfs for x in (make_plural(y) or [])]
              ok = False
              if set(defpl) == set(mfpls):
                ok = True
              elif len(defpl) > 1 and set(mfpls) < set(defpl):
                pagemsg("WARNING: for %s=%s, %spl=%s subset of default pl %s, allowing" % (
                  mf, ",".join(mfs), mf, ",".join(mfpls), ",".join(defpl)))
                ok = True
              if ok:
                pagemsg("Found %s=%s, %spl=%s matches default pl" % (mf, ",".join(mfs), mf, ",".join(mfpls)))
                notes.append("remove redundant explicit %s plural %s in {{es-noun}}" % (mf_full, ",".join(mfpls)))
                blib.remove_param_chain(t, mf + "pl", mf + "pl")
              else:
                for special in romance_utils.all_specials:
                  defpl = [x for y in mfs for x in (make_plural(y, special) or [])]
                  if set(defpl) == set(mfpls):
                    pagemsg("Found %s=%s, %spl=%s matches special=%s" % (
                      mf, ",".join(mfs), mf, ",".join(mfpls), special))
                    notes.append("replace explicit %s plural %s with special indicator '+%s' in {{es-noun}}" %
                        (mf_full, ",".join(mfpls), special))
                    blib.set_param_chain(t, ["+%s" % special], mf + "pl", mf + "pl")

      handle_mf("f", "feminine", make_feminine)
      handle_mf("m", "masculine", make_masculine)

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
      else:
        pagemsg("No changes to %s" % str(t))

    if tn == "es-noun" and args.make_multiword_plural_explicit:
      origt = str(t)
      lemma = blib.remove_links(getparam(t, "head") or pagetitle)
      def expand_text(tempcall):
        return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
      if " " in lemma and not getparam(t, "2"):
        g = getparam(t, "1")
        if not g.endswith("-p"):
          explicit_pl = expand_text("{{#invoke:es-headword|make_plural_noun|%s|%s|true}}" % (lemma, g))
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
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

    if tn == old_adj_template:
      origt = str(t)
      lemma = blib.remove_links(getparam(t, "head") or pagetitle)
      deff = make_feminine(pagetitle)
      defmpl = make_plural(pagetitle)
      fs = []
      fullfs = []
      f = getparam(t, "f") or pagetitle
      fullfs.append(f)
      if f == deff:
        f = "+"
      elif f == lemma:
        f = "#"
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
      if set(mpls) == set(defmpl):
        mpls = ["+"]
      elif set(mpls) < set(defmpl):
        pagemsg("WARNING: mpls=%s subset of defmpl=%s, replacing with default" % (",".join(mpls), ",".join(defmpl)))
        mpls = ["+"]
      mpls = ["#" if x == lemma else x for x in mpls]
      deffpl = [x for f in fullfs for x in make_plural(f)]
      fpls = []
      fpl = getparam(t, "fpl") or getparam(t, "pl") or (getparam(t, "f") or pagetitle) + "s"
      fpls.append(fpl)
      fpl2 = getparam(t, "fpl2") or getparam(t, "pl2")
      if fpl2:
        fpls.append(fpl2)
      fullfpls = fpls
      # should really check for subsequence but it never occurs
      if set(fpls) == set(deffpl):
        fpls = ["+"]
      elif set(fpls) < set(deffpl):
        pagemsg("WARNING: fpls=%s subset of deffpl=%s, replacing with default" % (",".join(fpls), ",".join(deffpl)))
        fpls = ["+"]
      fpls = ["#" if x == lemma else x for x in fpls]
      actual_special = None
      for special in romance_utils.all_specials:
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
        pv = str(param.value)
        if pn == "1" and pv in ["m", "mf"]:
          pagemsg("WARNING: Extraneous param %s=%s in %s, ignoring" % (pn, pv, str(t)))
          continue
        if pn not in ["head", "f", "f2", "pl", "pl2", "mpl", "mpl2", "fpl", "fpl2"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      if head:
        t.add("head", head)
      if fullfs == [pagetitle] and fullmpls == [pagetitle] and fullfpls == [pagetitle]:
        blib.set_template_name(t, "es-adj-inv")
      else:
        blib.set_template_name(t, "es-adj")
        if actual_special:
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

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{%s}} to new {{%s}} format" % (old_adj_template, tname(t)))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{es-adj}} templates to new format or remove redundant args in {{es-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--remove-redundant-noun-args", action="store_true")
parser.add_argument("--make-multiword-plural-explicit", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_redundant_noun_args:
  default_refs=["Template:es-noun"]
else:
  default_refs=["Template:%s" % old_adj_template]

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
