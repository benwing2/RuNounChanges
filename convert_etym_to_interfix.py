#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Convert expressions like {{affix|ru|кот|alt1=ко́то-|кафе́|tr2=kafɛ́}} to {{affix|ru|кот|-о-|кафе́|tr3=kafɛ́}}.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import rulib
import ruheadlib

etym_change = False

def stringize_heads(heads):
  return ",".join("%s%s%s" % (
    ru, "//%s" % tr if tr else "", "[lemma]" if is_lemma else "")
    for ru, tr, is_lemma in heads)

def find_stress(term, pagemsg):
  # Look up a term to find its accented form. If it's monosyllabic or
  # already stressed, this isn't necessary. At the point we're called,
  # there's no tr1= param; we skipped that case.
  if rulib.is_monosyllabic(term) or rulib.is_stressed(term):
    return term, None
  if term.endswith(u"ый") and rulib.is_monosyllabic(term[:-2]):
    return rulib.make_beginning_stressed_ru(term), None
  cached, info = ruheadlib.lookup_heads_and_inflections(term, pagemsg)
  if info is None:
    pagemsg("WARNING: Can't accent, page doesn't exist: %s" % term)
  elif info == "redirect":
    # FIXME, should follow redirects
    pagemsg("WARNING: Can't accent, page is a redirect: %s" % term)
  elif info == "no-russian":
    pagemsg("WARNING: Can't accent, page has no Russian section: %s" % term)
  else:
    heads, inflections_of, adj_forms = info
    heads_ignoring_lemma = set((ru, tr) for ru, tr, is_lemma in heads)
    if len(heads_ignoring_lemma) == 1:
      return list(heads_ignoring_lemma)[0]
    elif len(heads_ignoring_lemma) == 0:
      pagemsg("WARNING: Can't accent, no heads on page: %s" % term)
    else:
      pagemsg("WARNING: Can't accent, multiple accented forms on page %s: %s" %
        (term, stringize_heads(heads)))
  return term, None

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []
  found_affix = False

  parsed = blib.parse_text(text)

  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)

    if tn in ["compound", "com"]:
      lang = getparam(t, "lang")
      if (lang or getparam(t, "1")) != "ru":
        continue
      if lang:
        # Fetch all params, moving numbered params over to the right by one.
        params = [("1", lang, False)]
        for param in t.params:
          pname = str(param.name)
          if re.search("^[0-9]+$", pname):
            params.append((str(int(pname) + 1), param.value, param.showkey))
          elif pname != "lang":
            params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        # Put back parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
      t.name = "affix"
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))
      notes.append("convert {{compound}} to {{affix}}")
      origt = str(t)
      tn = tname(t)

    if tn in ["affix", "af"]:
      if getparam(t, "1") != "ru":
        continue
      m = re.search(r"\n(.*?%s.*?)\n" % re.escape(origt), text)
      if not m:
        pagemsg("WARNING: Something wrong, can't find template in text: %s" % origt)
        continue
      line = m.group(1)

      def warning(textmsg):
        if etym_change:
          pagemsg("WARNING: %s: /// %s /// %s" % (textmsg, line, line))
        else:
          pagemsg("WARNING: %s: %s" % (textmsg, origt))

      found_affix = True
      alt1 = getparam(t, "alt1")
      if alt1 and re.search(u"[ое]-$", alt1):
        tr1 = getparam(t, "tr1")
        if tr1:
          warning("Found alt1= and tr1=, not sure what to do")
          continue
        term = getparam(t, "2")
        term, termtr = find_stress(term, pagemsg)
        # Fetch all params, moving params > 1 over to the right by one.
        params = []
        for param in t.params:
          pname = str(param.name)
          if pname == "1":
            params.append((pname, param.value, param.showkey))
          elif pname == "2":
            params.append(("2", term, False))
            if termtr:
              params.append(("tr1", termtr, True))
            params.append(("3", alt1.endswith(u"о-") and u"-о-" or u"-е-", False))
          elif pname != "alt1":
            if re.search("^[0-9]+$", pname):
              params.append((str(int(pname) + 1), param.value, param.showkey))
            else:
              m = re.search("^(.*?)([0-9]+)$", pname)
              if m and int(m.group(2)) > 1:
                params.append((m.group(1) + str(int(m.group(2)) + 1), param.value, param.showkey))
              else:
                params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        # Put back parameters in order.
        for name, value, showkey in params:
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))
        notes.append("convert use of alt1= in etyms to proper use of interfixes")
      else:
        for param in t.params:
          if str(param.value) in [u"-о-", u"-е-"]:
            for param2 in t.params:
              if str(param2.name) == "alt1":
                warning("Has both interfix and alt1= in affix template")
                break
            else:
              pagemsg("Already has interfix in affix template: %s" % origt)
            break
        else:
          if "-" in pagetitle:
            pagemsg("No interfix but pagetitle '%s' has hyphen, probably OK: %s" % (pagetitle, origt))
          elif " " in pagetitle:
            pagemsg("No interfix but pagetitle '%s' has space, probably OK: %s" % (pagetitle, origt))
          else:
            warning("No interfix and no alt1= alternative")

  if not found_affix:
    pagemsg("WARNING: No affix template")

  return str(parsed), notes

parser = blib.create_argparser('Convert use of alt1= in etyms to proper use of interfixes',
    include_pagefile=True, include_stdin=True)
parser.add_argument('--etym-change', action="store_true",
    help="If specified, output warning lines in a format that they can be edited and the changes uploaded.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)
etym_change = args.etym_change

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian compound words"])
