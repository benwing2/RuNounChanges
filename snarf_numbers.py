#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

numbers = defaultdict(lambda: defaultdict(dict))

def print_valtr(valtr):
  if type(valtr) is tuple:
    val, tr, q = valtr
    if tr:
      tr = "<tr:%s>" % tr
    if q:
      q = "<q:%s>" % q
    return "%s%s%s" % (val, tr, q)
  else:
    return valtr


def read_existing_number_data(langindex, lang):
  modpagename = "Module:number list/data/%s" % lang
  def errandpagemsg(text):
    errandmsg("Page %s %s: %s" % (langindex, modpagename, text))
  datapage = pywikibot.Page(site, modpagename)
  if blib.safe_page_exists(datapage, errandpagemsg):
    pagetext = blib.safe_page_text(datapage, errandpagemsg)
    curnum = None
    for lineindex, line in enumerate(pagetext.split("\n")):
      lineno = lineindex + 1
      def linemsg(text):
        msg("Line %s %s: %s" % (lineno, modpagename, text))
      if not line:
        continue
      if line.startswith("local ") or line.startswith("return "):
        continue
      m = re.search(r"^numbers\[(\"?[0-9]+\"?)\] = \{$", line)
      if m:
        curnum = m.group(1)
        continue
      if line == "}":
        curnum = None
        continue
      m = re.search(r"^\s*([a-zA-Z0-9_]+) = (.*?),?$", line)
      if m:
        if curnum is None:
          linemsg("WARNING: Saw number type assignment outside of number object: %s" % line)
          continue
        numtype, numvals = m.groups()
        m = re.search(r"^\{(.*?)\}$", numvals)
        if m:
          numvals = m.group(1)
        numvals = re.split(r"\s*,\s*", numvals)
        must_continue = False
        parsed_numvals = []
        for numval in numvals:
          m = re.search('^"(.*?)"$', numval)
          if not m:
            linemsg("WARNING: Unparsable number term '%s' for number %s: %s" % (numval, curnum, line))
            must_continue = True
            break
          inside = m.group(1)
          term_and_modifiers = re.split("(<[^<>]*?>)", inside)
          term = term_and_modifiers[0]
          tr = None
          q = None
          for i in range(1, len(term_and_modifiers), 2):
            if i > 1 and term_and_modifiers[i - 1]:
              linemsg("WARNING: Extraneous text between modifiers for number %s: %s" % (numval, line))
              must_continue = True
              break
            m = re.search("^<([a-z]+):(.*)>$", term_and_modifiers[i])
            if not m:
              linemsg("WARNING: Unparsable modifier '%s' for number %s: %s" % (term_and_modifiers[i], numval, line))
              must_continue = True
              break
            mod, modval = m.groups()
            if mod not in ["q", "tr"]:
              linemsg("WARNING: Unrecognized modifier '%s' for number %s: %s" % (mod, numval, line))
              must_continue = True
              break
            if mod == "q":
              q = modval
            else:
              tr = modval
          if must_continue:
            break # outer loop will continue
          if tr or q:
            parsed = (term, tr, q)
          else:
            parsed = term
          parsed_numvals.append(parsed)
        if must_continue:
          continue

        if len(parsed_numvals) == 1:
          parsed_numvals = parsed_numvals[0]
        if numtype in numbers[lang][curnum]:
          linemsg("WARNING: Saw duplicate entry for number %s, type %s: %s" % (curnum, numtype, line))
          continue
        numbers[lang][curnum][numtype] = parsed_numvals


def process_text_on_page(index, pagetitle, text, langcodes):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  def putval(t, lang, num, typ, val, tr):
    num = re.sub(r"(st|nd|rd|th)$", "", num)
    m = re.search("^10<sup>([0-9]+)</sup>$", num)
    if m:
      num = "1" + "0" * int(m.group(1))
    else:
      m = re.search("^([0-9]+)[^0-9]+$", num)
      if m:
        pagemsg("WARNING: Number %s has extraneous text after it, ignoring extraneous text: %s" % (num, str(t)))
        num = m.group(1)
      elif not re.search("^[0-9]+$", num):
        pagemsg("WARNING: Bad number %s, doesn't look numeric: %s" % (num, str(t)))
        return

    # Check for multiple values embedded in a single parameter.
    vals = re.split(r"\s*,\s*", val)
    if len(vals) > 1:
      if tr:
        pagemsg("WARNING: For number %s, type %s, multiple values '%s' and tr=%s, can't handle: %s" % (
          num, typ, vals, tr, str(t)))
        return
      for val in vals:
        val = blib.remove_links(val)
        putval(t, lang, num, typ, val, None)
      return
    else:
      val = vals[0]

    if tr:
      valtr = (val, tr, None)
    else:
      valtr = val
    existing = numbers[lang][num].get(typ, None)
    if existing is not None:
      if type(existing) is list and valtr not in existing:
        pagemsg("WARNING: For lang %s, number %s, type %s, new %s not in existing %s, appending" % (
          lang, num, typ, print_valtr(valtr), ",".join(print_valtr(x) for x in existing)))
        existing.append(valtr)
      elif type(existing) is not list and valtr != existing:
        pagemsg("WARNING: For lang %s, number %s, type %s, new %s not equal to %s, converting to list and appending" % (
          lang, num, typ, print_valtr(val), print_valtr(existing)))
        numbers[lang][num][typ] = [existing, val]
    else:
      numbers[lang][num][typ] = val

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    def getp(param):
      return getparam(t, param).strip()
    tn = tname(t)
    if tn in ["cardinalbox", "ordinalbox", "adverbialbox"]:
      boxtype = tn[:-3]
      langcode = getp("1")
      if langcode in langcodes:
        def put(num, typ, val, tr):
          putval(t, langcode, num, typ, val, tr)
        num = getp("3")
        if not num:
          pagemsg("WARNING: Blank current number for {{%s}}: %s" % (tn, str(t)))
        else:
          put(num, boxtype, getp("alt") or pagetitle, getp("tr"))
        prevnum = getp("2")
        if prevnum:
          prevnumtext = getp("5")
          if not prevnumtext:
            pagemsg("WARNING: Previous number %s but blank textual form in {{%s}}: %s" % (prevnum, tn, str(t)))
          else:
            put(prevnum, boxtype, prevnumtext, None)
        nextnum = getp("4")
        if nextnum:
          nextnumtext = getp("6")
          if not nextnumtext:
            pagemsg("WARNING: Next number %s but blank textual form in {{%s}}: %s" % (nextnum, tn, str(t)))
          else:
            put(nextnum, boxtype, nextnumtext, None)
        for (other, othertype) in [
          ("card", "cardinal"),
          ("ord", "ordinal"),
          ("adv", "adverbial"),
          ("mult", "multiplier"),
          ("dis", "distributive"),
          ("coll", "collective"),
          ("frac", "fractional"),
        ]:
          otherval = getp(other + "alt") or getp(other)
          if otherval:
            put(num, othertype, otherval, getp(other + "tr"))
        for opt in ["opt", "opt2"]:
          opttype = getp(opt)
          if opttype:
            optval = getp(opt + "xalt") or getp(opt + "x")
            if not optval:
              pagemsg("WARNING: Saw optional type %s but no optional form in {{%s}}: %s" % (opttype, tn, str(t)))
            else:
              put(num, opttype, optval, getp(opt + "xtr"))
        wplink = getp("wplink")
        if wplink:
          put(num, "wplink", wplink, None)


parser = blib.create_argparser("Snarf numbers", include_pagefile=True, include_stdin=True)
parser.add_argument("--langs", help="Do these language codes.", required=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

langcodes = args.langs.split(",")
for langindex, langcode in enumerate(langcodes):
  read_existing_number_data(langindex + 1, langcode)

def do_process_text_on_page(index, pagetitle, text):
  return process_text_on_page(index, pagetitle, text, langcodes)
blib.do_pagefile_cats_refs(args, start, end, do_process_text_on_page, edit=True, stdin=True)

number_properties = [
  "cardinal",
  "ordinal",
  "ordinal_abbr",
  "adverbial",
  "multiplier",
  "distributive",
  "collective",
  "fractional",
]
indexed_number_properties = {prop: index for index, prop in enumerate(number_properties)}

for index, (langcode, numprops_by_num) in enumerate(numbers.iteritems()):
  msg("Page %s Module:number list/data/%s: -------- begin text ---------" % (index, langcode))
  msg("""local export = {numbers = {}}

local numbers = export.numbers
""")
  for num, numprops in sorted(numprops_by_num.iteritems(), key=lambda x: (len(x[0]), x[0])):
    msg("")
    msg("numbers[%s] = {" % (num if len(num) < 16 else '"%s"' % num))
    for prop, values in sorted(numprops.iteritems(),
        key=lambda x: (indexed_number_properties.get(x[0], len(number_properties)), x[0])):
      msg("\t%s = %s," % (prop, "{%s}" % ", ".join('"%s"' % print_valtr(x) for x in values) if type(values) is list
        else '"%s"' % print_valtr(values)))
    msg("}")
  msg("")
  msg("return export")
  msg("-------- end text --------")
