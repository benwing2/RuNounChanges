#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, site

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  origtext = text
  notes = []

  if blib.page_should_be_ignored(pagetitle):
    return

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "surname":
      origt = str(t)
      def getp(param):
        return getparam(t, param)
      adj = getp("2")
      aval = getp("A")
      if aval:
        m = re.search("^(A|An|a|an) +(.*)$", aval)
        if m:
          article, qual = m.groups()
          if adj:
            pagemsg("Move qualifier '%s' in A=%s to beginning of 2=%s: %s" % (qual, aval, adj, str(t)))
            notes.append("move qualifier '%s' in A=%s in {{surname}} to beginning of 2=%s" % (qual, aval, adj))
            adj = qual + " " + adj
            t.add("A", article)
            t.add("2", adj)
          else:
            pagemsg("Move qualifier '%s' in A=%s to 2=: %s" % (qual, aval, str(t)))
            notes.append("move qualifier '%s' in A=%s in {{surname}} to 2=" % (qual, aval))
            # We want the moved qualifier to go into 2= at the beginning directly after A=, but unfortunately there
            # isn't an after= param to add().
            newparams = []
            for param in t.params:
              pn = pname(param)
              pv = str(param.value)
              if pn == "A":
                newparams.append(("A", article))
                newparams.append(("2", qual))
              else:
                newparams.append((pn, pv))
            del t.params[:]
            for pn, pv in newparams:
              t.add(pn, pv, preserve_spacing=False)

      adj = getp("2")
      unlinked_adj = blib.remove_links(adj)
      aval = getp("A")
      g = getp("g")
      if g:
        expected_art = "An" if g.startswith("unknown") else "A"
      elif adj:
        expected_art = "An" if re.search("^[AEIOUaeiou]", unlinked_adj) else "A"
      else:
        expected_art = "A" # because the following word is 'surname'
      if expected_art == aval:
        pagemsg("Remove redundant article A=%s: %s" % (aval, str(t)))
        notes.append("remove redundant article A=%s in {{surname}}" % aval)
        rmparam(t, "A")
      elif expected_art == "A" and aval in ["an", "An"] or (expected_art == "An" and aval in ["a", "A"]
          and not re.search("^[Uu]", (g or unlinked_adj or "surname"))):
        pagemsg("WARNING: Probable wrong article A=%s: %s" % (aval, str(t)))

      def transfer_adj(adj):
        fromvals = blib.fetch_param_chain(t, "from")
        unlinked_adj = blib.remove_links(adj)
        def get_fromsubind():
          return "" if len(fromvals) == 1 else len(fromvals)
        qual_to_from = {
          "patronymic": "patronymics",
          "matronymic": "matronymics",
          "occupational": "occupations",
          "habitational": "place names",
        }
        qual_re = "(%s)" % "|".join(qual_to_from.keys())
        newadj = None
        if re.search(r"\b%s$" % qual_re, unlinked_adj):
          m = re.search(r"^(.*?) *\[*%s\]*$" % qual_re, adj)
          if not m:
            pagemsg("WARNING: Unable to locate '%s' from 2=%s when it should be there: %s" % (qual_re, adj, str(t)))
          else:
            newadj, qual = m.groups()
            qual_from = qual_to_from[qual]
            if qual in ["patronymic", "matronymic"] and len(fromvals) > 0 and fromvals[-1] == "given names":
              fromvals[-1] = qual_from
              fromsubind = get_fromsubind()
              pagemsg("Moving '%s' in 2=%s over from%s=given names: %s" % (qual, adj, fromsubind, str(t)))
              notes.append("move '%s' in 2=%s in {{surname}} over from%s=given names" % (qual, adj, fromsubind))
            elif len(fromvals) > 0 and fromvals[-1] == qual_from:
              fromsubind = get_fromsubind()
              pagemsg("Removing '%s' from 2=%s as it duplicates from%s=%s: %s" % (qual, adj, fromsubind, qual_from, str(t)))
              notes.append("removing '%s' from 2=%s in {{surname}} as it duplicates from%s=%s" % (qual, adj, fromsubind, qual_from))
            elif qual == "habitational": # Not all 'habitational' surnames are from place names
              newadj = None
            elif len(fromvals) > 0:
              oldfromval = fromvals[-1]
              if re.search("^[a-z]", oldfromval):
                # we need to append a new param, as we don't want e.g. 'matronymics < patronymics'
                fromvals.append(qual_from)
                fromsubind = get_fromsubind()
                pagemsg("Removing '%s' from 2=%s and appending as '%s' in new param from%s=%s: %s" % (qual, adj, qual_from, fromsubind, oldfromval, str(t)))
                notes.append("remove '%s' from 2=%s in {{surname}} and append as '%s' in new param from%s=%s" % (qual, adj, qual_from, fromsubind, oldfromval))
              else:
                # we need to append using ' < ' as we want e.g. 'Old English < patronymics'
                fromvals[-1] += " < " + qual_from
                fromsubind = get_fromsubind()
                pagemsg("Removing '%s' from 2=%s and appending as '< %s' to from%s=%s: %s" % (qual, adj, qual_from, fromsubind, oldfromval, str(t)))
                notes.append("remove '%s' from 2=%s in {{surname}} and append as '< %s' to from%s=%s" % (qual, adj, qual_from, fromsubind, oldfromval))
            else:
              fromvals = [qual_from]
              fromsubind = get_fromsubind()
              pagemsg("Moving '%s' in 2=%s to new param from%s=%s: %s" % (qual, adj, fromsubind, qual_from, str(t)))
              notes.append("move '%s' in 2=%s in {{surname}} to new param from%s=%s" % (qual, adj, fromsubind, qual_from))

            if newadj is not None:
              if newadj:
                t.add("2", newadj)
              else:
                rmparam(t, "2")
              blib.set_param_chain(t, fromvals, "from")

        return newadj is not None

      adj = getp("2")
      if re.search(r"^\[*[a-z]+\]* and \[*[a-z]+\]*$", adj):
        # 'patronymic and matronymic' or similar
        adjvals = adj.split(" and ")
        for i, adjval in enumerate(adjvals):
          if not transfer_adj(adjval):
            # Unable to transfer, e.g. 'patronymic and habitational'; we may already have partly transferred,
            # so skip everything
            return
      else:
        transfer_adj(adj)

      fromvals = blib.fetch_param_chain(t, "from")
      fromval = re.sub(" < .*", "", fromvals[0] if len(fromvals) > 0 else "")
      adj = getp("2")
      unlinked_adj = blib.remove_links(adj)
      if fromval:
        if unlinked_adj == fromval:
          pagemsg("from=%s duplicates 2=%s: %s" % (fromval, adj, str(t)))
          rmparam(t, "2")
          notes.append("remove 2=%s in {{surname}} that duplicates from=" % adj)
        elif adj:
          newadj = re.sub(r"^\[*%s\]* (?=\[*(habitational|topographic)\]*\b)" % re.escape(fromval), "", adj)
          if newadj == adj:
            newadj = re.sub(r"(?<=\bcommon) \[*%s\]*$" % re.escape(fromval), "", adj)
          if newadj != adj:
            pagemsg("Remove duplicate '%s' from adj=%s, duplicating from=: %s" % (fromval, adj, str(t)))
            notes.append("remove '%s' from adj=%s, duplicating from=" % (fromval, adj))
            t.add("2", newadj)
        adj = getp("2")
        unlinked_adj = blib.remove_links(adj)
        singular_fromval = fromval
        if re.search("^[a-z]", singular_fromval):
          singular_fromval = re.sub("s$", "", singular_fromval)
        if singular_fromval in unlinked_adj:
          pagemsg("WARNING: from=%s contained in 2=%s: %s" % (fromval, adj, str(t)))

      if origt != str(t):
        pagemsg("Replaced %s with %s" % (origt, str(t)))

  text = str(parsed)
  lines = text.split("\n")
  for lineno, line in enumerate(lines):
    if "{{surname|" in line and re.search(r"\}\} of .* origin", line):
      parsed = blib.parse_text(line)
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn == "surname":
          fromval = re.sub(" < .*", "", getparam(t, "from"))
          if fromval:
            newline = re.sub("(%s) of \[*%s\]* origin" % (re.escape(str(t)), fromval), r"\1", line)
            if newline != line:
              pagemsg("Replaced line #%s <%s> with <%s>" % (lineno + 1, line, newline))
              lines[lineno] = newline
              notes.append("remove redundant 'of %s origin' after {{surname|...|from=%s}}" % (fromval, fromval))
  text = "\n".join(lines)

  return text, notes

parser = blib.create_argparser("Clean up {{surname}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
