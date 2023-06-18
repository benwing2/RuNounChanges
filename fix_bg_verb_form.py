#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

import bglib

verbs_to_accents = {}

def snarf_verb_accents():
  for index, page in blib.cat_articles("Bulgarian verbs"):
    pagetitle = str(page.title())
    def pagemsg(txt):
      msg("Page %s %s: %s" % (index, pagetitle, txt))
    parsed = blib.parse(page)
    for t in parsed.filter_templates():
      if tname(t) == "bg-verb":
        verb = getparam(t, "1")
        if not verb:
          pagemsg("WARNING: Missing headword in verb: %s" % str(t))
          continue
        if bglib.needs_accents(verb):
          pagemsg("WARNING: Verb %s missing an accent: %s" % (verb, str(t)))
          continue
        unaccented_verb = bglib.remove_accents(verb)
        if unaccented_verb in verbs_to_accents and verbs_to_accents[unaccented_verb] != verb:
          pagemsg("WARNING: Two different accents possible for %s: %s and %s: %s" % (
            unaccented_verb, verbs_to_accents[unaccented_verb], verb, str(t)))
        verbs_to_accents[unaccented_verb] = verb

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  pagemsg("Processing")

  for t in parsed.filter_templates():
    if tname(t) == "bg-verb-form":
      if not getparam(t, "head"):
        if bglib.needs_accents(pagetitle):
          pagemsg("WARNING: Can't add head= to {{bg-verb-form}} missing it because pagetitle is multisyllabic: %s" %
              str(t))
        elif t.has("g"):
          t.add("head", pagetitle, before="g")
        else:
          t.add("head", pagetitle)

  text = str(parsed)

  newtext = re.sub(r"^\{\{bg-verb-form\|[^{}|\n]*?\|head=([^{}|\n]*?)((?:\|g=[a-z]+)?)\}\}, \{\{bg-verb-form\|[^{}|\n]*?\|head=([^{}|\n]*?)\2\}\}$", r"{{head|bg|verb form|head=\1|head2=\3\2}}", text, 0, re.M)
  newtext = re.sub(r"^\{\{bg-verb-form\|[^{}|\n]*?\|head=([^{}|\n]*?)((?:\|g=[a-z]+)?)\}\}$", r"{{head|bg|verb form|head=\1\2}}", newtext, 0, re.M)
  if newtext != text:
    notes.append("replace {{bg-verb-form}} with {{head|bg|verb form}}")
    text = newtext
  m = re.search("^.*?bg-verb-form.*?$", text, re.M)
  if m:
    pagemsg("WARNING: Still saw bg-verb-form after attempted replacements: %s" % m.group(0).strip())

  parsed = blib.parse_text(text)
  headt = None
  saw_infl_after_head = False
  vn_forms_to_add_header = []
  part_forms_to_add_header = []
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn == "head" and getparam(t, "1") == "bg" and getparam(t, "2") == "verb form":
      if headt and not saw_infl_after_head:
        pagemsg("WARNING: Saw two head templates %s and %s without intervening inflection" % (
          str(headt), origt))
      saw_infl_after_head = False
      headt = t
    if tn == "bg-verb form of":
      if not headt:
        pagemsg("WARNING: Saw {{bg-verb form of}} without head template: %s" % origt)
        continue
      must_continue = False
      for param in t.params:
        if pname(param) not in ["verb", "part", "g", "f", "d", "person", "number", "tense", "mood"]:
          pagemsg("WARNING: Saw unrecognized param %s=%s: %s" % (pname(param), str(param.value), origt))
          must_continue = True
          break
      if must_continue:
        continue
      saw_infl_after_head = True
      parttype = None
      verb = getparam(t, "verb")
      if not verb:
        pagemsg("WARNING: Didn't see verb=: %s" % origt)
        continue
      infls = []
      part = getparam(t, "part")
      if part == "adverbial participle":
        infls = ["adv", "part"]
        parttype = "adv"
      elif part == "verbal noun":
        d = getparam(t, "d")
        if d == "indefinite":
          infls.append("indef")
        elif d == "definite":
          infls.append("def")
        else:
          pagemsg("WARNING: Saw unrecognized d=%s: %s" % (d, origt))
          continue
        g = getparam(t, "g")
        if g == "singular":
          infls.append("s")
        elif g == "plural":
          infls.append("p")
        else:
          pagemsg("WARNING: Saw unrecognized g=%s: %s" % (g, origt))
          continue
        infls.append("vnoun")
        if g == "singular" and d == "indefinite":
          parttype = "vn"
        else:
          parttype = "vnform"
      elif not part:
        person = getparam(t, "person")
        if person == "first":
          infls.append("1")
        elif person == "second":
          infls.append("2")
        elif person == "third":
          infls.append("3")
        else:
          pagemsg("WARNING: Saw unrecognized person=%s: %s" % (person, origt))
          continue
        number = getparam(t, "number")
        if number == "singular":
          infls.append("s")
        elif number == "plural":
          infls.append("p")
        else:
          pagemsg("WARNING: Saw unrecognized number=%s: %s" % (number, origt))
          continue
        tense = getparam(t, "tense")
        if tense == "present":
          infls.append("pres")
        elif tense == "aorist":
          infls.append("aor")
        elif tense == "imperfect":
          infls.append("impf")
        elif tense: # can be missing when imperative
          pagemsg("WARNING: Saw unrecognized tense=%s: %s" % (tense, origt))
          continue
        mood = getparam(t, "mood")
        if mood == "indicative":
          infls.append("ind")
        elif mood == "imperative":
          infls.append("imp")
        elif mood == "renarrative":
          infls.append("renarr")
        else:
          pagemsg("WARNING: Saw unrecognized mood=%s: %s" % (mood, origt))
          continue
      else: # participle
        d = getparam(t, "d")
        if d == "indefinite":
          infls.append("indef")
        elif d == "definite":
          infls.append("def")
        elif d:
          pagemsg("WARNING: Saw unrecognized d=%s: %s" % (d, origt))
          continue
        f = getparam(t, "f")
        if f == "subject form":
          infls.append("sbjv")
        elif f == "object form":
          infls.append("objv")
        elif f:
          pagemsg("WARNING: Saw unrecognized f=%s: %s" % (f, origt))
          continue
        g = getparam(t, "g")
        if g == "masculine":
          infls.extend(["m", "s"])
        elif g == "feminine":
          infls.extend(["f", "s"])
        elif g == "neuter":
          infls.extend(["n", "s"])
        elif g == "plural":
          infls.append("p")
        else:
          pagemsg("WARNING: Saw unrecognized g=%s: %s" % (g, origt))
          continue
        if part == "present active participle":
          infls.extend(["pres", "act", "part"])
          parttype = "pres"
        elif part == "past passive participle":
          infls.extend(["past", "pass", "part"])
          parttype = "pass"
        elif part == "past active aorist participle":
          infls.extend(["past", "act", "aor", "part"])
          parttype = "aor"
        elif part == "past active imperfect participle":
          infls.extend(["past", "act", "impf", "part"])
          parttype = "impf"
        else:
          pagemsg("WARNING: Saw unrecognized part=%s: %s" % (part, origt))
          continue
        if not (g == "masculine" and (d == "indefinite" or not d and part == "past active imperfect participle")):
          parttype = "partform"

      if parttype == "vnform":
        if tname(headt) == "head":
          heads = blib.fetch_param_chain(headt, "head", "head")
          if not heads:
            pagemsg("WARNING: Something wrong, {{head|bg|verb form}} missing head=: %s" % str(headt))
            continue
          genders = blib.fetch_param_chain(headt, "g", "g")
          origheadt = str(headt)
          blib.set_template_name(headt, "bg-verbal noun form")
          del headt.params[:]
          blib.set_param_chain(headt, heads, "1", "head")
          blib.set_param_chain(headt, genders, "g", "g")
          pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
          notes.append("convert {{head|bg|verb form}} to {{bg-verbal noun form}}")
        elif tname(headt) == "bg-verbal noun":
          pagemsg("WARNING: Both verbal noun and verbal noun form under same head: head=%s, infl=%s" % (
            str(headt), origt))
          continue
        elif tname(headt) != "bg-verbal noun form":
          pagemsg("Both verbal noun form and participle (or something else?) under same head, will split: head=%s, infl=%s" % (
            str(headt), origt))
          vn_forms_to_add_header.append((headt, t, g == "singular" and "n" or "p"))
      elif parttype == "vn":
        if tname(headt) == "head":
          heads = blib.fetch_param_chain(headt, "head", "head")
          if not heads:
            pagemsg("WARNING: Something wrong, {{head|bg|verb form}} missing head=: %s" % str(headt))
            continue
          genders = blib.fetch_param_chain(headt, "g", "g")
          origheadt = str(headt)
          blib.set_template_name(headt, "bg-verbal noun")
          del headt.params[:]
          blib.set_param_chain(headt, heads, "1", "head")
          blib.set_param_chain(headt, genders, "g", "g")
          pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
          notes.append("convert {{head|bg|verb form}} to {{bg-verbal noun}}")
        elif tname(headt) == "bg-verbal noun form":
          pagemsg("WARNING: Both verbal noun and verbal noun form under same head: head=%s, infl=%s" % (
            str(headt), origt))
          continue
        elif tname(headt) != "bg-verbal noun":
          pagemsg("WARNING: Both verbal noun and participle (or something else?) under same head: head=%s, infl=%s" % (
            str(headt), origt))
          continue
      elif parttype == "partform":
        if tname(headt) == "head":
          heads = blib.fetch_param_chain(headt, "head", "head")
          if not heads:
            pagemsg("WARNING: Something wrong, {{head|bg|verb form}} missing head=: %s" % str(headt))
            continue
          genders = blib.fetch_param_chain(headt, "g", "g")
          origheadt = str(headt)
          blib.set_template_name(headt, "bg-part form")
          del headt.params[:]
          blib.set_param_chain(headt, heads, "1", "head")
          blib.set_param_chain(headt, genders, "g", "g")
          pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
          notes.append("convert {{head|bg|verb form}} to {{bg-part form}}")
        elif tname(headt) == "bg-part":
          pagemsg("WARNING: Both participle and participle form under same head: head=%s, infl=%s" % (
            str(headt), origt))
          continue
        elif tname(headt) != "bg-part form":
          pagemsg("Both participle form and verbal noun (or something else?) under same head, will split: head=%s, infl=%s" % (
            str(headt), origt))
          part_forms_to_add_header.append((headt, t,
            g == "masculine" and "m" or g == "feminine" and "f" or g == "neuter" and "n" or "p"
          ))
      elif parttype:
        if tname(headt) == "head":
          heads = blib.fetch_param_chain(headt, "head", "head")
          if not heads:
            pagemsg("WARNING: Something wrong, {{head|bg|verb form}} missing head=: %s" % str(headt))
            continue
          origheadt = str(headt)
          blib.set_template_name(headt, "bg-part")
          del headt.params[:]
          blib.set_param_chain(headt, heads, "1", "head")
          headt.add("2", parttype)
          pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
          notes.append("convert {{head|bg|verb form}} to {{bg-part}} for participle '%s'" % parttype)
        elif tname(headt) == "bg-part":
          if getparam(headt, "5"):
            pagemsg("WARNING: Too many participles attached to {{bg-part}}: %s" % str(headt))
            continue
          origheadt = str(headt)
          if getparam(headt, "4"):
            headt.add("5", parttype)
          elif getparam(headt, "3"):
            headt.add("4", parttype)
          elif getparam(headt, "2"):
            headt.add("3", parttype)
          else:
            pagemsg("WARNING: Something wrong, no participle in {{bg-part}}: %s" % str(headt))
          pagemsg("Replaced %s with %s" % (origheadt, str(headt)))
          notes.append("add participle '%s' to existing {{bg-part}}" % parttype)
        elif tname(headt) == "bg-part form":
          pagemsg("WARNING: Both participle and participle form under same head: head=%s, infl=%s" % (
            str(headt), origt))
          continue
        else:
          pagemsg("WARNING: Something wrong, unrecognized head template: %s" % str(headt))
          continue
      blib.set_template_name(t, "inflection of")
      del t.params[:]
      t.add("1", "bg")
      if verb in verbs_to_accents:
        verb = verbs_to_accents[verb]
      else:
        pagemsg("WARNING: Unable to find accented equivalent of %s: %s" % (verb, origt))
      t.add("2", verb)
      t.add("3", "")
      for i, infl in enumerate(infls):
        t.add(str(i + 4), infl)
      pagemsg("Replaced %s with %s" % (origt, str(t)))
      notes.append("convert {{bg-verb form of}} to {{inflection of}}")

  text = str(parsed)

  if vn_forms_to_add_header:
    for headt, inflt, gender in vn_forms_to_add_header:
      m = re.search("(=+)\n%s" % re.escape(str(headt)), text)
      if not m:
        pagemsg("WARNING: Something wrong, can't find head template %s in text" % str(headt))
        continue
      indents = m.group(1)
      headword = getparam(headt, "1")
      origtext = "# " + str(inflt)
      repltext = "\n%sNoun%s\n{{bg-verbal noun form|%s|g=%s}}\n\n%s" % (
          indents, indents, headword, gender, origtext)
      newtext = text.replace(origtext, repltext)
      if len(newtext) - len(text) > len(repltext) - len(origtext):
        pagemsg("WARNING: Something wrong, made more than one replacement of %s" % origtext)
        continue
      if len(newtext) - len(text) < len(repltext) - len(origtext):
        pagemsg("WARNING: Something wrong, made less than one replacement of %s" % origtext)
        continue
      text = newtext
      notes.append("add ==Noun== header before verbal noun mixed with participle")

  if part_forms_to_add_header:
    for headt, inflt, gender in part_forms_to_add_header:
      m = re.search("(=+)\n%s" % re.escape(str(headt)), text)
      if not m:
        pagemsg("WARNING: Something wrong, can't find head template %s in text" % str(headt))
        continue
      indents = m.group(1)
      headword = getparam(headt, "1")
      origtext = "# " + str(inflt)
      repltext = "\n%sParticiple%s\n{{bg-part form|%s|g=%s}}\n\n%s" % (
          indents, indents, headword, gender, origtext)
      newtext = text.replace(origtext, repltext)
      if len(newtext) - len(text) > len(repltext) - len(origtext):
        pagemsg("WARNING: Something wrong, made more than one replacement of %s" % origtext)
        continue
      if len(newtext) - len(text) < len(repltext) - len(origtext):
        pagemsg("WARNING: Something wrong, made less than one replacement of %s" % origtext)
        continue
      text = newtext
      notes.append("add ==Participle== header before participle mixed with verbal noun")

  newtext = re.sub(r"==Verb(==+\n\{\{bg-part)", r"==Participle\1", text)
  if newtext != text:
    notes.append("change ==Verb== to ==Participle== for participle")
    text = newtext
  newtext = re.sub(r"==Verb(==+\n\{\{bg-verbal noun)", r"==Noun\1", text)
  if newtext != text:
    notes.append("change ==Verb== to ==Noun== for verbal noun")
    text = newtext
  return text, notes

parser = blib.create_argparser(u"Convert Bulgarian verb forms to standard templates",
    include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

snarf_verb_accents()

blib.do_pagefile_cats_refs(args, start, end, process_page,
  default_cats=["Bulgarian verb forms"], edit=True)
