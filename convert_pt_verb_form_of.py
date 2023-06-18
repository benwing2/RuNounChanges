#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

conj_table = {}
def lookup_conjugation(inf, pagemsg, errandpagemsg):
  if inf in conj_table:
    conjs, warning = conj_table[inf]
    if warning:
      pagemsg("%s: No conjugation because '%s' (cached)" % (inf, warning))
    else:
      pagemsg("%s: Returning %s (cached)" % (inf, ", ".join("'%s'" % conj for conj in conjs)))
    return conj_table[inf]
  conjpage = pywikibot.Page(site, inf)
  conjtext = blib.safe_page_text(conjpage, errandpagemsg)
  if not conjtext:
    if blib.safe_page_exists(conjpage, errandpagemsg):
      warning = "WARNING: Infinitive page exists but is blank"
    else:
      warning = "WARNING: Infinitive page doesn't exist"
  else:
    parsed = blib.parse_text(conjtext)
    conjs = []
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "pt-conj":
        arg1 = getparam(t, "1")
        if arg1 == "":
          newconj = inf
        elif re.search("^<[^<>]*>$", arg1):
          newconj = "%s%s" % (inf, arg1)
        else:
          newconj = arg1
        if newconj == arg1:
          pagemsg("%s: Conjugation already has infinitive in it: %s" % (inf, arg1))
        else:
          pagemsg("%s: Converting conjugation '%s' to '%s'" % (inf, arg1, newconj))
          arg1 = newconj
        m = re.search("^([^<>]+)(<[^<>]*>)$", arg1)
        if m:
          conjinf, rawconj = m.groups()
        elif "<" not in arg1:
          conjinf = arg1
          rawconj = ""
        else:
          conjinf = None
          pagemsg("%s: WARNING: Can't parse out infinitive from conjugation '%s'" % (inf, arg1))
        if conjinf is not None:
          if conjinf.endswith("-se") and not inf.endswith("-se"):
            newarg1 = conjinf[:-2] + rawconj
            pagemsg("%s: Converting reflexive conjugation '%s' for non-reflexive infinitive to non-reflexive '%s'" %
                (inf, arg1, newarg1))
            arg1 = newarg1
        if arg1 not in conjs:
          conjs.append(arg1)
    if len(conjs) == 0:
      if re.search(r"==\s*Portuguese\s*==", conjtext):
        warning = "WARNING: Infinitive page exists and has a ==Portuguese== section but has no conjugations"
      else:
        warning = "WARNING: Infinitive page exists but does not have a ==Portuguese== section"
    else:
      if len(conjs) > 1:
        warning = "WARNING: Multiple conjugations %s" % ", ".join(conjs)
      conj = conjs[0]
      conj_table[inf] = (conjs, None)
      pagemsg("%s: Returning %s" % (inf, ", ".join("'%s'" % conj for conj in conjs)))
      return conj_table[inf]
  pagemsg("%s: %s" % (inf, warning))
  conj_table[inf] = (None, warning)
  pagemsg("%s: No conjugation because '%s'" % (inf, warning))
  return conj_table[inf]

def escape_newlines(text):
  return text.replace("\n", r"\n")

def process_text_on_page(index, pagetitle, pagetext):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if blib.page_should_be_ignored(pagetitle):
    return

  m = re.search(r"\A(.*?)(\n*)\Z", pagetext, re.S)
  pagetext_nonl, finalnl = m.groups()
  pagetext = pagetext_nonl + "\n\n"

  def do_sectext(sectext, do_infl_of):
    tname_re = "(?:inflection of\|pt|infl of\|pt)" if do_infl_of else "pt-verb[ -]form[ -]of"
    chunks = re.split(r"^((?:# \{\{%s\|.*\n)+)" % tname_re, sectext, 0, re.M)
    for k in range(1, len(chunks), 2):
      verb_form_chunk = chunks[k]
      extra_text = ""
      if not re.search(r"\A((?:# \{\{%s\|.*\}\}\n)+)\Z" % tname_re, verb_form_chunk):
        m = re.search(r"\A# \{\{(%s)\|.*\}\}(.*)\n\Z" % tname_re, verb_form_chunk)
        if m:
          pagemsg("WARNING: Extraneous text after {{%s}}, adding after new {{pt-verb form of}}: <%s>"
            % (m.group(1), escape_newlines(verb_form_chunk)))
          extra_text = re.sub(r"\.$", "", m.group(2))
        else:
          if do_infl_of:
            possible_templates = "{{inflection of}}/{{infl of}}"
          else:
            possible_templates = "{{pt-verb form of}}/{{pt-verb-form-of}}"
          pagemsg("WARNING: Multiple calls to %s with extraneous text, skipping: <%s>"
            % (possible_templates, escape_newlines(verb_form_chunk)))
          continue
      parsed = blib.parse_text(verb_form_chunk)
      must_continue = False
      seen_infs = set()
      parts = []
      for t in parsed.filter_templates():
        origt = str(t)
        def getp(param):
          return getparam(t, param)
        tn = tname(t)
        if tn == "pt-verb form of":
          is_old = False
          oldparams = ["dialect", "2", "3", "4", "5", "6", "tense", "number", "person", "polarity", "nocap"]
          for oldparam in oldparams:
            if t.has(oldparam):
              is_old = True
              break
          if not is_old:
            pagemsg("Saw new-style {{pt-verb form of}}, skipping: %s" % origt)
            must_continue = True
            break
          inf = getp("1")
        elif tn == "pt-verb-form-of":
          gloss_params = ["tg", "ig", "tg2", "ig2", "obj", "objtr", "imp"]
          for gloss_param in gloss_params:
            if t.has(gloss_param):
              pagemsg("WARNING: Saw gloss param %s=%s in {{pt-verb-form-of}}, skipping: %s" % (
                gloss_param, getp(gloss_param), origt))
              must_continue = True
              break
          inf = getp("1")
        elif tn in ["inflection of", "infl of"] and getp("1") == "pt":
          misc_params = ["t", "gloss", "lit", "g", "g2", "g3", "g4", "g5", "tr", "ts", "pos", "id"]
          for misc_param in misc_params:
            if t.has(misc_param):
              pagemsg("WARNING: Saw misc param %s=%s in {{%s}}, skipping: %s" % (
                misc_param, getp(misc_param), tn, origt))
              must_continue = True
              break
          inf = getp("2")
        else:
          pagemsg("WARNING: Saw non-%s template mixed in with such templates, skipping: %s" % (possible_templates, origt))
          must_continue = True
          break
        if not inf:
          pagemsg("WARNING: No infinitive in {{%s}}, skipping: %s" % (tn, origt))
          must_continue = True
          break
        if inf in seen_infs:
          continue
        seen_infs.add(inf)
        conjs, bad_reason = lookup_conjugation(inf, pagemsg, errandpagemsg)
        if conjs is None:
          pagemsg("WARNING: Can't find conjugation for infinitive '%s', skipping: %s" % (inf, origt))
          must_continue = True
          break
        expansions = []
        expansion_conjugations = []
        for conj in conjs:
          blib.set_template_name(t, "pt-verb form of")
          del t.params[:]
          t.add("1", conj)
          newtemp = str(t)
          expansion = expand_text(newtemp)
          if expansion is not False and expansion not in expansions:
            expansions.append(expansion)
            expansion_conjugations.append(conj)
        old_template_desc = tn == "pt-verb form of" and "old-style {{pt-verb form of}}" or "{{%s}}" % tn
        if len(expansions) == 0:
          pagemsg("WARNING: No expansions, can't replace %s with %s, skipping: %s" % (old_template_desc, newtemp, origt))
          must_continue = True
          break
        if len(expansions) > 1:
          pagemsg("WARNING: Multiple conjugations with differing expansions, can't replace %s, skipping: %s"
              % (old_template_desc, ", ".join(
                "%s=%s" % (expansion_conjugations[i], expansion) for i, expansion in enumerate(expansions)
              )))
          must_continue = True
          break
        conj = expansion_conjugations[0]
        notes.append("replace %s conjugation(s) for infinitive [[%s]] with {{pt-verb form of|%s}}" % (old_template_desc, inf, conj))
        del t.params[:]
        t.add("1", conj)
        newtemp = str(t)
        parts.append("# " + newtemp + extra_text + "\n")
      if must_continue:
        continue
      chunks[k] = "".join(parts)
      pagemsg("Replaced <%s> with <%s>" % (escape_newlines(verb_form_chunk), escape_newlines(chunks[k])))
    return "".join(chunks)

  # First do {{pt-verb form of}} and {{pt-verb-form-of}}.
  pagetext = do_sectext(pagetext, do_infl_of=False)

  # Then do {{inflection of}}. Do this second; if we do it first, the resulting new-style {{pt-verb form of}}
  # triggers a needless warning.
  subsections = re.split("(^==+[^=\n]+==+\n)", pagetext, 0, re.M)
  for k in range(2, len(subsections), 2):
    if "=Verb=" in subsections[k - 1] and re.search(r"\{\{head\|pt\|verb form[|}]", subsections[k]):
      parsed = blib.parse_text(subsections[k])
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["pt-verb", "pt-conj"]:
          pagemsg("WARNING: Saw verb form along with verb, skipping: %s" % (str(t)))
          must_continue = True
          break
        if tn == "head" and getparam(t, "1") != "pt":
          pagemsg("WARNING: Saw {{head}} for wrong language, skipping: %s" % (str(t)))
          must_continue = True
          break
        if tn == "head" and getparam(t, "2") != "verb form":
          pagemsg("WARNING: Saw {{head}} for wrong part of speech, skipping: %s" % (str(t)))
          must_continue = True
          break
        subsections[k] = do_sectext(subsections[k], do_infl_of=True)
  pagetext = "".join(subsections)

  pagetext = pagetext.rstrip("\n") + finalnl

  return pagetext, notes
  
parser = blib.create_argparser("Convert {{pt-verb form of}} and {{pt-verb-form-of}} to new format", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:pt-verb-form-of", "Template:pt verb form of"], skip_ignorable_pages=True)
