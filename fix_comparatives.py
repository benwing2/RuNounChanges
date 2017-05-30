#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib

def process_page(index, page, save, verbose):
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  text = unicode(page.text)
  parsed = blib.parse(page)
  notes = []
  hascomp = False
  headword_templates = []
  decl_templates = []
  for t in parsed.filter_templates():
    if unicode(t.name) == "ru-adj":
      headword_templates.append(t)
      if getparam(t, "2"):
        hascomp = True
      elif getparam(t, "comp2") or getparam(t, "comp3") or getparam(t, "comp4") or getparam(t, "comp5"):
        pagemsg("WARNING: Found compN= but no 2=: %s" % unicode(t))
    if unicode(t.name) == "ru-decl-adj":
      decl_templates.append(t)
  if hascomp:
    if len(headword_templates) > 1 or len(decl_templates) > 1:
      pagemsg("WARNING: Found comparative and multiple headword or decl templates, can't proceed")
    elif len(decl_templates) == 1 and not headword_templates:
      pagemsg("WARNING: Strange, decl template but no headword template: %s" %
          unicode(decl_templates[0]))
    elif len(headword_templates) == 1 and not decl_templates:
      pagemsg("WARNING: Strange, headword template but no decl template: %s" %
          unicode(headword_templates[0]))
    elif pagetitle.endswith(u"ся"):
      pagemsg("WARNING: Comparative with reflexive adjective, not sure what to do: %s" %
          unicode(headword_templates[0]))
    else:
      head = getparam(decl_templates[0], "1")
      decl = getparam(decl_templates[0], "2")
      if decl == "-" or decl == "?" or not decl:
        pagemsg("WARNING: Found comparative with no short decl '%s': %s" %
            (decl, getparam(headword_templates[0], "2")))
        compspec = "+"
      else:
        decl = re.sub(r"\*", "", decl)
        decl = re.sub(r"\([12]\)", "", decl)
        decl = set(re.sub(":.*", "", x) for x in re.split(",", decl))
        if len(decl) > 1:
          pagemsg("WARNING: Found multiple short declensions, not sure what to do: %s (reduced to %s)" %
              getparam(decl_templates[0], "2"), ",".join(decl))
          return
        decl = list(decl)[0]
        if not re.search("^[abc]'*$", decl):
          pagemsg("WARNING: Strange canonicalized decl %s (orig %s), don't know what to do" %
              (decl, getparam(decl_templates[0], "2")))
          return
        if (decl == "a" and not pagetitle.endswith(u"ой") or
            decl == "b" and pagetitle.endswith(u"ой")):
          compspec = "+"
        else:
          compspec = "+" + decl
      comparatives = expand_text("{{#invoke:ru-headword|generate_comparative|%s|%s}}" %
          (head, compspec))
      if not comparatives:
        # Already output warning
        return
      comparatives = [re.sub("//.*", "", x) for x in re.split(",", comparatives)]
      unique_comparatives = []
      for comp in comparatives:
        if comp not in unique_comparatives:
          unique_comparatives.append(comp)
      origt = unicode(headword_templates[0])
      existing_comparatives = []
      compparams = []
      i = 0
      while True:
        compparam = "2" if i == 0 else "comp" + str(i + 1)
        existing_comp = getparam(headword_templates[0], compparam)
        if not existing_comp:
          break
        existing_comparatives.append(existing_comp)
        compparams.append(compparam)
        i += 1
      if "peri" in existing_comparatives:
        if len(existing_comparatives) > 1:
          pagemsg("WARNING: 'peri' along with other explicit comparatives, not sure what to do: %s" %
              ",".join(existing_comparatives))
      elif any(x.startswith("+") for x in existing_comparatives):
        if len(existing_comparatives) > 1:
          pagemsg("WARNING: auto-comparative along with other explicit comparatives, not sure what to do: %s" %
              ",".join(existing_comparatives))
      elif existing_comparatives != unique_comparatives:
        pagemsg("WARNING: Explicit comparative(s) %s not same as auto-generated %s" %
            (",".join(existing_comparatives), ",".join(unique_comparatives)))
      else:
        superlatives = blib.fetch_param_chain(headword_templates[0], "3", "sup")
        blib.remove_param_chain(headword_templates[0], "3", "sup")
        for compparam in compparams:
          rmparam(headword_templates[0], compparam)
        headword_templates[0].add("2", compspec)
        blib.set_param_chain(headword_templates[0], superlatives, "3", "sup")
        pagemsg("Replaced %s with %s" % (origt, unicode(headword_templates[0])))
        notes.append("replaced explicit comparative %s with %s" %
            (",".join(existing_comparatives), compspec))

  new_text = unicode(parsed)

  if new_text != text:
    if verbose:
      pagemsg("Replacing <%s> with <%s>" % (text, new_text))
    assert notes
    comment = "; ".join(notes)
    if save:
      pagemsg("Saving with comment = %s" % comment)
      page.text = new_text
      page.save(comment=comment)
    else:
      pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Fix up comparatives that can be converted to +, +c, etc.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for i, page in blib.cat_articles("Russian adjectives", start, end):
  process_page(i, page, args.save, args.verbose)
