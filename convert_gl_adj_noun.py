#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, unicodedata
import romance_utils

import blib
from blib import getparam, rmparam, tname, pname, msg, site

unaccented_vowel = "aeiouüAEIOUÜ"
accented_vowel = "áéíóúýÁÉÍÓÚÝ"
vowel = unaccented_vowel + accented_vowel
V = "[" + vowel + "]"
AV = "[" + accented_vowel + "]"
NAV = "[^" + accented_vowel + "]"
W = "[iyuw]" # glide
C = "[^" + vowel + ".]"
remove_accent = {
  "á":"a", "é":"e", "í":"i", "ó":"o", "ú":"u", "ý":"y",
  "Á":"A", "É":"E", "Í":"I", "Ó":"O", "Ú":"U", "Ý":"Y",
}

prepositions = [
  # a + optional article
  "a ",
  "ás? ",
  "aos? ",
  # con + optional article
  "con ",
  "coa?s? ",
  # de + optional article
  "de ",
  "d[oa]s? ",
  "d'",
  # en/em + optional article
  "en ",
  "n[oa]s? ",
  # por + optional article
  "por ",
  "pol[oa]s? ",
  # para + optional article
  "para ",
  "pr[óá]s? ",
  # others
  "at[aé] ",
  "como ",
  "entre ",
  "sen ",
  "so ",
  "sobre ",
]

deny_list = set()

def make_try(word):
  def retfun(fr, to):
    if re.search(fr, word):
      return re.sub(fr, to, word)
    return None
  return retfun

def make_feminine(term, is_noun, special=None):
  retval = romance_utils.handle_multiword(term, special, lambda term: make_feminine(term, is_noun), prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  tr = make_try(term)

  # Based on https://www.lingua.gal/c/document_library/get_file?file_path=/portal-lingua/celga/celga-1/material-alumno/Manual_Aula_de_Galego_1_resumo_gramatical.pdf
  return (
    tr("o$", "a") or
    tr("º$", "ª") or # ordinal indicator
    tr("^(" + C + "*)u$", r"\1úa") or # [[nu]] -> núa, [[cru]] -> crúa
    tr("^eu$", "ía") or # [[sandeu]] -> sandía, [[xudeu]] -> xudía
    # many nouns and adjectives in -án:
    # [[afgán]], [[alazán]], [[aldeán]], [[alemán]], [[ancián]], [[aresán]], [[arnoián]], [[arousán]], [[artesán]],
    # [[arzuán]], [[barregán]], [[bergantiñán]], [[bosquimán]], [[buxán]], [[caldelán]], [[camariñán]],
    # [[capitán]], [[carnotán]], [[castelán]], [[catalán]], [[cidadán]], [[cirurxián]], [[coimbrán]], [[comarcán]],
    # [[compostelán]], [[concidadán]], [[cortesán]], [[cotián]], [[cristián]], [[curmán]], [[desirmán]],
    # [[ermitán]], [[ferrolán]], [[fisterrán]], [[gardián]], [[insán]], [[irmán]], [[louzán]], [[malpicán]],
    # [[malsán]], [[mariñán]], [[marrán]], [[muradán]], [[musulmán]], [[muxián]], [[neurocirurxián]], [[nugallán]],
    # [[otomán]], [[ourensán]], [[pagán]], [[paleocristián]], [[ponteareán]], [[pontecaldelán]], [[redondelán]],
    # [[ribeirán]], [[rufián]], [[sacristán]], [[salnesán]], [[sancristán]], [[sultán]], [[tecelán]], [[temperán]],
    # [[temporán]], [[truán]], [[turcomán]], [[ullán]], [[vilagarcián]], [[vilán]]
    #
    # but not (instead in -ana):
    # [[baleigán]], [[barbuzán]], [[barrigán]], [[barullán]], [[bergallán]], [[bocalán]], [[brután]], [[buleirán]],
    # [[burrán]], [[burricán]], [[cabezán]], [[cachamoulán]], [[cachán]], [[cacholán]], [[cagán]], [[canelán]],
    # [[cangallán]], [[carallán]], [[carcamán]], [[carneirán]], [[carroulán]], [[chalán]], [[charlatán]],
    # [[cornán]], [[cornelán]], [[farfallán]], [[folán]], [[folgazán]], [[galbán]], [[guedellán]], [[lacazán]],
    # [[langrán]], [[larpán]], [[leilán]], [[lerchán]], [[lombán]], [[lorán]], [[lordán]], [[loubán]],
    # [[mentirán]], [[mourán]], [[orellán]], [[paduán]], [[pailán]], [[palafustrán]], [[papán]], [[parvallán]],
    # [[paspán]], [[pastrán]], [[pelandrán]], [[pertegán]], [[pillabán]], [[porcallán]], [[ruán]],
    # [[tangueleirán]], [[testalán]], [[testán]], [[toleirán]], [[vergallán]], [[zalapastrán]], [[zampallán]]
    tr("án$", "á") or
    # nouns in -z e.g. [[rapaz]]; but not [[feliz]], [[capaz]], [[perspicaz]], etc.
    # only such adjective is [[andaluz]] -> andaluza, [[rapaz]] -> rapaza
    is_noun and tr("z$", "za") or
    tr("ín$", "ina") or # [[bailarín]], [[benxamín]], [[danzarín]], [[galopín]], [[lampantín]], [[mandarín]],
               # [[palanquín]]; but not [[afín]], [[pimpín]], [[ruín]]
    # [[abusón]], [[chorón]], [[felón]], etc.
    #
    # but not (instead in -oa): [[anglosaxón]], [[baixosaxón]], [[beirón]], [[borgoñón]], [[bretón]], [[campión]],
    # [[eslavón]], [[francón]], [[frisón]], [[gascón]], [[grisón]], [[ladrón]] (also fem. ladra), [[letón]],
    # [[nipón]], [[patagón]], [[saxón]], [[teutón]], [[valón]], [[vascón]]
    #
    # but not (invariable in singular): [[grelón]], [[maricón]], [[marón]], [[marrón]], [[roulón]], [[salmón]],
    # [[xiprón]]
    tr("ón$", "ona") or
    tr("és$", "esa") or # [[francés]], [[portugués]], [[fregués]], [[vigués]] etc.
               # but not [[cortés]], [[descortés]] 
    # adjectives in:
    # * [[-ador]], [[-edor]] ([[amortecedor]], [[compilador]], etc.), [[-idor]] ([[inhibidor]], etc.)
    # * -tor ([[condutor]], [[construtor]], [[colector]], etc.)
    # * -sor ([[agresor]], [[censor]], [[divisor]], etc.)
    # but not:
    # * [[anterior]]/[[posterior]]/[[inferior]]/[[júnior]]/[[maior]]/[[peor]]/[[mellor]]/etc.
    # * [[bicolor]]/[[multicolor]]/etc.
    tr("([dts]or)$", r"\1a") or
    term
  )

def make_plural(term, special=None):
  retval = romance_utils.handle_multiword(term, special, make_plural, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  tr = make_try(term)

  # Based on https://www.lingua.gal/c/document_library/get_file?file_path=/portal-lingua/celga/celga-1/material-alumno/Manual_Aula_de_Galego_1_resumo_gramatical.pdf
  return (
    tr("r$", "res") or
    tr("z$", "ces") or
    tr("(" + V + "be)l$", r"\1is") or # vowel + -bel
    tr("(" + AV + ".*" + V + ")l$", r"\1es") or # non-final stress + -l e.g. [[túnel]] -> 'túneles'
    tr("^(" + C + "*" + V + C + "*)l$", r"\1es") or # monosyllable ending in -l e.g. [[sol]] -> 'soles'
    tr("il$", "ís") or # final stressed -il e.g. [[civil]] -> 'civís'
    tr("(" + V + ")l$", r"\1is") or # any other vowel + -l e.g. [[papel]] -> 'papeis'
    tr("(" + V + "[íú])s$", r"\1ses") or # vowel + stressed í/ú + -s e.g. [[país]] -> 'países'
    tr("(" + AV + ")s$", # other final accented vowel + -s e.g. [[autobús]] -> 'autobuses'
       lambda m: remove_accent[m.group(1)] + "ses") or
    tr("(" + V + "[iu]?s)$", r"\1es") or # diphthong + final -s e.g. [[deus]] -> 'deuses'
    tr("^(C" + "*" + V + "s)$", r"\1es") or # monosyllable + final -s e.g. [[fros]] -> 'froses', [[gas]] -> 'gases'
    tr("([sx])$", r"\1") or # other final -s or -x (stressed on penult or antepenult or ending in cluster), e.g.
                # [[mércores]], [[lapis]], [[lux]], [[unisex]], [[luns]]
    term + "s" # ending in vowel, -n or other consonant e.g. [[cadeira]], [[marroquí]], [[xersei]], [[limón]],
          # [[club]], [[clip]], [[robot]], [[álbum]]
  )

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "gl-adj" not in text and "gl-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  if pagetitle in deny_list:
    pagemsg("Skipping because in deny_list")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  def do_make_plural(form, special=None):
    retval = make_plural(form, special)
    if retval is None:
      return None
    return [retval]

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param).strip()

    ############# Remove redundant params

    if tn == "gl-noun" and args.do_nouns:
      origt = str(t)
      subnotes = []

      sg = getp("sg")
      if sg:
        t.add("head", sg)
        rmparam(t, "sg")
        subnotes.append("move sg= to head=")
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

      pls = [getp("2")] + blib.fetch_param_chain(t, "pl")
      pls = [pl for pl in pls if pl]
      orig_pls = pls

      if not is_plural:
        while True:
          if not pls:
            break

          if g not in ["m", "f", "mf", "mfbysense"]:
            pagemsg("WARNING: Saw unrecognized gender '%s', can't handle: %s" % (g, str(t)))
            break

          g_for_plural = "f" if g == "f" else "m"
          new_pls = []
          defpl = do_make_plural(lemma)
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
            special_pl = do_make_plural(lemma, special)
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
          defmf = make_mf(lemma, True)
          if mfs == [defmf]:
            subnotes.append("replace %s=%s with '+'" % (g, mfs[0]))
            return ["+"]
          actual_special = None
          for special in romance_utils.all_specials:
            special_mf = make_mf(lemma, True, special)
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

      has_pl = t.has("pl")
      blank_2_or_pl = not orig_pls and (t.has("2") or t.has("pl"))
      blib.remove_param_chain(t, "pl")
      if not is_plural:
        if pls and has_pl:
          subnotes.append("move plural in pl= to 2=")
        elif blank_2_or_pl:
          subnotes.append("remove blank plural in 2= and/or pl=")
        blib.set_param_chain(t, pls, "2", "pl", preserve_spacing=False)
      blib.set_param_chain(t, fs, "f", preserve_spacing=False)

      if head is None:
        rmparam(t, "head")
      elif head and head == pagetitle:
        subnotes.append("convert head= without brackets to nolinkhead=1")
        rmparam(t, "head")
        t.add("nolinkhead", "1")

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("clean up {{gl-noun}} (%s)" % "; ".join(blib.group_notes(subnotes)))
      else:
        pagemsg("No changes to %s" % str(t))

    if tn == "gl-adj" and args.do_adjs:
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
        deff = make_feminine(lemma, False)
        if fs == ["mf"]:
          fs = [lemma]
        if not fs:
          fs = [deff]

        fem_like_lemma = fs == [lemma]

        pls = blib.fetch_param_chain(t, "pl")
        origpls = pls
        mpls = blib.fetch_param_chain(t, "mpl")
        origmpls = mpls

        defmpl = do_make_plural(lemma)
        if defmpl is None:
          continue

        deffpl = [x for f in fs for x in do_make_plural(f)]

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

        blib.set_param_chain(t, fs, "1", "f", preserve_spacing=False)
        blib.set_param_chain(t, pls, "pl", preserve_spacing=False)
        blib.set_param_chain(t, mpls, "mpl", preserve_spacing=False)

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
        notes.append("clean up {{gl-adj}} (%s)" % "; ".join(blib.group_notes(subnotes)))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Remove redundant args in {{gl-noun}} or {{gl-adj}}",
    include_pagefile=True, include_stdin=True)
  parser.add_argument("--do-nouns", action="store_true")
  parser.add_argument("--do-adjs", action="store_true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  default_refs = []
  if args.do_nouns:
    default_refs.append("Template:gl-noun")
  elif args.do_adjs:
    default_refs.append("Template:gl-adj")

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=default_refs)
