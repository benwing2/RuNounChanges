#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

prepositions = {
  u"à ",
  "aux? ",
  "d[eu] ",
  u"d['’]",
  "des ",
  "en ",
  "sous ",
  "sur ",
  "avec ",
  "pour ",
  "par ",
  "dans ",
  "contre ",
  "sans ",
}

all_specials = ["first", "second", "first-second", "first-last", "last", "each"]

TEMPCHAR = u"\uFFF1"

old_adj_template = "fr-adj-old"
#old_adj_template = "fr-adj"

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

  m = re.search("^(.*?)( (?:%s))(.*)$" % "|".join(prepositions), form)

  if m:
    first, space_prep, rest = m.groups()
    return add_endings(inflect(first), space_prep + rest)

  if " " in form:
    return handle_multiword(form, "first-last", inflect)

  return None

# Generate a default plural form, which is correct for most regular nouns and adjectives.
def make_plural(form, special=None):
  retval = handle_multiword(form, special, make_plural)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None
  
  if re.search("[sxz]$", form):
    return form
  elif form.endswith("au"):
    return form + "x"
  elif form.endswith("al"):
    return form[:-1] + "ux"
  else:
    return form + "s"

# Generate a default feminine form.
def make_feminine(form, special=None):
  retval = handle_multiword(form, special, make_feminine)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  if form.endswith("e"):
    return form
  elif form.endswith("en"):
    return form + "ne"
  elif form.endswith("er"):
    return form[:-2] + u"ère"
  elif form.endswith("el"):
    return form + "le"
  elif form.endswith("et"):
    return form + "te"
  elif form.endswith("on"):
    return form + "ne"
  elif form.endswith("ieur"):
    return form + "e"
  elif form.endswith("teur"):
    return form[:-3] + "rice"
  elif re.search("eu[rx]$", form):
    return form[:-1] + "se"
  elif form.endswith("if"):
    return form[:-1] + "ve"
  elif form.endswith("c"):
    return form[:-1] + "que"
  elif form.endswith("eau"):
    return form[:-2] + "lle"
  else:
    return form + "e"

def make_masculine(form, special=None):
  retval = handle_multiword(form, special, make_masculine)
  if retval:
    assert len(retval) == 1
    return retval[0]
  if special:
    return None

  return form

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if old_adj_template not in text and "fr-noun" not in text:
    return

  if ":" in pagetitle:
    pagemsg("Skipping non-mainspace title")
    return

  pagemsg("Processing")

  parsed = blib.parse_text(text)

  def do_make_plural(form, special=None):
    retval = make_plural(form, special)
    if retval is None:
      return []
    return [retval]

  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    def join_with_brackets(args):
      return ",".join("'%s'" % arg if arg in ["s", "x"] else "[[%s]]" % arg for arg in args)
    if tn == "fr-noun" and args.remove_redundant_noun_args:
      origt = unicode(t)
      lemma = pagetitle
      g = getp("1")
      pls = blib.fetch_param_chain(t, "2")
      if g.endswith("-p"):
        if pls:
          pagemsg("WARNING: Plural-only noun with explicit plurals: %s" % unicode(t))
        continue
      if not pls:
        if " " in lemma:
          old_algorithm_pl = do_make_plural(lemma, "last")
          new_algorithm_pl = do_make_plural(lemma)
          if old_algorithm_pl == new_algorithm_pl:
            pagemsg("Space in headword and old default noun algorithm applying, leading to same results '%s' as new: %s"
                % (",".join(old_algorithm_pl), unicode(t)))
          else:
            pagemsg("WARNING: Space in headword and old default noun algorithm applying, leading to '%s' which is not the same as new algorithm '%s': %s"
                % (",".join(old_algorithm_pl), ",".join(new_algorithm_pl), unicode(t)))
        continue
      orig_pls = pls
      pls = [lemma + pl if pl in ["s", "x"] else pl for pl in pls]
      pls_with_def = []
      pls_with_def_notes = []
      defpl = do_make_plural(lemma)
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
        for i, pl in enumerate(pls):
          if pl == defpl[0]:
            pls_with_def.append("+")
            pls_with_def_notes.append("replace default plural %s with '+' in {{fr-noun}}"
                % join_with_brackets(defpl))
          elif pl == lemma:
            pls_with_def.append("#")
            pls_with_def_notes.append("replace unchanged plural with '#' in {{fr-noun}}")
          elif pl == lemma + "s":
            pls_with_def.append("s")
            if orig_pls[i] != "s":
              pls_with_def_notes.append("replace plural in '-s' with 's' in {{fr-noun}}")
          elif pl == lemma + "x":
            pls_with_def.append("x")
            if orig_pls[i] != "x":
              pls_with_def_notes.append("replace plural in '-x' with 'x' in {{fr-noun}}")
          elif pl == "*":
            pls_with_def.append("#")
            pls_with_def_notes.append("replace unchanged plural indicator '*' with '#' in {{fr-noun}}")
          else:
            pls_with_def.append(pl)

      actual_special = None
      for special in all_specials:
        special_pl = do_make_plural(lemma, special)
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
        notes.append("remove redundant plural%s %s from {{fr-noun}}"
            % ("s" if len(pls) > 1 else "", join_with_brackets(orig_pls)))
        blib.remove_param_chain(t, "2")
      elif pls_with_def in [["#"], ["s"], ["x"]]:
        notes.extend(pls_with_def_notes)
        blib.set_param_chain(t, pls_with_def, "2")
      elif actual_special:
        notes.append("replace plural%s %s with +%s in {{fr-noun}}" % (
          "s" if len(pls) > 1 else "", join_with_brackets(orig_pls), actual_special))
        blib.set_param_chain(t, ["+" + actual_special], "2")
      elif pls_with_def != pls:
        notes.extend(pls_with_def_notes)
        blib.set_param_chain(t, pls_with_def, "2")

      def handle_mf(mf, mf_full, make_mf):
        mfs = blib.fetch_param_chain(t, mf, mf)
        if mfs and not any(x.startswith("+") for x in mfs):
          defmf = make_mf(lemma)
          if set(mfs) == {defmf}:
            notes.append("replace %s=%s with '+' in {{fr-noun}}" % (mf, join_with_brackets(mfs)))
            blib.set_param_chain(t, ["+"], mf, mf)
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
            notes.append("replace explicit %s %s with special indicator '+%s' in {{fr-noun}}" %
                (mf_full, join_with_brackets(mfs), actual_special))
            blib.set_param_chain(t, ["+%s" % actual_special], mf, mf)
          if not actual_special:
            defmf = make_mf(lemma)
            mfs_with_def = ["+" if x == defmf else x for x in mfs]
            if mfs_with_def != mfs:
              notes.append("replace default %s %s with '+' in {{fr-noun}}" % (mf_full, defmf))
              blib.set_param_chain(t, mfs_with_def, mf, mf)

      handle_mf("f", "feminine", make_feminine)
      handle_mf("m", "masculine", make_masculine)

      head = getp("head")
      if head == lemma:
        if " " not in lemma and "-" not in lemma and "'" not in lemma:
          pagemsg("WARNING: Unnecessary head=%s, removing" % head)
          rmparam(t, "head")
          notes.append("remove redundant head=")
        else:
          pagemsg("Replacing head=%s with nolinkhead=1" % head)
          notes.append("replace head=%s with nolinkhead=1" % head)
          t.add("nolinkhead", "1", before="head")
          rmparam(t, "head")

      if origt != unicode(t):
        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
      else:
        pagemsg("No changes to %s" % unicode(t))

#    if tn == old_adj_template:
#      if not getp("1") and not getp("2") and not getp("3") and not getp("4") and not getp("5"):
#        pagemsg("WARNING: no numbered params: %s" % unicode(t))
#        continue
#      origt = unicode(t)
#      stem = getp("1")
#      end1 = getp("2")
#
#      if not stem: # all specified
#        if not end1:
#          pagemsg("WARNING: 1= not given and 2=missing: %s" % unicode(t))
#        f = getp("3")
#        if not f:
#          pagemsg("WARNING: 1= not given and 3=missing: %s" % unicode(t))
#        mpl = getp("4")
#        if not mpl:
#          pagemsg("WARNING: 1= not given and 4=missing: %s" % unicode(t))
#        fpl = getp("5")
#        if not fpl:
#          pagemsg("WARNING: 1= not given and 5=missing: %s" % unicode(t))
#      elif not end1: # no ending vowel parameters - generate default
#        f = stem + "a"
#        mpl = make_plural(stem + "o", "m", False) # not new_algorithm as this is old algorithm
#        fpl = make_plural(stem + "a", "f", False) # not new_algorithm as this is old algorithm
#      else:
#        end2 = getp("3") # or error("Either 0, 2 or 4 vowel endings should be supplied!")
#        end3 = getp("4")
#        
#        if not end3: # 2 ending vowel parameters - m and f are identical
#          f = pagetitle
#          mpl = stem + end2
#          fpl = mpl
#        else: # 4 ending vowel parameters - specify exactly
#          end4 = getp("5") # or error("Either 0, 2 or 4 vowel endings should be supplied!")
#          f = stem + end2
#          mpl = stem + end3
#          fpl = stem + end4
#
#      lemma = pagetitle
#      deff = make_feminine(pagetitle)
#      defmpl = do_make_plural(pagetitle, "m")
#      fs = []
#      fullfs = []
#      fullfs.append(f)
#      if f == deff:
#        f = "+"
#      elif f == lemma:
#        f = "#"
#      fs.append(f)
#      mpls = []
#      mpls.append(mpl)
#      fullmpls = mpls
#      # should really check for subsequence but it never occurs
#      if set(mpls) == set(defmpl):
#        mpls = ["+"]
#      elif set(mpls) < set(defmpl):
#        pagemsg("WARNING: mpls=%s subset of defmpl=%s, replacing with default" % (",".join(mpls), ",".join(defmpl)))
#        mpls = ["+"]
#      mpls = ["#" if x == lemma else x for x in mpls]
#      deffpl = [x for f in fullfs for x in do_make_plural(f, "f")]
#      fpls = []
#      fpls.append(fpl)
#      fullfpls = fpls
#      # should really check for subsequence but it never occurs
#      if set(fpls) == set(deffpl):
#        fpls = ["+"]
#      elif set(fpls) < set(deffpl):
#        pagemsg("WARNING: fpls=%s subset of deffpl=%s, replacing with default" % (",".join(fpls), ",".join(deffpl)))
#        fpls = ["+"]
#      fpls = ["#" if x == lemma else x for x in fpls]
#      actual_special = None
#      for special in all_specials:
#        deff = make_feminine(pagetitle, special)
#        if deff is None:
#          continue
#        defmpl = do_make_plural(pagetitle, "m", special)
#        deffpl = do_make_plural(deff, "f", special)
#        deff = [deff]
#        if fullfs == deff and fullmpls == defmpl and fullfpls == deffpl:
#          actual_special = special
#          break
#
#      head = getp("head")
#      sort = getp("sort")
#
#      must_continue = False
#      for param in t.params:
#        pn = pname(param)
#        pv = unicode(param.value)
#        if pn not in ["head", "1", "2", "3", "4", "5", "sort"]:
#          pagemsg("WARNING: Saw unrecognized param %s=%s in %s" % (pn, pv, unicode(t)))
#          must_continue = True
#          break
#      if must_continue:
#        continue
#
#      del t.params[:]
#      if head:
#        t.add("head", head)
#      blib.set_template_name(t, "fr-adj")
#      if fullfs == [pagetitle] and fullmpls == [pagetitle] and fullfpls == [pagetitle]:
#        t.add("inv", "1")
#      else:
#        if actual_special:
#          t.add("sp", actual_special)
#        else:
#          if fs != ["+"]:
#            blib.set_param_chain(t, fs, "f")
#
#          if mpls == fpls and ("+" not in mpls or defmpl == deffpl):
#            # masc and fem pl the same
#            if mpls != ["+"]:
#              blib.set_param_chain(t, mpls, "pl")
#          else:
#            if mpls != ["+"]:
#              blib.set_param_chain(t, mpls, "mpl")
#            if fpls != ["+"]:
#              blib.set_param_chain(t, fpls, "fpl")
#
#      if origt != unicode(t):
#        pagemsg("Replaced %s with %s" % (origt, unicode(t)))
#        if old_adj_template == tname(t):
#          notes.append("convert {{%s}} to new format" % old_adj_template)
#        else:
#          notes.append("convert {{%s}} to new {{%s}} format" % (old_adj_template, tname(t)))
#      else:
#        pagemsg("No changes to %s" % unicode(t))

  return unicode(parsed), notes

parser = blib.create_argparser("Convert {{fr-adj}} templates to new format or remove redundant args in {{fr-noun}}",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--remove-redundant-noun-args", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.remove_redundant_noun_args:
  default_refs=["Template:fr-noun"]
else:
  default_refs=["Template:%s" % old_adj_template]

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=default_refs)
