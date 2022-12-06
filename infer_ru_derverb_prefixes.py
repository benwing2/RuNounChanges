#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse, unicodedata
from collections import defaultdict

from blib import msg
import blib
import rulib

parser = argparse.ArgumentParser(description="Infer prefixes from derived verb tables without them.")
parser.add_argument('files', nargs='+', help="Files containing directives.")
parser.add_argument('--suffixes', help="Extra suffixes, of the format FILE=SUFFIX,SUFFIX,...;FILE=SUFFIX,SUFFIX,...")
args = parser.parse_args()

AC = u"\u0301"

def remove_stress(term):
  return rulib.remove_accents(term)

class UnrecognizedSuffix(Exception):
  pass

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
        raise ValueError("Can't extract prefix %s from verb %s for suffixes %s" %
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

  return prefix, pf_suffixes, impf_suffixes

def convert_prefix_and_suffixes_to_full(prefix, pf_suffixes, impf_suffixes):
  pfs = [prefix + (remove_stress(pf_suffix) if AC in prefix else pf_suffix) for pf_suffix in pf_suffixes]
  impfs = [remove_stress(prefix) + impf_suffix for impf_suffix in impf_suffixes]
  return "%s %s" % (",".join(pfs) or "-", ",".join(impfs) or "-")

def augment_suffix(suffix):
  retval = []
  retval.append(suffix)
  if suffix.endswith(u"ть") or suffix.endswith(u"чь"):
    retval.append(suffix + u"ся")
  elif suffix.endswith(u"ти"):
    retval.append(suffix + u"сь")
  elif suffix.endswith(u"ся") or suffix.endswith(u"сь"):
    retval.append(suffix[:-2])
  return retval

extra_suffixes_by_file = {}
if args.suffixes:
  for spec in args.suffixes.decode("utf-8").split(";"):
    fn, suffixes = spec.split("=")
    extra_suffixes_by_file[fn] = [augsuf for suffix in suffixes.split(",") for augsuf in augment_suffix(suffix)]

for extfn in args.files:
  prefixes_by_suffixes = defaultdict(list)
  unstressed_suffix_to_suffix = {}
  unrecognized_lines = []
  fn = rulib.recompose(extfn.decode("utf-8"))
  msg("---------------- %s ------------------" % fn)
  suffix_no_stress = re.sub("-.*$", "", re.sub(r"[0-9a-z]*\.der$", "", fn))

  for pass_ in [0, 1]:
    if pass_ == 1:
      # We try to process lines with previously unrecognized suffixes using the suffixes seen so far.
      extra_suffixes = set()
      for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
        if pf_suffixes:
          for pf_suffix in pf_suffixes.split(","):
            extra_suffixes |= set(augment_suffix(remove_stress(pf_suffix)))
        if impf_suffixes:
          for impf_suffix in impf_suffixes.split(","):
            extra_suffixes |= set(augment_suffix(remove_stress(impf_suffix)))
      extra_suffixes = list(extra_suffixes) + extra_suffixes_by_file.get(fn, [])
      items = list(blib.iter_items(unrecognized_lines))
    else:
      extra_suffixes = []
      items = list(blib.iter_items_from_file(extfn, None, None))

    items = [(lineno, rulib.recompose(line)) for lineno, line in items]
    new_format = False
    for lineno, line in items:
      if line != "-" and (" " not in line or "! " in line or " !" in line):
        # Already in "new" format, pass through unchanged
        new_format = True
        break
    if new_format:
      msg("# File %s: Passing through unchanged" % fn)
      for lineno, line in items:
        msg(line)
      pass_ = 1
      continue

    for lineno, line in items:
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
            prefix, pf_suffixes, impf_suffixes = extract_prefix_and_suffixes(pfs, impfs,
              [suffix_no_stress] + extra_suffixes)
            prefixes_by_suffixes[(",".join(pf_suffixes), ",".join(impf_suffixes))].append(prefix)
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
        msg(convert_prefix_and_suffixes_to_full(prefix,
          [] if aspect == "impf" else split_non_empty_suffixes,
          split_non_empty_suffixes if aspect == "impf" else []
        ))
    else:
      # If more than one possible set of suffixes, take the set with the smallest number of suffixes
      # and if more than one such, take the set with the largest number of prefixes.
      best_suffixes = sorted(potential_full_suffixes, key=lambda x:(-len(x[0].split(",")), x[1]))[0][0]
      suffix_key = (best_suffixes, non_empty_suffixes) if aspect == "impf" else (non_empty_suffixes, best_suffixes)
      for prefix in prefixes:
        prefix = prefix or "."
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

  for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
    msg("-%s -%s" % (pf_suffixes, impf_suffixes))
    for prefix in prefixes:
      msg(prefix)
