#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse, unicodedata
from collections import defaultdict

from blib import msg
import blib
import rulib

FIXME: Brackets not handled correctly. E.g. for бросить.der, '[бро́сить] броса́ть' snares prefix поза even though the latter doesn't have brackets around anything.

parser = argparse.ArgumentParser(description="Infer prefixes from derived verb tables without them.")
parser.add_argument('files', nargs='+', help="Files containing directives.")
parser.add_argument('--suffixes', help="Extra suffixes, of the format FILE=SUFFIX,SUFFIX,...;FILE=SUFFIX,SUFFIX,...")
args = parser.parse_args()

AC = u"\u0301"

def remove_stress(term):
  return rulib.remove_accents(term)

class UnrecognizedSuffix(Exception):
  pass

def remove_brackets(verbs, bracketed_verbs):
  retval = []
  for verb in verbs:
    m = re.search(r"^\[(.*)\]$", verb)
    if m:
      verb = m.group(1)
      bracketed_verbs.add(verb)
    retval.append(verb)
  return retval

def extract_prefix_and_suffix(term, suffixes_no_stress):
  num_acs = len([x for x in term if x == AC])
  if num_acs > 1:
    raise ValueError("Saw term with multiple accents: %s" % term)
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
  bracketed_verbs = set()
  pfs = remove_brackets(pfs, bracketed_verbs)
  impfs = remove_brackets(impfs, bracketed_verbs)

  all_verbs = pfs + impfs

  prefix = None
  for verb in all_verbs:
    this_prefix, this_suffix = extract_prefix_and_suffix(verb, suffixes_no_stress)
    if this_prefix is not None:
      if prefix is not None:
        if this_prefix != prefix:
          if remove_stress(this_prefix) == prefix:
            pass
          elif this_prefix == remove_stress(prefix):
            this_prefix = prefix
          else:
            raise ValueError("Saw two different prefixes %s and %s for suffixes %s" %
                (prefix, this_prefix, ",".join(suffixes_no_stress)))
      prefix = this_prefix
  if prefix is None:
    raise UnrecognizedSuffix("Can't extract prefix from perfect(s) %s, imperfect(s) %s, possible suffixes %s" %
        (",".join(pfs), ",".join(impfs), ",".join(suffixes_no_stress)))

  def process_verb(verb, append_to):
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
        raise ValueError("Can't extract prefix %s from verb %s (suffixes %s)" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    append_to.append(suffix)
    return new_prefix

  first = True

  impf_suffixes = []
  for verb in impfs:
    new_prefix = process_verb(verb, impf_suffixes)
    if new_prefix != prefix:
      if first:
        prefix = new_prefix
      else:
        raise ValueError("Can't extract prefix %s from verb %s for suffixes %s" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    first = False

  pf_suffixes = []
  for verb in pfs:
    new_prefix = process_verb(verb, pf_suffixes)
    if new_prefix != prefix:
      if first:
        prefix = new_prefix
      else:
        raise ValueError("Can't extract prefix %s from verb %s for suffixes %s" %
          (prefix, verb, ",".join(suffixes_no_stress)))
    first = False

  return prefix or ".", pf_suffixes, impf_suffixes, bracketed_verbs

def convert_prefix_and_suffixes_to_full(prefix, pf_suffixes, impf_suffixes, bracketed_suffixes):
  prefix = "" if prefix == "." else prefix
  pfs = combine_prefix(prefix, pf_suffixes, bracketed_suffixes)
  impfs = combine_prefix(rulib.make_unstressed_ru(prefix), impf_suffixes, bracketed_suffixes)
  return "%s %s" % (pfs or "-", impfs or "-")

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
  return [augsuf for suffix in suffixes for augsuf in augment_suffix(suffix)]

def paste_verb(prefix, suffix):
  if rulib.is_stressed(prefix):
    verb = prefix + rulib.make_unstressed_ru(suffix)
  else:
    verb = prefix + suffix
  return rulib.remove_monosyllabic_accents(verb)

def combine_prefix(prefix, suffixes, bracketed_suffixes):
  links = []
  for suffix in suffixes:
    expanded = paste_verb(prefix, suffix)
    if suffix in bracketed_suffixes:
      expanded = "[%s]" % suffix
    links.append(expanded)
  return ",".join(links)

current_pf_suffixes = []
current_impf_suffixes = []
current_bracketed_suffixes = set()

def expand_line(line, linemsg):
  global current_pf_suffixes, current_impf_suffixes, current_bracketed_suffixes
  if line.startswith("suffixes:"):
    return line
  elif re.search("^--+$", line):
    # FIXME
    return False
  elif line == "-":
    return None
  elif " " not in line:
    # A single prefix; combine with previous suffixes.
    return "%s %s" % (
      combine_prefix(line, current_pf_suffixes, current_bracketed_suffixes),
      combine_prefix(rulib.make_unstressed_ru(line), current_impf_suffixes, current_bracketed_suffixes)
    )
  elif "!" in line:
    # Something like "об !" or "+об !" or "! об" or "! +об". This indicates that one of the two is missing and the
    # other should combine with previous suffixes, maybe originally with the aspect included (see лететь.der for
    # good examples of this).
    pf, impf = re.split(r"\s+", line)
    assert pf == "!" or impf == "!"
    if pf == "!":
      return "- %s" % combine_prefix(rulib.make_unstressed_ru(impf), current_impf_suffixes, current_bracketed_suffixes)
    else:
      return "%s -" % combine_prefix(pf, current_pf_suffixes, current_bracketed_suffixes)
  else:
    # Something like "обмени́ть,обменя́ть обме́нивать" or "+переменя́ться -".
    # We directly include the perfective and imperfective verb(s), where
    # a lone "-" means to not include it, and a prefixed "+" means to
    # include the aspect.
    pf, impf = re.split(r"\s+", line)
    if pf.startswith("-") and impf.startswith("-"):
      current_bracketed_suffixes = set()
      current_pf_suffixes = [] if pf == "-" else remove_brackets(
        [re.sub("^-", "", x) for x in re.split(",", pf)], current_bracketed_suffixes
      )
      current_impf_suffixes = [] if impf == "-" else remove_brackets(
        [re.sub("^-", "", x) for x in re.split(",", impf)], current_bracketed_suffixes
      )
      return [current_pf_suffixes, current_impf_suffixes, current_bracketed_suffixes]

    def expand_item(item, suffixes, aspect):
      if item == "-":
        return item
      retval = []
      maybe_prefs = item.split(",")
      for ind, maybe_pref in enumerate(maybe_prefs):
        if not maybe_pref:
          continue
        if maybe_pref.endswith("-"):
          maybe_pref = maybe_pref[:-1]
          if aspect == "impf":
            maybe_pref = rulib.make_unstressed_ru(maybe_pref)
          expanded = paste_verb(maybe_pref, suffixes[ind])
          if suffixes[ind] in current_bracketed_suffixes:
            expanded = "[%s]" % expanded
          retval.append(expanded)
        else:
          retval.append(maybe_pref)
      return ",".join(retval)

    return "%s %s" % (expand_item(pf, current_pf_suffixes, "pf"), expand_item(impf, current_impf_suffixes, "impf"))

for extfn in args.files:
  prefixes_by_suffixes = defaultdict(list)
  bracketed_suffixes = {}
  ordering_of_seen_suffixes = []
  unstressed_suffix_to_suffix = {}
  unrecognized_lines = []
  fn = rulib.recompose(extfn.decode("utf-8"))
  msg("---------------- %s ------------------" % fn)
  suffix_no_stress = re.sub("-.*$", "", re.sub(r"[0-9a-z]*\.der$", "", fn))
  explicit_extra_suffixes = []
  unattached_lines = []

  for pass_ in [0, 1]:
    if pass_ == 1:
      # We try to process lines with previously unrecognized suffixes using the suffixes seen so far.
      extra_suffixes = set()
      for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
        if pf_suffixes:
          for pf_suffix in pf_suffixes.split(","):
            extra_suffixes |= set(augment_suffix(pf_suffix))
        if impf_suffixes:
          for impf_suffix in impf_suffixes.split(","):
            extra_suffixes |= set(augment_suffix(impf_suffix))
      # Put longer suffixes first.
      extra_suffixes = sorted(list(extra_suffixes) + explicit_extra_suffixes, key=lambda x:-len(x))
      items = list(blib.iter_items(unrecognized_lines))
    else:
      extra_suffixes = []
      items = list(blib.iter_items_from_file(extfn, None, None))

    # Formerly we could precede a prefix with + to indicate that the perfective should be marked with its aspect (for
    # cases where the same verb occurred as both perfective and imperfective, as with derivatives of лететь/летать), or
    # write something like "об +" or "+об +", originally indicating that the imperfective (and maybe the perfective)
    # should include the aspect. See лететь.der for good examples. Now handled automatically.
    items = [(lineno, rulib.recompose(line.replace("+", "").strip())) for lineno, line in items]
    new_format = False
    for lineno, line in items:
      if line != "-" and not line.startswith("suffixes:") and (" " not in line or "! " in line or " !" in line):
        # Already in "new" format, pass through unchanged
        new_format = True
        break
    if new_format:
      msg("# File %s: New format; converting to old format and then processing" % fn)
      new_items = []
      for lineno, line in items:
        newline = expand_line(line, lineno)
        if type(newline) is list:
          this_pf_suffixes, this_impf_suffixes, this_bracketed_suffixes = newline
          explicit_extra_suffixes.extend(augment_suffixes(this_pf_suffixes))
          explicit_extra_suffixes.extend(augment_suffixes(this_impf_suffixes))
        elif newline:
          new_items.append((lineno, newline))
      items = new_items

    for lineno, line in items:
      if line.startswith("suffixes:"):
        explicit_extra_suffixes.extend(augment_suffixes(re.sub("^suffixes:", "", line).split(",")))
        continue
      if line == "-":
        continue
      def linemsg(txt):
        msg("# File %s: Line %s: %s" % (fn, lineno, txt))
      try:
        if " " not in line:
          linemsg("WARNING: No space in line: %s" % line)
          msg(line)
        else:
          pfs, impfs = re.split(r"\s+", line)
          pfs = [] if pfs == "-" else pfs.split(",")
          impfs = [] if impfs == "-" else impfs.split(",")
          try:
            prefix, pf_suffixes, impf_suffixes, bracketed_verbs = extract_prefix_and_suffixes(pfs, impfs,
              [suffix_no_stress] + extra_suffixes)
            key = (",".join(pf_suffixes), ",".join(impf_suffixes))
            if key not in prefixes_by_suffixes:
              ordering_of_seen_suffixes.append(key)
              bracketed_suffixes[key] = bracketed_verbs
            elif bracketed_suffixes[key] != bracketed_verbs:
              raise ValueError("For key (%s,%s), saw existing bracketed verbs %s different from new bracketed verbs %s" %
                (key[0], key[1], ",".join(bracketed_suffixes[key]), ",".join(bracketed_verbs)))
            prefixes_by_suffixes[key].append(prefix)
            for pf_suffix in pf_suffixes:
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
          except UnrecognizedSuffix as e:
            if pass_ == 1:
              raise e
            unrecognized_lines.append(line)

      except (ValueError, UnrecognizedSuffix) as e:
        linemsg("WARNING: %s: %s" % (unicode(e), line))
        msg(line)

  # Combine unstressed suffixes with stressed equivalents to handle вы́-, повы́-, etc.
  keys_to_delete = []
  for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
    orig_pf_suffixes = pf_suffixes
    pf_suffixes = pf_suffixes.split(",")
    pf_suffixes = [unstressed_suffix_to_suffix.get(pf_suffix, pf_suffix) for pf_suffix in pf_suffixes]
    pf_suffixes = ",".join(pf_suffixes)
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
    potential_full_suffixes = []
    for (full_pf_suffixes, full_impf_suffixes), full_prefixes in prefixes_by_suffixes.iteritems():
      full_other_aspect_suffixes = full_pf_suffixes if aspect == "impf" else full_impf_suffixes
      if full_other_aspect_suffixes and (
        non_empty_suffixes == (full_impf_suffixes if aspect == "impf" else full_pf_suffixes)
      ):
        potential_full_suffixes.append((full_other_aspect_suffixes, len(full_prefixes)))
    if len(potential_full_suffixes) == 0:
      if len(prefixes) > 1:
        # leave as-is
        return
      for prefix in prefixes:
        split_non_empty_suffixes = non_empty_suffixes.split(",")
        unattached_lines.append(convert_prefix_and_suffixes_to_full(prefix,
          [] if aspect == "impf" else split_non_empty_suffixes,
          split_non_empty_suffixes if aspect == "impf" else [],
          bracketed_suffixes
        ))
    else:
      # If more than one possible set of suffixes, take the set with the smallest number of suffixes
      # and if more than one such, take the set with the largest number of prefixes.
      best_suffixes = sorted(potential_full_suffixes, key=lambda x:(-len(x[0].split(",")), x[1]))[0][0]
      suffix_key = (best_suffixes, non_empty_suffixes) if aspect == "impf" else (non_empty_suffixes, best_suffixes)
      for prefix in prefixes:
        assert suffix_key in prefixes_by_suffixes, "Saw key %s not in prefixes_by_suffixes" % suffix_key
        prefixes_by_suffixes[suffix_key].append("! %s" % prefix if aspect == "impf" else "%s !" % prefix)
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
  for (pf_suffixes, impf_suffixes), prefixes in sorted(prefixes_by_suffixes.iteritems(), key=lambda x: ordering_dict[x[0]]):
    bracketed_verbs = bracketed_suffixes[(pf_suffixes, impf_suffixes)]
    def bracket_suffixes(suffixes):
      suffixes = suffixes.split(",")
      suffixes = [
        "[%s]" % suffix if suffix in bracketed_verbs else suffix
        for suffix in suffixes
      ]
      return ",".join(suffixes)
    pf_suffixes = bracket_suffixes(pf_suffixes)
    impf_suffixes = bracket_suffixes(impf_suffixes)
    msg("-%s -%s" % (pf_suffixes, impf_suffixes))
    for prefix in prefixes:
      msg(prefix)
