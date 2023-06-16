#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname, pname

def parse_aux(aux):
  if aux == "h":
    return ""
  elif aux == "s":
    return "sein"
  elif aux == "hs":
    return "haben,sein"
  elif aux == "sh":
    return "sein,haben"
  else:
    return None

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  old_generate_template = re.sub(r"\}\}$", "|generate_forms=1}}", str(origt))
  old_result = expand_text(old_generate_template)
  if not old_result:
    return None

  new_generate_template = re.sub(r"^\{\{de-conj\|", "{{User:Benwing2/de-generate-verb-forms|", str(newt))
  new_result = expand_text(new_generate_template)
  if not new_result:
    return None

  def remove_forms_in(forms, regex):
    forms = forms.split(",")
    forms = [form for form in forms if not re.search(regex, form)]
    return ",".join(forms)

  newarg1 = re.sub("<.*>", "", getparam(newt, "1")) or pagetitle
  if old_result is None:
    errandpagemsg("WARNING: Error generating old forms, can't compare")
    return False
  old_forms = blib.split_generate_args(old_result)
  if not re.search("[._]", newarg1):
    old_forms = {k: v for k, v in old_forms.items() if k != "zu_infinitive" and not k.startswith("subc")}
  old_forms = {k: v.replace("&#32;", " ").replace("&nbsp;", " ").strip().replace(" ,", ",") for k, v in old_forms.items()}
  if "_" in newarg1 and "zu_infinitive" in old_forms:
    # Fix bug in old form zu-infinitive
    old_forms["zu_infinitive"] = old_forms["zu_infinitive"].replace(" zu", " zu ")
  if "imp_2s" in old_forms and re.search("[dt]en$", newarg1):
    # Old code leaves out imperative without -e
    forms = old_forms["imp_2s"].split(",")
    if not [x for x in forms if not re.search("e($| )", x)]:
      nforms = []
      for form in forms:
        if re.search("e($| )", form):
          nforms.append(re.sub("e($| )", r"\1", form))
        nforms.append(form)
      old_forms["imp_2s"] = ",".join(nforms)
  if new_result is None:
    errandpagemsg("WARNING: Error generating new forms, can't compare")
    return False
  new_forms = blib.split_generate_args(new_result)
  if "subii_2s" in new_forms:
    # New code generates subii 2s in both -est and -st; old only in -est
    new_forms["subii_2s"] = remove_forms_in(new_forms["subii_2s"], u"^[^ ]*([^e]|ie)[sxßz]t($| )")
  if "subii_2p" in new_forms:
    # New code generates subii 2p in both -et and -t; old only in -et
    new_forms["subii_2p"] = remove_forms_in(new_forms["subii_2p"], "^[^ ]*[^e]t($| )")
  if "subc_subii_2s" in new_forms:
    # New code generates subii 2s in both -est and -st; old only in -est
    new_forms["subc_subii_2s"] = remove_forms_in(new_forms["subc_subii_2s"], u"([^e]|ie)[sxßz]t$")
  if "subc_subii_2p" in new_forms:
    # New code generates subii 2p in both -et and -t; old only in -et
    new_forms["subc_subii_2p"] = remove_forms_in(new_forms["subc_subii_2p"], "[^e]t$")
  #if "perf_sub_2s" in new_forms and "seiest" in new_forms["perf_sub_2s"] and not re.search("e[rl]n$", newarg1):
  #  # New code generates perf sub 2s in both seist and seiest; old only in seist
  #  new_forms["perf_sub_2s"] = remove_forms_in(new_forms["perf_sub_2s"], "seiest")
  if re.search(u"[sxzß]en$", newarg1):
    if "pret_2s" in new_forms:
      # New code generates pret 2s for -sen verbs in both -sest and -st; old only in -st
      new_forms["pret_2s"] = remove_forms_in(new_forms["pret_2s"], u"^[^ ]*[sxzß]est($| )")
    if "subc_pret_2s" in new_forms:
      # New code generates pret 2s for -sen verbs in both -sest and -st; old only in -st
      new_forms["subc_pret_2s"] = remove_forms_in(new_forms["subc_pret_2s"], u"[sxzß]est$")
  if re.search(u"[td]en$", newarg1):
    if "pret_2s" in new_forms:
      # New code generates pret 2s for -ten verbs in both -test and -tst; old only in -test
      new_forms["pret_2s"] = remove_forms_in(new_forms["pret_2s"], u"^[^ ]*[td]st($| )")
    if "subc_pret_2s" in new_forms:
      # New code generates pret 2s for -sen verbs in both -test and -tst; old only in -test
      new_forms["subc_pret_2s"] = remove_forms_in(new_forms["subc_pret_2s"], u"[td]st$")

  for form in set(old_forms.keys() + new_forms.keys()):
    if form not in new_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but missing in new forms" % (
        str(origt), str(newt), form, old_forms[form]))
      return False
    if form not in old_forms:
      pagemsg("WARNING: for original %s and new %s, form %s=%s in new forms but missing in old forms" % (
        str(origt), str(newt), form, new_forms[form]))
      return False
    if set(new_forms[form].split(",")) != set(old_forms[form].split(",")):
      pagemsg("WARNING: for original %s and new %s, form %s=%s in old forms but =%s in new forms" % (
        str(origt), str(newt), form, old_forms[form], new_forms[form]))
      return False
  pagemsg("%s and %s have same forms" % (str(origt), str(newt)))
  return True

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  global args

  notes = []

  pagemsg("Processing")

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    origt = str(t)
    tn = tname(t)
    newarg1 = None
    if tn == "de-conj-strong":
      presstem = getparam(t, "1")
      paststem = getparam(t, "2")
      paststem2 = getparam(t, "2b")
      pp = getparam(t, "3")
      pp2 = getparam(t, "3b")
      aux = getparam(t, "4")
      ends_in_dt = getparam(t, "5")
      pres23stem = getparam(t, "6")
      subiistem = getparam(t, "7")
      subiistem2 = getparam(t, "7b")
      strongpast = getparam(t, "8")
      shortimp = getparam(t, "9")
      seppref = getparam(t, "10")
      impnotpres23 = getparam(t, "11")
      ends_in_sxz = getparam(t, "12")
      if pres23stem == presstem:
        pagemsg("WARNING: Discarding redundant pres23stem=%s (orig 6=)" % pres23stem)
        pres23stem = ""
        if args.correct:
          t.add("6", "")
          notes.append("discard redundant 6= in {{de-conj-strong}} (pres23stem)")
      if subiistem == paststem:
        pagemsg("WARNING: Discarding redundant subiistem=%s (orig 7=)" % subiistem)
        subiistem = ""
        if args.correct:
          t.add("7", "")
          notes.append("discard redundant 7= in {{de-conj-strong}} (subiistem)")
      prestem_actually_ends_in_dt = re.search("[dt]$", presstem)
      prestem_actually_ends_in_sxz = re.search(u"[sxzß]$", presstem)
      if (not not prestem_actually_ends_in_dt) != (not not ends_in_dt):
        pagemsg("WARNING: explicit ends_in_dt=%s (orig 5=) not same as prestem_actually_ends_in_dt=%s for presstem=%s (orig 1=)" % (
          not not ends_in_dt, not not prestem_actually_ends_in_dt, presstem))
        if args.correct:
          if prestem_actually_ends_in_dt:
            t.add("5", "e")
            notes.append("add 5=e in {{de-conj-strong}} because stem ends in -d or -t")
          else:
            t.add("5", "")
            notes.append("remove 5= in {{de-conj-strong}} because stem doesn't end in -d or -t")
      if (not not prestem_actually_ends_in_sxz) != (not not ends_in_sxz):
        pagemsg("WARNING: explicit ends_in_sxz=%s (orig 12=) not same as prestem_actually_ends_in_sxz=%s for presstem=%s (orig 1=)" % (
          not not ends_in_sxz, not not prestem_actually_ends_in_sxz, presstem))
        if args.correct:
          if prestem_actually_ends_in_sxz:
            t.add("12", "a")
            notes.append(u"add 12=a in {{de-conj-strong}} because stem ends in -s, -z or -ß")
          else:
            t.add("12", "")
            notes.append(u"remove 12= in {{de-conj-strong}} because stem doesn't end in -s, -z or -ß")
      if seppref:
        seppref = seppref.replace("&#32;", " ").replace("&nbsp;", " ")
        seppref_with_underscore = seppref.replace(" ", "_")
        if seppref_with_underscore.endswith("_"):
          lemma_with_dot = "%s%sen" % (seppref_with_underscore, presstem)
        else:
          lemma_with_dot = "%s.%sen" % (seppref_with_underscore, presstem)
        lemma = "%s%sen" % (seppref, presstem)
      else:
        lemma_with_dot = "%sen" % presstem
        lemma = lemma_with_dot
      if lemma != pagetitle:
        pagemsg("WARNING: Pagetitle doesn't match lemma %s constructed from presstem=%s (orig 1=) and seppref=%s (orig 10=)" % (
          lemma, presstem, seppref))
      pres23stem_ao_umlaut = not not re.search(u"[äö]", pres23stem)
      if impnotpres23:
        if not pres23stem:
          pagemsg("WARNING: impnotpres23=%s (orig 11=) specified but not pres23stem (orig 6=)" % impnotpres23)
          if args.correct:
            t.add("11", "")
            notes.append("remove 11= (impnotpres23) in {{de-conj-strong}} because pres23stem (6=) not given")
        elif not pres23stem_ao_umlaut:
          pagemsg(u"WARNING: impnotpres23=%s (orig 11=) specified but pres23stem=%s (orig 6=) doesn't have ä or ö" % (impnotpres23, pres23stem))
          if args.correct:
            t.add("11", "")
            notes.append(u"remove 11= (impnotpres23) in {{de-conj-strong}} because pres23stem (6=) doesn't have ä or ö")
      elif pres23stem_ao_umlaut:
        pagemsg(u"WARNING: impnotpres23 (orig 11=) not specified but pres23stem=%s (orig 6=) has ä or ö" % pres23stem)
        if args.correct:
          t.add("11", "a")
          notes.append(u"add 11=a (impnotpres23) in {{de-conj-strong}} because pres23stem (6=) has ä or ö")
      if shortimp:
        if not pres23stem:
          pagemsg("WARNING: shortimp=%s (orig 9=) specified but not pres23stem (orig 6=)" % shortimp)
          if args.correct:
            t.add("9", "")
            notes.append("remove 9= (shortimp) in {{de-conj-strong}} because pres23stem (6=) not given")
      elif pres23stem and not pres23stem_ao_umlaut:
        pagemsg(u"WARNING: shortimp (orig 9=) not specified but pres23stem=%s (orig 6=) given without ä or ö" % pres23stem)
        if args.correct:
          t.add("9", "a")
          notes.append(u"add 9=a (shortimp) in {{de-conj-strong}} because non-redundant pres23stem (6=) given without ä or ö")
      parts = []
      parts.append(lemma_with_dot)
      if lemma.endswith("haben"):
        parts.append("<irreg>")
      else:
        parts.append("<")
        if pres23stem:
          if pres23stem.endswith("t"):
            parts.append("%s-#" % pres23stem)
          else:
            parts.append("%st#" % pres23stem)
        if not strongpast:
          pagemsg("Saw weak past for strong verb %s" % lemma_with_dot)
        parts.append(paststem + ("" if strongpast else "te"))
        if paststem2:
          parts.append(":" + paststem2 + ("" if strongpast else "te"))
        parts.append("," + pp)
        if pp2:
          parts.append(":" + pp2)
        if subiistem and subiistem != paststem:
          parts.append("," + subiistem + ("e" if strongpast else "te"))
        if subiistem2:
          if not subiistem:
            pagemsg("WARNING: Saw subiistem2=%s (orig 7b=) without subiistem (orig 7=)" % (subiistem2))
          else:
            parts.append(":" + subiistem2 + ("e" if strongpast else "te"))
        auxval = parse_aux(aux)
        if auxval is None:
          pagemsg("WARNING: Unrecognized aux=%s (orig 4=)" % aux)
          continue
        if auxval:
          parts.append("." + auxval)
        if lemma.endswith("sehen"):
          parts.append(".longimp")
        parts.append(">")
      newarg1 = "".join(parts)
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "2b", "3", "3b", "4", "5", "6", "7", "7b", "8", "9", "10", "11", "12"]:
          pagemsg("WARNING: Unrecognized param %s=%s" % (pn, str(param.value)))
          must_continue = True
          break
      if must_continue:
        continue
      if args.correct:
        pagemsg("Would replace %s with {{de-conj|%s}}" % (str(t), newarg1))
        maxarg = 0
        # Find maximum argument
        for i in range(1, 13):
          if getparam(t, str(i)):
            maxarg = i
        # Fill in blank arguments for any missing arguments below that
        for i in range(1, maxarg):
          if not t.has(str(i)):
            t.add(str(i), "")
        # Remove any blank arguments above that
        for i in range(maxarg + 1, 13):
          if t.has(str(i)):
            rmparam(t, str(i))
        if str(t) != origt and not notes:
          notes.append("add missing blank arguments in {{de-conj-strong}}")
        continue
    elif tn == "de-conj-weak":
      presstem = getparam(t, "1")
      pp = getparam(t, "2")
      aux = getparam(t, "3")
      infix_e = getparam(t, "4")
      ends_in_sxz = getparam(t, "5")
      seppref = getparam(t, "6").replace("&#32;", " ").replace("&nbsp;", " ")
      seppref2 = getparam(t, "7").replace("&#32;", " ").replace("&nbsp;", " ")
      seppref_with_underscore = seppref.replace(" ", "_")
      seppref2_with_underscore = seppref2.replace(" ", "_")
      overall_seppref_with_underscore = ""
      if seppref_with_underscore:
        overall_seppref_with_underscore += seppref_with_underscore + "."
      if seppref2_with_underscore:
        overall_seppref_with_underscore += seppref2_with_underscore + "."
      overall_seppref_with_underscore = overall_seppref_with_underscore.replace("_.", "_")
      overall_seppref = seppref + seppref2
      lemma_with_dot = "%s%sen" % (overall_seppref_with_underscore, presstem)
      lemma = "%s%sen" % (overall_seppref, presstem)
      auxval = parse_aux(aux or "h")
      if auxval is None:
        pagemsg("WARNING: Unrecognized aux=%s (orig 3=)" % aux)
        continue
      if auxval:
        newarg1 = "<" + auxval + ">"
      else:
        newarg1 = ""
      if lemma_with_dot != pagetitle:
        newarg1 = lemma_with_dot + newarg1
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "5", "6", "7"]:
          pagemsg("WARNING: Unrecognized param %s=%s" % (pn, str(param.value)))
          must_continue = True
          break
      if must_continue:
        continue
    elif tn in ["de-conj-weak-eln", "de-conj-weak-ern"]:
      presstem = getparam(t, "1")
      pp = getparam(t, "2")
      aux = getparam(t, "3")
      seppref = getparam(t, "4")
      if seppref:
        seppref = seppref.replace("&#32;", " ").replace("&nbsp;", " ")
        seppref_with_underscore = seppref.replace(" ", "_")
        if seppref_with_underscore.endswith("_"):
          lemma_with_dot = "%s%s%s" % (seppref_with_underscore, presstem, tn[-3:])
        else:
          lemma_with_dot = "%s.%s%s" % (seppref_with_underscore, presstem, tn[-3:])
        lemma = "%s%s%s" % (seppref, presstem, tn[-3:])
      else:
        lemma_with_dot = "%s%s" % (presstem, tn[-3:])
        lemma = lemma_with_dot
      auxval = parse_aux(aux)
      if auxval is None:
        pagemsg("WARNING: Unrecognized aux=%s (orig 3=)" % aux)
        continue
      if auxval:
        newarg1 = "<%s>" % auxval
      else:
        newarg1 = ""
      if lemma_with_dot != pagetitle:
        newarg1 = lemma_with_dot + newarg1
    elif tn == "de-conj-pp":
      infstem = getparam(t, "1")
      pres13 = getparam(t, "2")
      paststem = getparam(t, "3")
      subiistem = getparam(t, "4")
      pp = getparam(t, "5")
      aux = getparam(t, "6")
      ends_in_sxz = getparam(t, "7")
      seppref = getparam(t, "pref")
      if seppref:
        seppref = seppref.replace("&#32;", " ").replace("&nbsp;", " ")
        seppref_with_underscore = seppref.replace(" ", "_")
        if seppref_with_underscore.endswith("_"):
          lemma_with_dot = "%s%sen" % (seppref_with_underscore, infstem)
        else:
          lemma_with_dot = "%s.%sen" % (seppref_with_underscore, infstem)
        lemma = "%s%sen" % (seppref, infstem)
      else:
        lemma_with_dot = "%sen" % infstem
        lemma = lemma_with_dot
      auxval = parse_aux(aux)
      parts = []
      parts.append(lemma_with_dot)
      parts.append("<pretpres.")
      parts.append("%s#" % pres13)
      parts.append(paststem + "te")
      parts.append("," + pp)
      if subiistem and subiistem != paststem:
        parts.append("," + subiistem + "te")
      auxval = parse_aux(aux)
      if auxval is None:
        pagemsg("WARNING: Unrecognized aux=%s (orig 6=)" % aux)
        continue
      if auxval:
        parts.append("." + auxval)
      parts.append(">")
      newarg1 = "".join(parts)
      must_continue = False
      for param in t.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "5", "6", "7", "pref"]:
          pagemsg("WARNING: Unrecognized param %s=%s" % (pn, str(param.value)))
          must_continue = True
          break
      if must_continue:
        continue

    if newarg1 is not None:
      newt = list(blib.parse_text("{{de-conj}}").filter_templates())[0]
      newt.add("1", newarg1)
      if not args.compare or compare_new_and_old_templates(t, newt, pagetitle, pagemsg, errandpagemsg):
        notes.append("convert {{%s}} to {{de-conj|%s}}" % (tn, newarg1))
        del t.params[:]
        blib.set_template_name(t, "de-conj")
        if newarg1:
          t.add("1", newarg1)

    if str(t) != origt:
      pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

  return str(parsed), notes

parser = blib.create_argparser("Convert {{de-conj-strong}} to {{de-conj}}",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--correct", action="store_true", help="Correct bugs in older template.")
parser.add_argument("--compare", action="store_true", help="Compare new with old before changing.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_refs=["Template:de-conj-strong"], edit=True, stdin=True)
