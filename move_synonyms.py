#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

from collections import defaultdict

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if not args.partial_page:
    retval = blib.find_modifiable_lang_section(text, args.langname, pagemsg)
    if retval is None:
      return
    sections, j, secbody, sectail, has_non_lang = retval
  else:
    sections = [text]
    j = 0
    secbody, sectail = blib.split_trailing_separator_and_categories(text)

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  defn_subsection = None
  for k in xrange(2, len(subsections), 2):
    if "\n#" in subsections[k] and not re.search("=(Etymology|Pronunciation|Usage notes)", subsections[k - 1]):
      defn_subsection = k
      saw_nyms_already = set()
    m = re.search("=(Synonyms|Antonyms)=", subsections[k - 1])
    if m:
      syntype = m.group(1).lower()[:-1]
      if defn_subsection is None:
        pagemsg("WARNING: Encountered %ss section #%s without preceding definition section" % (syntype, k // 2 + 1))
        continue
      if syntype in saw_nyms_already:
          pagemsg("WARNING: Encountered two %s sections without intervening definition section" % syntype)
          continue

      def parse_syns(syns):
        retval = []
        syns = syns.strip()
        orig_syns = syns
        m = re.search("^(.*?)\{\{(?:qualifier|qual|q|i)\|([^{}|=]*)\}\}(.*?)$", syns)
        if m:
          before_text, qualifier, after_text = m.groups()
          syns = before_text + after_text
        else:
          # check for qualifier-like ''(...)''
          m = re.search("^(.*?)''\(([^'{}]*)\)''(.*?)$", syns)
          if m:
            before_text, qualifier, after_text = m.groups()
            syns = before_text + after_text
          else:
            # check for qualifier-like (''...'')
            m = re.search("^(.*?)\(''([^'{}]*)''\)(.*?)$", syns)
            if m:
              before_text, qualifier, after_text = m.groups()
              syns = before_text + after_text
            else:
              qualifier = None
        syns = re.split("(?: *[,;] *| +/ +)", syns.strip())
        if qualifier and len(syns) > 1:
          pagemsg("WARNING: Saw qualifier along with multiple synonyms, not sure how to proceed: <%s>" % orig_syns)
          return None
        for syn in syns:
          orig_syn = syn
          m = re.search(r"^\{\{[lm]\|%s\|([^{}=]*)\|g=([a-z-]+)\}\}$" % re.escape(args.lang), syn)
          if m:
            raw_syn, gender = m.groups()
            syn = "[[%s]]" % raw_syn
          else:
            syn = re.sub(r"\{\{[lm]\|%s\|([^{}=]*)\}\}" % re.escape(args.lang), r"[[\1]]", syn)
            gender = None
          if "{{" in syn or "}}" in syn:
            pagemsg("WARNING: Unmatched braces in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          if "''" in syn:
            pagemsg("WARNING: Italicized text in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          # Strip brackets around entire synonym
          syn = re.sub(r"^\[\[([^\[\]]*)\]\]$", r"\1", syn)
          # If there are brackets around some words but not all, put brackets around the remaining words
          if "[[" in syn:
            split_by_brackets = re.split(r"(\[\[[^\[\]]*\]\])", syn)
            for i in xrange(0, len(split_by_brackets), 2):
              split_by_brackets[i] = re.sub("([^ ]+)", r"[[\1]]", split_by_brackets[i])
            new_syn = "".join(split_by_brackets)
            if new_syn != syn:
              pagemsg("Add brackets to '%s', producing '%s'" % (syn, new_syn))
              syn = new_syn
          retval.append((syn, qualifier, gender))
        return retval

      def find_defns():
        m = re.search(r"\A(.*?)((?:^#[^\n]*\n)+)(.*?)\Z", subsections[defn_subsection], re.M | re.S)
        if not m:
          pagemsg("WARNING: Couldn't find definitions in definition subsection #%s" % (defn_subsection // 2 + 1))
          return None, None, None
        before_defn_text, defn_text, after_defn_text = m.groups()
        if re.search("^##", defn_text, re.M):
          pagemsg("WARNING: Found ## definition in definition subsection #%s, not sure what to do" % (defn_subsection // 2 + 1))
          return None, None, None
        defns = re.split("^(#[^*:].*\n(?:#[*:].*\n)*)", defn_text, 0, re.M)
        for between_index in xrange(0, len(defns), 2):
          if defns[between_index]:
            pagemsg("WARNING: Saw unknown text <%s> between definitions, not sure what to do" % defns[between_index].strip())
            return None, None, None
        defns = [x for i, x in enumerate(defns) if i % 2 == 1]
        return before_defn_text, defns, after_defn_text

      def add_syns_to_defn(syns, defn):
        joined_syns = "|".join("%s%s%s" %
          (syn, "|q%s=%s" % (i + 1, qualifier) if qualifier else "", "|g%s=%s" % (i + 1, gender) if gender else "")
          for i, (syn, qualifier, gender) in enumerate(syns))
        if syntype == "synonym":
          if re.search(r"\{\{(syn|synonyms)\|", defn):
            pagemsg("WARNING: Already saw inline synonyms in definition: <%s>" % defn)
            return None
          return re.sub(r"^(.*\n)", r"\1#: {{syn|%s|%s}}" % (args.lang, joined_syns) + "\n", defn)
        else:
          if re.search(r"\{\{(ant|antonyms)\|", defn):
            pagemsg("WARNING: Already saw inline antonyms in definition: <%s>" % defn)
            return None
          # Need to put antonyms after any inline synonyms
          return re.sub(r"^(.*\n(?:#: *\{\{(?:syn|synonyms)\|.*\n)*)", r"\1#: {{ant|%s|%s}}" %
              (args.lang, joined_syns) + "\n", defn)
        saw_nyms_already.add(syntype)

      # Find definitions
      before_defn_text, defns, after_defn_text = find_defns()
      if before_defn_text is None:
        continue

      def put_back_new_defns(defns, syndesc):
        subsections[defn_subsection] = before_defn_text + "".join(defns) + after_defn_text
        subsections[k - 1] = ""
        subsections[k] = ""
        notes.append("Convert %ss in %s subsection %s to inline %ss in subsection %s based on %s" % (
          syntype, args.langname, k // 2 + 1, syntype, defn_subsection // 2 + 1, syndesc))

      # Pull out all synonyms by number
      unparsable = False
      syns_by_number = defaultdict(list)
      must_continue = False
      for line in subsections[k].split("\n"):
        if not line.strip():
          continue
        # Look for '* (1) {{l|...}}'
        m = re.search(r"^\* *\(([0-9]+)\) *(.*?)$", line)
        if m:
          defnum, syns = m.groups()
        else:
          # Look for '* {{l|...}} (1)'
          m = re.search(r"^\* *(.*?) *\(([0-9]+)\)$", line)
          if m:
            syns, defnum = m.groups()
          else:
            # Look for '* {{sense|1}} {{l|...}}'
            m = re.search(r"^\* *\{\{(?:s|sense)\|([0-9]+)\}\} *(.*?)$", line)
            if m:
              defnum, syns = m.groups()
            else:
              # couldn't parse line
              pagemsg("Couldn't parse %s line for numbers: %s" % (syntype, line))
              unparsable = True
              break

        parsed_syns = parse_syns(syns)
        if parsed_syns is None:
          must_continue = True
          break
        syns_by_number[int(defnum)] += parsed_syns
      if must_continue:
        continue

      if not unparsable:
        # Find definitions
        before_defn_text, defns, after_defn_text = find_defns()
        if before_defn_text is None:
          continue

        # Don't consider definitions with {{reflexive of|...}} in them
        reindexed_defns = {}
        next_index = 1
        for index, defn in enumerate(defns):
          if "{{reflexive of|" in defn:
            continue
          reindexed_defns[next_index] = index
          next_index += 1

        # Make sure synonyms don't refer to nonexistent definition
        max_syn = max(syns_by_number.keys())
        max_defn = max(reindexed_defns.keys())
        if max_syn > max_defn:
          pagemsg("WARNING: Numbered synonyms refer to maximum %s > maximum defn %s" % (max_syn, max_defn))
          continue

        # Add inline synonyms
        must_continue = False
        for synno, syns in syns_by_number.iteritems():
          index = reindexed_defns[synno]
          new_defn = add_syns_to_defn(syns, defns[index])
          if new_defn is None:
            must_continue = True
            break
          defns[index] = new_defn
        if must_continue:
          continue

        # Put back new definition text and clear out synonyms
        put_back_new_defns(defns, "numbered %ss" % syntype)
        continue

      # Try checking for {{sense|...}} or (''...'') indicators
      unparsable = False
      syns_by_tag = {}
      must_continue = False
      for line in subsections[k].split("\n"):
        if not line.strip():
          continue
        m = re.search(r"^\* *\(''([^']*?)''\) *(.*?)$", line)
        if m:
          tag, syns = m.groups()
        else:
          m = re.search(r"^\* *''\(([^']*?)\)'' *(.*?)$", line)
          if m:
            tag, syns = m.groups()
          else:
            m = re.search(r"^\* *\{\{(?:s|sense)\|([^{}|]*?)\}\} *(.*?)$", line)
            if m:
              tag, syns = m.groups()
            else:
              # couldn't parse line
              pagemsg("Couldn't parse %s line for tags: %s" % (syntype, line))
              unparsable = True
              break
        tag = re.sub(r",? +etc\.?$", "", tag)
        parsed_syns = parse_syns(syns)
        if parsed_syns is None:
          must_continue = True
          break
        if tag in syns_by_number:
          pagemsg("WARNING: Saw the same tag '%s' twice" % tag)
          must_continue = True
          break
        syns_by_tag[tag] = parsed_syns
      if must_continue:
        continue

      if not unparsable:
        # Pull out each definition (not including continuations) and remove links
        unlinked_defns = []
        must_continue = False
        for defn in defns:
          m = re.search("^# *(.*)\n", defn)
          if not m:
            pagemsg("WARNING: Something wrong, can't pull out definition from <%s>" % defn)
            must_continue = True
            break
          unlinked_defns.append(blib.remove_links(m.group(1)))
        if must_continue:
          continue

        # Match tags against definitions
        tag_to_defn = {}
        defn_to_tag = {}
        must_continue = False
        for tag in syns_by_tag.keys():
          matching_defn = None
          must_break = False
          for defno, unlinked_defn in enumerate(unlinked_defns):
            if re.search(r"\b%s\b" % re.escape(tag), unlinked_defn):
              if matching_defn is not None:
                pagemsg("WARNING: Matched tag '%s' against both defn <%s> and <%s>" % (
                  tag, unlinked_defns[matching_defn], unlinked_defn))
                must_break = True
                must_continue = True
                break
              matching_defn = defno
          if must_break:
            break
          if matching_defn is None:
            pagemsg("WARNING: Couldn't match tag '%s' against definitions %s" % (
              tag, ", ".join("<%s>" % unlinked_defn for unlinked_defn in unlinked_defns)))
            must_continue = True
            break
          if matching_defn in defn_to_tag:
            pagemsg("WARNING: Matched two tags '%s' and '%s' against the same defn <%s>" % (
              tag, defn_to_tag[matching_defn], unlinked_defns[matching_defn]))
            must_continue = True
            break
          defn_to_tag[matching_defn] = tag
          tag_to_defn[tag] = matching_defn
        if must_continue:
          continue

        # Add inline synonyms
        must_continue = False
        for tag, syns in syns_by_tag.iteritems():
          index = tag_to_defn[tag]
          new_defn = add_syns_to_defn(syns, defns[index])
          if new_defn is None:
            must_continue = True
            break
          defns[index] = new_defn
        if must_continue:
          continue

        # Put back new definition text and clear out synonyms
        put_back_new_defns(defns, "tagged %ss" % syntype)
        continue

      # Add synonyms if only one definition
      if len(defns) == 1:
        unparsable = False
        all_syns = []
        must_continue = False
        for line in subsections[k].split("\n"):
          if not line.strip():
            continue
          m = re.search(r"^\* *(.*?)$", line)
          if m:
            syns = m.group(1)
          else:
            # couldn't parse line
            pagemsg("Couldn't parse %s line when only one definition: %s" % (syntype, line))
            unparsable = True
            break
          parsed_syns = parse_syns(syns)
          if parsed_syns is None:
            must_continue = True
            break
          all_syns.extend(parsed_syns)
        if must_continue:
          continue

        if not unparsable:
          # Add inline synonyms
          new_defn = add_syns_to_defn(all_syns, defns[0])
          if new_defn is None:
            continue
          defns[0] = new_defn

          # Put back new definition text and clear out synonyms
          put_back_new_defns(defns, "%ss with only one definition" % syntype)
          continue

  secbody = "".join(subsections)
  sections[j] = secbody + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert =Synonyms= sections to inline synonyms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--lang", required=True, help="Lang code of language to do.")
parser.add_argument("--langname", required=True, help="Lang name of language to do.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
