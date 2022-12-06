#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re, sys, codecs, argparse, unicodedata
from collections import defaultdict

from blib import msg
import blib

parser = argparse.ArgumentParser(description="Infer prefixes from derived verb tables without them.")
parser.add_argument('files', nargs='+', help="Files containing directives.")
args = parser.parse_args()

AC = u"\u0301"

def remove_accents(term):
  return term.replace(AC, "")

class UnrecognizedSuffix(Exception):
  pass

def extract_prefix_and_suffix(term, suffixes_no_accents):
  num_acs = len([x for x in term if x == AC])
  if num_acs > 1:
    raise ValueError("Saw term with multiple accents: %s" % term)
  for suffix_no_accents in suffixes_no_accents:
    for refl_suffix in ["", u"ся", u"сь"]:
      full_suffix = suffix_no_accents + refl_suffix
      suflen = len(full_suffix)
      if term.endswith(full_suffix):
        return term[0:-suflen], full_suffix
      term_no_accents = remove_accents(term)
      if term_no_accents.endswith(full_suffix):
        return term[0:-(suflen + 1)], term[-(suflen + 1):]
  return None, None

def extract_prefix_and_suffixes(pfs, impfs, suffixes_no_accents):
  all_verbs = pfs + impfs

  prefix = None
  for verb in all_verbs:
    this_prefix, this_suffix = extract_prefix_and_suffix(verb, suffixes_no_accents)
    if this_prefix is not None:
      if prefix is not None:
        if this_prefix != prefix:
          raise ValueError("Saw two different prefixes %s and %s for suffixes %s" %
              (prefix, this_prefix, ",".join(suffixes_no_accents)))
      prefix = this_prefix
  if prefix is None:
    raise UnrecognizedSuffix("Can't extract prefix from perfect(s) %s, imperfect(s) %s" %
        (",".join(pfs), ",".join(impfs)))

  def process_verb(verb, append_to):
    if verb.startswith(prefix):
      suffix = verb[len(prefix):]
    else:
      prefix_no_accents = remove_accents(prefix)
      if verb.startswith(prefix_no_accents):
        suffix = verb[len(prefix_no_accents):]
      else:
        raise ValueError("Can't extract prefix %s from verb %s for suffixes %s" %
          (prefix, verb, ",".join(suffixes_no_accents)))
    append_to.append(suffix)

  pf_suffixes = []
  for verb in pfs:
    process_verb(verb, pf_suffixes)
  impf_suffixes = []
  for verb in impfs:
    process_verb(verb, impf_suffixes)
  return prefix, pf_suffixes, impf_suffixes

def convert_prefix_and_suffixes_to_full(prefix, pf_suffixes, impf_suffixes):
  pfs = [prefix + (remove_accents(pf_suffix) if AC in prefix else pf_suffix) for pf_suffix in pf_suffixes]
  impfs = [remove_accents(prefix) + impf_suffix for impf_suffix in impf_suffixes]
  return "%s %s" % (",".join(pfs) or "-", ",".join(impfs) or "-")

for extfn in args.files:
  prefixes_by_suffixes = defaultdict(list)
  unaccented_suffix_to_suffix = {}
  unrecognized_lines = []
  fn = extfn.decode("utf-8")
  for pass_ in [0, 1]:
    if pass_ == 1:
      # We try to process lines with previously unrecognized suffixes using the suffixes seen so far.
      extra_suffixes = set()
      for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
        if pf_suffixes:
          for pf_suffix in pf_suffixes.split(","):
            extra_suffixes.add(pf_suffix)
        if impf_suffixes:
          for impf_suffix in impf_suffixes.split(","):
            extra_suffixes.add(impf_suffix)
      extra_suffixes = list(extra_suffixes)
      items = blib.iter_items(unrecognized_lines)
    else:
      extra_suffixes = []
      items = blib.iter_items_from_file(extfn, None, None)
    for lineno, line in items:
      suffix_no_accents = re.sub(r"\.der$", "", fn)
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
              [suffix_no_accents] + extra_suffixes)
            prefixes_by_suffixes[(",".join(pf_suffixes), ",".join(impf_suffixes))].append(prefix)
            for pf_suffix in pf_suffixes:
              if AC in pf_suffix:
                unaccented_pf_suffix = remove_accents(pf_suffix)
                if (
                  unaccented_pf_suffix in unaccented_suffix_to_suffix and
                  unaccented_suffix_to_suffix[unaccented_pf_suffix] != pf_suffix
                ):
                  raise ValueError("Unaccented perfective suffix %s maps to two different accented suffixes %s and %s" %
                    (unaccented_pf_suffix, unaccented_suffix_to_suffix[unaccented_pf_suffix], pf_suffix))
                unaccented_suffix_to_suffix[unaccented_pf_suffix] = pf_suffix
          except UnrecognizedSuffix as e:
            if pass_ == 1:
              raise e
            unrecognized_lines.append(line)

      except (ValueError, UnrecognizedSuffix) as e:
        linemsg("WARNING: %s" % unicode(e))

  # Combine unaccented suffixes with accented equivalents to handle вы́-, повы́-, etc.
  keys_to_delete = []
  for (pf_suffixes, impf_suffixes), prefixes in prefixes_by_suffixes.iteritems():
    orig_pf_suffixes = pf_suffixes
    pf_suffixes = pf_suffixes.split(",")
    pf_suffixes = [unaccented_suffix_to_suffix.get(pf_suffix, pf_suffix) for pf_suffix in pf_suffixes]
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
