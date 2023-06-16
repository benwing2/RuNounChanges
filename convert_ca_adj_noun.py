#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata
import romance_utils

import blib
from blib import getparam, rmparam, tname, pname, msg, site

prepositions = [
  # a + optional article (including salat)
  "al?s? ",
  # de + optional article (including salat)
  "del?s? ",
  "d'",
  # ca + optional article (including salat and [[en]])
  "can? ",
  "cal?s? ",
  # per + optional article
  "per ",
  "pels? ",
  # others
  "en ",
  "amb ",
  "cap ",
  "com ",
  "entre ",
  "sense ",
  "sobre ",
]

TEMPCHAR = u"\uFFF1"

unaccented_vowel = "aeiou"
accented_vowel = u"àèéíòóú"
vowel = unaccented_vowel + accented_vowel

V = "[" + vowel + "]"
UV = "[" + unaccented_vowel + "]"
AV = "[" + accented_vowel + "]"
C = "[^" + vowel + "]"

deny_list = {
  "test de Rorschach",
  "test",
  "host",
}

# Used when forming the feminine of adjectives in -i. Those with the stressed vowel 'e' or 'o' always seem to have è, ò.
accent_vowel = {
  "a": u"à",
  "e": u"è",
  "i": u"í",
  "o": u"ò",
  "u": u"ù",
}

# Remove accents from any of the vowels in a word.
# If an accented í follows another vowel, a diaeresis is added following
# normal Catalan spelling rules.
def remove_accents(word):
  def repl(m):
    preceding, vowel = m.groups()
    if vowel == u"í":
      if re.search("^[gq]u$", preceding):
        return preceding + "i"
      elif re.search("[aeiou]$", preceding):
        return preceding + u"ï"

    # Decompose the accented vowel to an unaccented vowel (a, e, i, o, u)
    # plus an acute or grave; return the unaccented vowel.
    return preceding + unicodedata.normalize("NFD", vowel)[0]

  return re.sub(u"(.?.?)([àèéíòóú])", repl, word)

# Applies alternation of the final consonant of a stem, converting the form
# used before a back vowel into the form used before a front vowel.
def back_to_front(stem):
  stem = re.sub("qu$", u"qü", stem)
  stem = re.sub("c$", "qu", stem)
  stem = re.sub(u"ç$", "c", stem)
  stem = re.sub("gu$", u"gü", stem)
  stem = re.sub("g$", "gu", stem)
  stem = re.sub("j$", "g", stem)
  return stem

# Applies alternation of the final consonant of a stem, converting the form
# used before a front vowel into the form used before a back vowel.
def front_to_back(stem):
  stem = re.sub("c$", u"ç", stem)
  stem = re.sub("qu$", "c", stem)
  stem = re.sub(u"qü$", "qu", stem)
  stem = re.sub("g$", "j", stem)
  stem = re.sub("gu$", "g", stem)
  stem = re.sub(u"gü$", "gu", stem)
  return stem

def make_feminine(base, special=None):
  retval = romance_utils.handle_multiword(base, special, make_feminine, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  # special cases
  # -able, -ible, -uble
  if (base.endswith("ble") or
    # stressed -al/-ar in a multisyllabic word (not [[gal]], [[anòmal]], or [[car]], [[clar]], [[rar]], [[var]],
    # [[isòbar]], [[èuscar]], [[búlgar]], [[tàrtar]]/[[tàtar]], [[càtar]], [[àvar]])
    (re.search(V + "[^ ]*a[lr]$", base) and not re.search(AV + "[^ ]*a[lr]$", base)) or
    # -ant in a multisyllabic word (not [[mant]], [[tant]], also [[quant]] but that needs manual handling)
    # -ent in a multisyllabic word (not [[lent]]; some other words in -lent have feminine in -a but not all)
    re.search(V + "[^ ]*[ae]nt$", base) or
    # Words in -aç, -iç, -oç (not [[descalç]], [[dolç]], [[agredolç]]; [[balbuç]] has -a and needs manual handling)
    re.search(V + u"ç$", base) or
    # Words in -il including when non-stressed ([[hàbil]], [[dèbil]], [[mòbil]], [[fàcil]], [[símil]], [[tàmil]],
    # etc.); but not words in -òfil, -èfil, etc.
    re.search("[^f]il$", base)):
    return base

  # final vowel -> -a
  if base.endswith("a"):
    return base
  if base.endswith("o"):
    return base[:-1] + "a"
  if base.endswith("e"):
    return front_to_back(base[:-1]) + "a"
  
  # -u -> -va
  if re.search(UV + "u$", base):
    return base[:-1] + "va"
  
  # accented vowel -> -na
  if re.search(AV + "$", base):
    return remove_accents(base) + "na"
  
  # accented vowel + -s -> -sa
  if re.search(AV + "s$", base):
    return remove_accents(base) + "a"
  
  # vowel + consonant(s) + i -> accent the first vowel, add -a
  m = re.search("^(.*)([aeo])i(" + C + "+)i$", base)
  if m:
    prev, first_vowel, cons = m.groups()
    # At least [[malaisi]]
    return prev + accent_vowel[first_vowel] + "i" + cons + "ia"
  m = re.search("^(.*)(" + UV + ")(" + C + "+)i$", base)
  if m:
    prev, first_vowel, cons = m.groups()
    return prev + accent_vowel[first_vowel] + cons + "ia"

  # multisyllabic -at/-it/-ut (also -ït/-üt) with stress on the final vowel -> -ada/-ida/-uda
  mod_base = re.sub("([gq])u(" + UV + ")", r"\1w\2", base) # hack so we don't treat the u in qu/gu as a vowel
  if (re.search(V + "[^ ]*[aiu]t$", mod_base) and not re.search(AV + "[^ ]*[aiu]t$", mod_base) and
      not re.search("[aeo][iu]t$", mod_base)) or re.search(u"[ïü]t$", mod_base):
    return base[:-1] + "da"

  return base + "a"

def make_plural(base, gender, special=None):
  retval = romance_utils.handle_multiword(base, special, lambda term: make_plural(term, gender), prepositions)
  if retval:
    return retval
  if special:
    return None

  # a -> es
  if base.endswith("a"):
    return [back_to_front(base[:-1]) + "es"]

  # accented vowel -> -ns
  if re.search(AV + "$", base):
    return [remove_accents(base) + "ns"]

  if gender == "m":
    if re.search(AV + "s$", base):
      return [remove_accents(base) + "os"]

    if re.search(u"[sçxz]$", base):
      return [base + "os"]

    if base.endswith("sc") or re.search("[sx]t$", base):
      return [base + "s", base + "os"]

  if gender == "f":
    if base.endswith("s"):
      return [base]

    if base.endswith("sc") or re.search("[sx]t$", base):
      return [base + "s", base + "es"]

  if base.endswith("eig"):
    return [base + "s", re.sub("ig$", "jos", base)]

  return [base + "s"]

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "ca-adj" not in text and "ca-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  if pagetitle in deny_list:
    pagemsg("Skipping because in deny_list")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  def do_make_plural(form, gender, special=None):
    retval = make_plural(form, gender, special)
    if retval is None:
      return []
    return retval

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)

    ############# Remove redundant params

    if tn == "ca-noun" and args.do_nouns:
      origt = str(t)
      subnotes = []

      head = getp("head")
      lemma = pagetitle

      def replace_lemma_with_hash(term):
        if term.startswith(lemma):
          replaced_term = "#" + term[len(lemma):]
          pagemsg("Replacing lemma-containing term '%s' with '%s'" % (term, replaced_term))
          subnotes.append("replace lemma-containing term '%s' with '%s'" % (term, replaced_term))
          term = replaced_term
        return term

      saw_qual = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if re.search("_qual$", pn):
          pagemsg("WARNING: Saw _qual parameter, can't handle: %s=%s" % (pn, pv))
          saw_qual = True
          break
      if saw_qual:
        continue

      gs = blib.fetch_param_chain(t, "1", "g")
      if len(gs) > 1:
        pagemsg("WARNING: Saw multiple genders, can't handle: %s" % str(t))
        continue
      if not gs:
        pagemsg("WARNING: No genders, can't handle: %s" % str(t))
        continue
      g = gs[0]

      autohead = romance_utils.add_links_to_multiword_term(lemma, splithyph=False)
      if autohead == head:
        pagemsg("Remove redundant head %s" % head)
        subnotes.append("remove redundant head '%s'" % head)
        head = None

      is_plural = g.endswith("-p")

      if not is_plural:
        while True:
          pls = blib.fetch_param_chain(t, "2", "pl")
          if not pls:
            break
          orig_pls = pls

          if g not in ["m", "f", "mf", "mfbysense"]:
            pagemsg("WARNING: Saw unrecognized gender '%s', can't handle: %s" % (g, str(t)))
            break

          g_for_plural = "f" if g == "f" else "m"
          new_pls = []
          defpl = make_plural(lemma, g_for_plural)
          if defpl is None:
            pagemsg("Can't generate default plural, skipping: %s" % str(t))
            break
          if len(defpl) > 1:
            if set(pls) == set(defpl):
              new_pls = ["+"]
            elif set(pls) < set(defpl):
              pagemsg("WARNING: pls=%s subset of defpls=%s, replacing with default" % (",".join(pls), ",".join(defpl)))
              new_pls = ["+"]
            else:
              new_pls = pls
          else:
            for pl in pls:
              if pl == defpl[0]:
                new_pls.append("+")
              else:
                new_pls.append(pl)

          if new_pls == ["+"]:
            redundant_msg = "redundant plural%s %s" % ("s" if len(pls) > 1 else "", ",".join("'%s'" % pl for pl in pls))
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
            pls = []
          elif new_pls != pls:
            for old_pl, new_pl in zip(pls, new_pls):
              if old_pl != new_pl:
                assert old_pl == defpl[0]
                assert new_pl == "+"
                pagemsg("Replacing default plural '%s' with '+'" % defpl)
                subnotes.append("replace default plural '%s' with '+'" % defpl)
            pls = new_pls

          for special in romance_utils.all_specials:
            special_pl = make_plural(lemma, g_for_plural, special)
            if special_pl is None:
              continue
            new_pls = []
            if len(special_pl) > 1:
              if set(pls) == set(special_pl):
                pagemsg("Found special=%s with special_pl=%s" % (special, ",".join(special_pl)))
                new_pls = ["+%s" % special]
              elif set(pls) < set(special_pl):
                pagemsg("WARNING: pls=%s subset of special_pl=%s, replacing with +%s" %
                  (",".join(pls), ",".join(special_pl), special))
                new_pls = ["+%s" % special]
            else:
              new_pls = []
              for pl in pls:
                if pl == special_pl[0]:
                  pagemsg("Found special=%s with special_pl=%s" % (special, ",".join(special_pl)))
                  pagemsg("Replacing plural '%s' with '+%s'" % (pl, special))
                  subnotes.append("replace plural '%s' with '+%s'" % (pl, special))
                  new_pls.append("+%s" % special)
                else:
                  new_pls.append(pl)
              if new_pls == pls:
                new_pls = []
            if new_pls:
              pls = new_pls
              break

          pls = [replace_lemma_with_hash(pl) for pl in pls]

          break

      def handle_mf(g, g_full, make_mf):
        mfs = [getp(g)]
        mfs = [mf for mf in mfs if mf]

        if mfs:
          defmf = make_mf(lemma)
          if mfs == [defmf]:
            subnotes.append("replace %s=%s with '+'" % (g, mfs[0]))
            return ["+"]
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
            subnotes.append("replace explicit %s '%s' with special indicator '+%s'" %
                (g_full, ",".join(mfs), actual_special))
            return ["+%s" % actual_special]
        return [replace_lemma_with_hash(mf) for mf in mfs]

      retval = handle_mf("f", "feminine", make_feminine)
      if retval is None:
        continue
      fs = retval

      if not is_plural:
        blib.set_param_chain(t, pls, "2", "pl")
      blib.set_param_chain(t, fs, "f")

      if head is None:
        rmparam(t, "head")
      elif head and head == pagetitle:
        subnotes.append("convert head= without brackets to nolinkhead=1")
        rmparam(t, "head")
        t.add("nolinkhead", "1")

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("clean up {{ca-noun}} (%s)" % "; ".join(blib.group_notes(subnotes)))
      else:
        pagemsg("No changes to %s" % str(t))

    if tn == "ca-adj" and args.do_adjs:
      origt = str(t)
      subnotes = []

      head = getp("head")
      lemma = pagetitle

      def replace_lemma_with_hash(term):
        if term.startswith(lemma):
          replaced_term = "#" + term[len(lemma):]
          pagemsg("Replacing lemma-containing term '%s' with '%s'" % (term, replaced_term))
          subnotes.append("replace lemma-containing term '%s' with '%s'" % (term, replaced_term))
          term = replaced_term
        return term

      saw_unhandlable = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn == "sp" or pn.startswith("fpl") or pn.endswith("_qual"):
          pagemsg("WARNING: Saw sp=, fpl* or *_qual parameter, can't handle: %s=%s: %s" % (pn, pv, str(t)))
          saw_unhandlable = True
          break
        if (pn == "1" or pn.startswith("f") or pn.startswith("pl") or pn.startswith("mpl")) and (pv == "+" or pv.startswith("#")):
          pagemsg("Saw + or #, skipping: %s=%s: %s" % (pn, pv, str(t)))
          saw_unhandlable = True
          break

      fs = blib.fetch_param_chain(t, "1", "f")
      origfs = fs
      if fs == ["inv"] or fs == ["ind"]:
        pagemsg("Saw invariable adjective, skipping: %s" % str(t))
        saw_unhandlable = True

      if not saw_unhandlable:
        deff = make_feminine(lemma)
        if fs == ["mf"]:
          fs = [lemma]
        if not fs:
          fs = [deff]

        fem_like_lemma = fs == [lemma]

        pls = blib.fetch_param_chain(t, "pl")
        origpls = pls
        mpls = blib.fetch_param_chain(t, "mpl")
        origmpls = mpls

        defmpl = None
        if not fem_like_lemma and " " not in lemma:
          for f in fs:
            if f.endswith("ssa"):
              # If the feminine ends in -ssa, assume that the -ss- is also in the
              # masculine plural form.
              defmpl = [f[:-1] + "os"]
              break
            elif f == lemma + "na":
              defmpl = [lemma + "ns"]
              break
            elif lemma.endswith("ig") and f.endswith("ja"):
              # Adjectives in -ig have two masculine plural forms, one derived from
              # the m.sg. and the other derived from the f.sg.
              defmpl = [lemma + "s", f[:-1] + "os"]
              break
        defmpl = defmpl or make_plural(lemma, "m")
        if defmpl is None:
          continue

        deffpl = None
        if fem_like_lemma and " " not in lemma and re.search(u"[çx]$", lemma):
          # Adjectives ending in -ç or -x behave as mf-type in the singular, but
          # regular type in the plural.
          deffpl = make_plural(lemma + "a", "f")
          if deffpl is None:
            continue
        else:
          deffpl = [x for f in fs for x in make_plural(f, "f")]

        new_fs = []
        this_subnotes = []
        if origfs:
          for f in fs:
            if f == deff:
              pagemsg("Replacing feminine '%s' with '+'" % f)
              this_subnotes.append("replace feminine '%s' with '+'" % f)
              new_fs.append("+")
            else:
              new_fs.append(replace_lemma_with_hash(f))
          if new_fs == ["+"]:
            redundant_msg = "redundant feminine%s %s" % ("s" if len(origfs) > 1 else "", ",".join("'%s'" % f for f in origfs))
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
            fs = []
          elif fem_like_lemma:
            fs = ["mf"]
            if fs != origfs:
              notes.append("convert feminine same as lemma to 'mf'")
          else:
            fs = new_fs
            subnotes.extend(this_subnotes)
        else:
          fs = []
     
        new_mpls = []

        if mpls:
          this_subnotes = []
          if len(defmpl) > 1:
            if set(mpls) == set(defmpl):
              new_mpls = ["+"]
            elif set(mpls) < set(defmpl):
              pagemsg("WARNING: mpls=%s subset of defmpl=%s, replacing with +" %
                (",".join(mpls), ",".join(defmpl)))
              new_mpls = ["+"]
          else:
            for mpl in mpls:
              if mpl == defmpl[0]:
                pagemsg("Replacing masculine plural '%s' with '+'" % mpl)
                this_subnotes.append("replace masculine plural '%s' with '+'" % mpl)
                new_mpls.append("+")
              else:
                new_mpls.append(replace_lemma_with_hash(mpl))
          if new_mpls == ["+"]:
            redundant_msg = "redundant masculine plural%s %s" % ("s" if len(mpls) > 1 else "", ",".join("'%s'" % mpl for mpl in mpls))
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
            mpls = []
          else:
            mpls = new_mpls
            subnotes.extend(this_subnotes)

        new_pls = []

        if pls and defmpl == deffpl:
          this_subnotes = []
          if len(defmpl) > 1:
            if set(pls) == set(defmpl):
              new_pls = ["+"]
            elif set(pls) < set(defmpl):
              pagemsg("WARNING: pls=%s subset of defmpl=%s, replacing with +" %
                (",".join(pls), ",".join(defmpl)))
              new_pls = ["+"]
          else:
            for pl in pls:
              if pl == defmpl[0]:
                pagemsg("Replacing plural '%s' with '+'" % pl)
                this_subnotes.append("replace plural '%s' with '+'" % pl)
                new_pls.append("+")
              else:
                new_pls.append(replace_lemma_with_hash(pl))
          if new_pls == ["+"]:
            redundant_msg = "redundant plural%s %s" % ("s" if len(pls) > 1 else "", ",".join("'%s'" % pl for pl in pls))
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
            pls = []
          else:
            pls = new_pls
            subnotes.extend(this_subnotes)

        # Don't bother trying to deduce sp=. There are few instances and most are invariable.

        blib.set_param_chain(t, fs, "1", "f")
        blib.set_param_chain(t, pls, "pl")
        blib.set_param_chain(t, mpls, "mpl")

      autohead = romance_utils.add_links_to_multiword_term(lemma, splithyph=False)
      if autohead == head:
        pagemsg("Remove redundant head %s" % head)
        subnotes.append("remove redundant head '%s'" % head)
        head = None

      if head is None:
        rmparam(t, "head")
      elif head and head == pagetitle:
        subnotes.append("convert head= without brackets to nolinkhead=1")
        rmparam(t, "head")
        t.add("nolinkhead", "1")

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("clean up {{ca-adj}} (%s)" % "; ".join(blib.group_notes(subnotes)))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Remove redundant args in {{ca-noun}} or {{ca-adj}}",
    include_pagefile=True, include_stdin=True)
  parser.add_argument("--do-nouns", action="store_true")
  parser.add_argument("--do-adjs", action="store_true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  default_refs = []
  if args.do_nouns:
    default_refs.append("Template:ca-noun")
  elif args.do_adjs:
    default_refs.append("Template:ca-adj")

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=default_refs)
