#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix up raw verb forms when possible, canonicalize existing 'conjugation of'
# to 'inflection of'

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping page")
    return

  text = str(page.text)
  notes = []

  foundrussian = False
  sections = re.split("(^==[^=]*==\n)", text, 0, re.M)

  for j in range(2, len(sections), 2):
    if sections[j-1] == "==Russian==\n":
      if foundrussian:
        pagemsg("WARNING: Found multiple Russian sections, skipping page")
        return
      foundrussian = True

      # Try to canonicalize existing 'conjugation of'
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "conjugation of" and getparam(t, "lang") == "ru":
          origt = str(t)
          t.name = "inflection of"
          newt = str(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("converted 'conjugation of' to 'inflection of'")
      sections[j] = str(parsed)

      # Try to split 'inflection of' containing 'present or future' into two
      # defns
      newsec = re.sub(r"^# \{\{inflection of\|(.*?)\|present or future\|(.*?)\}\}$",
          r"# {{inflection of|\1|pres|\2}}\n# {{inflection of|\1|fut|\2}}",
          sections[j], 0, re.M)
      if newsec != sections[j]:
        notes.append("split 'present or future' form code into two defns with 'pres' and 'fut'")
        sections[j] = newsec

      # Convert 'indc' to 'ind', 'futr' to 'fut', 'perfective' and
      # '(perfective)' to 'pfv', 'imperfective' and '(imperfective)' to 'impfv',
      # 'impr' to 'imp'
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          for frm, to in [
              ("indc", "ind"), ("indicative", "ind"),
              ("futr", "fut"), ("future", "fut"),
              ("impr", "imp"), ("imperative", "imp"),
              ("perfective", "pfv"), ("(perfective)", "pfv"),
              ("imperfective", "impfv"), ("(imperfective)", "impfv"),
              ("singular", "s"), ("(singular)", "s"),
              ("plural", "p"), ("(plural)", "p"),
              ("masculine", "m"), ("(masculine)", "m"),
              ("feminine", "f"), ("(feminine)", "f"),
              ("neuter", "n"), ("(neuter)", "n"), ("neutral", "n"), ("(neutral)", "n"),
              ]:
            origt = str(t)
            for i in range(3,20):
              val = getparam(t, str(i))
              if val == frm:
                t.add(str(i), to)
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("converted '%s' form code to '%s'" % (frm, to))
      sections[j] = str(parsed)

      # Remove blank form codes and canonicalize position of lang=, tr=
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          origt = str(t)
          # Fetch the numbered params starting with 3, skipping blank ones
          numbered_params = []
          for i in range(3,20):
            val = getparam(t, str(i))
            if val:
              numbered_params.append(val)
          # Fetch param 1 and param 2, and non-numbered params except lang=
          # and nocat=.
          param1 = getparam(t, "1")
          param2 = getparam(t, "2")
          tr = getparam(t, "tr")
          nocat = getparam(t, "nocat")
          non_numbered_params = []
          for param in t.params:
            pname = str(param.name)
            if not re.search(r"^[0-9]+$", pname) and pname not in ["lang", "nocat", "tr"]:
              non_numbered_params.append((pname, param.value))
          # Erase all params.
          del t.params[:]
          # Put back lang, param 1, param 2, tr, then the replacements for the
          # higher numbered params, then the non-numbered params.
          t.add("lang", "ru")
          t.add("1", param1)
          t.add("2", param2)
          if tr:
            t.add("tr", tr)
          for i, param in enumerate(numbered_params):
            t.add(str(i+3), param)
          for name, value in non_numbered_params:
            t.add(name, value)
          newt = str(t)
          if origt != newt:
            pagemsg("Replaced %s with %s" % (origt, newt))
            notes.append("removed any blank form codes and maybe rearranged lang=, tr=")
            if nocat:
              notes.append("removed nocat=")
      sections[j] = str(parsed)

      # Try to canonicalize 'inflection of' involving the imperative,
      # present, future
      parsed = blib.parse_text(sections[j])
      for t in parsed.filter_templates():
        if str(t.name) == "inflection of" and getparam(t, "lang") == "ru":
          # Fetch the numbered params starting with 3
          numbered_params = []
          for i in range(3,20):
            val = getparam(t, str(i))
            if val:
              numbered_params.append(val)
          while len(numbered_params) > 0 and not numbered_params[-1]:
            del numbered_params[-1]
          # Now canonicalize
          numparamstr = "/".join(numbered_params)
          numparamset = set(numbered_params)
          canon_params = []
          while True:
            if numparamset == {'s', 'pfv', 'imp'}:
              canon_params = ['2', 's', 'pfv', 'imp']
            elif numparamset == {'s', 'impfv', 'imp'}:
              canon_params = ['2', 's', 'impfv', 'imp']
            elif numparamset == {'s', 'imp'}:
              canon_params = ['2', 's', 'imp']
            elif numparamset == {'p', 'pfv', 'imp'}:
              canon_params = ['2', 'p', 'pfv', 'imp']
            elif numparamset == {'p', 'impfv', 'imp'}:
              canon_params = ['2', 'p', 'impfv', 'imp']
            elif numparamset == {'p', 'imp'}:
              canon_params = ['2', 'p', 'imp']
            elif numparamset == {'m', 's', 'past'}:
              canon_params = ['m', 's', 'past', 'ind']
            elif numparamset == {'f', 's', 'past'}:
              canon_params = ['f', 's', 'past', 'ind']
            elif numparamset == {'n', 's', 'past'}:
              canon_params = ['n', 's', 'past', 'ind']
            elif numparamset == {'p', 'past'}:
              canon_params = ['p', 'past', 'ind']
            else:
              m = re.search(r"^([123])/([sp])/(pres|fut)$", numparamstr)
              if m:
                canon_params = [m.group(1), m.group(2), m.group(3), "ind"]
            break
          if canon_params:
            origt = str(t)
            # Fetch param 1 and param 2. Erase all numbered params.
            # Put back param 1 and param 2 (this will put them after lang=ru),
            # then the replacements for the higher params.
            param1 = getparam(t, "1")
            param2 = getparam(t, "2")
            for i in range(19,0,-1):
              rmparam(t, str(i))
            t.add("1", param1)
            t.add("2", param2)
            for i, param in enumerate(canon_params):
              t.add(str(i+3), param)
            newt = str(t)
            if origt != newt:
              pagemsg("Replaced %s with %s" % (origt, newt))
              notes.append("canonicalized 'inflection of' for %s" % "/".join(canon_params))
            else:
              pagemsg("Apparently already canonicalized: %s" % newt)
      sections[j] = str(parsed)

      # Try to add 'inflection of' to raw-specified participial inflection
      def add_participle_inflection_of(m):
        prefix = m.group(1)
        tense = m.group(2).lower()
        if tense == "present":
          tense = "pres"
        voice = m.group(3).lower()
        if voice == "active":
          voice = "act"
        elif voice == "passive":
          voice = "pass"
        elif voice == "adverbial":
          voice = "adv"
        lemma = m.group(4)
        retval = prefix + "{{inflection of|lang=ru|%s||%s|%s|part}}" % (lemma, tense, voice)
        pagemsg("Replaced <%s> with %s" % (m.group(0), retval))
        notes.append("converted raw to 'inflection of' for %s/%s/part" % (tense, voice))
        return retval
      newsec = re.sub(r"(# |\()'*(present|past) participle (active|passive|adverbial) of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_participle_inflection_of,
          sections[j], 0, re.I)
      newsec = re.sub(r"(# |\()'*(present|past) (active|passive|adverbial) participle of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_participle_inflection_of,
          newsec, 0, re.I)
      sections[j] = newsec

      # Try to add 'inflection of' to raw-specified past inflection
      def add_past_inflection_of(m):
        prefix = m.group(1)
        gender = {"masculine":"m", "male":"m", "feminine":"f", "female":"f",
            "neuter":"n", "neutral":"n", "plural":"p"}[m.group(2).lower()]
        lemma = m.group(3)
        retval = prefix + "{{inflection of|lang=ru|%s||%s%s|past|ind}}" % (lemma, gender, gender != "p" and "|s" or "")
        pagemsg("Replaced <%s> with %s" % (m.group(0), retval))
        notes.append("converted raw to 'inflection of' for %s%s/past/ind" % (gender, gender != "p" and "/s" or ""))
        return retval
      newsec = re.sub(r"(# |\()'*(male|masculine|female|feminine|neutral|neuter|plural) (?:singular |)past (?:tense |form |)of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_past_inflection_of,
          sections[j], 0, re.I)
      newsec = re.sub(r"(# |\()'*past(?:-tense| tense|) (male|masculine|female|feminine|neutral|neuter|plural) (?:singular |)(?:form |)of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_past_inflection_of,
          newsec, 0, re.I)
      sections[j] = newsec

      # Try to add 'inflection of' to raw-specified imperative inflection
      def add_imper_inflection_of(m):
        prefix = m.group(1)
        number = {"singular":"s", "plural":"p"}[m.group(2).lower()]
        lemma = m.group(3)
        retval = prefix + "{{inflection of|lang=ru|%s||2|%s|imp}}" % (lemma, number)
        pagemsg("Replaced <%s> with %s" % (m.group(0), retval))
        notes.append("converted raw to 'inflection of' for 2/%s/imp" % number)
        return retval
      newsec = re.sub(r"(# |\()'*(singular|plural) imperative (?:form |)of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_imper_inflection_of,
          sections[j], 0, re.I)
      newsec = re.sub(r"(# |\()'*imperative (singular|plural) (?:form |)of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_imper_inflection_of,
          newsec, 0, re.I)
      sections[j] = newsec

      # Try to add 'inflection of' to raw-specified finite pres/fut inflection
      def add_pres_fut_inflection_of(m):
        prefix = m.group(1)
        person = m.group(2)[0]
        number = {"singular":"s", "plural":"p"}[m.group(3).lower()]
        tense = {"present":"pres", "future":"fut"}[m.group(4).lower()]
        lemma = m.group(5)
        retval = prefix + "{{inflection of|lang=ru|%s||%s|%s|%s|ind}}" % (lemma, person, number, tense)
        pagemsg("Replaced <%s> with %s" % (m.group(0), retval))
        notes.append("converted raw to 'inflection of' for %s/%s/%s/ind" % (person, number, tense))
        return retval
      newsec = re.sub(r"(# |\()'*(1st|2nd|3rd)(?:-person| person|) (singular|plural) (present|future) (?:tense |)of'* '*(?:\[\[|\{\{[lm]\|ru\||\{\{term\|)([^|]*?)(?:\]\]|\}\}|\|+lang=ru\}\})'*", add_pres_fut_inflection_of,
          sections[j], 0, re.I)
      sections[j] = newsec

  return "".join(sections), notes

parser = blib.create_argparser("Convert raw verb forms to use 'inflection of'",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["Russian verb forms"])
