#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
import romance_utils

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

no_split_apostrophe_words = {
  u"c'è",
  "c'era",
  "c'erano",
}


TEMPCHAR = u"\uFFF1"

#old_adj_template = "it-adj-old"
old_adj_template = "it-adj"

# Generate a default plural form, which is correct for most regular nouns and adjectives.
def make_plural(form, gender, new_algorithm, special=None):
  retval = romance_utils.handle_multiword(form, special, lambda form: make_plural(form, gender, new_algorithm), prepositions)
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
  retval = romance_utils.handle_multiword(form, special, make_feminine, prepositions)
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
  retval = romance_utils.handle_multiword(form, special, make_masculine, prepositions)
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

    ############# Convert old-style noun headwords

    if tn == "it-noun" and args.do_nouns:
      origt = str(t)
      subnotes = []

      head = getp("head")
      lemma = blib.remove_links(head or pagetitle)

      def replace_lemma_with_hash(term):
        if term.startswith(lemma):
          replaced_term = "#" + term[len(lemma):]
          pagemsg("Replacing lemma-containing term '%s' with '%s'" % (term, replaced_term))
          subnotes.append("replace lemma-containing term '%s' with '%s'" % (term, replaced_term))
          term = replaced_term
        return term

      def warn_when_exiting(txt):
        pagemsg("WARNING: %s: %s" % (txt, str(t)))

      saw_g_or_qual = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if re.search("_(g|qual)$", pn):
          pagemsg("WARNING: Saw _g or _qual parameter, can't handle: %s=%s" % (pn, pv))
          saw_g_or_qual = True
          break
      if saw_g_or_qual:
        continue

      gs = blib.fetch_param_chain(t, "1", "g")
      if len(gs) > 1:
        pagemsg("WARNING: Saw multiple genders, can't handle: %s" % str(t))
        continue
      if not gs:
        pagemsg("WARNING: No genders, can't handle: %s" % str(t))
        continue
      g = gs[0]

      autohead = romance_utils.add_links_to_multiword_term(lemma, splithyph=False,
          no_split_apostrophe_words=no_split_apostrophe_words)
      if autohead == head:
        pagemsg("Remove redundant head %s" % head)
        subnotes.append("remove redundant head '%s'" % head)
        head = None

      is_plural = g.endswith("-p")

      if not is_plural:
        while True:
          pls = blib.fetch_param_chain(t, "2", "pl")
          mpls = blib.fetch_param_chain(t, "mpl")
          fpls = blib.fetch_param_chain(t, "fpl")
          orig_pls = pls

          if g not in ["m", "f", "mf", "mfbysense"]:
            pagemsg("WARNING: Saw unrecognized gender '%s', can't handle: %s" % (g, str(t)))
            break

          if g in ["m", "f"]:
            if mpls or fpls:
              pagemsg("Saw g=%s along with mpl=/fpl=, can't handle: %s" % (g, str(t)))
              break
            defpl = make_plural(lemma, g, True)
            if defpl is None:
              pagemsg("Can't generate default plural, skipping: %s" % str(t))
              break
            new_pls = ["+" if pl == defpl else pl for pl in pls]
            if new_pls == ["+"]:
              pagemsg("Removing redundant plural '%s'" % pls[0])
              subnotes.append("remove redundant plural '%s'" % pls[0])
              pls = []
            elif new_pls != pls:
              for old_pl, new_pl in zip(pls, new_pls):
                if old_pl != new_pl:
                  assert old_pl == defpl
                  assert new_pl == "+"
                  pagemsg("Replacing default plural '%s' with '+'" % defpl)
                  subnotes.append("replace default plural '%s' with '+'" % defpl)
              pls = new_pls

            for special in romance_utils.all_specials:
              special_pl = make_plural(lemma, g, True, special)
              if special_pl is None:
                continue
              new_pls = []
              for pl in pls:
                if pl == special_pl:
                  pagemsg("Replacing plural '%s' with '+%s'" % (pl, special))
                  subnotes.append("replace plural '%s' with '+%s'" % (pl, special))
                  new_pls.append("+%s" % special)
                else:
                  new_pls.append(pl)
              pls = new_pls

            pls = [replace_lemma_with_hash(pl) for pl in pls]

          else:
            pagemsg("Can't handle g=%s yet, skipping: %s" % (g, str(t)))

          break

      def handle_mf(g, g_full, make_mf):
        mf = getp(g)
        mf2 = getp(g + "2")
        mf_qual = getp("qual_" + g)
        mf2_qual = getp("qual_" + g + "2")
        if not mf and mf2:
          warn_when_exiting("Saw gap in %ss, can't handle, skipping" % g_full)
          return None
        if not g and mf_qual:
          warn_when_exiting("No value for %s= but saw qual_%s=%s, skipping" % (g, g, mf_qual))
          return None
        if not mf2 and mf2_qual:
          warn_when_exiting("No value for %s2= but saw qual_%s2=%s, skipping" % (g, g, mf2_qual))
          return None
        mfs = [mf, mf2]
        mfs = [mf for mf in mfs if mf]
        mf_quals = [mf_qual, mf2_qual]

        if not is_plural:
          mfpl = getp(g + "pl")
          mfpl2 = getp(g + "pl2")
          if not mfpl and mfpl2:
            warn_when_exiting("Saw gap in %s plurals, can't handle, skipping" % g_full)
            return None
          if getp("qual_" + g + "pl") or getp("qual_" + g + "pl2"):
            warn_when_exiting("Saw %s plural qualifier, can't handle, skipping" % g_full)
            return None
          mfpls = [mfpl, mfpl2]
          mfpls = [mfpl for mfpl in mfpls if mfpl]

        if mfs:
          defmf = make_mf(lemma)
          if mfs == [defmf]:
            if is_plural or (not mfpls or mfpls == [make_plural(defmf, g, True)]):
              subnotes.append("replace %s=%s with '+'" % (g, mfs[0]))
              return ["+"], mf_quals, []
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
            if is_plural:
              pass
            elif not mfpls:
              pagemsg("WARNING: Explicit %s=%s matches special=%s but no %s plural, allowing" % (
                g, ",".join(mfs), actual_special, g_full))
            else:
              special_mfpl = make_plural(special_mf, g, True, actual_special)
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
            defmf = make_mf(lemma)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              subnotes.append("replace default %s '%s' with '+'" % (g_full, defmf))
              mfs = mfs_with_def
            if not is_plural and mfpls:
              defpl = [make_plural(x, g, True) for x in mfs]
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
                  defpl = [make_plural(x, g, True, special) for x in mfs]
                  if set(defpl) == set(mfpls):
                    pagemsg("Found %s=%s, %spl=%s matches special=%s" % (
                      g, ",".join(mfs), g, ",".join(mfpls), special))
                    subnotes.append("replace explicit %s plural '%s' with special indicator '+%s'" %
                        (g_full, ",".join(mfpls), special))
                    mfpls = ["+%s" % special]
        mfs = [replace_lemma_with_hash(mf) for mf in mfs]
        return mfs, mf_quals, mfpls if not is_plural else []

      retval = handle_mf("f", "feminine", make_feminine)
      if retval is None:
        continue
      fs, f_quals, fpls = retval
      retval = handle_mf("m", "masculine", make_masculine)
      if retval is None:
        continue
      ms, m_quals, mpls = retval

      if not is_plural:
        blib.set_param_chain(t, pls, "2", "pl")
      blib.set_param_chain(t, fs, "f")
      if not is_plural:
        blib.set_param_chain(t, fpls, "fpl")
      blib.set_param_chain(t, ms, "m")
      if not is_plural:
        blib.set_param_chain(t, mpls, "mpl")

      if head is None:
        rmparam(t, "head")
      elif head and head == pagetitle:
        subnotes.append("convert head= without brackets to nolinkhead=1")
        rmparam(t, "head")
        t.add("nolinkhead", "1")

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        notes.append("clean up {{it-noun}} (%s)" % "; ".join(blib.group_notes(subnotes)))
      else:
        pagemsg("No changes to %s" % str(t))

    if tn == "it-noun" and args.make_multiword_plural_explicit:
      origt = str(t)
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
      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

    if tn == old_adj_template and args.do_adjs:
      if not getp("1") and not getp("2") and not getp("3") and not getp("4") and not getp("5"):
        pagemsg("WARNING: no numbered params: %s" % str(t))
        continue
      origt = str(t)
      stem = getp("1")
      end1 = getp("2")

      if not stem: # all specified
        if not end1:
          pagemsg("WARNING: 1= not given and 2=missing: %s" % str(t))
        f = getp("3")
        if not f:
          pagemsg("WARNING: 1= not given and 3=missing: %s" % str(t))
        mpl = getp("4")
        if not mpl:
          pagemsg("WARNING: 1= not given and 4=missing: %s" % str(t))
        fpl = getp("5")
        if not fpl:
          pagemsg("WARNING: 1= not given and 5=missing: %s" % str(t))
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
      for special in romance_utils.all_specials:
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
        pv = str(param.value)
        if pn not in ["head", "1", "2", "3", "4", "5", "sort"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, str(t)))
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

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))
        if old_adj_template == tname(t):
          notes.append("convert {{%s}} to new format" % old_adj_template)
        else:
          notes.append("convert {{%s}} to new {{%s}} format" % (old_adj_template, tname(t)))
      else:
        pagemsg("No changes to %s" % str(t))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{it-adj}} templates to new format or remove redundant args in {{it-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--do-nouns", action="store_true")
parser.add_argument("--do-adjs", action="store_true")
parser.add_argument("--make-multiword-plural-explicit", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

default_refs = []
if args.do_nouns:
  default_refs.append("Template:it-noun")
elif args.do_adjs:
  default_refs.append("Template:%s" % old_adj_template)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
