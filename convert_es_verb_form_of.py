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
      if tn == "es-conj":
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
          if conjinf.endswith("se") and not inf.endswith("se"):
            newarg1 = conjinf[:-2] + rawconj
            pagemsg("%s: Converting reflexive conjugation '%s' for non-reflexive infinitive to non-reflexive '%s'" %
                (inf, arg1, newarg1))
            arg1 = newarg1
        if arg1 not in conjs:
          conjs.append(arg1)
    if len(conjs) == 0:
      warning = "WARNING: Infinitive page exists but has no conjugations"
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

  chunks = re.split(r"^((?:# \{\{es-verb form of\|.*\n)+)", pagetext, 0, re.M)
  for k in range(1, len(chunks), 2):
    verb_form_chunk = chunks[k]
    extra_text = ""
    if not re.search(r"\A((?:# \{\{es-verb form of\|.*\}\}\n)+)\Z", verb_form_chunk):
      m = re.search(r"\A# \{\{es-verb form of\|.*\}\}(.*)\n\Z", verb_form_chunk)
      if m:
        pagemsg("WARNING: Extraneous text after {{es-verb form of}}, adding after new {{es-verb form of}}: <%s>"
          % escape_newlines(verb_form_chunk))
        extra_text = re.sub(r"\.$", "", m.group(1))
      else:
        pagemsg("WARNING: Multiple calls to {{es-verb form of}} with extraneous text, skipping: <%s>"
          % escape_newlines(verb_form_chunk))
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
      if tn != "es-verb form of":
        pagemsg("WARNING: Saw non-{{es-verb form of}} template mixed in with {{es-verb form of}} templates, skipping: %s" % origt)
        must_continue = True
        break
      is_old = False
      oldparams = ["verb", "inf", "infinitive", "end", "ending", "nocap", "nodot", "mood", "tense", "num", "number",
          "pers", "person", "formal", "sense", "sera", "gen", "gender", "par", "part", "participle", "voseo", "region"]
      for oldparam in oldparams:
        if t.has(oldparam):
          is_old = True
          break
      if not is_old:
        pagemsg("Saw new-style {{es-verb form of}}, skipping: %s" % origt)
        must_continue = True
        break
      inf = getp("1") or getp("verb") or getp("inf") or getp("infinitive")
      if not inf:
        pagemsg("WARNING: No infinitive in {{es-verb form of}}, skipping: %s" % origt)
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
        del t.params[:]
        t.add("1", conj)
        newtemp = str(t)
        expansion = expand_text(newtemp)
        if expansion is not False and expansion not in expansions:
          expansions.append(expansion)
          expansion_conjugations.append(conj)
      if len(expansions) == 0:
        pagemsg("WARNING: No expansions, can't replace old-style {{es-verb form of}} with %s, skipping: %s"
          % (newtemp, origt))
        must_continue = True
        break
      if len(expansions) > 1:
        pagemsg("WARNING: Multiple conjugations with differing expansions, can't replace old-style {{es-verb form of}}, skipping: %s"
            % ", ".join("%s=%s" % (expansion_conjugations[i], expansion) for i, expansion in enumerate(expansions)))
        must_continue = True
        break
      conj = expansion_conjugations[0]
      notes.append("replace {{es-verb form of}} conjugation(s) for infinitive [[%s]] with '%s'" % (inf, conj))
      del t.params[:]
      t.add("1", conj)
      newtemp = str(t)
      parts.append("# " + newtemp + extra_text + "\n")
    if must_continue:
      continue
    chunks[k] = "".join(parts)
    pagemsg("Replaced <%s> with <%s>" % (escape_newlines(verb_form_chunk), escape_newlines(chunks[k])))
  pagetext = "".join(chunks).rstrip("\n") + finalnl

  parsed = blib.parse_text(pagetext)
  for t in parsed.filter_templates():
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    tn = tname(t)
    if tn == "es-compound of":
      inf = getp("1") + getp("2")
      if not re.search(u"(ar|er|ir|ír)(se)?$", inf):
        pagemsg("WARNING: Strange infinitive in {{es-compound of}}, skipping: %s" % origt)
        continue
      conjs, bad_reason = lookup_conjugation(inf, pagemsg, errandpagemsg)
      if conjs is None:
        pagemsg("WARNING: Can't find conjugation for infinitive '%s', skipping: %s" % (inf, origt))
        continue
      expansions = []
      expansion_conjugations = []
      full_expansions = []
      for conj in conjs:
        newtemp = "{{es-verb form of|%s|json=1}}" % conj
        expansion = expand_text(newtemp)
        if expansion is not False:
          expansion = json.loads(expansion)
          expansion_retval = expansion["retval"]
          if expansion_retval not in expansions:
            expansions.append(expansion_retval)
            expansion_conjugations.append(conj)
            full_expansions.append(expansion)
      if len(expansions) == 0:
        pagemsg("WARNING: No expansions, can't replace {{es-compound of}} with %s, skipping: %s"
          % (newtemp, origt))
        continue
      if len(expansions) > 1:
        pagemsg("WARNING: Multiple conjugations with differing expansions, can't replace {{es-compound of}}, skipping: %s"
            % ", ".join("%s=%s" % (expansion_conjugations[i], expansion) for i, expansion in enumerate(expansions)))
        continue
      conj = expansion_conjugations[0]
      if not full_expansions[0]["partial"]:
        saw_comb = any("comb" in tag for tag in full_expansions[0]["tags"])
        all_comb = all("comb" in tag for tag in full_expansions[0]["tags"])
        if saw_comb and not all_comb:
          pagemsg("WARNING: Mixture of combination and non-combination tags   ") FIXME
      if not partial
      notes.append("replace {{es-compound of}} with {{es-verb form of|%s}} for infinitive [[%s]]" % (conj, inf))
      del t.params[:]
      t.add("1", conj)
      blib.set_template_name(t, "es-verb form of")
      pagemsg("Replaced %s with %s" % (origt, str(t)))
  pagetext = str(parsed)

  return pagetext, notes
  
parser = blib.create_argparser(u"Convert {{es-verb form of}} and {{es-compound of}} to new format", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_refs=["Template:es-verb form of"], skip_ignorable_pages=True)
