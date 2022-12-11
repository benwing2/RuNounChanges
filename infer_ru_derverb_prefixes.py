#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse, unicodedata
from collections import defaultdict

from blib import msg
import blib
import rulib

parser = argparse.ArgumentParser(description="Infer prefixes from derived verb tables without them.")
parser.add_argument('files', nargs='*', help="Files containing directives.")
parser.add_argument('--suffixes', help="Extra suffixes, of the format FILE=SUFFIX,SUFFIX,...;FILE=SUFFIX,SUFFIX,...")
parser.add_argument('--direcfile', help="File containing input in find_regex format.")
parser.add_argument('--sort', action='store_true', help="Sort template suffix groups.")
args = parser.parse_args()

AC = u"\u0301"

def remove_stress(term):
  return rulib.remove_accents(term)

class InferError(Exception):
  pass

def debracket(verb):
  m = re.search(r"^(.*)(<.*>)$", verb)
  if m:
    verb, mods = m.groups()
  else:
    mods = ""
  m = re.search(r"^\[(.*)\]$", verb)
  if m:
    verb = m.group(1)
    brackets = True
  else:
    brackets = False
  return verb, brackets, mods

def rebracket(verb, brackets, mods):
  if brackets:
    verb = "[%s]" % verb
  return verb + mods

def paste_verb(prefix, suffix):
  if rulib.is_stressed(prefix):
    verb = prefix + rulib.make_unstressed_ru(suffix)
  else:
    verb = prefix + suffix
  return rulib.remove_monosyllabic_accents(verb)

def combine_prefix(prefix, suffixes):
  links = []
  for suffix, brackets, mods in suffixes:
    links.append(rebracket(paste_verb(prefix, suffix), brackets, mods))
  return ",".join(links)

def convert_prefix_and_suffixes_to_full(prefix, pf_suffixes, impf_suffixes):
  prefix = "" if prefix == "." else prefix
  pfs = combine_prefix(prefix, pf_suffixes)
  impfs = combine_prefix(rulib.make_unstressed_ru(prefix), impf_suffixes)
  return "%s/%s" % (pfs or "-", impfs or "-")

def extract_prefix_and_suffix(term, suffixes_no_stress):
  num_acs = len([x for x in term if x == AC])
  if num_acs > 1:
    raise InferError("Saw term with multiple accents: %s" % term)
  for suffix_no_stress in suffixes_no_stress:
    for refl_suffix in ["", u"ся", u"сь"]:
      full_suffix = suffix_no_stress + refl_suffix
      suflen = len(full_suffix)
      if term.endswith(full_suffix):
        return term[0:-suflen], full_suffix
      term_no_stress = remove_stress(term)
      if term_no_stress.endswith(full_suffix):
        return term[0:-(suflen + 1)], term[-(suflen + 1):]
  return None, None

def extract_prefix_and_suffixes(pfs, impfs, suffixes_no_stress):
  all_verbs = pfs + impfs

  prefix = None
  for verb, bracketed, mods in all_verbs:
    this_prefix, this_suffix = extract_prefix_and_suffix(verb, suffixes_no_stress)
    if this_prefix is not None:
      if prefix is not None:
        if this_prefix != prefix:
          if remove_stress(this_prefix) == prefix:
            pass
          elif this_prefix == remove_stress(prefix):
            this_prefix = prefix
          elif this_prefix + u"о" == prefix:
            pass
          else:
            raise InferError("Saw two different prefixes %s and %s for suffixes %s" %
                (prefix, this_prefix, ",".join(suffixes_no_stress)))
      prefix = this_prefix
  if prefix is None:
    raise InferError("Can't extract prefix from perfect(s) %s, imperfect(s) %s, possible suffixes %s" %
        (join_verbs(pfs), join_verbs(impfs), ",".join(suffixes_no_stress)))

  def process_verb(verb, bracketed, mods, append_to):
    new_prefix = prefix
    if verb.startswith(prefix):
      suffix = verb[len(prefix):]
    else:
      prefix_no_stress = remove_stress(prefix)
      if verb.startswith(prefix_no_stress):
        suffix = verb[len(prefix_no_stress):]
      elif prefix.endswith(u"о") and verb.startswith(prefix[:-1]):
        new_prefix = prefix[:-1]
        suffix = verb[len(new_prefix):]
      else:
        raise InferError("Can't extract prefix %s from verb %s (suffixes %s)" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    append_to.append((suffix, bracketed, mods))
    return new_prefix

  first = True

  impf_suffixes = []
  for verb, bracketed, mods in impfs:
    new_prefix = process_verb(verb, bracketed, mods, impf_suffixes)
    if new_prefix != prefix:
      if first:
        prefix = new_prefix
      else:
        raise InferError("Can't extract prefix %s from verb %s for suffixes %s" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    first = False

  pf_suffixes = []
  for verb, bracketed, mods in pfs:
    new_prefix = process_verb(verb, bracketed, mods, pf_suffixes)
    if new_prefix != prefix:
      if first:
        prefix = new_prefix
      else:
        raise InferError("Can't extract prefix %s from verb %s for suffixes %s" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    first = False

  return prefix or ".", pf_suffixes, impf_suffixes

def augment_suffix(suffix):
  suffix = remove_stress(suffix)
  retval = []
  def augment_1(suffix):
    retval.append(suffix)
    if suffix.endswith(u"ть") or suffix.endswith(u"чь"):
      retval.append(suffix + u"ся")
    elif suffix.endswith(u"ти"):
      retval.append(suffix + u"сь")
    elif suffix.endswith(u"ся") or suffix.endswith(u"сь"):
      retval.append(suffix[:-2])
  augment_1(suffix)
  if u"ё" in suffix:
    augment_1(suffix.replace(u"ё", u"е"))
  return retval

def augment_suffixes(suffixes):
  return [augsuf for suffix, brackets, mods in suffixes for augsuf in augment_suffix(suffix)]

def split_verbs(verbs):
  verb_parts = re.split("((?:<.*?>|[^,<>])*)", verbs)
  verb_parts = [verb_parts[i] for i in range(1, len(verb_parts), 2)]
  return [debracket(verb) for verb in verb_parts]

def split_pf_impf(line):
  pf_impf_items = re.split(r"\s+", line)
  if len(pf_impf_items) != 2:
    raise InferError("Not exactly two aspects on line: %s" % line)
  pf, impf = pf_impf_items
  pf = pf.replace("_", " ")
  impf = impf.replace("_", " ")
  return pf, impf

def join_verbs(verbs):
  return ",".join(rebracket(verb, brackets, mods) for verb, brackets, mods in verbs)

def join_pf_impf(pf, impf):
  return pf.replace(" ", "_") + " " + impf.replace(" ", "_")

def split_lines_into_groups(lines):
  groups = []
  group = []
  suffix_lines = []
  for lineno, line in lines:
    if line == "-":
      if group:
        groups.append(group)
        group = []
    elif line.startswith("suffixes:"):
      suffix_lines.append(re.sub("^suffixes:", "", line))
    else:
      group.append((lineno, line))
  if group:
    groups.append(group)
  return groups, suffix_lines

def split_lines_into_tables(lines):
  tables = []
  table = []
  for lineno, line in lines:
    if re.search("^--+", line):
      if table:
        tables.append(table)
        table = []
    else:
      table.append((lineno, line))
  if table:
    tables.append(table)
  return tables

current_pf_suffixes = []
current_impf_suffixes = []
current_bracketed_suffixes = set()

def expand_line(line, linemsg):
  global current_pf_suffixes, current_impf_suffixes
  if line.startswith("suffixes:"):
    return line
  elif re.search("^--+$", line):
    # FIXME
    return False
  elif line == "-":
    return line
  elif " " not in line:
    # A single prefix; combine with previous suffixes.
    return join_pf_impf(
      combine_prefix(line, current_pf_suffixes) or "-",
      combine_prefix(rulib.make_unstressed_ru(line), current_impf_suffixes) or "-"
    )
  elif "!" in line:
    # Something like "об !" or "+об !" or "! об" or "! +об". This indicates that one of the two is missing and the
    # other should combine with previous suffixes, maybe originally with the aspect included (see лететь.der for
    # good examples of this).
    pf, impf = split_pf_impf(line)
    assert pf == "!" or impf == "!"
    if pf == "!":
      return "- %s" % combine_prefix(rulib.make_unstressed_ru(impf), current_impf_suffixes)
    else:
      return "%s -" % combine_prefix(pf, current_pf_suffixes)
  else:
    # Something like "обмени́ть,обменя́ть обме́нивать" or "+переменя́ться -".
    # We directly include the perfective and imperfective verb(s), where
    # a lone "-" means to not include it, and a prefixed "+" means to
    # include the aspect.
    pf, impf = split_pf_impf(line)
    if pf.startswith("-") and impf.startswith("-"):
      current_pf_suffixes = [] if pf == "-" else [
        (re.sub("^-", "", suffix), brackets, mods) for suffix, brackets, mods in split_verbs(pf)
      ]
      current_impf_suffixes = [] if impf == "-" else [
        (re.sub("^-", "", suffix), brackets, mods) for suffix, brackets, mods in split_verbs(impf)
      ]
      return [current_pf_suffixes, current_impf_suffixes]

    def expand_item(item, suffixes, aspect):
      if item == "-":
        return item
      retval = []
      maybe_prefs = split_verbs(item)
      for ind, (maybe_pref, brackets, mods) in enumerate(maybe_prefs):
        if not maybe_pref:
          continue
        if maybe_pref.endswith("-"):
          maybe_pref = maybe_pref[:-1]
          if aspect == "impf":
            maybe_pref = rulib.make_unstressed_ru(maybe_pref)
          suffix, suffix_brackets, suffix_mods = suffixes[ind]
          retval.append(rebracket(paste_verb(maybe_pref, suffix), brackets or suffix_brackets, mods + suffix_mods))
        else:
          retval.append(rebracket(maybe_pref, brackets, mods))
      return ",".join(retval)

    return join_pf_impf(expand_item(pf, current_pf_suffixes, "pf"), expand_item(impf, current_impf_suffixes, "impf"))

def do_line_group(group, fn, suffix_lines, extra_suffixes, pass_):
  suffix_no_stress = re.sub("^-", "", re.sub(r"[0-9a-z]*\.der$", "", fn))
  explicit_extra_suffixes = []

  for suffix_line in suffix_lines:
    explicit_extra_suffixes.extend(augment_suffixes(split_verbs(suffix_line)))

  # Put longer suffixes first.
  extra_suffixes = sorted(list(extra_suffixes) + explicit_extra_suffixes, key=lambda x:-len(x))

  items = group

  prefixes_by_suffixes = defaultdict(list)
  ordering_of_seen_suffixes = []
  unstressed_suffix_to_suffix = {}
  unattached_lines = []

  # Formerly we could precede a prefix with + to indicate that the perfective should be marked with its aspect (for
  # cases where the same verb occurred as both perfective and imperfective, as with derivatives of лететь/летать), or
  # write something like "об +" or "+об +", originally indicating that the imperfective (and maybe the perfective)
  # should include the aspect. See лететь.der for good examples. Now handled automatically.
  items = [(lineno, rulib.recompose(line.replace("+", "").strip())) for lineno, line in items]
  new_format = False
  for lineno, line in items:
    if line != "-" and (" " not in line or "! " in line or " !" in line):
      # Already in "new" format, pass through unchanged
      new_format = True
      break
  if new_format:
    msg("# File %s: New format; converting to old format and then processing" % fn)
    new_items = []
    for lineno, line in items:
      newline = expand_line(line, lineno)
      if type(newline) is list:
        this_pf_suffixes, this_impf_suffixes = newline
        explicit_extra_suffixes.extend(augment_suffixes(this_pf_suffixes))
        explicit_extra_suffixes.extend(augment_suffixes(this_impf_suffixes))
      elif newline:
        new_items.append((lineno, newline))
    items = new_items

  for lineno, line in items:
    if line == "-":
      continue
    def linemsg(txt):
      msg("# File %s: Line %s: %s" % (fn, lineno, txt))
    try:
      if " " not in line:
        linemsg("WARNING: No space in line: %s" % line)
        if pass_ == 1:
          msg(line)
      elif "(" in line:
        linemsg("WARNING: Paren in line: %s" % line)
        if pass_ == 1:
          msg(line)
      else:
        pfs, impfs = split_pf_impf(line)
        pfs = [] if pfs == "-" else split_verbs(pfs)
        impfs = [] if impfs == "-" else split_verbs(impfs)
        def warn_if_needs_accents(terms):
          for term, brackets, mods in terms:
            if rulib.needs_accents(term):
              linemsg("WARNING: Term %s needs accents" % term)
        warn_if_needs_accents(pfs)
        warn_if_needs_accents(impfs)
        prefix, pf_suffixes, impf_suffixes = extract_prefix_and_suffixes(pfs, impfs,
          [suffix_no_stress] + extra_suffixes)
        key = (join_verbs(pf_suffixes), join_verbs(impf_suffixes))
        if key not in prefixes_by_suffixes:
          ordering_of_seen_suffixes.append(key)
        prefixes_by_suffixes[key].append(prefix)
        for pf_suffix, brackets, mods in pf_suffixes:
          if AC in pf_suffix:
            unstressed_pf_suffix = remove_stress(pf_suffix)
            if (
              unstressed_pf_suffix in unstressed_suffix_to_suffix and
              unstressed_suffix_to_suffix[unstressed_pf_suffix] != pf_suffix
            ):
              linemsg("Unstressed perfective suffix %s maps to two different stressed suffixes %s and %s" %
                (unstressed_pf_suffix, unstressed_suffix_to_suffix[unstressed_pf_suffix], pf_suffix))
              del unstressed_suffix_to_suffix[unstressed_pf_suffix]
            else:
              unstressed_suffix_to_suffix[unstressed_pf_suffix] = pf_suffix

    except InferError as e:
      if pass_ == 1:
        linemsg("WARNING: %s: %s" % (unicode(e), line))
        msg(line.replace(" ", "/"))

  if pass_ == 0:
    # We try to process lines with previously unrecognized suffixes using the suffixes seen so far.
    extra_suffixes = set()
    for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
      if pf_suffixes:
        for pf_suffix, brackets, mods in split_verbs(pf_suffixes):
          extra_suffixes |= set(augment_suffix(pf_suffix))
      if impf_suffixes:
        for impf_suffix, brackets, mods in split_verbs(impf_suffixes):
          extra_suffixes |= set(augment_suffix(impf_suffix))
    return extra_suffixes

  # Combine unstressed suffixes with stressed equivalents to handle вы́-, повы́-, etc.
  keys_to_delete = []
  for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
    orig_pf_suffixes = pf_suffixes
    pf_suffixes = split_verbs(pf_suffixes)
    pf_suffixes = [
      (unstressed_suffix_to_suffix.get(pf_suffix, pf_suffix), brackets, mods)
      for pf_suffix, brackets, mods in pf_suffixes
    ]
    pf_suffixes = join_verbs(pf_suffixes)
    if pf_suffixes != orig_pf_suffixes:
      key = (pf_suffixes, impf_suffixes)
      if key in prefixes_by_suffixes:
        # Python doesn't like it if you side-effect a dictionary you're iterating over
        keys_to_delete.append((orig_pf_suffixes, impf_suffixes))
        prefixes_by_suffixes[key].extend(prefixes)
  for key_to_delete in keys_to_delete:
    del prefixes_by_suffixes[key_to_delete]

  # Combine cases with missing pf or impf with similar values with present pf and impf
  keys_to_delete = []
  def handle_empty_pf_or_impf(non_empty_suffixes, prefixes, aspect):
    if len(prefixes) > 1:
      # leave as-is
      return
    potential_full_suffixes = []
    for (full_pf_suffixes, full_impf_suffixes), full_prefixes in prefixes_by_suffixes.iteritems():
      full_other_aspect_suffixes = full_pf_suffixes if aspect == "impf" else full_impf_suffixes
      if full_other_aspect_suffixes and (
        non_empty_suffixes == (full_impf_suffixes if aspect == "impf" else full_pf_suffixes)
      ):
        potential_full_suffixes.append((full_other_aspect_suffixes, len(full_prefixes)))
    if len(potential_full_suffixes) == 0:
      for prefix in prefixes:
        split_non_empty_suffixes = split_verbs(non_empty_suffixes)
        unattached_lines.append(convert_prefix_and_suffixes_to_full(prefix,
          [] if aspect == "impf" else split_non_empty_suffixes,
          split_non_empty_suffixes if aspect == "impf" else []
        ))
    else:
      # If more than one possible set of suffixes, take the set with the smallest number of suffixes
      # and if more than one such, take the set with the largest number of prefixes.
      best_suffixes = sorted(potential_full_suffixes,
        key=lambda x: (-len(split_verbs(x[0])), x[1]))[0][0]
      suffix_key = (best_suffixes, non_empty_suffixes) if aspect == "impf" else (non_empty_suffixes, best_suffixes)
      for prefix in prefixes:
        assert suffix_key in prefixes_by_suffixes, "Saw key %s not in prefixes_by_suffixes" % suffix_key
        prefixes_by_suffixes[suffix_key].append("-/%s-" % prefix if aspect == "impf" else "%s-/-" % prefix)
    keys_to_delete.append((
      "" if aspect == "impf" else non_empty_suffixes,
      non_empty_suffixes if aspect == "impf" else ""
    ))

  for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
    if pf_suffixes == "":
      handle_empty_pf_or_impf(impf_suffixes, prefixes, "impf")
    elif impf_suffixes == "":
      handle_empty_pf_or_impf(pf_suffixes, prefixes, "pf")
  for key_to_delete in keys_to_delete:
    del prefixes_by_suffixes[key_to_delete]

  for unattached_line in unattached_lines:
    msg(unattached_line)
  # Sort prefix/suffix sets by the order in which they were originally seen.
  # NOTE: Python 3 automatically preserves order in dictionaries.
  ordering_dict = dict((y, x) for x, y in enumerate(ordering_of_seen_suffixes))
  def sort_key_for_sorting(x):
    (pf_suffixes, impf_suffixes), prefixes = x
    return (rulib.remove_accents(pf_suffixes), pf_suffixes, rulib.remove_accents(impf_suffixes), impf_suffixes)
  for (pf_suffixes, impf_suffixes), prefixes in sorted(prefixes_by_suffixes.iteritems(),
      key=sort_key_for_sorting if args.sort else lambda x: ordering_dict[x[0]]):
    if len(prefixes) == 1 and "." in prefixes[0]:
      msg(convert_prefix_and_suffixes_to_full(prefixes[0], split_verbs(pf_suffixes), split_verbs(impf_suffixes)))
    else:
      msg("*%s/%s" % (pf_suffixes or "-", impf_suffixes or "-"))
      for prefix in sorted(prefixes):
        msg(prefix)

def process_lines_from_file(index, lines, fn):
  tables = split_lines_into_tables(lines)
  msg("Page %s %s: --------- begin text -----------" % (index, re.sub(r"\.der$", "", fn)))
  # do all tables
  for tableno, table in enumerate(tables):
    groups, suffix_lines = split_lines_into_groups(table)
    # first extract the suffixes
    all_groups = [x for group in groups for x in group]
    extra_suffixes = do_line_group(all_groups, fn, suffix_lines, [], 0)
    # now do the groups separately
    for groupno, group in enumerate(groups):
      do_line_group(group, fn, suffix_lines, extra_suffixes, 1)
      if groupno < len(groups) - 1:
        msg("-")
    if tableno < len(tables) - 1:
      msg("----")
  msg("--------- end text -----------")

def add_newline(generator):
  for line in generator:
    yield line + "\n"

if args.direcfile:
  for index, pagename, pagetext, comment in blib.yield_text_from_find_regex(
      add_newline(blib.yield_items_from_file(args.direcfile)), verbose=False):
    linenos_and_lines = []
    lines = pagetext.rstrip("\n").split("\n")
    for lineindex, line in enumerate(lines):
      linenos_and_lines.append((lineindex + 1, line))
    process_lines_from_file(index, linenos_and_lines, rulib.recompose(pagename) + ".der")
else:
  for index, extfn in enumerate(args.files):
    lines = list(blib.iter_items_from_file(extfn, None, None))
    fn = rulib.recompose(extfn.decode("utf-8"))
    process_lines_from_file(index + 1, lines, fn)
