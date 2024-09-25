#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from collections import defaultdict

num_pages_by_dim_ending = defaultdict(int)
pages_by_dim_ending = defaultdict(list)
pages_by_dim_ending_set = defaultdict(set)

irregular_diminutives = [
  ("blad", "blaadje"),
  ("gat", "gaatje"),
  ("glas", "glaasje"),
  ("jongen", "jongetje"),
  ("meid", "meisje"),
  ("pad", "paadje"),
  ("schip", "scheepje"),
  ("vat", "vaatje"),
]

vowels = "AEIOUaeiouäëïöüâêîôû"
V = "[%s]" % vowels
NV = "[^%s]" % vowels
long_monophthongs = "[aä]a|[eë]e|[iï]e|[oö]o|[uü]u"
diphthongs = "[aä]ai|[aä][iu]|[eë]eu|[eë][iu]|[iï]eu|[iï]j|[oö][eui]|[oö]oi|[oö]ei|[uü]i"
LONGV = "(?:%s|%s)" % (long_monophthongs, diphthongs)
lengthen = {
  "a": "aa",
  "e": "ee",
  "i": "ie",
  "o": "oo",
  "u": "uu",
  "A": "Aa",
  "E": "Ee",
  "I": "Ie",
  "O": "Oo",
  "U": "Uu",
  # FIXME: Do the following ever occur and if so are these correct?
  "ä": "äa",
  "ë": "ëe",
  "ï": "ïe",
  "ö": "öo",
  "ü": "üu",
  # FIXME: Do the following ever occur and if so are these correct?
  "â": "âa",
  "ê": "êe",
  "î": "îe",
  "ô": "ôo",
  "û": "ûu",
}
devoice = {
  "z": "s", # grijze -> grijs
  "v": "f", # gave -> gaafje
}

def devoice_final(form):
  return form[:-1] + devoice.get(form[-1], form[-1])

def remove_final_e(form, final_multisyllable_stress=False):
  if re.search(LONGV + "$", form) or not re.search(V + NV + "*[eë]$", form):
    return form
  form = form[:-1]
  if re.search(LONGV + NV + "$", form):
    return devoice_final(form)
  m = re.search(V + NV + "*([eë][rln]|[oö]r|[eëuü]m|[iï]g)$", form)
  if m and not final_multisyllable_stress:
    return devoice_final(form)
  m = re.search("^(.*)(" + V + NV + ")$", form)
  if m:
    base, ending = m.groups()
    assert len(ending) == 2
    ending_v = ending[0]
    ending_c = ending[1]
    return base + lengthen[ending_v] + devoice_final(ending_c)
  m = re.search("^(.*)(" + NV + r")\2$", form)
  if m:
    base, first_c = m.groups()
    return base + devoice_final(first_c)
  return devoice_final(form)

# Based on [https://www.dutchgrammar.com/en/?n=NounsAndArticles.23].
def default_dim_1(lemma, final_multisyllable_stress=False, modifier_final_multisyllable_stress=False, first_only=False):
  if first_only:
    m = re.search("^([^ ]+) (.*)$", lemma)
    if m:
      first_word, rest = m.groups()
      return default_dim_1(first_word, final_multisyllable_stress, modifier_final_multisyllable_stress) + " " + rest
  m = re.search("^([^ ]+[eë]) (.*)$", lemma)
  if m:
    first_word, rest = m.groups()
    return remove_final_e(first_word, modifier_final_multisyllable_stress) + " " + default_dim_1(
        rest, final_multisyllable_stress, modifier_final_multisyllable_stress)
  for ending, repl in irregular_diminutives:
    if lemma.endswith(ending):
      return lemma[:-len(ending)] + repl
  if re.search(LONGV + "$", lemma):
    return lemma + "tje"
  if re.search("[aouäöü]$", lemma):
    return lemma[:-1] + lengthen[lemma[-1]] + "tje"
  if re.search("i$", lemma):
    return lemma + "etje"
  if re.search(NV + "y$", lemma):
    return lemma + "'tje"
  if re.search("é$", lemma):
    return lemma[:-1] + "eetje"
  if re.search("e$", lemma) and final_multisyllable_stress:
    lemma = remove_final_e(lemma, True)
  if (re.search(V + "$", lemma) or re.search("[wy]$", lemma) or re.search(LONGV + "[rln]$", lemma) or
      re.search("rn$", lemma)):
    return lemma + "tje"
  if re.search(V + NV + "*([eë][rln]|[oö]r)$", lemma):
    # NOTE: we already handled LONGV + [rln]$ above, so any occurrence of V + (e[rln]|or)$ is not a long vowel or
    # diphthong.
    return lemma + lemma[-1] + "etje" if final_multisyllable_stress else lemma + "tje"
  if re.search(V + "[rln]$", lemma):
    # NOTE: we already handled LONGV + [rln]$ above, so any occurrence of V + [rln]$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje"
  if re.search(LONGV + "m$", lemma) or re.search("[lr]m$", lemma):
    return lemma + "pje"
  if re.search(V + NV + "*[eëuü]m$", lemma):
    # NOTE: we already handled LONGV + m$ above, so any occurrence of V + [eu]m$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje" if final_multisyllable_stress else lemma + "pje"
  if re.search(V + "m$", lemma):
    # NOTE: we already handled LONGV + m$ above, so any occurrence of V + m$ is not a long vowel or diphthong.
    return lemma + lemma[-1] + "etje"
  if re.search(LONGV + "ng$", lemma):
    # NOTE: This may not exist.
    return lemma + "je"
  if re.search(V + NV + "*[iï]ng$", lemma):
    # NOTE: we already handled LONGV + ng$ above, so any occurrence of V + ing$ is not a long vowel or diphthong.
    return lemma + "etje" if final_multisyllable_stress else lemma[:-1] + "kje"
  if re.search(V + "ng$", lemma):
    # NOTE: we already handled LONGV + ng$ above, so any occurrence of V + ng$ is not a long vowel or diphthong.
    return lemma + "etje"
  return lemma + "je"

def default_dim(lemma, final_multisyllable_stress=False, modifier_final_multisyllable_stress=False, first_only=False):
  retval = default_dim_1(lemma, final_multisyllable_stress, modifier_final_multisyllable_stress, first_only)
  #msg("default_dim(%s, final_multisyllable_stress=%s, modifier_final_multisyllable_stress=%s, first_only=%s) = %s" % (
  #  lemma, final_multisyllable_stress, modifier_final_multisyllable_stress, first_only, retval))
  return retval
  
def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else "Dutch",
                                             pagemsg, force_final_nls=True)
  if retval is None:
    return

  sections, j, secbody, sectail, has_non_lang = retval

  notes = []

  def add_dim(dim_ending):
    num_pages_by_dim_ending[dim_ending] += 1
    if len(pages_by_dim_ending_set[dim_ending]) < 1000:
      if pagetitle not in pages_by_dim_ending_set[dim_ending]:
        pages_by_dim_ending_set[dim_ending].add(pagetitle)
        pages_by_dim_ending[dim_ending].append(pagetitle)

  parsed = blib.parse_text(secbody)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "nl-noun":
      dims = blib.fetch_param_chain(t, "3", "dim")
      newdims = []
      for dim in dims:
        if dim == "-":
          newdims.append(dim)
          continue
        if dim == default_dim(pagetitle):
          newdim = "+"
        elif dim == default_dim(pagetitle, True):
          newdim = "++"
        elif " " in pagetitle and dim == default_dim(pagetitle, False, True):
          newdim = "++/+"
        elif " " in pagetitle and dim == default_dim(pagetitle, True, True):
          newdim = "++/++"
        elif " " in pagetitle and dim == default_dim(pagetitle, False, False, True):
          newdim = "+first"
        elif " " in pagetitle and dim == default_dim(pagetitle, True, False, True):
          newdim = "++first"
        elif dim.startswith(pagetitle):
          dimending = dim[len(pagetitle):]
          newdim = "-" + dimending
        else:
          pagemsg("WARNING: Can't analyze diminutive %s" % dim)
          newdims.append(dim)
          continue
        add_dim(newdim)
        newdims.append(newdim)
        if args.fix:
          notes.append("replace Dutch diminutive '%s' with '%s'" % (dim, newdim))
      if args.fix:
        if dims != newdims:
          blib.set_param_chain(t, newdims, "3", "dim")

  secbody = str(parsed)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  text = "".join(sections)

  return text, notes

parser = blib.create_argparser("Analyze {{nl-noun}} diminutive usage",
  include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang Dutch' and has no ==Dutch== header.")
parser.add_argument("--fix", action="store_true", help="Modify diminutives to use shortcut notation.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)

msg("%20s  %5s  %s" % ("Ending", "Count", "Examples"))
msg("-"*80)
for dimending, num_occur in sorted(num_pages_by_dim_ending.items(), reverse=True, key=lambda x:x[1]):
  msg("%20s = %d  %s" % (dimending, num_occur, ",".join(pages_by_dim_ending[dimending])))
