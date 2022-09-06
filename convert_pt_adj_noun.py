#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import romance_utils

import blib
from blib import getparam, rmparam, tname, pname, msg, site

unaccented_vowel = u"aeiouà"
accented_vowel = u"áéíóúýâêô"
maybe_accented_vowel = u"ãõ"
vowel = unaccented_vowel + accented_vowel + maybe_accented_vowel
V = "[" + vowel + "]"
AV = "[" + accented_vowel + "]"
NAV = "[^" + accented_vowel + "]"
C = "[^" + vowel + ".]"
remove_accent = {u"á": "a", u"é": "e", u"í": "i", u"ó": "o", u"ú": "u", u"ý": "y", u"â": "a", u"ê": "e", u"ô": "o"}

prepositions = [
  # a + optional article
  "a ",
  "às? ",
  "aos? ",
  # de + optional article
  "de ",
  "d[oa]s? ",
  # em + optional article
  "em ",
  "n[oa]s? ",
  # por + optional article
  "por ",
  "pel[oa]s? ",
  # others
  "até ",
  "com ",
  "como ",
  "entre ",
  "para ",
  "sem ",
  "sob ",
  "sobre ",
]

TEMPCHAR = u"\uFFF1"

#old_adj_template = "pt-adj-old"
old_adj_template = "pt-adj"

def get_old_inflections(ending):
  if ending == "a":
    return "a", "a", "as", "as", "", "", ("dim_a", "")
  if ending == "ca":
    return "ca", "ca", "cas", "cas", "qu", "c", "qu"
  if ending == "e":
    return "e", "e", "es", "es", "", "", ""
  if ending == "l":
    return "l", "l", "is", "is", "l", "l", "l"
  if ending == "m":
    return "m", "m", "ns", "ns", "m", "m", "m"
  if ending == "z":
    return "z", "z", "zes", "zes", "c", "z", "z"
  if ending == "al":
    return "al", "al", "ais", "ais", "al", "al", "al"
  if ending == u"ável":
    return u"ável", u"ável", u"áveis", u"áveis", "abil", "abil", "abil"
  if ending == u"ímico":
    return u"ímico", u"ímica", u"ímicos", u"ímicas", "qu", "c", "qu"
  if ending == u"ível":
    return u"ível", u"ível", u"íveis", u"íveis", "ibil", "ibil", "ibil"
  if ending == u"incrível":
    return u"incrível", u"incrível", u"incríveis", u"incríveis", "incredibil", "incredibil", "incredibil"
  if ending == "il":
    return "il", "il", "is", "is", "il", "il", "il"
  if ending == u"ágico":
    return u"ágico", u"ágica", u"ágicos", u"ágicas", "agiqu", "agic", "agiqu"
  if ending == u"ágil":
    return u"ágil", u"ágil", u"ágeis", u"ágeis", "agil", "agil", "agil"
  if ending == u"ão":
    return u"ão", "ona", u"ões", "onas", "on", "on", "on"
  if ending == "o":
    return "o", "a", "os", "as", "", "", ""
  if ending == "co":
    return "co", "ca", "cos", "cas", "qu", "c", "qu"
  if ending == "co2":
    return "co", "ca", "cos", "cas", ["c", "qu"], "c", "qu"
  if ending == u"ógico":
    return u"ógico", u"ógica", u"ógicos", u"ógicas", "ogiqu", "ogic", "ogiqu"
  if ending == u"ítmico":
    return u"ítmico", u"ítmica", u"ítmicos", u"ítmicas", "itmiqu", "itmic", "itmiqu"
  if ending == u"áfico":
    return u"áfico", u"áfica", u"áficos", u"áficas", "afic", "afic", "afic"
  if ending == u"ático":
    return u"ático", u"ática", u"áticos", u"áticas", "atic", "atic", "atic"
  if ending == u"ático2":
    return u"ático", u"ática", u"áticos", u"áticas", ["atic", "atiqu"], "atic", "atic"
  if ending == u"ítico":
    return u"ítico", u"ítica", u"íticos", u"íticas", "itic", "itic", "itic"
  if ending == u"ótico":
    return u"ótico", u"ótica", u"óticos", u"óticas", "otic", "otic", "otic"
  if ending == u"ástico":
    return u"ástico", u"ástica", u"ásticos", u"ásticas", "astiqu", "astic", "astiqu"
  if ending == u"ácido":
    return u"ácido", u"ácida", u"ácidos", u"ácidas", "acid", "acid", "acid"
  if ending == u"tímido":
    return u"tímido", u"tímida", u"tímidos", u"tímidas", "timid", "timid", "timid"
  if ending == u"ítido":
    return u"ítido", u"ítida", u"ítidos", u"ítidas", "itid", "itid", "itid"
  if ending == "go":
    return "go", "ga", "gos", "gas", "gu", "g", "gu"
  if ending == u"ério":
    return u"ério", u"éria", u"érios", u"érias", ["er", "eri"], ("mf", "erioz", "eriaz"), ("mf", "erioz", "eriaz")
  if ending == "frio":
    return "frio", "fria", "frios", "frias", ["fri", "frigid"], "fri", ["frioz", "fri"]
  if ending == "r":
    return "r", "r", "res", "res", "r", "r", "r"
  if ending == "ar":
    return "ar", "ar", "ares", "ares", "ar", "ar", "ar"
  if ending == "or":
    return "or", "ora", "ores", "oras", "or", "or", "or"
  if ending == u"ôr":
    return u"ôr", u"ôra", u"ôres", u"ôras", u"ôr", u"ôr", u"ôr"
  if ending == u"ês":
    return u"ês", "esa", "eses", "esas", "es", "es", "es"
  if ending == "eu":
    return "eu", "eia", "eus", "eias", "euz", "euz", "euz"
  if ending == "ez":
    return "ez", "eza", "ezes", "ezas", "ez", "ez", "ez"
  return None, None, None, None, None, None, None

# Generate a default plural form, which is correct for most regular nouns and adjectives.
def make_plural(form, new_algorithm, special=None):
  retval = romance_utils.handle_multiword(form, special, lambda form: make_plural(form, new_algorithm), prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  formarr = [form]
  def check(fr, to):
    newform = re.sub(fr, to, formarr[0])
    if newform != formarr[0]:
      formarr[0] = newform
      return True
    return False

  # This is ported from the former [[Module:pt-plural]] except that the old code sometimes returned nil (final -ão
  # other than -ção and -são, final consonant other than [lrmzs]), whereas we always return a default plural
  # (all -ão -> ões, all final consonants other than [lrmzs] are left unchanged).
  if not new_algorithm and re.search(u"([^çs]ão|[^ç]aõ|[^" + vowel + "lrmzs])$", formarr[0]):
    return None
  (
  check(u"ão$", u"ões") or
  check(u"aõ$", u"oens") or
  check("(" + AV + ".*)[ei]l$", r"\1eis") or # final unstressed -el or -il
  check("el$", u"éis") or # final stressed -el
  check("il$", "is") or # final stressed -il
  check("(" + AV + ".*)ol$", r"\1ois") or # final unstressed -ol
  check("ol$", u"óis") or # final stressed -ol
  check("(" + V + ")l$", r"\1is") or # any other vowel + -l
  check("m$", "ns") or # final -m
  check("([rz])$", r"\1es") or # final -r or -z
  check("(" + V + ")$", r"\1s") or # final vowel
  check("(" + AV + ")s$", lambda m: remove_accent.get(m.group(1), m.group(1)) + "ses") or # final -ês, -ós etc.
  check("^(" + NAV + "*" + C + "[ui]s)$", r"\1es") # final stressed -us or -is after consonant
  )

  return formarr[0]

# Generate a default feminine form.
def make_feminine(form, special=None):
  retval = romance_utils.handle_multiword(form, special, make_feminine, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  formarr = [form]
  def check(fr, to):
    newform = re.sub(fr, to, formarr[0])
    if newform != formarr[0]:
      formarr[0] = newform
      return True
    return False

  (
  # Exceptions: [[afegão]] (afegã), [[alazão]] (alazã), [[alemão]] (alemã), [[ancião]] (anciã),
  #             [[anglo-saxão]] (anglo-saxã), [[beirão]] (beirã/beiroa), [[bretão]] (bretã), [[cão]] (cã),
  #             [[castelão]] (castelã/castelona[rare]/casteloa[rare]), [[catalão]] (catalã), [[chão]] (chã),
  #             [[cristão]] (cristã), [[fodão]] (fodão since from [[foda]]), [[grão]] (grã), [[lapão]] (lapoa),
  #             [[letão]] (letã), [[meão]] (meã), [[órfão]] (órfã), [[padrão]] (padrão), [[pagão]] (pagã),
  #             [[paleocristão]] (paleocristã), [[parmesão]] (parmesã), [[romão]] (romã), [[são]] (sã),
  #             [[saxão]] (saxã), [[temporão]] (temporã), [[teutão]] (teutona/teutã/teutoa), [[vão]] (vã),
  #             [[varão]] (varoa), [[verde-limão]] (invariable), [[vilão]] (vilã/viloa)
  check(u"ão$", "ona") or
  check("o$", "a") or
  # [[francês]], [[português]], [[inglês]], [[holandês]] etc.
  check(u"ês$", "esa") or
  # [[francez]], [[portuguez]], [[inglez]], [[holandez]] (archaic)
  check("ez$", "eza") or
  # adjectives in:
  # * [[-ador]], [[-edor]] ([[amortecedor]], [[comovedor]], etc.), [[-idor]] ([[inibidor]], etc.)
  # * -tor ([[condutor]], [[construtor]], [[coletor]], etc.)
  # * -sor ([[admissor]], [[censor]], [[decisor]], etc.)
  # but not:
  # * [[anterior]]/[[posterior]]/[[inferior]]/[[maior]]/[[pior]]/[[melhor]]
  # * [[bicolor]]/[[incolor]]/[[multicolor]]/etc., [[indolor]], etc.
  check(u"([dts][oô]r)$", r"\1a") or
  # [[amebeu]], [[aqueu]], [[aquileu]], [[arameu]], [[cananeu]], [[cireneu]], [[egeu]], [[eritreu]],
  # [[europeu]], [[galileu]], [[indo-europeu]]/[[indoeuropeu]], [[macabeu]], [[mandeu]], [[pigmeu]],
  # [[proto-indo-europeu]]
  # Exceptions: [[judeu]] (judia), [[sandeu]] (sandia)
  check("eu$", "eia")
  )

  # note: [[espanhol]] (espanhola), but this is the only case in ''-ol'' (vs. [[bemol]], [[mongol]] with no
  # change in the feminine)
  return formarr[0]

def make_masculine(form, special=None):
  retval = romance_utils.handle_multiword(form, special, make_masculine, prepositions)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  # FIXME, implement me
  return form

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if old_adj_template not in text and "pt-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  def do_make_plural(form, special=None):
    retval = make_plural(form, "new algorithm", special)
    if retval is None:
      return []
    return [retval]

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "pt-noun" and args.remove_redundant_noun_args:
      # FIXME, this hasn't been converted; code in convert_it_adj_noun.py wasn't converted, either, so this goes back
      # to convert_es_adj_noun.py.
      origt = unicode(t)
      lemma = blib.remove_links(getp("head") or pagetitle)
      if not getp("2") and (getp("pl2") or getp("pl3")):
        pagemsg("WARNING: Saw pl2= or pl3= without 2=: %s" % unicode(t))
        continue
      g = getp("1")
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
        notes.append("remove redundant plural%s %s from {{pt-noun}}" % ("s" if len(pls) > 1 else "", ",".join(pls)))
        blib.remove_param_chain(t, "2", "pl")
      elif actual_special:
        notes.append("replace plural%s %s with +%s in {{pt-noun}}" % (
          "s" if len(pls) > 1 else "", ",".join(pls), actual_special))
        blib.set_param_chain(t, ["+" + actual_special], "2", "pl")
      elif pls_with_def != pls:
        notes.append("replace default plural %s with '+' in {{pt-noun}}" % ",".join(defpl))
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
              notes.append("replace %s=%s with '+' in {{pt-noun}}" % (mf, ",".join(mfs)))
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
              notes.append("replace explicit %s %s with special indicator '+%s' in {{pt-noun}} and remove explicit %s plural" %
                  (mf_full, ",".join(mfs), actual_special, mf_full))
              blib.set_param_chain(t, ["+%s" % actual_special], mf, mf)
              blib.remove_param_chain(t, mf + "pl", mf + "pl")
          if not actual_special:
            defmf = make_mf(lemma)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              notes.append("replace default %s %s with '+' in {{pt-noun}}" % (mf_full, defmf))
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
                notes.append("remove redundant explicit %s plural %s in {{pt-noun}}" % (mf_full, ",".join(mfpls)))
                blib.remove_param_chain(t, mf + "pl", mf + "pl")
              else:
                for special in romance_utils.all_specials:
                  defpl = [x for y in mfs for x in (make_plural(y, special) or [])]
                  if set(defpl) == set(mfpls):
                    pagemsg("Found %s=%s, %spl=%s matches special=%s" % (
                      mf, ",".join(mfs), mf, ",".join(mfpls), special))
                    notes.append("replace explicit %s plural %s with special indicator '+%s' in {{pt-noun}}" %
                        (mf_full, ",".join(mfpls), special))
                    blib.set_param_chain(t, ["+%s" % special], mf + "pl", mf + "pl")

      handle_mf("f", "feminine", make_feminine)
      handle_mf("m", "masculine", make_masculine)

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

    if tn == old_adj_template:
      origt = unicode(t)
      if args.add_old_to_adjs:
        if not getp("old") and not getp("1") and not getp("2"):
          # needs old=1
          t.add("old", "1")
          notes.append("add old=1 to old-style Portuguese adjective template not automatically identifiable as such")
          if origt != unicode(t):
            pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        continue

      #if not getp("old") and not getp("1") and not getp("2"):
      #  # new-style
      #  continue
      base = getp("1")
      infl_type = getp("2")
      invariable = False
      if base == "-":
        invariable = True
      else:
        if not infl_type:
          lemma = pagetitle
          if not getp("f") and not getp("mpl") and not getp("pl") and not getp("fpl"):
            pagemsg("WARNING: Probable bad template invocation, no parameters: %s" % unicode(t))
            continue
          f = getp("f") or lemma
          mpl = (getp("mpl") if t.has("mpl") else getp("pl")) or lemma
          fpl = getp("fpl") or mpl
        else:
          _, f, mpl, fpl, _, _, _ = get_old_inflections(infl_type)
          f = base + f
          mpl = base + mpl
          fpl = base + fpl
          if f is None:
            pagemsg("WARNING: Unrecognized inflection type %s: %s" % (infl_type, unicode(t)))
            continue
          lemma = base + infl_type
          if lemma != pagetitle:
            pagemsg("WARNING: Saw lemma '%s' not equal to page title: %s" % (lemma, unicode(t)))

        deff = make_feminine(lemma)
        defmpl = do_make_plural(lemma)
        fs = []
        fullfs = []
        fullfs.append(f)
        if f == deff:
          f = "+"
        elif f == lemma:
          f = "#"
        fs.append(f)
        mpls = []
        mpls.append(mpl)
        fullmpls = mpls
        # should really check for subsequence but it never occurs
        if set(mpls) == set(defmpl):
          mpls = ["+"]
        elif set(mpls) < set(defmpl):
          pagemsg("WARNING: mpls=%s subset of defmpl=%s, replacing with default" % (",".join(mpls), ",".join(defmpl)))
          mpls = ["+"]
        mpls = ["#" if x == lemma else x for x in mpls]
        deffpl = [x for f in fullfs for x in do_make_plural(f)]
        fpls = []
        fpls.append(fpl)
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
          deff = make_feminine(lemma, special)
          if deff is None:
            continue
          defmpl = do_make_plural(lemma, special)
          deffpl = do_make_plural(deff, special)
          deff = [deff]
          if fullfs == deff and fullmpls == defmpl and fullfpls == deffpl:
            actual_special = special
            break

      head = getp("head")
      comp = getp("comp")

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = unicode(param.value)
        if pn not in ["head", "1", "2", "f", "mpl", "pl", "fpl", "comp", "old"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, unicode(t)))
          must_continue = True
          break
      if must_continue:
        continue
      if comp and comp not in ["yes", "no", "both"]:
        pagemsg("WARNING: Saw unrecognized value '%s' for comp=: %s" % (comp, unicode(t)))
        continue

      del t.params[:]
      if head:
        t.add("head", head)
      if invariable or fullfs == [lemma] and fullmpls == [lemma] and fullfpls == [lemma]:
        t.add("inv", "1")
      else:
        if actual_special:
          t.add("sp", actual_special)
        else:
          if fs != ["+"]:
            blib.set_param_chain(t, fs, "f")

          if mpls == fpls and ("+" not in mpls or defmpl == deffpl):
            # masc and fem pl the same
            if mpls != ["+"]:
              blib.set_param_chain(t, mpls, "pl")
          else:
            if mpls != ["+"]:
              blib.set_param_chain(t, mpls, "mpl")
            if fpls != ["+"]:
              blib.set_param_chain(t, fpls, "fpl")
      if comp:
        t.add("hascomp", comp)

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        if old_adj_template == tname(t):
          notes.append("convert {{%s}} to new format" % old_adj_template)
        else:
          notes.append("convert {{%s}} to new {{%s}} format" % (old_adj_template, tname(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{pt-adj}} templates to new format or remove redundant args in {{pt-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--remove-redundant-noun-args", action="store_true")
parser.add_argument("--add-old-to-adjs", action="store_true",
    help="Add old=1 to adjectives without old=1 or 1=/2=")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_redundant_noun_args:
  default_refs=["Template:pt-noun"]
else:
  default_refs=["Template:%s" % old_adj_template]

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
