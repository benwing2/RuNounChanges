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
  "com[oa] ",
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
    tr("eu$", "ía") or # [[sandeu]] -> sandía, [[xudeu]] -> xudía
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

def old_make_plural(lemma):
  def is_accented(x):
    return re.search("[áéíóúâêô]", x)
  OLDV = "[aeiouãáéíóêôú]"
  def has_multiple_vowels(x):
    return re.search(OLDV + ".*" + OLDV, x)
  def is_vowel(x):
    return re.search(OLDV, x)
  old_remove_accent = {
    "á":"a", "é":"e", "í":"i", "ó":"o", "ú":"u",
    "â":"a", "ê":"e", "ô":"o",
  }
  if " " in lemma or "-" in lemma:
    return None
  if lemma.endswith("bel"):
    return lemma[:-3] + "beis"
  if lemma.endswith("l"):
    if has_multiple_vowels(lemma) and not is_accented(lemma[:-2]):
      if lemma.endswith("il"):
        return lemma[:-2] + "ís"
      else:
        return lemma[:-1] + "is"
    else:
      return lemma + "es"
  if lemma.endswith("m"):
    return lemma[:-1] + "ns"
  if lemma.endswith("z"):
    return lemma[:-1] + "ces"
  if lemma.endswith("r"):
    return lemma + "es"
  if re.search("[çs]ão$", lemma):
    return lemma[:-2] + "ões"
  if re.search("ão$", lemma):
    return None
  if lemma.endswith("x"):
    return lemma
  if is_vowel(lemma[-1]) or lemma.endswith("n"):
    return lemma + "s"
  if lemma.endswith("s"):
    penult = lemma[-2]
    if not is_vowel(penult):
      return lemma
    antepenult = lemma[-3]
    if is_vowel(antepenult):
      return lemma + "es"
    if is_accented(penult):
      return lemma[:-2] + remove_accent[penult] + "ses"
    else:
      return lemma
  return None

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
    tr("(" + AV + ".*" + V + "l)$", r"\1es") or # non-final stress + -l e.g. [[túnel]] -> 'túneles'
    tr("^(" + C + "*" + V + C + "*l)$", r"\1es") or # monosyllable ending in -l e.g. [[sol]] -> 'soles'
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

  if "gl-adj-old" not in text and "gl-noun-old" not in text:
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

    if tn == "gl-noun-old" and args.do_nouns:
      must_continue = False
      for tt in parsed.filter_templates():
        ttn = tname(tt)
        if ttn == "gl-reinteg sp":
          pagemsg("WARNING: Saw reintegrationist noun, skipping: head=%s, defn=%s" % (str(t), str(tt)))
          must_continue = True
          break
      if must_continue:
        continue
    
      subnotes = []
      origt = str(t)

      head = getp("sg") or getp("head")
      lemma = blib.remove_links(head or pagetitle)

      def replace_lemma_with_hash(term):
        if term.startswith(lemma):
          replaced_term = "#" + term[len(lemma):]
          subnotes.append("replace lemma-containing term '%s' with '%s'" % (term, replaced_term))
          term = replaced_term
        return term

      def warn_when_exiting(txt):
        pagemsg("WARNING: %s: %s" % (txt, str(t)))

      autohead = romance_utils.add_links_to_multiword_term(lemma, splithyph=False)
      if autohead == head:
        pagemsg("Remove redundant head %s" % head)
        subnotes.append("remove redundant head '%s'" % head)
        head = None

      unc = getp("unc")
      g = getp("1")
      g2 = getp("g2")

      if not g:
        warn_when_exiting("No gender, can't convert")
        continue

      if getp("unc"):
        warn_when_exiting("Saw unc=, can't convert")
        continue

      if g in ["morf", "c"]:
        g = "mf"

      is_plural = "p" in g or "p" in "g2"

      if is_plural and (not g.endswith("-p") or (g2 and not g2.endswith("-p"))):
        warn_when_exiting("Both singular and plural, can't convert")
        continue

      if not is_plural:
        pl = getp("2") or getp("pl")
        orig_pl = pl
        if not pl:
          old_defpl = old_make_plural(lemma)
          if old_defpl is None:
            warn_when_exiting("No plurals and can't generate default plural, skipping")
            continue
          pl = old_defpl
        pl2 = getp("pl2")
        pl3 = getp("pl3")
        if not pl2 and pl3:
          warn_when_exiting("Saw gap in plurals, can't handle, skipping")
          continue

        pls = [pl, pl2, pl3]
        pls = [x for x in pls if x]
        orig_pls = [orig_pl, pl2, pl3]
        orig_pls = [x for x in orig_pls if x]
        pls = [lemma + x if x in ["s", "es"] else x for x in pls]

        if unc:
          pls = ["-"] + pls

        defpl = make_plural(lemma)
        if not defpl:
          continue
        pls_with_def = ["+" if pl == defpl else pl for pl in pls]

        actual_special = None
        for special in romance_utils.all_specials:
          special_pl = make_plural(lemma, special)
          if special_pl is None:
            continue
          if pls == [special_pl]:
            pagemsg("Found special=%s with special_pl=%s" % (special, special_pl))
            actual_special = special
            break

        if pls_with_def == ["+"]:
          if orig_pls:
            subnotes.append("remove redundant plural '%s'" % orig_pls[0])
          pls = []
        elif actual_special:
          if orig_pls:
            subnotes.append("replace plural '%s' with '+%s'" % (orig_pls[0], actual_special))
          else:
            subnotes.append("replace default plural '%s' with '+%s'" % (pls[0], actual_special))
          pls = ["+" + actual_special]
        elif pls_with_def != pls:
          # orig_pls should always have an entry and pls_with_def should have its length > 1
          subnotes.append("replace default plural '%s' with '+'" % defpl)
          pls = pls_with_def

        pls = [replace_lemma_with_hash(pl) for pl in pls]

      def handle_mf(g, g_full, make_mf):
        mf = getp(g)
        mf2 = getp(g + "2")
        if not mf and mf2:
          warn_when_exiting("Saw gap in %ss, can't handle, skipping" % g_full)
          return None
        mfs = [mf, mf2]
        mfs = [mf for mf in mfs if mf]

        if not is_plural:
          mfpl = getp(g + "pl")
          mfpl2 = getp(g + "pl2")
          if not mfpl and mfpl2:
            warn_when_exiting("Saw gap in %s plurals, can't handle, skipping" % g_full)
            return None
          mfpls = [mfpl, mfpl2]
          mfpls = [mfpl for mfpl in mfpls if mfpl]

        if mfs:
          defmf = make_mf(lemma, True)
          if mfs == [defmf]:
            if is_plural or (not mfpls or mfpls == [make_plural(defmf)]):
              subnotes.append("replace %s=%s with '+'" % (g, mfs[0]))
              return ["+"], []
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
            if is_plural:
              pass
            elif not mfpls:
              pagemsg("WARNING: Explicit %s=%s matches special=%s but no %s plural, allowing" % (
                g, ",".join(mfs), actual_special, g_full))
            else:
              special_mfpl = make_plural(special_mf, actual_special)
              if special_mfpl:
                if mfpls == [special_mfpl]:
                  pagemsg("Found %s=%s and special=%s, %spls=%s matches special_%spl" % (
                    g, ",".join(mfs), actual_special, g, ",".join(mfpls), g))
                else:
                  pagemsg("WARNING: for %s=%s and special=%s, %spls=%s doesn't match special_%spl=%s, allowing" % (
                    g, ",".join(mfs), actual_special, g, ",".join(mfpls), g, special_mfpl))
                  actual_special = None
            if actual_special:
              subnotes.append("replace explicit %s '%s' with special indicator '+%s' and remove explicit %s plural" %
                  (g_full, ",".join(mfs), actual_special, g_full))
              mfs = ["+%s" % actual_special]
              mfpls = []
          if not actual_special:
            defmf = make_mf(lemma, True)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              subnotes.append("replace default %s '%s' with '+'" % (g_full, defmf))
              mfs = mfs_with_def
            if not is_plural and mfpls:
              defpl = [make_plural(x) for x in mfs]
              ok = False
              if set(defpl) == set(mfpls):
                ok = True
              elif len(defpl) > 1 and set(mfpls) < set(defpl):
                pagemsg("WARNING: for %s=%s, %spl=%s subset of default pl %s, allowing" % (
                  g, ",".join(mfs), g, ",".join(mfpls), ",".join(defpl)))
                ok = True
              if ok:
                pagemsg("Found %s=%s, %spl=%s matches default pl" % (g, ",".join(mfs), g, ",".join(mfpls)))
                subnotes.append("remove redundant explicit %s plural '%s'" % (g_full, ",".join(mfpls)))
                mfpls = []
              else:
                for special in romance_utils.all_specials:
                  defpl = [make_plural(x, special) for x in mfs]
                  if set(defpl) == set(mfpls):
                    pagemsg("Found %s=%s, %spl=%s matches special=%s" % (
                      g, ",".join(mfs), g, ",".join(mfpls), special))
                    subnotes.append("replace explicit %s plural '%s' with special indicator '+%s'" %
                        (g_full, ",".join(mfpls), special))
                    mfpls = ["+%s" % special]
        mfs = [replace_lemma_with_hash(mf) for mf in mfs]
        return mfs, mfpls if not is_plural else []

      retval = handle_mf("f", "feminine", make_feminine)
      if retval is None:
        continue
      fs, fpls = retval
      #retval = handle_mf("m", "masculine", make_masculine)
      #if retval is None:
      #  continue
      #ms, mpls = retval

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in ["sg", "head", "1", "2", "f", "f2", "fpl", "fpl2", "g2", "pl", "pl2", "pl3", "unc"]:
          warn_when_exiting("Saw unrecognized param %s=%s" % (pn, pv))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      blib.set_template_name(t, "gl-noun")
      t.add("1", g)
      if g2:
        t.add("g2", g2)
      def add_vals(vals, prefix, first=None):
        first = first or prefix
        for i, val in enumerate(vals):
          if i == 0:
            param = first
          else:
            param = "%s%s" % (prefix, i + 1)
          t.add(param, val)

      if not is_plural:
        add_vals(pls, "pl", "2")
      add_vals(fs, "f")
      if not is_plural:
        add_vals(fpls, "fpl")
      #add_vals(ms, "m")
      #if not is_plural:
      #  add_vals(mpls, "mpl")

      if head:
        if head == lemma:
          t.add("nolinkhead", "1")
        else:
          t.add("head", head)

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{gl-noun-old}} to {{gl-noun}} with new syntax%s" %
            (" (%s)" % ", ".join(subnotes) if subnotes else ""))
      else:
        pagemsg("No changes to %s" % str(t))

    if tn == "gl-adj-old" and args.do_adjs:
      origt = str(t)
      subnotes = []

      lemma = pagetitle

      def replace_lemma_with_hash(term):
        if term.startswith(lemma):
          replaced_term = "#" + term[len(lemma):]
          pagemsg("Replacing lemma-containing term '%s' with '%s'" % (term, replaced_term))
          subnotes.append("replace lemma-containing term '%s' with '%s'" % (term, replaced_term))
          term = replaced_term
        return term

      lemma = pagetitle
      m = getp("masculine") or getp("m")
      if m:
        pagemsg("WARNING: Saw m=%s, probable non-lemma form, skipping" % m)
        continue

      f = getp("feminine") or getp("f")
      origf = not not f
      f = f or lemma
      fullf = f
      mpl = getp("masculine plural") or getp("mpl") or getp("pl")
      origmpl = not not (getp("masculine plural") or getp("mpl"))
      origpl = not not getp("pl")
      mpl = mpl or (getp("masculine") or getp("m") or lemma) + "s"
      fullmpl = mpl
      fpl = getp("feminine plural") or getp("fpl") or getp("pl")
      origfpl = not not (getp("feminine plural") or getp("fpl"))
      fpl = fpl or (getp("feminine") or getp("f") or lemma) + "s"
      fullfpl = fpl

      deff = make_feminine(lemma, False)
      defmpl = make_plural(lemma)
      deffpl = make_plural(f)
      msg("lemma=%s, deff=%s, defmpl=%s, deffpl=%s" % (lemma, deff, defmpl, deffpl))
      inv = False

      if f == lemma and mpl == lemma and fpl == lemma:
        inv = True
        subnotes.append("convert to inv=1")
      else:
        if f == deff:
          if origf:
            redundant_msg = "redundant feminine '%s'" % f
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
          f = "+"
        else:
          f = replace_lemma_with_hash(f)

        if mpl == defmpl:
          if origmpl:
            redundant_msg = "redundant masculine plural '%s'" % mpl
          elif origpl:
            redundant_msg = "redundant plural '%s'" % mpl
          else:
            redundant_msg = None
          if redundant_msg:
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
          mpl = "+"
        else:
          mpl = replace_lemma_with_hash(mpl)
        if fpl == deffpl:
          if origfpl:
            redundant_msg = "redundant feminine plural '%s'" % fpl 
            pagemsg("Removing %s" % redundant_msg)
            subnotes.append("remove %s" % redundant_msg)
          fpl = "+"
        else:
          fpl = replace_lemma_with_hash(fpl)

        actual_special = None
        for special in romance_utils.all_specials:
          deff = make_feminine(lemma, False, special)
          if deff is None:
            continue
          defmpl = make_plural(lemma, special)
          deffpl = make_plural(deff, special)
          if fullf == deff and fullmpl == defmpl and fullfpl == deffpl:
            actual_special = special
            break

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in ["sg", "1", "f", "mpl", "pl", "fpl"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, str(t)))
          must_continue = True
          break
      if must_continue:
        continue

      sg = getp("sg")
      del t.params[:]
      blib.set_template_name(t, "gl-adj")

      sg = getp("sg")
      autohead = romance_utils.add_links_to_multiword_term(lemma, splithyph=False)
      if autohead == sg:
        pagemsg("Remove redundant head %s" % sg)
        subnotes.append("remove redundant head '%s'" % sg)
        head = None

      if sg is None:
        rmparam(t, "sg")
      elif sg and sg == pagetitle:
        subnotes.append("convert sg= without brackets to nolinkhead=1")
        rmparam(t, "sg")
        t.add("nolinkhead", "1")

      if inv:
        t.add("inv", "1")
      elif actual_special:
        t.add("sp", actual_special)
      else:
        if f != "+":
          t.add("f", f)

        if mpl == fpl and (mpl != "+" or defmpl == deffpl):
          # masc and fem pl the same
          if mpl != "+":
            t.add("pl", mpl)
        else:
          if mpl != "+":
            t.add("mpl", mpl)
          if fpl != "+":
            t.add("fpl", fpl)

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("convert {{gl-adj-old}} to {{gl-adj}} with new syntax%s" % (
          " (%s)" % "; ".join(blib.group_notes(subnotes)) if subnotes else ""))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

if __name__ == "__main__":
  parser = blib.create_argparser("Convert {{gl-noun-old}} or {{gl-adj-old}} to {{gl-noun}} or {{gl-adj}} and remove redundant args",
    include_pagefile=True, include_stdin=True)
  parser.add_argument("--do-nouns", action="store_true")
  parser.add_argument("--do-adjs", action="store_true")
  args = parser.parse_args()
  start, end = blib.parse_start_end(args.start, args.end)

  default_refs = []
  if args.do_nouns:
    default_refs.append("Template:gl-noun-old")
  elif args.do_adjs:
    default_refs.append("Template:gl-adj-old")

  blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=default_refs)
