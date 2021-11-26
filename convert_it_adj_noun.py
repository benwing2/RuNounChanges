#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

prepositions = {
  # a, da + optional article
  "d?al? ",
  "d?all[oae] ",
  "d?all'",
  "d?ai ",
  "d?agli ",
  # di, in + optional article
  "di ",
  "d'",
  "in ",
  "[dn]el ",
  "[dn]ell[oae] ",
  "[dn]ell'",
  "[dn]ei ",
  "[dn]egli ",
  # su + optional article
  "su ",
  "sul ",
  "sull[oae] ",
  "sull'",
  "sui ",
  "sugli ",
  # others
  "come ",
  "con ",
  "per ",
  "tra ",
  "fra ",
}

all_specials = ["first", "second", "first-second", "first-last", "last", "each"]

TEMPCHAR = u"\uFFF1"

#old_adj_template = "it-adj-old"
old_adj_template = "it-adj"

def add_endings(bases, endings):
  if bases is None or endings is None:
    return None
  retval = []
  if type(bases) is not list:
    bases = [bases]
  if type(endings) is not list:
    endings = [endings]
  for base in bases:
    for ending in endings:
      retval.append(base + ending)
  return retval

def handle_multiword(form, special, inflect):
  if special == "first":
    m = re.search("^(.*?)( .*)$", form)
    if not m:
      return None
    first, rest = m.groups()
    return add_endings(inflect(first), rest)
  elif special == "second":
    m = re.search("^(.+? )(.+?)( .*)$", form)
    if not m:
      return None
    first, second, rest = m.groups()
    return add_endings(add_endings([first], inflect(second)), rest)
  elif special == "first-second":
    m = re.search("^([^ ]+)( )([^ ]+)( .*)$", form)
    if not m:
      return None
    first, space, second, rest = m.groups()
    return add_endings(add_endings(add_endings(inflect(first), space), inflect(second)), rest)
  elif special == "first-last":
    m = re.search("^(.*?)( .* )(.*?)$", form)
    if not m:
      m = re.search("^(.*?)( )(.*)$", form)
    if not m:
      return None
    first, middle, last = m.groups()
    return add_endings(add_endings(inflect(first), middle), inflect(last))
  elif special == "last":
    m = re.search("^(.* )(.*?)$", form)
    if not m:
      return None
    rest, last = m.groups()
    return add_endings(rest, inflect(last))
  elif special == "each":
    if " " not in form:
      return None
    terms = form.split(" ")
    inflected_terms = []
    for i, term in enumerate(terms):
      term = inflect(term)
      if i > 0:
        term = add_endings(" ", term)
      inflected_terms.append(term)
    result = ""
    for term in inflected_terms:
      result = add_endings(result, term)
    return result
  else:
    assert not special, "Saw unrecognized special=%s" % special

  m = re.search("^(.*?)( (?:%s))( .*)$" % "|".join(prepositions), form)

  if m:
    first, space_prep, rest = m.groups()
    return add_endings(inflect(first), space_prep + rest)

  if " " in form:
    return handle_multiword(form, "first-last", inflect)

  return None

# Generate a default plural form, which is correct for most regular nouns and adjectives.
def make_plural(form, gender, new_algorithm, special=None):
  retval = handle_multiword(form, special, lambda form: make_plural(form, gender, new_algorithm))
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None
  
  # If there are spaces in the term, then we can't reliably form the plural.
  # Return nothing instead.
  if not new_algorithm and " " in form:
    return None
  elif re.search("io$", form):
    form = re.sub("io$", "i", form)
  elif re.search("ologo$", form):
    form = re.sub("o$", "i", form)
  # FIXME, probably nouns behave the same way but some nouns may depend on the existing behavior.
  elif new_algorithm and re.search("[ia]co$", form):
    form = re.sub("o$", "i", form)
  # Of adjectives in -co but not in -aco or -ico, there are several in -esco that take -eschi, and various
  # others that take -chi: [[adunco]], [[anficerco]], [[azteco]], [[bacucco]], [[barocco]], [[basco]],
  # [[bergamasco]], [[berlusco]], [[bianco]], [[bieco]], [[bisiacco]], [[bislacco]], [[brigasco]], [[brusco]],
  # [[bustocco]], [[caduco]], [[ceco]], [[cecoslovacco]], [[cerco]], [[chiavennasco]], [[cieco]], [[ciucco]],
  # [[comasco]], [[cosacco]], [[cremasco]], [[crucco]], [[dificerco]], [[dolco]], [[eterocerco]], [[etrusco]],
  # [[falisco]], [[farlocco]], [[fiacco]], [[fioco]], [[fosco]], [[franco]], [[fuggiasco]], [[giucco]],
  # [[glauco]], [[gnocco]], [[gnucco]], [[guatemalteco]], [[ipsiconco]], [[lasco]], [[livignasco]], [[losco]], 
  # [[manco]], [[monco]], [[monegasco]], [[neobarocco]], [[olmeco]], [[parco]], [[pitocco]], [[pluriconco]], 
  # [[poco]], [[polacco]], [[potamotoco]], [[prebarocco]], [[prisco]], [[protobarocco]], [[rauco]], [[ricco]], 
  # [[risecco]], [[rivierasco]], [[roco]], [[roiasco]], [[sbieco]], [[sbilenco]], [[sciocco]], [[secco]],
  # [[semisecco]], [[slovacco]], [[somasco]], [[sordocieco]], [[sporco]], [[stanco]], [[stracco]], [[staricco]],
  # [[taggiasco]], [[tocco]], [[tosco]], [[triconco]], [[tronco]], [[turco]], [[usbeco]], [[uscocco]],
  # [[uto-azteco]], [[uzbeco]], [[valacco]], [[vigliacco]], [[zapoteco]].
  #
  # Only the following take -ci: [[biunivoco]], [[dieco]], [[equivoco]], [[estrinseco]], [[greco]], [[inequivoco]],
  # [[intrinseco]], [[italigreco]], [[magnogreco]], [[meteco]], [[neogreco]], [[osco]] (either -ci or -chi),
  # [[petulco]] (either -chi or -ci), [[plurivoco]], [[porco]], [[pregreco]], [[reciproco]], [[stenoeco]],
  # [[tagicco]], [[univoco]], [[volsco]].
  elif re.search("[cg]o$", form):
    form = re.sub("o$", "hi", form)
  elif re.search("o$", form):
    form = re.sub("o$", "i", form)
  elif re.search("[cg]a$", form):
    form = re.sub("a$", (gender == "m" and "hi" or "he"), form)
  elif re.search("[cg]ia$", form):
    form = re.sub("ia$", "e", form)
  elif re.search("a$", form):
    form = re.sub("a$", (gender == "m" and "i" or "e"), form)
  elif re.search("e$", form):
    form = re.sub("e$", "i", form)
  elif new_algorithm:
    return None
  return form

# Generate a default feminine form.
def make_feminine(form, special=None):
  retval = handle_multiword(form, special, make_feminine)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  if form.endswith("o"):
    return form[:-1] + "a"
  if form.endswith("tore"):
    return form[:-4] + "trice"
  if form.endswith("one"):
    return form[:-1] + "a"
  return form

def make_masculine(form, special=None):
  retval = handle_multiword(form, special, make_masculine)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  if form.endswith("trice"):
    return form[:-5] + "tore"
  if form.endswith("a"):
    return form[:-1] + "o"
  return form

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if old_adj_template not in text and "it-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  def do_make_plural(form, gender, special=None):
    retval = make_plural(form, gender, "new algorithm", special)
    if retval is None:
      return []
    return [retval]

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn == "it-noun" and args.remove_redundant_noun_args:
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
      for special in all_specials:
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
        notes.append("remove redundant plural%s %s from {{it-noun}}" % ("s" if len(pls) > 1 else "", ",".join(pls)))
        blib.remove_param_chain(t, "2", "pl")
      elif actual_special:
        notes.append("replace plural%s %s with +%s in {{it-noun}}" % (
          "s" if len(pls) > 1 else "", ",".join(pls), actual_special))
        blib.set_param_chain(t, ["+" + actual_special], "2", "pl")
      elif pls_with_def != pls:
        notes.append("replace default plural %s with '+' in {{it-noun}}" % ",".join(defpl))
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
              notes.append("replace %s=%s with '+' in {{it-noun}}" % (mf, ",".join(mfs)))
              blib.set_param_chain(t, ["+"], mf, mf)
              blib.remove_param_chain(t, mf + "pl", mf + "pl")
              return
          actual_special = None
          for special in all_specials:
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
              notes.append("replace explicit %s %s with special indicator '+%s' in {{it-noun}} and remove explicit %s plural" %
                  (mf_full, ",".join(mfs), actual_special, mf_full))
              blib.set_param_chain(t, ["+%s" % actual_special], mf, mf)
              blib.remove_param_chain(t, mf + "pl", mf + "pl")
          if not actual_special:
            defmf = make_mf(lemma)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              notes.append("replace default %s %s with '+' in {{it-noun}}" % (mf_full, defmf))
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
                notes.append("remove redundant explicit %s plural %s in {{it-noun}}" % (mf_full, ",".join(mfpls)))
                blib.remove_param_chain(t, mf + "pl", mf + "pl")
              else:
                for special in all_specials:
                  defpl = [x for y in mfs for x in (make_plural(y, special) or [])]
                  if set(defpl) == set(mfpls):
                    pagemsg("Found %s=%s, %spl=%s matches special=%s" % (
                      mf, ",".join(mfs), mf, ",".join(mfpls), special))
                    notes.append("replace explicit %s plural %s with special indicator '+%s' in {{it-noun}}" %
                        (mf_full, ",".join(mfpls), special))
                    blib.set_param_chain(t, ["+%s" % special], mf + "pl", mf + "pl")

      handle_mf("f", "feminine", make_feminine)
      handle_mf("m", "masculine", make_masculine)

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

    if tn == "it-noun" and args.make_multiword_plural_explicit:
      origt = unicode(t)
      lemma = blib.remove_links(getp("head") or pagetitle)
      def expand_text(tempcall):
        return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)
      if " " in lemma and not getp("2"):
        g = getp("1")
        if not g.endswith("-p"):
          explicit_pl = expand_text("{{#invoke:it-headword|make_plural_noun|%s|%s|true}}" % (lemma, g))
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
          explicit_pl = expand_text("{{#invoke:it-headword|make_plural_noun|%s|m|true}}" % (
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
          explicit_pl = expand_text("{{#invoke:it-headword|make_plural_noun|%s|f|true}}" % (
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

    if tn == old_adj_template:
      if not getp("1") and not getp("2") and not getp("3") and not getp("4") and not getp("5"):
        pagemsg("WARNING: no numbered params: %s" % unicode(t))
        continue
      origt = unicode(t)
      stem = getp("1")
      end1 = getp("2")

      if not stem: # all specified
        if not end1:
          pagemsg("WARNING: 1= not given and 2=missing: %s" % unicode(t))
        f = getp("3")
        if not f:
          pagemsg("WARNING: 1= not given and 3=missing: %s" % unicode(t))
        mpl = getp("4")
        if not mpl:
          pagemsg("WARNING: 1= not given and 4=missing: %s" % unicode(t))
        fpl = getp("5")
        if not fpl:
          pagemsg("WARNING: 1= not given and 5=missing: %s" % unicode(t))
      elif not end1: # no ending vowel parameters - generate default
        f = stem + "a"
        mpl = make_plural(stem + "o", "m", False) # not new_algorithm as this is old algorithm
        fpl = make_plural(stem + "a", "f", False) # not new_algorithm as this is old algorithm
      else:
        end2 = getp("3") # or error("Either 0, 2 or 4 vowel endings should be supplied!")
        end3 = getp("4")
        
        if not end3: # 2 ending vowel parameters - m and f are identical
          f = pagetitle
          mpl = stem + end2
          fpl = mpl
        else: # 4 ending vowel parameters - specify exactly
          end4 = getp("5") # or error("Either 0, 2 or 4 vowel endings should be supplied!")
          f = stem + end2
          mpl = stem + end3
          fpl = stem + end4

      lemma = pagetitle
      deff = make_feminine(pagetitle)
      defmpl = do_make_plural(pagetitle, "m")
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
      deffpl = [x for f in fullfs for x in do_make_plural(f, "f")]
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
      for special in all_specials:
        deff = make_feminine(pagetitle, special)
        if deff is None:
          continue
        defmpl = do_make_plural(pagetitle, "m", special)
        deffpl = do_make_plural(deff, "f", special)
        deff = [deff]
        if fullfs == deff and fullmpls == defmpl and fullfpls == deffpl:
          actual_special = special
          break

      head = getp("head")
      sort = getp("sort")

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = unicode(param.value)
        if pn not in ["head", "1", "2", "3", "4", "5", "sort"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, unicode(t)))
          must_continue = True
          break
      if must_continue:
        continue

      del t.params[:]
      if head:
        t.add("head", head)
      blib.set_template_name(t, "it-adj")
      if fullfs == [pagetitle] and fullmpls == [pagetitle] and fullfpls == [pagetitle]:
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

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
        if old_adj_template == tname(t):
          notes.append("convert {{%s}} to new format" % old_adj_template)
        else:
          notes.append("convert {{%s}} to new {{%s}} format" % (old_adj_template, tname(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{it-adj}} templates to new format or remove redundant args in {{it-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--remove-redundant-noun-args", action="store_true")
parser.add_argument("--make-multiword-plural-explicit", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_redundant_noun_args:
  default_refs=["Template:it-noun"]
else:
  default_refs=["Template:%s" % old_adj_template]

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
