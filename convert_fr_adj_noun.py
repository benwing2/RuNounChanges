#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

prepositions = {
  "à ",
  "aux? ",
  "d[eu] ",
  "d['’]",
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
  "comme ",
  "jusqu['’]",
}

all_specials = ["first", "second", "first-second", "first-last", "last", "each"]

TEMPCHAR = "\uFFF1"

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
    return form[:-2] + "ère"
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

  if "fr-noun" not in text and "fr-adj" not in text:
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
      return ",".join("'%s'" % arg if arg in ["s", "x", "e", "+", "#"] else "[[%s]]" % arg for arg in args)
    if tn == "fr-noun" and args.do_nouns:
      origt = str(t)
      from_to_end = "<from> %s <to> %s <end>" % (origt, origt)
      lemma = pagetitle

      head = getp("head")
      use_nolinkhead = False
      remove_head = False
      headnotes = []
      if head == lemma:
        if " " not in lemma and "-" not in lemma and "'" not in lemma:
          pagemsg("Unnecessary head=%s, removing" % head)
          headnotes.append("remove redundant head= in {{fr-adj}}")
          head = None
          remove_head = True
        else:
          pagemsg("Replacing head=%s with nolinkhead=1" % head)
          headnotes.append("replace head=%s with nolinkhead=1 in {{fr-adj}}" % head)
          head = None
          use_nolinkhead = True

      def add_head_params():
        if remove_head:
          rmparam(t, "head")
        elif use_nolinkhead:
          t.add("nolinkhead", "1", before="head")
          rmparam(t, "head")
        notes.extend(headnotes)
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))

      g = getp("1")
      pls = blib.fetch_param_chain(t, "2")
      if g.endswith("-p"):
        if pls:
          pagemsg("WARNING: Plural-only noun with explicit plurals: %s" % from_to_end)
        continue

      mode = []
      if pls and pls[0] in ["~", "-"]:
        mode = [pls[0]]
        pls = pls[1:]

      if not pls:
        if " " in lemma and mode != ["-"]:
          old_algorithm_pl = do_make_plural(lemma, "last")
          new_algorithm_pl = do_make_plural(lemma)
          if old_algorithm_pl == new_algorithm_pl:
            pagemsg("Space in headword and old default noun algorithm applying, leading to same results '%s' as new: %s"
                % (",".join(old_algorithm_pl), str(t)))
          else:
            pagemsg("WARNING: Space in headword and old default noun algorithm applying, leading to '%s' which is not the same as new algorithm '%s': %s"
                % (",".join(old_algorithm_pl), ",".join(new_algorithm_pl), from_to_end))
            continue

      else:
        orig_pls = pls
        pls = [lemma + pl if pl in ["s", "x"] else pl for pl in pls]
        pls_with_def = []
        pls_with_def_notes = []
        defpl = do_make_plural(lemma)
        assert defpl
        if len(defpl) > 1:
          if set(pls) == set(defpl):
            pls_with_def = ["+"]
          elif set(pls) < set(defpl):
            pagemsg("WARNING: pls=%s subset of defpls=%s, replacing with default: %s"
                % (",".join(pls), ",".join(defpl), from_to_end))
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
            pagemsg("WARNING: for special=%s, pls=%s subset of special_pl=%s, allowing: %s" % (
              special, ",".join(pls), ",".join(special_pl), from_to_end))
            actual_special = special
            break
          if set(pls) == set(special_pl):
            pagemsg("Found special=%s with special_pl=%s" % (special, ",".join(special_pl)))
            actual_special = special
            break

        if pls_with_def == ["+"] and mode != ["-"]:
          notes.append("remove redundant plural%s %s from {{fr-noun}}"
              % ("s" if len(pls) > 1 else "", join_with_brackets(orig_pls)))
          if not mode:
            blib.remove_param_chain(t, "2")
          else:
            blib.set_param_chain(t, mode, "2")
        elif pls_with_def in [["+"], ["#"], ["s"], ["x"]]:
          notes.extend(pls_with_def_notes)
          blib.set_param_chain(t, mode + pls_with_def, "2")
        elif actual_special:
          notes.append("replace plural%s %s with +%s in {{fr-noun}}" % (
            "s" if len(pls) > 1 else "", join_with_brackets(orig_pls), actual_special))
          blib.set_param_chain(t, mode + ["+" + actual_special], "2")
        elif pls_with_def != orig_pls:
          notes.extend(pls_with_def_notes)
          blib.set_param_chain(t, mode + pls_with_def, "2")

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

      add_head_params()
      continue

    if tn == "fr-adj" and args.do_adjectives:
      origt = str(t)
      from_to_end = "<from> %s <to> %s <end>" % (origt, origt)
      lemma = pagetitle
      head = getp("head")
      use_nolinkhead = False
      remove_head = False
      headnotes = []
      if head == lemma:
        if " " not in lemma and "-" not in lemma and "'" not in lemma:
          pagemsg("Unnecessary head=%s, removing" % head)
          headnotes.append("remove redundant head= in {{fr-adj}}")
          head = None
          remove_head = True
        else:
          pagemsg("Replacing head=%s with nolinkhead=1" % head)
          headnotes.append("replace head=%s with nolinkhead=1 in {{fr-adj}}" % head)
          head = None
          use_nolinkhead = True

      if getp("sp") or getp("inv"):
        pagemsg("Already saw sp= or inv= in {{fr-adj}}, skipping other than maybe removing head=: %s" % str(t))
        if remove_head:
          rmparam(t, "head")
        elif use_nolinkhead:
          t.add("nolinkhead", "1", before="head")
          rmparam(t, "head")
        notes.extend(headnotes)
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
        continue

      fs = blib.fetch_param_chain(t, "f")
      mpls = blib.fetch_param_chain(t, "mp")
      fpls = blib.fetch_param_chain(t, "fp")
      pls = blib.fetch_param_chain(t, "p")
      gender = getp("1")
      all_defaulted = not fs and not mpls and not fpls
      if len(fs) > 1 or len(mpls) > 1 or len(fpls) > 1:
        pagemsg("WARNING: Saw multiple values for inflections, can't handle yet: %s" % from_to_end)
        continue

      if " " in lemma and not fs and not fpls and lemma.endswith("e"):
        pagemsg("WARNING: Multiword lemma ending in -e without f= or fpl=, would be mf= before, won't now, review manually: %s"
          % from_to_end)
        continue

      def expand_shortcuts(value, default):
        if value == "+":
          return default
        if value == "#":
          return lemma
        if value == "e":
          return lemma + "e"
        if value == "s":
          return lemma + "s"
        if value == "x":
          return lemma + "x"
        return value

      def replace_with_shortcuts(value, default):
        if value == default:
          return "+"
        if value == lemma:
          return "#"
        if value == lemma + "e":
          return "e"
        if value == lemma + "s":
          return "s"
        if value == lemma + "x":
          return "x"
        return value

      def add_head_params():
        if head:
          t.add("head", head)
        if use_nolinkhead:
          t.add("nolinkhead", "1")
        notes.extend(headnotes)
        if origt != str(t):
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          if not notes:
            # This can happen e.g. if we end up just moving head= to the end, or we convert |1=mf to |mf
            notes.append("clean up {{fr-adj}}")

      if gender and gender != "mf":
        pagemsg("WARNING: Saw gender=%s not 'mf', can't handle: %s" % (gender, from_to_end))
        continue
      automf = " " not in lemma and lemma.endswith("e")
      if gender != "mf" and not automf and pls:
        pagemsg("WARNING: Saw pl= and not gender=mf, can't handle: %s" % from_to_end)
        continue
      if len(pls) > 1:
        pagemsg("WARNING: Saw multiple pl=, can't handle yet: %s" % from_to_end)
        continue
      if gender == "mf" or automf:
        if not all_defaulted:
          pagemsg("WARNING: Saw gendered inflections along with 1=mf, can't handle: %s" % from_to_end)
          continue
        gendernotes = []

        if automf:
          if gender:
            gendernotes.append("remove redundant 1=mf in {{fr-adj}}")
          gender = None
        defpl = make_plural(lemma)
        if len(pls) > 0:
          pl = expand_shortcuts(pls[0], defpl)
        else:
          pl = defpl

        must_continue = False
        for param in t.params:
          pn = pname(param)
          pv = str(param.value)
          if pn not in ["head", "1", "p"]:
            pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, from_to_end))
            must_continue = True
            break
        if must_continue:
          continue

        if not pls and " " in lemma:
          old_algorithm_pl = make_plural(lemma, "last")
          if old_algorithm_pl == pl:
            pagemsg("Space in headword and old default noun algorithm applying, leading to same results as new: pl='%s': %s"
                % (old_algorithm_pl, str(t)))
          else:
            pagemsg("WARNING: Space in headword and old default noun algorithm applying, leading to values not all same as new algorithm: oldpl='%s', newpl='%s': %s"
                % (old_algorithm_pl, pl, from_to_end))
            continue

        if pl == defpl:
          del t.params[:]
          if pls:
            notes.append("remove redundant {{fr-adj}} params")
          if gender:
            t.add("1", gender)
          notes.extend(gendernotes)
          add_head_params()
          continue

        actual_special = None
        for special in all_specials:
          spdefpl = make_plural(lemma, special)
          if pl == spdefpl:
            actual_special = special
            break
        if actual_special:
          del t.params[:]
          assert pls
          if gender:
            t.add("1", gender)
          notes.extend(gendernotes)
          t.add("sp", actual_special)
          notes.append("replace {{fr-adj}} params with sp=%s" % actual_special)
          add_head_params()
          continue

        pl = replace_with_shortcuts(pl, defpl)

        del t.params[:]
        assert pls
        if gender:
          t.add("1", gender)
        notes.extend(gendernotes)
        if pl == "#":
          notes.append("replace {{fr-adj}} params with inv=1")
          t.add("inv", "1")
        else:
          if pl != "+":
            t.add("p", pl)
          if [pl] != pls:
            notes.append("remove unnecessary {{fr-adj}} params and/or replace with shortcut(s)")
        add_head_params()
        continue

      deff = make_feminine(lemma)
      defmpl = make_plural(lemma)
      if len(fs) > 0:
        f = expand_shortcuts(fs[0], deff)
      else:
        f = deff
      if len(mpls) > 0:
        mpl = expand_shortcuts(mpls[0], defmpl)
      else:
        mpl = defmpl
      deffpl = make_plural(f)
      if len(fpls) > 0:
        fpl = expand_shortcuts(fpls[0], deffpl)
      else:
        fpl = deffpl

      must_continue = False
      for param in t.params:
        pn = pname(param)
        pv = str(param.value)
        if pn not in ["head", "f", "mp", "fp"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pn, pv, from_to_end))
          must_continue = True
          break
      if must_continue:
        continue

      if (not fs or not mpls or not fpls) and " " in lemma:
        old_algorithm_f = fs and fs[0] or make_feminine(lemma, "last")
        assert old_algorithm_f
        old_algorithm_mpl = make_plural(lemma, "last")
        old_algorithm_fpl = make_plural(old_algorithm_f, "last")
        if (fs or old_algorithm_f == f) and (mpls or old_algorithm_mpl == mpl) and (fpls or old_algorithm_fpl == fpl):
          pagemsg("Space in headword and old default noun algorithm applying, leading to same results as new: f='%s', mpl='%s', fpl='%s': %s"
              % (old_algorithm_f, old_algorithm_mpl, old_algorithm_fpl, str(t)))
        else:
          pagemsg("WARNING: Space in headword and old default noun algorithm applying, leading to values not all same as new algorithm: %s; %s; %s: %s"
              % (fs and "explicit-f=%s" % f or "oldf='%s', newf='%s'" % (old_algorithm_f, f),
                 mpls and "explicit-mpl=%s" % mpl or "oldmpl='%s', newmpl='%s'" % (old_algorithm_mpl, mpl),
                 fpls and "explicit-fpl=%s" % fpl or "oldfpl='%s', newfpl='%s'" % (old_algorithm_fpl, fpl),
                 from_to_end))
          continue

      if f == deff and mpl == defmpl and fpl == deffpl:
        del t.params[:]
        if not all_defaulted:
          notes.append("remove redundant {{fr-adj}} params")
        add_head_params()
        continue

      actual_special = None
      for special in all_specials:
        spdeff = make_feminine(lemma, special)
        if spdeff is None:
          continue
        spdefmpl = make_plural(lemma, special)
        spdeffpl = make_plural(spdeff, special)
        if f == spdeff and mpl == spdefmpl and fpl == spdeffpl:
          actual_special = special
          break
      if actual_special:
        del t.params[:]
        assert not all_defaulted
        t.add("sp", actual_special)
        notes.append("replace {{fr-adj}} params with sp=%s" % actual_special)
        add_head_params()
        continue

      f = replace_with_shortcuts(f, deff)
      mpl = replace_with_shortcuts(mpl, defmpl)
      fpl = replace_with_shortcuts(fpl, deffpl)

      del t.params[:]
      assert not all_defaulted
      if f == "#" and mpl == "#" and fpl == "#":
        notes.append("replace {{fr-adj}} params with inv=1")
        t.add("inv", "1")
      elif f == "#" and mpl == fpl:
        notes.append("convert {{fr-adj}} to 1=mf")
        t.add("1", "mf")
        if mpl != "+":
          t.add("p", mpl)
      else:
        if f != "+":
          t.add("f", f)
        if mpl != "+":
          t.add("mp", mpl)
        if fpl != "+":
          t.add("fp", fpl)
        if [f] != fs or [mpl] != mpls or [fpl] != fpls:
          notes.append("remove unnecessary {{fr-adj}} params and/or replace with shortcut(s)")
      add_head_params()
      continue

  return str(parsed), notes

parser = blib.create_argparser("Remove redundant params in {{fr-noun}}/{{fr-adj}} or replace with shortcut(s)",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--do-nouns", action="store_true")
parser.add_argument("--do-adjectives", action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=["Template:fr-noun", "Template:fr-adj"])
