#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, json

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
      if tn in ["it-conj", "it-conj-rfc"]:
        arg1 = getparam(t, "1")
        # remove references, which may include embedded <<...>> cross-refs etc.
        arg1 = re.sub(r"\[(r|ref):[^\[\]]*?\]", "", arg1)
        if re.search("^<[^<>]*>$", arg1):
          newconj = "%s%s" % (inf, arg1)
        elif "<" in arg1:
          newconj = arg1
        else:
          newconj = "%s<%s>" % (inf, arg1)
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
          if conjinf.endswith("si") and not inf.endswith("si"):
            newarg1 = conjinf[:-2] + rawconj
            pagemsg("%s: Converting reflexive conjugation '%s' for non-reflexive infinitive to non-reflexive '%s'" %
                (inf, arg1, newarg1))
            arg1 = newarg1
        if arg1 not in conjs:
          conjs.append(arg1)
    if len(conjs) == 0:
      if re.search(r"==\s*Italian\s*==", conjtext):
        warning = "WARNING: Infinitive page exists and has an ==Italian== section but has no conjugations"
      else:
        warning = "WARNING: Infinitive page exists but does not have an ==Italian== section"
    else:
      if len(conjs) > 1:
        warning = "WARNING: Multiple conjugations %s" % ", ".join(conjs)
        pagemsg("%s: %s" % (inf, warning))
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

  def do_sectext(sectext, secheadertext):
    tname_re = "(?:(?:inflection|infl) of\|it)"
    chunks = re.split(r"^((?:# \{\{%s\|.*\n)+)" % tname_re, sectext, 0, re.M)
    this_note_parts = []
    for k in xrange(1, len(chunks), 2):
      verb_form_chunk = chunks[k]
      extra_text = ""
      if not re.search(r"\A((?:# \{\{%s\|.*\}\}\n)+)\Z" % tname_re, verb_form_chunk):
        m = re.search(r"\A# \{\{(%s)\|.*\}\}(.*)\n\Z" % tname_re, verb_form_chunk)
        if m:
          pagemsg("WARNING: Extraneous text after {{%s}}, adding after new {{it-verb form of}}: <%s>"
            % (m.group(1), escape_newlines(verb_form_chunk)))
          extra_text = re.sub(r"\.$", "", m.group(2))
        else:
          possible_templates = "{{inflection of}}/{{infl of}}"
          pagemsg("WARNING: Multiple calls to %s with extraneous text, skipping: <%s>"
            % (possible_templates, escape_newlines(verb_form_chunk)))
          continue
      parsed = blib.parse_text(verb_form_chunk)
      must_continue = False
      seen_infs = set()
      parts = []
      for t in parsed.filter_templates():
        origt = unicode(t)
        def getp(param):
          return getparam(t, param)
        tn = tname(t)
        if tn == "it-verb form of":
          pagemsg("Saw new-style {{it-verb form of}}, skipping: %s" % origt)
          must_continue = True
          break
        elif tn in ["inflection of", "infl of"] and getp("1") == "it":
          misc_params = ["g", "g2", "g3", "g4", "g5", "tr", "ts", "pos"]
          for misc_param in misc_params:
            if t.has(misc_param):
              pagemsg("WARNING: Saw misc param %s=%s in {{%s}}, skipping: %s" % (
                misc_param, getp(misc_param), tn, origt))
              must_continue = True
              break
          inf = getp("2")
          gloss = getp("t") or getp("gloss")
          lit = getp("lit")
          id = getp("id")
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
          blib.set_template_name(t, "User:Benwing2/it-verb form of")
          del t.params[:]
          t.add("1", conj)
          newtemp = unicode(t)
          expansion = expand_text(newtemp)
          if expansion is not False and expansion not in expansions:
            expansions.append(expansion)
            expansion_conjugations.append(conj)
        old_template_desc = "{{%s}}" % tn
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
        this_note_parts.append((old_template_desc, inf, conj))
        blib.set_template_name(t, "it-verb form of")
        del t.params[:]
        t.add("1", conj)
        if gloss:
          t.add("t", gloss)
        if lit:
          t.add("lit", lit)
        if id:
          t.add("id", id)
        t.add("noheadword", "1")
        newtemp = unicode(t)
        parts.append("# " + newtemp + extra_text + "\n")
      if must_continue:
        continue
      chunks[k] = "".join(parts)
      pagemsg("Replaced <%s> with <%s>" % (escape_newlines(verb_form_chunk), escape_newlines(chunks[k])))
    retval = "".join(chunks)
    retval_body, retval_tail = blib.split_trailing_separator_and_categories(retval)
    retval_body_included_headword = (
      re.sub(r"\A\{\{head\|it\|verb form(?:\|head=[^{}|=]*)?\}\}\n\n*# (\{\{it-verb form of\|.*)\|noheadword=1(\}\}\n*)\Z", r"\1\2", retval_body)
    )
    if retval_body_included_headword != retval_body:
      pagemsg("Removed headword and |noheadword=1 from {{it-verb form of}}")
      retval_body = retval_body_included_headword
      for old_template_desc, inf, conj in this_note_parts:
        notes.append("replace headword and %s conjugation(s) for infinitive [[%s]] with {{it-verb form of|%s}}"
          % (old_template_desc, inf, conj))
    else:
      def split_headers(m):
        verb_form_ofs, trailing = m.groups()
        verb_form_ofs = verb_form_ofs.rstrip("\n").split("\n")
        verb_form_ofs = [re.sub(r"^# (.*)\|noheadword=1(.*)$", r"\1\2", verb_form_of) for verb_form_of in verb_form_ofs]
        return ("\n\n%s" % secheadertext).join(verb_form_ofs) + "\n" + trailing
      # there may be more than one {{it-verb form of}}; split headers
      retval_body_split_headword = (
        re.sub(r"\A\{\{head\|it\|verb form(?:\|head=[^{}|=]*)?\}\}\n\n*((?:# \{\{it-verb form of\|.*\|noheadword=1\}\}\n)+)(\n*)\Z",
          split_headers, retval_body)
      )
      if retval_body_split_headword != retval_body:
        pagemsg("Split multiple {{it-verb form of}} invocations into separate header sections")
        retval_body = retval_body_split_headword
        for i, (old_template_desc, inf, conj) in enumerate(this_note_parts):
          notes.append("replace headword and %s conjugation(s) for infinitive [[%s]] with %s{{it-verb form of|%s}}"
            % (old_template_desc, inf, "header + " if i > 0 else "", conj))
      else:
        for old_template_desc, inf, conj in this_note_parts:
          notes.append("replace %s conjugation(s) for infinitive [[%s]] with {{it-verb form of|%s|noheadword=1}}"
            % (old_template_desc, inf, conj))
    return retval_body + retval_tail

  # Do {{inflection of}}.
  subsections = re.split("(^==+[^=\n]+==+\n)", pagetext, 0, re.M)
  for k in xrange(2, len(subsections), 2):
    if "=Verb=" in subsections[k - 1] and re.search(r"\{\{head\|it\|verb form[|}]", subsections[k]):
      parsed = blib.parse_text(subsections[k])
      must_continue = False
      for t in parsed.filter_templates():
        tn = tname(t)
        if tn in ["it-verb", "it-verb-rfc", "it-conj", "it-conj-rfc"]:
          pagemsg("WARNING: Saw verb form along with verb, skipping: %s" % (unicode(t)))
          must_continue = True
          break
        if tn == "head" and getparam(t, "1") != "it":
          pagemsg("WARNING: Saw {{head}} for wrong language, skipping: %s" % (unicode(t)))
          must_continue = True
          break
        if tn == "head" and getparam(t, "2") != "verb form":
          pagemsg("WARNING: Saw {{head}} for wrong part of speech, skipping: %s" % (unicode(t)))
          must_continue = True
          break
        subsections[k] = do_sectext(subsections[k], subsections[k - 1])
  pagetext = "".join(subsections)

  pagetext = pagetext.rstrip("\n") + finalnl

  return pagetext, notes
  
parser = blib.create_argparser(u"Convert {{inflection of|it}} to {{it-verb form of}}", include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
    default_cats=["Italian verb forms"], skip_ignorable_pages=True)
