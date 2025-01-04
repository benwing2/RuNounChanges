#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

from collections import defaultdict

def rsub_repeatedly(fr, to, text):
  while True:
    new_text = re.sub(fr, to, text)
    if new_text == text:
      return new_text
    text = new_text

def get_subsection_level(subsection_text):
  return len(re.sub("[^=].*", "", subsection_text.strip()))

def process_text_on_page(pageindex, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageindex, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  lemma_defn_subsection = None
  non_lemma_defn_subsection = None
  num_defn_subsections_seen = 0
  for k in range(2, len(subsections), 2):
    if re.search("=Etymology", subsections[k - 1]):
      lemma_defn_subsection = None
      non_lemma_defn_subsection = None
      num_defn_subsections_seen = 0
    if "\n#" in subsections[k] and not re.search("=(Etymology|Pronunciation|Usage notes)", subsections[k - 1]):
      lines = subsections[k].strip().split("\n")
      for lineind, line in enumerate(lines):
        if re.search(r"\{\{(head\|[^{}]*|[a-z][a-z][a-z]?-[^{}|]*)forms?\b", line):
          pagemsg("Saw potential lemma section #%s %s but appears to be a non-lemma form due to line #%s, not counting as lemma: %s" %
              (k // 2 + 1, subsections[k - 1].strip(), lineind + 1, line))
          non_lemma_defn_subsection = k
          break
      else: # no break
        lemma_defn_subsection = k
        num_defn_subsections_seen += 1
      defn_subsection_level = get_subsection_level(subsections[k - 1])
      saw_nyms_already = set()
    m = re.search("=(Synonyms|Antonyms)=", subsections[k - 1])
    if m:
      syntype = m.group(1).lower()[:-1]
      if lemma_defn_subsection is None and non_lemma_defn_subsection is None:
        pagemsg("WARNING: Encountered %ss section #%s without preceding definition section" % (syntype, k // 2 + 1))
        continue
      synant_subsection_level = get_subsection_level(subsections[k - 1])
      if num_defn_subsections_seen > 1 and synant_subsection_level <= defn_subsection_level:
        pagemsg("WARNING: Saw %s definition sections followed by %s section #%s at same level or higher, skipping section" % (
          num_defn_subsections_seen, syntype, k // 2 + 1))
        continue
      if syntype in saw_nyms_already:
          pagemsg("WARNING: Encountered two %s sections without intervening definition section" % syntype)
          continue
      prev_num_defn_subsections_seen = num_defn_subsections_seen
      num_defn_subsections_seen = 0
      # Prefer the last lemma definition subsection, if any, over a subsequent non-lemma definition subsection.
      defn_subsection = lemma_defn_subsection or non_lemma_defn_subsection

      def parse_syns(syns):
        retval = []
        syns = syns.strip()
        orig_syns = syns
        qualifier = None
        while True:
          # check for qualifiers specified using a qualifier template
          m = re.search(r"^(.*?)\{\{(?:qualifier|qual|q|i)\|([^{}|=]*)\}\}(.*?)$", syns)
          if m:
            before_text, qualifier, after_text = m.groups()
            syns = before_text + after_text
            break
          # check for qualifiers using e.g. {{lb|ru|...}}
          m = re.search(r"^(.*?)\{\{(?:lb)\|%s\|([^{}=]*)\}\}(.*?)$" % re.escape(args.langcode), syns)
          if m:
            before_text, qualifier, after_text = m.groups()
            # do this before handling often/sometimes/etc. in case the label has often|_|pejorative or similar
            qualifier = qualifier.replace("|_|", " ")
            terms_no_following_comma = ["also", "and", "or", "by", "with", "except", "outside", "in",
                "chiefly", "mainly", "mostly", "primarily", "especially", "particularly", "excluding",
                "extremely", "frequently", "humorously", "including", "many", "markedly", "mildly",
                "now", "occasionally", "of", "often", "sometimes", "originally", "possibly", "rarely",
                "slightly", "somewhat", "strongly", "then", "typically", "usually", "very"]
            qualifier = re.sub(r"\b(%s)\|" % "|".join(terms_no_following_comma), r"\1 ", qualifier)
            qualifier = qualifier.replace("|", ", ")
            syns = before_text + after_text
            break
          # check for qualifier-like ''(...)''
          m = re.search(r"^(.*?)''\(([^'{}]*)\)''(.*?)$", syns)
          if m:
            before_text, qualifier, after_text = m.groups()
            syns = before_text + after_text
            break
          # check for qualifier-like (''...'')
          m = re.search(r"^(.*?)\(''([^'{}]*)''\)(.*?)$", syns)
          if m:
            before_text, qualifier, after_text = m.groups()
            syns = before_text + after_text
            break
          break

        # Split on commas, semicolons, slashes but don't split commas etc. inside of braces or brackets
        split_by_brackets_braces = re.split(r"(\{\{[^{}]*\}\}|\[\[[^\[\]]*\]\])", syns.strip())
        comma_separated_runs = blib.split_alternating_runs(split_by_brackets_braces, "(?: *[,;] *| +/ +)")
        syns = ["".join(comma_separated_run) for comma_separated_run in comma_separated_runs]

        if qualifier and len(syns) > 1:
          pagemsg("WARNING: Saw qualifier along with multiple synonyms, not sure how to proceed: <%s>" % orig_syns)
          return None
        joiner_after = ";" if qualifier or len(syns) > 1 else ","
        for synindex, syn in enumerate(syns):
          orig_syn = syn
          m = re.search(r"^\{\{[lm]\|%s\|([^{}]*)\}\}$" % re.escape(args.langcode), syn)
          if m:
            decl = blib.parse_text(syn).filter_templates()[0]
            gender = None
            translit = None
            raw_syn = None
            alt = None
            gloss = None
            lit = None
            pos = None
            for param in decl.params:
              pn = pname(param)
              pv = str(param.value)
              if pn in ["1"]:
                pass
              elif pn == "2":
                raw_syn = pv
              elif pn == "3":
                alt = pv
              elif pn in ["4", "t", "gloss"]:
                gloss = pv
              elif pn == "g":
                gender = pv
              elif pn in ["g2", "g3", "g4"]:
                if not gender:
                  pagemsg("WARNING: Saw %s=%s without g= in %s <%s> in line: %s" % (pn, pv, syntype, orig_syn, line))
                  return None
                gender += "," + pv
              elif pn == "tr":
                translit = pv
              elif pn == "lit":
                lit = pv
              elif pn == "pos":
                pos = pv
              else:
                pagemsg("WARNING: Unrecognized param %s=%s in %s <%s> in line: %s" % (pn, pv, syntype, orig_syn, line))
                return None
            if not raw_syn:
              pagemsg("WARNING: Couldn't find raw synonym in %s <%s> in line: %s" % (syntype, orig_syn, line))
              return None
            if raw_syn and alt:
              if "[[" in raw_syn or "[[" in alt:
                pagemsg("WARNING: Saw both synonym=%s and alt=%s with brackets in one or both in %s <%s> in line: %s"
                    % (raw_syn, alt, syntype, orig_syn, line))
                return None
              syn = "[[%s|%s]]" % (raw_syn, alt)
            elif raw_syn:
              if "[[" in raw_syn:
                syn = raw_syn
              else:
                syn = "[[%s]]" % raw_syn
            elif alt:
              pagemsg("WARNING: Saw alt=%s but no link text in %s <%s> in line: %s" % (alt, syntype, orig_syn, line))
              return
          else:
            def add_brackets_if_not_already(m):
              raw_syn = m.group(1)
              if "[[" not in raw_syn:
                raw_syn = "[[%s]]" % raw_syn
              return raw_syn
            syn = re.sub(r"\{\{[lm]\|%s\|([^{}=]*)\}\}" % re.escape(args.langcode), add_brackets_if_not_already, syn)
            gender = None
            translit = None
            gloss = None
            lit = None
            pos = None
          if "{{" in syn or "}}" in syn:
            pagemsg("WARNING: Unmatched braces in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          if "''" in syn:
            pagemsg("WARNING: Italicized text in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          if "(" in syn or ")" in syn:
            pagemsg("WARNING: Unmatched parens in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          if ":" in syn:
            pagemsg("WARNING: Unmatched colon in %s <%s> in line: %s" % (syntype, orig_syn, line))
            return None
          # Strip brackets around entire synonym
          syn = re.sub(r"^\[\[([^\[\]|{}]*)\]\]$", r"\1", syn)
          # If there are brackets around some words but not all, put brackets around the remaining words
          if "[[" in syn:
            split_by_brackets = re.split(r"([^ ]*\[\[[^\[\]]*\]\][^ ]*)", syn)
            def maybe_add_brackets(m):
              text = m.group(1)
              if "[" in text or "]" in text:
                pagemsg("WARNING: Saw nested brackets in %s in %s <%s> in line: %s" % (
                  text, syntype, orig_syn, line))
                return text
              if not re.search(r"\w", text, re.U):
                pagemsg("Not adding brackets around '%s', saw no letters in %s <%s> in line: %s"
                    % (text, syntype, orig_syn, line))
                return text
              return "[[%s]]" % text
            # Put brackets around the remainin words not already bracketed or partially bracketed. But don't put
            # brackets around words inside of HTML comments, and don't include punctuation inside the brackets.
            for i in range(0, len(split_by_brackets), 2):
              split_out_comments = re.split("(<!--.*?-->)", split_by_brackets[i])
              for j in range(0, len(split_out_comments), 2):
                split_out_comments[j] = re.sub("([^ ,*/{}:;()?!+<>]+)", maybe_add_brackets, split_out_comments[j])
              split_by_brackets[i] = "".join(split_out_comments)

            new_syn = "".join(split_by_brackets)
            if new_syn != syn:
              pagemsg("Add brackets to '%s', producing '%s'" % (syn, new_syn))
              syn = new_syn
          other_params = [
            ("tr", translit),
            ("t", gloss),
            ("q", qualifier),
            ("g", gender),
            ("pos", pos),
            ("lit", lit),
          ]
          # Set the joiner_after to None for everything but the last synonym on the row; we will then change
          # all commas to semicolons if there is any semicolon, so we are consistently using commas or
          # semicolons to separate groups of synonyms.
          retval.append((syn, other_params, joiner_after if synindex == len(syns) - 1 else None))
        return retval

      def find_defns():
        m = re.search(r"\A(.*?)((?:^#[^\n]*\n)+)(.*?)\Z", subsections[defn_subsection], re.M | re.S)
        if not m:
          pagemsg("WARNING: Couldn't find definitions in definition subsection #%s" % (defn_subsection // 2 + 1))
          return None, None, None
        before_defn_text, defn_text, after_defn_text = m.groups()
        if re.search("^#", before_defn_text, re.M) or re.search("^#", after_defn_text, re.M):
          pagemsg("WARNING: Saw definitions in before or after text in definition subsection #%s, not sure what to do" %
              (defn_subsection // 2 + 1))
          return None, None, None
        if re.search("^##", defn_text, re.M):
          pagemsg("WARNING: Found ## definition in definition subsection #%s, not sure what to do" % (defn_subsection // 2 + 1))
          return None, None, None
        defns = re.split("^(#[^*:].*\n(?:#[*:].*\n)*)", defn_text, 0, re.M)
        for between_index in range(0, len(defns), 2):
          if defns[between_index]:
            pagemsg("WARNING: Saw unknown text <%s> between definitions, not sure what to do" % defns[between_index].strip())
            return None, None, None
        defns = [x for i, x in enumerate(defns) if i % 2 == 1]
        return before_defn_text, defns, after_defn_text

      def add_syns_to_defn(syns, defn, add_fixme):
        for syn, other_params, joiner_after in syns:
          if not syn and joiner_after is not None:
            pagemsg("WARNING: Would remove last synonym from a group: %s" %
              ",".join(syn for syn, other_params, joiner_after in syns))
            return None
        syns = [(syn, other_params, joiner_after) for syn, other_params, joiner_after in syns if syn]
        if len(syns) == 0:
          return defn
        any_semicolon = any(joiner_after == ";" for sy, other_params, joiner_after in syns)
        if any_semicolon:
          syns = [(syn, other_params, ";" if joiner_after is not None and any_semicolon else joiner_after)
              for syn, other_params, joiner_after in syns]
        saw_nyms_already.add(syntype)
        joined_syns = "|".join("%s%s%s" %
          (syn, "".join("<%s:%s>" % (param, val) if val else "" for param, val in other_params),
            "|" + joiner_after if i < len(syns) - 1 and joiner_after is not None and joiner_after != "," else "")
          for i, (syn, other_params, joiner_after) in enumerate(syns))
        fixme_msg = " FIXME" if add_fixme else ""
        if syntype == "synonym":
          if re.search(r"\{\{(syn|synonyms)\|", defn):
            pagemsg("WARNING: Already saw inline synonyms in definition: <%s>" % defn)
            return None
          return re.sub(r"^(.*\n)", r"\1#: {{syn|%s|%s}}%s" % (args.langcode, joined_syns, fixme_msg) + "\n", defn)
        else:
          if re.search(r"\{\{(ant|antonyms)\|", defn):
            pagemsg("WARNING: Already saw inline antonyms in definition: <%s>" % defn)
            return None
          # Need to put antonyms after any inline synonyms
          return re.sub(r"^(.*\n(?:#: *\{\{(?:syn|synonyms)\|.*\n)*)", r"\1#: {{ant|%s|%s}}%s" %
              (args.langcode, joined_syns, fixme_msg) + "\n", defn)

      # Find definitions
      before_defn_text, defns, after_defn_text = find_defns()
      if before_defn_text is None:
        continue

      def put_back_new_defns(defns, syndesc, skipped_a_line, lines, skipped_linenos):
        subsections[defn_subsection] = before_defn_text + "".join(defns) + after_defn_text
        if skipped_a_line:
          skipped_linenos = sorted(skipped_linenos)
          skipped_lines = [lines[lineno] for lineno in skipped_linenos]
          subsections[k] = "\n".join(skipped_lines)
        else:
          subsections[k - 1] = ""
          subsections[k] = ""
        notes.append("convert %ss in %s subsection %s to inline %ss in subsection %s based on %s" % (
          syntype, args.langname, k // 2 + 1, syntype, defn_subsection // 2 + 1, syndesc))

      # Pull out all synonyms by number
      unparsable = False
      syns_by_number = defaultdict(list)
      skipped_lines = []
      skipped_a_line = False
      lines = subsections[k].split("\n")
      for lineno, line in enumerate(lines):
        if not line.strip():
          skipped_lines.append(lineno)
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
            m = re.search(r"^\* *\{\{(?:s|sense|as|antsense)\|([0-9]+)\}\} *(.*?)$", line)
            if m:
              defnum, syns = m.groups()
            else:
              # couldn't parse line
              pagemsg("Couldn't parse %s line for numbers: %s" % (syntype, line))
              unparsable = True
              break

        parsed_syns = parse_syns(syns)
        if parsed_syns is None:
          skipped_a_line = True
          skipped_lines.append(lineno)
        else:
          syns_by_number[int(defnum)] += parsed_syns

      if not unparsable and len(syns_by_number) > 0:
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
        for synno, syns in syns_by_number.items():
          index = reindexed_defns[synno]
          new_defn = add_syns_to_defn(syns, defns[index], False)
          if new_defn is None:
            must_continue = True
            break
          defns[index] = new_defn
        if must_continue:
          continue

        # Put back new definition text and clear out synonyms
        put_back_new_defns(defns, "numbered %ss" % syntype, skipped_a_line, lines, skipped_lines)
        continue

      # Try checking for {{sense|...}} or (''...'') indicators
      unparsable = False
      syns_by_tag = {}
      skipped_lines = []
      skipped_a_line = False
      must_continue = False
      lines = subsections[k].split("\n")
      for lineno, line in enumerate(lines):
        if not line.strip():
          skipped_lines.append(lineno)
          continue
        m = re.search(r"^\* *\(''([^']*?)''\):? *(.*?)$", line)
        if m:
          tag, syns = m.groups()
        else:
          m = re.search(r"^\* *''\(([^']*?)\):?'':? *(.*?)$", line)
          if m:
            tag, syns = m.groups()
          else:
            m = re.search(r"^\* *\{\{(?:s|sense|as|antsense)\|([^{}|]*?)\}\} *(.*?)$", line)
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
          skipped_a_line = True
          skipped_lines.append(lineno)
        else:
          if tag in syns_by_number:
            pagemsg("WARNING: Saw the same tag '%s' twice" % tag)
            must_continue = True
            break
          syns_by_tag[tag] = (parsed_syns, lineno)
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
        bad = False
        for tag in syns_by_tag.keys():
          matching_defn = None
          must_break = False
          for defno, unlinked_defn in enumerate(unlinked_defns):
            tag_re = r"\b" + re.sub(r"[ ,.*/{}:;()?!\[\]+]+", r"\\b.*\\b", tag) + r"\b"
            if re.search(tag_re, unlinked_defn):
              if matching_defn is not None:
                pagemsg("WARNING: Matched tag '%s' against both defn <%s> and <%s>" % (
                  tag, unlinked_defns[matching_defn], unlinked_defn))
                if args.do_your_best:
                  bad = True
                else:
                  must_break = True
                  must_continue = True
                  break
              else:
                matching_defn = defno
          if must_break:
            break
          if not bad and matching_defn is None:
            pagemsg("WARNING: Couldn't match tag '%s' against definitions %s" % (
              tag, ", ".join("<%s>" % unlinked_defn for unlinked_defn in unlinked_defns)))
            if args.do_your_best:
              bad = True
            else:
              must_continue = True
              break
          if not bad and matching_defn in defn_to_tag:
            pagemsg("WARNING: Matched two tags '%s' and '%s' against the same defn <%s>" % (
              tag, defn_to_tag[matching_defn], unlinked_defns[matching_defn]))
            if args.do_your_best:
              bad = True
            else:
              must_continue = True
              break
          if not bad:
            defn_to_tag[matching_defn] = tag
            tag_to_defn[tag] = matching_defn
        if must_continue:
          continue

        # Add inline synonyms
        must_continue = False
        for tag, (syns, lineno) in syns_by_tag.items():
          if tag in tag_to_defn:
            index = tag_to_defn[tag]
            new_defn = add_syns_to_defn(syns, defns[index], bad)
            if new_defn is None:
              must_continue = True
              break
            defns[index] = new_defn
          else:
            skipped_a_line = True
            skipped_lines.append(lineno)
        if must_continue:
          continue

        # Put back new definition text and clear out synonyms
        put_back_new_defns(defns, "tagged %ss" % syntype, skipped_a_line, lines, skipped_lines)
        continue

      # Add synonyms if only one definition or --do-your-best
      if prev_num_defn_subsections_seen > 1:
        pagemsg("WARNING: Saw %s definition sections followed by %s section #%s and didn't match by sense tags, can't add" % (
          prev_num_defn_subsections_seen, syntype, k // 2 + 1))
        continue
      if len(defns) > 1:
        pagemsg("WARNING: Saw %s subsection %s with %s definitions and don't know where to add, %s" % (
          syntype, k // 2 + 1, len(defns), "adding to first definition" if args.do_your_best else "can't add"))
      if len(defns) == 1 or args.do_your_best:
        unparsable = False
        all_syns = []
        syns_by_tag = {}
        skipped_lines = []
        skipped_a_line = False
        lines = subsections[k].split("\n")
        total_syns = 0
        for lineno, line in enumerate(lines):
          if not line.strip():
            skipped_lines.append(lineno)
            continue
          m = re.search(r"^\* *(.*?)$", line)
          if m:
            syns = m.group(1)
          else:
            # couldn't parse line
            pagemsg("WARNING: Couldn't parse %s line in last stage: %s" % (syntype, line))
            unparsable = True
            break
          parsed_syns = parse_syns(syns)
          if parsed_syns is None:
            skipped_a_line = True
            skipped_lines.append(lineno)
          else:
            all_syns.append((lineno, total_syns, parsed_syns))
          total_syns += 1

        if not unparsable:
          changed = False
          if total_syns > 1 and len(defns) == total_syns:
            # only happens when --do-your-best
            pagemsg("Saw %s definitions and %s synonym lines, matching definitions and synonym lines" % (
              len(defns), total_syns))
            for lineno, synno, parsed_syns in all_syns:
              # Add inline synonyms
              new_defn = add_syns_to_defn(parsed_syns, defns[synno], True)
              if new_defn is None:
                pagemsg("WARNING: Couldn't add %s line when matching definitions and synonym lines: %s" % (syntype, lines[lineno]))
                skipped_a_line = True
                skipped_lines.append(lineno)
                continue
              defns[synno] = new_defn
              changed = True
          else:
            if len(defns) > 1:
              # only happens when --do-your-best
              pagemsg("WARNING: Saw %s definitions but %s synonym lines, adding to first definition" % (
                len(defns), total_syns))
              # If more than one synonym line, add a qualifier specifying the original synonym line number
              # to the first synonym on the line to make it easier to manually line up synonyms with definitions.
              if total_syns > 1:
                all_syns = [
                  (lineno, synno,
                    [(syn, other_params + [("qq", "l%s" % (synno + 1))] if synindex == 0 else other_params, joiner_after)
                      for synindex, (syn, other_params, joiner_after) in enumerate(parsed_syns)
                    ]
                  )
                  for lineno, synno, parsed_syns in all_syns
                ]
            # Add inline synonyms
            all_syns = [syn for lineno, synno, parsed_syns in all_syns for syn in parsed_syns] # flatten
            new_defn = add_syns_to_defn(all_syns, defns[0], len(defns) > 1)
            if new_defn is None:
              continue
            defns[0] = new_defn
            changed = True

          # Put back new definition text and clear out moved synonyms
          if changed:
            put_back_new_defns(defns, "%ss with only one definition" % syntype, skipped_a_line, lines, skipped_lines)
          continue

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Convert =Synonyms= sections to inline synonyms", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langcode", required=True, help="Lang code of language to do.")
parser.add_argument("--langname", required=True, help="Lang name of language to do.")
parser.add_argument("--do-your-best", action="store_true", help="Try to take action even if there might be issues.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
