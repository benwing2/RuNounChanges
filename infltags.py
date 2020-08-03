#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json

from blib import site

semicolon_tags = [';', ';<!--\n-->']

# FIXME, generate this automatically.
multipart_list_tag_to_parts = {
  "1s": ["1", "s"],
  "2s": ["2", "s"],
  "3s": ["3", "s"],
  "1d": ["1", "d"],
  "2d": ["2", "d"],
  "3d": ["3", "d"],
  "1p": ["1", "p"],
  "2p": ["2", "p"],
  "3p": ["3", "p"],
  "mf": ["m//f"],
  "mn": ["m//n"],
  "fn": ["f//n"],
  "mfn": ["m//f//n"],
}

# Split tags into tag sets.
def split_tags_into_tag_sets(tags):
  tag_set_group = []
  cur_tag_set = []
  for tag in tags:
    if tag in semicolon_tags:
      if cur_tag_set:
        tag_set_group.append(cur_tag_set)
      cur_tag_set = []
    else:
      cur_tag_set.append(tag)
  if cur_tag_set:
    tag_set_group.append(cur_tag_set)
  return tag_set_group

def combine_tag_set_group(group):
  result = []
  for tag_set in group:
    if result:
      result.append(";")
    result.extend(tag_set)
  return result

# Fetch and return two sorts of tables from Wiktionary form data:
# (1) tag_to_dimension_table: Mapping from tags to dimensions. Only tags in
#     the same dimension can be combined into a multipart tag.
# (2) tag_to_canonical_form_table: Mapping from tags to canonical tags, e.g.
#     form 'pasv' to 'pass'. `preferred_tag_variants` is used in computing this:
#     it is a set of preferred tag variants when more than one exist. If a
#     variant exists in this set, all other variants will be mapped to this one.
#     Otherwise, they will be mapped to the first listed shortcut.
#     NOTE: Currently this table is used in combine_adjacent_tags_into_multipart
#     to compare tags but not to convert all tags to their canonical form.
# These tables should be passed to combine_adjacent_tags_into_multipart().
def fetch_tag_tables(preferred_tag_variants=set()):
  jsonstr = site.expand_text(u"{{#invoke:User:Benwing2/form of|dump_form_of_data}}")
  jsondata = json.loads(jsonstr)
  tag_to_dimension_table = {}
  tag_to_canonical_form_table = {}
  def process_data(data):
    for tag, tagdata in data["tags"].iteritems():
      if "tag_type" in tagdata:
        tag_to_dimension_table[tag] = tagdata["tag_type"]
      if "shortcuts" in tagdata and len(tagdata["shortcuts"]) > 0:
        canon_variant = tagdata["shortcuts"][0]
        all_variants = set(tagdata["shortcuts"] + [tag])
        for variant in all_variants:
          if variant in preferred_tag_variants:
            canon_variant = variant
            break
        all_variants -= {canon_variant}
        for variant in all_variants:
          tag_to_canonical_form_table[variant] = canon_variant

    for shortcut, tag in data["shortcuts"].iteritems():
      # shortcuts contain entries like "mfn" -> "m//f//n" and "2p" -> ["2", "p"]
      if isinstance(tag, basestring) and tag in data["tags"]:
        tag_to_dimension_table[shortcut] = data["tags"][tag]["tag_type"]

  process_data(jsondata["data"])
  process_data(jsondata["data2"])
  return tag_to_dimension_table, tag_to_canonical_form_table

# When multiple tag sets separated by semicolon, combine adjacent
# ones that differ in only one tag in a given dimension. Repeat this
# until no changes in case we can reduce along multiple dimensions, e.g.
#
# {{inflection of|canus||dat|m|p|;|dat|f|p|;|dat|n|p|;|abl|m|p|;|abl|f|p|;|abl|n|p|lang=la}}
#
# which can be reduced to
#
# {{inflection of|la|canus||dat//abl|m//f//n|p}}
def combine_adjacent_tags_into_multipart(tags, tag_to_dimension_table,
  pagemsg, warn, multipart_list_tag_to_parts=multipart_list_tag_to_parts,
  tag_to_canonical_form_table={},
):
  notes = []
  origtags = tags
  while True:
    # First, canonicalize 1s etc. into 1|s
    canonicalized_tags = []
    for tag in tags:
      if tag in multipart_list_tag_to_parts:
        canonicalized_tags.extend(multipart_list_tag_to_parts[tag])
      else:
        canonicalized_tags.append(tag)

    old_canonicalized_tags = canonicalized_tags

    # Then split into tag sets.
    tag_set_group = split_tags_into_tag_sets(canonicalized_tags)

    # Try combining in two different styles ("adjacent-first" =
    # do two passes, where the first pass only combines adjacent
    # tag sets, while the second pass combines nonadjacent tag sets;
    # "all-first" = do one pass combining nonadjacent tag sets).
    # Sometimes one is better, sometimes the other.
    #
    # An example where adjacent-first is better:
    #
    # {{inflection of|medius||m|acc|s|;|n|nom|s|;|n|acc|s|;|n|voc|s|lang=la}}
    #
    # all-first results in
    #
    # {{inflection of|la|medius||m//n|acc|s|;|n|nom//voc|s}}
    #
    # which isn't ideal.
    #
    # If we do adjacent-first, we get
    #
    # {{inflection of|la|medius||m|acc|s|;|n|nom//acc//voc|s}}
    #
    # which is much better.
    #
    # The opposite happens in
    #
    # {{inflection of|βουλόμενος||n|nom|s|;|m|acc|s|;|n|acc|s|;|n|voc|s|lang=grc}}
    #
    # where all-first results in
    #
    # {{inflection of|grc|βουλόμενος||n|nom//acc//voc|s|;|m|acc|s}}
    #
    # which is better than the result from adjacent-first, which is
    #
    # {{inflection of|grc|βουλόμενος||n|nom//voc|s|;|m//n|acc|s}}
    #
    # To handle this conundrum, we try both, and look to see which one
    # results in fewer "combinations" (where a tag with // in it counts
    # as a combination). If both are different but have the same # of
    # combinations, we prefer adjacent-first, we seems generally a better
    # approach.

    tag_set_group_by_style = {}
    notes_by_style = {}

    # Split a possibly multipart tag into the components and
    # canonicalize them.
    def split_and_canonicalize_tag(tag):
      return [tag_to_canonical_form_table.get(tg, tg) for tg in tag.split("//")]

    for combine_style in ["adjacent-first", "all-first"]:
      # Now, we do two passes. The first pass only combines adjacent
      # tag sets, while the second pass combines nonadjacent tag sets.
      # Copy tag_set_group, since we destructively modify the list.
      tag_sets = list(tag_set_group)
      this_notes = []
      if combine_style == "adjacent-first":
        combine_passes = ["adjacent", "all"]
      else:
        combine_passes = ["all"]
      for combine_pass in combine_passes:
        tag_ind = 0
        while tag_ind < len(tag_sets):
          if combine_pass == "adjacent":
            if tag_ind == 0:
              prev_tag_range = []
            else:
              prev_tag_range = [tag_ind - 1]
          else:
            prev_tag_range = range(tag_ind)
          for prev_tag_ind in prev_tag_range:
            cur_tag_set = tag_sets[prev_tag_ind]
            tag_set = tag_sets[tag_ind]
            if len(cur_tag_set) == len(tag_set):
              mismatch_ind = None
              for i, (tag1, tag2) in enumerate(zip(cur_tag_set, tag_set)):
                tag1 = split_and_canonicalize_tag(tag1)
                tag2 = split_and_canonicalize_tag(tag2)
                if set(tag1) == set(tag2):
                  continue
                if mismatch_ind is not None:
                  break
                dims1 = [tag_to_dimension_table.get(tag, "unknown") for tag in tag1]
                dims2 = [tag_to_dimension_table.get(tag, "unknown") for tag in tag2]
                unique_dims = set(dims1 + dims2)
                if len(unique_dims) == 1 and unique_dims != {"unknown"}:
                  mismatch_ind = i
                else:
                  break
              else:
                # No break, we either match perfectly or are combinable
                if mismatch_ind is None:
                  warn("Two identical tag sets: %s and %s in %s" % (
                    "|".join(cur_tag_set), "|".join(tag_set), "|".join(origtags)
                  ))
                  del tag_sets[tag_ind]
                  break
                else:
                  tag1 = cur_tag_set[mismatch_ind]
                  tag2 = tag_set[mismatch_ind]
                  tag1 = split_and_canonicalize_tag(tag1)
                  tag2 = split_and_canonicalize_tag(tag2)
                  combined_tag = "//".join(tag1 + tag2)
                  new_tag_set = []
                  for i in xrange(len(cur_tag_set)):
                    if i == mismatch_ind:
                      new_tag_set.append(combined_tag)
                    else:
                      cur_canon_tag = split_and_canonicalize_tag(cur_tag_set[i])
                      canon_tag = split_and_canonicalize_tag(tag_set[i])
                      assert set(cur_canon_tag) == set(canon_tag)
                      new_tag_set.append(cur_tag_set[i])
                  combine_msg = "tag sets %s and %s into %s" % (
                    "|".join(cur_tag_set), "|".join(tag_set), "|".join(new_tag_set)
                  )
                  pagemsg("Combining %s" % combine_msg)
                  this_notes.append("combined %s" % combine_msg)
                  tag_sets[prev_tag_ind] = new_tag_set
                  del tag_sets[tag_ind]
                  break
          else:
            # No break from inner for-loop. Break from that loop indicates
            # that we found that the current tag set can be combined with
            # a preceding tag set, did the combination and deleted the
            # current tag set. The next iteration then processes the same
            # numbered tag set again (which is actually the following tag
            # set, because we deleted the tag set before it). No break
            # indicates that we couldn't combine the current tag set with
            # any preceding tag set, and need to advance to the next one.
            tag_ind += 1
      tag_set_group_by_style[combine_style] = tag_sets
      notes_by_style[combine_style] = this_notes

    if tag_set_group_by_style["adjacent-first"] != tag_set_group_by_style["all-first"]:
      def num_combinations(group):
        num_combos = 0
        for tag_set in group:
          for tag in tag_set:
            if "//" in tag:
              num_combos += 1
        return num_combos
      def join_tag_set_group(group):
        return "|".join(combine_tag_set_group(group))

      num_adjacent_first_combos = num_combinations(tag_set_group_by_style["adjacent-first"])
      num_all_first_combos = num_combinations(tag_set_group_by_style["all-first"])
      if num_adjacent_first_combos < num_all_first_combos:
        pagemsg("Preferring adjacent-first result %s (%s combinations) to all-first result %s (%s combinations)" % (
          join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
          num_adjacent_first_combos,
          join_tag_set_group(tag_set_group_by_style["all-first"]),
          num_all_first_combos
        ))
        tag_set_group = tag_set_group_by_style["adjacent-first"]
        notes.extend(notes_by_style["adjacent-first"])
      elif num_all_first_combos < num_adjacent_first_combos:
        pagemsg("Preferring all-first result %s (%s combinations) to adjacent-first result %s (%s combinations)" % (
          join_tag_set_group(tag_set_group_by_style["all-first"]),
          num_all_first_combos,
          join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
          num_adjacent_first_combos
        ))
        tag_set_group = tag_set_group_by_style["all-first"]
        notes.extend(notes_by_style["all-first"])
      else:
        pagemsg("Adjacent-first and all-first combination style different but same #combinations %s, preferring adjacent-first result %s to all-first result %s" % (
          num_adjacent_first_combos,
          join_tag_set_group(tag_set_group_by_style["adjacent-first"]),
          join_tag_set_group(tag_set_group_by_style["all-first"])
        ))
        tag_set_group = tag_set_group_by_style["adjacent-first"]
        notes.extend(notes_by_style["adjacent-first"])
    else:
      # Both are the same, pick either one
      tag_set_group = tag_set_group_by_style["adjacent-first"]
      notes.extend(notes_by_style["adjacent-first"])

    canonicalized_tags = []
    for tag_set in tag_set_group:
      if canonicalized_tags:
        canonicalized_tags.append(";")
      canonicalized_tags.extend(tag_set)
    if canonicalized_tags == old_canonicalized_tags:
      break
    # FIXME, we should consider reversing the transformation 1s -> 1|s,
    # but it's complicated to figure out when the transformation occurred;
    # not really important as both are equivalent
    tags = canonicalized_tags

  return tags, notes
