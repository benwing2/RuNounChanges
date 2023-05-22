#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site
from lalib import remove_macrons

MACRON = u"\u0304" # macron =  ̄

etym_templates = ["bor", "inh", "der", "bor+", "inh+", "der+", "uder", "ubor", "unadapted borrowing", "lbor",
    "learned borrowing", "slbor", "semi-learned borrowing"]
etym_template_re = "(?:" + "|".join(re.escape(x) for x in etym_templates) + ")"
latin_langcodes = ["la", "CL.", "LL.", "ML.", "VL.", "EL.", "NL.", "la-cla", "la-lat", "la-med", "la-vul", "la-ecc", "la-new"]
latin_langcode_re = "(?:" + "|".join(re.escape(x) for x in latin_langcodes) + ")"

def addparam_after(t, param, value, after):
  following_param = blib.find_following_param(t, after)
  if following_param:
    t.add(param, value, before=following_param)
  else:
    t.add(param, value)

def verify_latin1_verb(lemma, pagemsg):
  lemma_page = pywikibot.Page(site, remove_macrons(lemma))
  if lemma_page:
    pagetext = blib.safe_page_text(lemma_page, pagemsg)
    parsed = blib.parse_text(pagetext)
    saw_non_1 = None
    saw_1 = None
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "la-verb":
        if getparam(t, "1").startswith("1"):
          saw_1 = unicode(t)
        else:
          saw_non_1 = unicode(t)
    if saw_non_1 and saw_1:
      pagemsg(u"WARNING: For lemma %s, saw both class-1 verb %s and non-class-1 verb %s, not adding -āre/-ārī etymon but needs manual verification" %
        (lemma, saw_1, saw_non_1))
      return False
    if saw_non_1:
      pagemsg(u"For lemma %s, saw non-class-1 verb, not adding -āre/-ārī etymon: %s" % (lemma, saw_non_1))
      return False
    if saw_1:
      pagemsg(u"For lemma %s, saw class-1 verb, adding -āre/-ārī etymon: %s" % (lemma, saw_1))
      return True
    pagemsg(u"For lemma %s, found page but didn't see any verb, assuming OK to add -āre/-ārī etymon" % lemma)
    return True
  pagemsg(u"For lemma %s, didn't find page, assuming OK to add -āre/-ārī etymon" % lemma)
  return True

es_suffixes_to_latin_etym_suffixes = [
  ({"es": "ada", "fr": u"ée"}, u"āta", None, [(u"[aā]tam$", u"āta")]),
  ({"es": "a", "fr": "e"}, "a", None, [("am$", "a")]),
  ({"es": "dad", "fr": u"té"}, u"tās", u"tātem", [(u"t[āa]tis$", u"tātem")]),
  ({"es": "tud", "fr": "tu"}, u"tūs", u"tūtem", [(u"t[ūu]tis$", u"tūtem")]),
  ({"es": "able", "fr": "able"}, u"ābilis", None, [(u"[āa]bilem$", u"ābilis")]),
  ({"es": "ble", "fr": "ble"}, u"bilis", None, [("bilem$", "bilis")]),
  ({"es": "ante", "fr": "ant"}, u"āns", "antem", [("antis$", "antem")]),
  ({"es": "ente", "fr": ["ant", "ent"]}, u"ēns", "entem", [("entis$", "entem")]),
  ({"es": "al", "fr": ["al", "el"]}, u"ālis", None, [(u"[aā]lem$", u"ālis")]),
  ({"es": u"ación", "fr": ["ation", "aison"]}, u"ātiō", u"ātiōnem", [(u"[āa]ti[ōo]nis$", u"ātiōnem")]),
  ({"es": u"ción", "fr": ["tion", "son"]}, u"tiō", u"tiōnem", [(u"ti[ōo]nis$", u"tiōnem")]),
  ({"es": u"ión", "fr": ["ion", "on"]}, u"iō", u"iōnem", [(u"i[ōo]nis$", u"iōnem")]),
  ({"es": ["ario", "ero"], "fr": ["aire", "ier"]}, u"ārius", None, [(u"[aā]rium$", u"ārius")]),
  ({"es": ["ario", "ero"], "fr": ["aire", "ier"]}, u"ārium", None, []),
  ({"es": "atorio", "fr": "ateur"}, u"ātōrius", None, [(u"[aā]tōrium$", u"ātōrius")]),
  ({"es": "torio", "fr": "teur"}, u"tōrius", None, [(u"tōrium$", u"tōrius")]),
  ({"es": "sorio", "fr": "seur"}, u"sōrius", None, [(u"sōrium$", u"sōrius")]),
  ({"es": "ado", "fr": u"é"}, u"ātus", None, [(u"[aā]tum$", u"ātus")]),
  ({"es", "ado", "fr": u"é"}, u"ātum", None, []),
  ({"es": "o"}, "us", None, [("um$", "us")]),
  ({"es": "o"}, "um", None, []),
  ({"es": "ar"}, u"āris", None, [(u"[aā]rem$", u"āris")]),
  ({"es": "ar", "fr": "er"}, u"ō", u"āre", [], verify_latin1_verb),
  ({"es": "ar", "fr": "er"}, "or", u"ārī", [], verify_latin1_verb),
  ({"es": "ecer"}, u"ēscō", u"ēscere", []),
  ({"es": "ecer"}, u"ēscor", u"ēscī", []),
  ({"es": "er"}, u"eō", u"ēre", []),
  ({"es": "er"}, "eor", u"ērī", []),
  ({"es": "ador", "fr": "eur"}, u"ātor", u"ātōrem", [(u"[aā]tōris", u"ātōrem")]),
  ({"es": "triz", "fr": "trice"}, u"trīx", u"trīcem", [(u"trīcis", u"trīcem")]),
  # Don't include -ĕre or -īre verbs because potentially either could produce an -ir or -ecer verb, so we wouldn't
  # be able to confidently extend '-iō' into either '-ere' or '-īre'.
]

deny_list_canonicalize_suffix = {
  "cata",
  "sabbata",
  "elephas",
  "stabilis",
  "datio",
  "circumdatio",
  "ratio",
  "satio",
  "Marius",
  "Macarius",
  "Hilarius",
  "varius",
}

latin_etymon_should_match = "(m|[aei]r[ei]|i)$"

def self_canonicalize_latin_term(term):
  term = unicodedata.normalize("NFC", re.sub("([AEIOUYaeiouy])(n[sf])", r"\1" + MACRON + r"\2", term))
  if term not in ["modo", "ego"]:
    term = re.sub("o$", u"ō", term)
  return term

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  retval = blib.find_modifiable_lang_section(text, None if args.partial_page else args.langname, pagemsg,
    force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  for k in xrange(2, len(subsections), 2):
    m = re.search("^===*([^=]*)=*==\n$", subsections[k - 1])
    subsectitle = m.group(1)
    if not subsectitle.startswith("Etymology"):
      continue

    def replace_gen_sg(m):
      groups = m.groups()
      if len(groups) == 3:
        temp1, source_code, gen_sg = groups
      else:
        assert len(groups) == 2
        temp1, gen_sg = groups
      temp1t = list(blib.parse_text(temp1).filter_templates())[0]
      existing_alt = getparam(temp1t, "4") or getparam(temp1t, "alt")
      if existing_alt:
        pagemsg("WARNING: When incorporating genitive singular, saw existing alt form %s: %s" %
          (existing_alt, temp1))
        return m.group(0)
      if gen_sg.endswith("is"):
        new_gen_sg = gen_sg[:-2] + "em"
        notes.append("convert Latin gen sg %s to acc sg %s" % (gen_sg, new_gen_sg))
        gen_sg = new_gen_sg
      notes.append("incorporate separate genitive singular into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      addparam_after(temp1t, "4", gen_sg, "3")
      return unicode(temp1t)

    # Do cases where the lang code on the left and right agree.
    subsections[k] = re.sub(r"(\{\{%s\|%s\|([^|{}=\[\]]+)\|[^{}]*\}\}) \(genitive(?: singular)? \{\{m\|\2\|([^{}|=\[\]]+)\}\}\)" %
      (etym_template_re, args.langcode), replace_gen_sg, subsections[k])
    # Do cases where the lang code on the left is any Latin variety and the lang code on the right is 'la'.
    subsections[k] = re.sub(r"(\{\{%s\|%s\|%s\|[^{}]*\}\}) \(genitive(?: singular)? \{\{m\|la\|([^{}|=\[\]]+)\}\}\)" %
      (etym_template_re, args.langcode, latin_langcode_re), replace_gen_sg, subsections[k])

    def replace_following_etymon(m):
      temp1, etymon = m.groups()
      temp1t = list(blib.parse_text(temp1).filter_templates())[0]
      existing_alt = getparam(temp1t, "4") or getparam(temp1t, "alt")
      if existing_alt:
        pagemsg("WARNING: When incorporating following etymon, saw existing alt form %s: %s" %
          (existing_alt, temp1))
        return m.group(0)
      if etymon.endswith("is"):
        new_etymon = etymon[:-2] + "em"
        notes.append("convert Latin gen sg %s to acc sg %s" % (etymon, new_etymon))
        etymon = new_etymon
      notes.append("incorporate following Latin etymon into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      addparam_after(temp1t, "4", etymon, "3")
      return unicode(temp1t)

    subsections[k] = re.sub(r"(\{\{%s\|%s\|%s\|[^{}]*\}\}), ''+([^'{}]+?)''+" %
      (etym_template_re, args.langcode, latin_langcode_re), replace_following_etymon, subsections[k])
    
    def replace_acc_sg_pres_act_inf(m):
      temp1, lemma_temp = m.groups()
      temp1t = list(blib.parse_text(temp1).filter_templates())[0]
      lemmat = list(blib.parse_text(lemma_temp).filter_templates())[0]
      existing_alt = getparam(temp1t, "4") or getparam(temp1t, "alt")
      if existing_alt:
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, saw existing alt form %s: %s" %
          (existing_alt, temp1))
        return m.group(0)
      existing_gloss = getparam(temp1t, "t") or getparam(temp1t, "5") or getparam(temp1t, "gloss")
      if existing_gloss:
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, saw existing gloss %s: %s" %
          (existing_gloss, temp1))
        return m.group(0)
      existing_lemma_alt = getparam(lemmat, "3") or getparam(lemmat, "alt")
      if existing_lemma_alt:
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, saw existing alt form %s in lemma: %s" %
          (existing_lemma_alt, lemma_temp))
        return m.group(0)
      non_lemma = getparam(temp1t, "3")
      if not non_lemma:
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, didn't see existing non-lemma form: %s" %
          temp1t)
        return m.group(0)
      lemma = getparam(lemmat, "2")
      if not lemma:
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, didn't see existing lemma form: %s" %
          lemma_temp)
        return m.group(0)
      for param in lemmat.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "t", "gloss", "alt"]:
          pagemsg("WARNING: Unrecognized param %s=%s in lemma template: %s" %
            (pn, unicode(param.value), lemma_temp))
          return m.group(0)
      existing_lemma_gloss = getparam(lemmat, "t") or getparam(lemmat, "4") or getparam(lemmat, "gloss")
      temp1t.add("3", lemma)
      addparam_after(temp1t, "4", non_lemma, "3")
      if existing_lemma_gloss:
        temp1t.add("t", existing_lemma_gloss)
      notes.append("incorporate separate accusative singular or present active infinitive into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      return unicode(temp1t)

    subsections[k] = re.sub(r"(\{\{%s\|%s\|%s\|[^{}]*\}\}), (?:accusative singular|singular accusative|accusative|present active infinitive|present infinitive) of (\{\{m\|la\|[^{}]*\}\})" %
      (etym_template_re, args.langcode, latin_langcode_re), replace_acc_sg_pres_act_inf, subsections[k])

    def replace_probable_acc_sg_pres_act_inf(m):
      temp1, non_lemma_temp = m.groups()
      temp1t = list(blib.parse_text(temp1).filter_templates())[0]
      non_lemmat = list(blib.parse_text(non_lemma_temp).filter_templates())[0]
      lemma = getparam(temp1t, "3")
      if not lemma:
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, didn't see existing lemma form: %s" %
          temp1)
        return m.group(0)
      non_lemma = getparam(non_lemmat, "2")
      if not non_lemma:
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, didn't see existing non-lemma form: %s" %
          non_lemma_temp)
        return m.group(0)
      if not (
        non_lemma.endswith("is") and not lemma.endswith("is") or
        re.search(u"[āēeī]re$", non_lemma) and re.search(u"[oō]$", lemma) or
        non_lemma.endswith(u"ī") and lemma.endswith("or")
      ):
        pagemsg("For lemma %s, putative non-lemma %s doesn't appear to be corresponding non-lemma: %s" %
          (lemma, non_lemma, m.group(0)))
        return m.group(0)
      existing_alt = getparam(temp1t, "4") or getparam(temp1t, "alt")
      if existing_alt:
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, saw existing alt form %s: %s" %
          (existing_alt, temp1))
        return m.group(0)
      existing_gloss = getparam(temp1t, "t") or getparam(temp1t, "5") or getparam(temp1t, "gloss")
      if existing_gloss:
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, saw existing gloss %s: %s" %
          (existing_gloss, temp1))
        return m.group(0)
      existing_non_lemma_alt = getparam(non_lemmat, "3") or getparam(non_lemmat, "alt")
      if existing_non_lemma_alt:
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, saw existing alt form %s in non-lemma: %s" %
          (existing_non_lemma_alt, non_lemma_temp))
        return m.group(0)
      for param in non_lemmat.params:
        pn = pname(param)
        if pn not in ["1", "2", "3", "4", "t", "gloss", "alt"]:
          pagemsg("WARNING: Unrecognized param %s=%s in non-lemma template: %s" %
            (pn, unicode(param.value), non_lemma_temp))
          return m.group(0)
      existing_non_lemma_gloss = getparam(non_lemmat, "t") or getparam(non_lemmat, "4") or getparam(non_lemmat, "gloss")
      if non_lemma.endswith("is"):
        new_non_lemma = non_lemma[:-2] + "em"
        notes.append("convert presumable Latin gen sg %s to acc sg %s" % (non_lemma, new_non_lemma))
        pagemsg("Convert presumable gen sg %s to acc sg %s (please verify)" % (non_lemma, new_non_lemma))
        non_lemma = new_non_lemma
      addparam_after(temp1t, "4", non_lemma, "3")
      if existing_non_lemma_gloss:
        temp1t.add("t", existing_non_lemma_gloss)
      pagemsg("WARNING: Replaced '%s' with %s, assuming accusative singular or present active infinitive, please check" % (
        m.group(0), unicode(temp1t)))
      notes.append("incorporate probable separate accusative singular or present active infinitive into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      return unicode(temp1t)

    subsections[k] = re.sub(r"(\{\{%s\|%s\|%s\|[^{}]*\}\}), (\{\{m\|la\|[^{}]*\}\})" %
      (etym_template_re, args.langcode, latin_langcode_re), replace_probable_acc_sg_pres_act_inf, subsections[k])
    
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn in etym_templates:
        if getp("1") != args.langcode:
          pagemsg("WARNING: Wrong language code in etymology template: %s" % unicode(t))
          continue
        if getp("2") not in latin_langcodes:
          continue
        lemma = getp("3")
        if not lemma:
          continue
        alt = getp("4")
        if ", " in alt:
          altparts = alt.split(", ")
          if len(altparts) > 2:
            pagemsg("WARNING: Saw more than two parts in comma-separated etymon alt text '%s': %s" %
              (alt, unicode(t)))
            continue
          alt_lemma, alt_form = altparts
          if remove_macrons(lemma) != remove_macrons(alt_lemma):
            pagemsg("WARNING: In etymology template, Latin lemma %s doesn't match alt text lemma %s: %s" %
                (lemma, alt_lemma, unicode(t)))
            continue
          if alt_lemma.startswith("*") and not alt_form.startswith("*"):
            alt_form = "*" + alt_form
          t.add("3", alt_lemma)
          addparam_after(t, "4", alt_form, "3")
          notes.append("split alt param '%s' in {{%s|%s}} into Latin lemma and non-lemma etymon" %
            (alt, tn, args.langcode))

        # move duplicative lemma to lemma slot
        lemma = getp("3")
        alt = getp("4")
        if remove_macrons(alt) == remove_macrons(lemma):
          notes.append("move duplicative Latin lemma %s from 4= to 3= in {{%s|%s}}" %
            (alt, tn, args.langcode))
          rmparam(t, "4")
          t.add("3", alt)

        # now try to add some long vowels
        lemma = getp("3")
        alt = getp("4")
        if remove_macrons(lemma) in deny_list_canonicalize_suffix:
          pagemsg("WARNING: Skipping lemma %s because in deny_list_canonicalize_suffix, review manually: %s" %
            (lemma, unicode(t)))
          continue
        if remove_macrons(alt) == remove_macrons(lemma):
          notes.append("move duplicative Latin lemma %s from 4= to 3= in {{%s|%s}}" %
            (alt, tn, args.langcode))
          rmparam(t, "4")
          t.add("3", alt)
        else:
          for es_suffix_to_latin_etym_suffix in es_suffixes_to_latin_etym_suffixes:
            if len(es_suffix_to_latin_etym_suffix) == 4:
              romance_suffix, latin_lemma_suffix, latin_form_suffix, latin_subs = es_suffix_to_latin_etym_suffix
              verify_lemma = None
            else:
              romance_suffix, latin_lemma_suffix, latin_form_suffix, latin_subs, verify_lemma = es_suffix_to_latin_etym_suffix
            if pagetitle.endswith(romance_suffix):
              if remove_macrons(lemma).endswith(remove_macrons(latin_lemma_suffix)):
                if latin_form_suffix:
                  if alt:
                    for refrom, reto in latin_subs:
                      newalt = re.sub(refrom, reto, alt)
                      if newalt != alt:
                        notes.append("canonicalize Latin non-lemma etymon %s -> %s in {{%s|%s}}" %
                          (alt, newalt, tn, args.langcode))
                        alt = newalt
                    if not remove_macrons(alt).endswith(remove_macrons(latin_form_suffix)):
                      pagemsg("WARNING: Canonicalized Latin non-lemma etymon %s doesn't match expected suffix %s: %s" %
                        (alt, latin_form_suffix, unicode(t)))
                    elif latin_form_suffix != remove_macrons(latin_form_suffix) and alt.endswith(remove_macrons(latin_form_suffix)):
                      newalt = alt[:-len(latin_form_suffix)] + latin_form_suffix
                      if newalt != alt:
                        notes.append("add missing long vowels in suffix -%s to Latin non-lemma etymon %s in {{%s|%s}}" %
                          (latin_form_suffix, alt, tn, args.langcode))
                        alt = newalt
                    elif remove_macrons(alt).endswith(remove_macrons(latin_form_suffix)):
                      newalt = alt[:-len(latin_form_suffix)] + latin_form_suffix
                      if newalt != alt:
                        pagemsg("WARNING: Possible wrong macrons in non-lemma etymon %s, expected suffix -%s, please verify: %s" %
                          (alt, latin_form_suffix, unicode(t)))
                    addparam_after(t, "4", alt, "3")
                  else:
                    if verify_lemma:
                      verified = verify_lemma(lemma, pagemsg)
                    else:
                      verified = True
                    if verified:
                      alt = lemma[:-len(latin_lemma_suffix)] + latin_form_suffix
                      notes.append("add presumably correct Latin non-lemma etymon %s for lemma %s to {{%s|%s}}" %
                        (alt, lemma, tn, args.langcode))
                      addparam_after(t, "4", alt, "3")
                else:
                  if alt:
                    for refrom, reto in latin_subs:
                      newalt = re.sub(refrom, reto, alt)
                      if newalt != alt:
                        notes.append("canonicalize Latin non-lemma etymon %s -> %s in {{%s|%s}}" %
                          (alt, newalt, tn, args.langcode))
                        alt = newalt
                    if remove_macrons(alt) == remove_macrons(lemma):
                      # We may e.g. canonicalize -am to -a, making the non-lemma etymon duplicative.
                      notes.append("move duplicative Latin lemma %s from 4= to 3= in {{%s|%s}}" %
                        (alt, tn, args.langcode))
                      rmparam(t, "4")
                      t.add("3", alt)
                    else:
                      pagemsg("WARNING: Should be no Latin non-lemma etymon for lemma %s but saw %s: %s" %
                        (lemma, alt, unicode(t)))
                  elif latin_lemma_suffix != remove_macrons(latin_lemma_suffix) and lemma.endswith(remove_macrons(latin_lemma_suffix)):
                    newlemma = lemma[:-len(latin_lemma_suffix)] + latin_lemma_suffix
                    if newlemma != lemma:
                      notes.append("add missing long vowels in suffix -%s to Latin lemma %s in {{%s|%s}}" %
                        (latin_lemma_suffix, lemma, tn, args.langcode))
                      lemma = newlemma
                      t.add("3", lemma)
                  elif remove_macrons(lemma).endswith(remove_macrons(latin_lemma_suffix)):
                    newlemma = lemma[:-len(latin_lemma_suffix)] + latin_lemma_suffix
                    if newlemma != lemma:
                      pagemsg("WARNING: Possible wrong macrons in lemma %s, expected suffix -%s, please verify: %s" %
                        (lemma, latin_lemma_suffix, unicode(t)))

                # Once we've seen the appropriage Romance and Latin suffixes, don't process further.
                break

        # make sure etymon in the right form
        lemma = getp("3")
        alt = getp("4")
        if alt.endswith("is"):
          newalt = alt[:-2] + "em"
          notes.append("convert presumable Latin gen sg %s to acc sg %s in {{%s|%s}}" %
            (alt, newalt, tn, args.langcode))
          pagemsg("Convert presumable gen sg %s to acc sg %s (please verify)" % (alt, newalt))
          alt = newalt
          addparam_after(t, "4", alt, "3")
        if alt and not re.search(latin_etymon_should_match, remove_macrons(alt)):
          pagemsg("WARNING: Latin non-lemma etymon %s doesn't look like accusative or infinitive: %s" %
            (alt, unicode(t)))

        # self-canonicalize lemma or etymon
        lemma = getp("3")
        alt = getp("4")
        if alt:
          newalt = self_canonicalize_latin_term(alt)
          if alt != newalt:
            notes.append("self-canonicalize Latin non-lemma etymon %s -> %s in {{%s|%s}}" %
              (alt, newalt, tn, args.langcode))
            alt = newalt
            addparam_after(t, "4", alt, "3")
        elif lemma:
          newlemma = self_canonicalize_latin_term(lemma)
          if lemma != newlemma:
            notes.append("self-canonicalize Latin lemma %s -> %s in {{%s|%s}}" %
              (lemma, newlemma, tn, args.langcode))
            lemma = newlemma
            t.add("3", lemma)

    subsections[k] = unicode(parsed)

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Clean up Latin etyma in Romance etymologies", include_pagefile=True, include_stdin=True)
parser.add_argument("--partial-page", action="store_true", help="Input was generated with 'find_regex.py --lang LANG' and has no ==LANG== header.")
parser.add_argument("--langcode", required=True, help="Language code of language to do")
parser.add_argument("--langname", required=True, help="Language name of language to do")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True, default_cats=["%s lemmas" % args.langname])
