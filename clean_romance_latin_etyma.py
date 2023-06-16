#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse, unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site
import lalib
from lalib import remove_macrons, remove_non_macron_accents

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

def number_of_macrons(term):
  term = unicodedata.normalize("NFD", term)
  return len([x for x in term if x == MACRON])

def verify_suffix(lemma, suffix, pagemsg):
  pagename = remove_macrons(lemma)
  lemma_page = pywikibot.Page(site, pagename)
  if lemma_page:
    pagetext = blib.safe_page_text(lemma_page, pagemsg)
    parsed = blib.parse_text(pagetext)
    saw_long_suffix = None
    saw_short_suffix = None
    for t in parsed.filter_templates():
      if lalib.la_template_is_head(t):
        headwords = lalib.la_get_headword_from_template(t, pagename, pagemsg)
        for headword in headwords:
          if headword.endswith(suffix):
            saw_long_suffix = headword
          elif headword.endswith(remove_macrons(suffix)):
            saw_short_suffix = headword
          elif (
            remove_macrons(headword).endswith(remove_macrons(suffix)) and
            number_of_macrons(headword[-len(suffix):]) > number_of_macrons(suffix)
          ):
            pagemsg("For lemma %s with suffix -%s, suffix of headword %s has more macrons than suffix, ignoring"
              % (lemma, suffix, headword))
          else:
            pagemsg("WARNING: For lemma %s with supposed suffix -%s, headword %s doesn't end with suffix"
              % (lemma, suffix, headword))
    if saw_long_suffix and saw_short_suffix:
      pagemsg("WARNING: For lemma %s and suffix -%s, saw headwords %s and %s both with and without matching macrons, not adding macrons but needs manual verification"
        % (lemma, suffix, saw_long_suffix, saw_short_suffix))
      return False
    if saw_short_suffix:
      pagemsg("For lemma %s and suffix -%s, saw headword %s without matching macrons, not adding macrons"
        % (lemma, suffix, saw_short_suffix))
      return False
    if saw_long_suffix:
      pagemsg("For lemma %s and suffix -%s, saw headword %s with matching macrons, adding macrons"
        % (lemma, suffix, saw_long_suffix))
      return True
    pagemsg("For lemma %s and suffix -%s, found page but didn't see any Latin headwords, assuming OK to add add macrons"
      % (lemma, suffix))
    return True
  pagemsg("For lemma %s and suffix -%s, didn't find page, assuming OK to add macrons" % (lemma, suffix))
  return True

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
          saw_1 = str(t)
        else:
          saw_non_1 = str(t)
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

class Suffix(object):
  def __init__(self, romance_suffix_dict, latin_lemma_suffix, latin_form_suffix=None, canonicalize_to_form_re=None,
      latin_deny_re=None, verify_lemma=None):
    self.romance_suffix_dict = romance_suffix_dict
    self.latin_lemma_suffix = latin_lemma_suffix
    self.latin_form_suffix = latin_form_suffix
    self.canonicalize_to_form_re = canonicalize_to_form_re
    self.latin_deny_re = latin_deny_re
    self.verify_lemma = verify_lemma

romance_suffixes_to_latin_etym_suffixes = [
  Suffix({"es": "ada", "pt": "ada", "ca": "ada", "fr": u"ée", "it": "ata"}, u"āta", None, [u"[aā]tam$"]),
  Suffix({"es": "ura", "pt": "ura", "ca": "ura", "fr": "ure", "it": "ura"}, u"ūra", None, [u"[uū]ram$"], latin_deny_re="aura$"),
  Suffix({"es": "osa", "pt": "osa", "ca": "osa", "fr": "euse", "it": "osa"}, u"ōsa", None, [u"[oō]sam$"]),
  Suffix({"es": "a", "pt": "a", "ca": "a", "fr": "e", "it": "a"}, "a", None, ["am$"]),
  Suffix({"es": "dad", "pt": "dade", "ca": ["dat", "tat"], "fr": u"té", "it": u"tà"}, u"tās", u"tātem", [u"t[āa]tis$"]),
  Suffix({"es": "tud", "pt": "tude", "ca": "tut", "fr": "tu", "it": u"tù"}, u"tūs", u"tūtem", [u"t[ūu]tis$"]),
  Suffix({"es": "able", "pt": u"ável", "ca": "able", "fr": "able", "it": ["abile", "evole"]}, u"ābilis", None, [u"[āa]bilem$"]),
  Suffix({"es": "ble", "pt": "vel", "ca": "ble", "fr": "ble", "it": ["bile", "vole"]}, u"bilis", None, ["bilem$"]),
  Suffix({"es": "aje", "pt": "agem", "ca": "atge", "fr": "age", "it": "aggio"}, u"āticum", None),
  Suffix({"es": "ante", "pt": "ante", "ca": "ant", "fr": "ant", "it": "ante"}, u"āns", "antem", ["antis$"]),
  Suffix({"es": "ente", "pt": "ente", "ca": "ent", "fr": ["ant", "ent"], "it": "ente"}, u"ēns", "entem", ["entis$"]),
  Suffix({"es": "al", "pt": "al", "ca": "al", "fr": ["al", "el"], "it": "ale"}, u"ālis", None, [u"[aā]lem$"]),
  Suffix({"es": u"ación", "pt": u"ação", "ca": u"ació", "fr": ["ation", "aison"], "it": "azione"}, u"ātiō", u"ātiōnem", [u"[āa]ti[ōo]nis$"]),
  Suffix({"es": u"ción", "pt": u"ção", "ca": u"ció", "fr": ["tion", "son"], "it": "zione"}, u"tiō", u"tiōnem", [u"ti[ōo]nis$"]),
  Suffix({"es": u"ión", "pt": u"ão", "ca": u"ió", "fr": ["ion", "on"], "it": "ione"}, u"iō", u"iōnem", [u"i[ōo]nis$"]),
  # Don't include -ō -> -ōnem because it will try to canonicalize verbs in -ō.
  Suffix({"es": ["ario", "ero"], "pt": [u"ário", "eiro"], "ca": ["ari", "er"], "fr": ["aire", "ier"], "it": ["ario", "aio"]}, u"ārium", None),
  Suffix({"es": ["ario", "ero"], "pt": [u"ário", "eiro"], "ca": ["ari", "er"], "fr": ["aire", "ier"], "it": ["ario", "aio"]}, u"ārius", None, [u"[aā]rium$"]),
  Suffix({"es": "atorio", "pt": u"atório", "ca": "atori", "fr": "ateur", "it": ["atorio", "atoio"]}, u"ātōrium", None),
  Suffix({"es": "atorio", "pt": u"atório", "ca": "atori", "fr": "ateur", "it": ["atorio", "atoio"]}, u"ātōrius", None, [u"[aā]tōrium$"]),
  Suffix({"es": "torio", "pt": u"tório", "ca": "tori", "fr": "teur", "it": ["torio", "toio"]}, u"tōrium", None),
  Suffix({"es": "torio", "pt": u"tório", "ca": "tori", "fr": "teur", "it": ["torio", "toio"]}, u"tōrius", None, [u"tōrium$"]),
  Suffix({"es": "sorio", "pt": u"sório", "ca": "sori", "fr": "seur", "it": ["sorio", "soio"]}, u"sōrius", None),
  Suffix({"es": "sorio", "pt": u"sório", "ca": "sori", "fr": "seur", "it": ["sorio", "soio"]}, u"sōrius", None, [u"sōrium$"]),
  Suffix({"es": "ado", "pt": "ado", "ca": "at", "fr": u"é", "it": "ato"}, u"ātum", None),
  Suffix({"es": "ado", "pt": "ado", "ca": "at", "fr": u"é", "it": "ato"}, u"ātus", None, [u"[aā]tum$"]),
  Suffix({"es": "oso", "pt": "oso", "ca": u"ós", "fr": "eux", "it": "oso"}, u"ōsum", None),
  Suffix({"es": "oso", "pt": "oso", "ca": u"ós", "fr": "eux", "it": "oso"}, u"ōsus", None, [u"[oō]sum$"]),
  Suffix({"es": "o", "pt": "o", "it": "o"}, "um", None),
  Suffix({"es": "o", "pt": "o", "it": "o"}, "us", None, ["um$"]),
  Suffix({"es": "ar", "pt": "ar", "ca": "ar", "it": "are"}, u"āris", None, [u"[aā]rem$"]),
  Suffix({"es": "ar", "pt": "ar", "ca": "ar", "fr": "er", "it": "are"}, u"ō", u"āre", verify_lemma=verify_latin1_verb),
  Suffix({"es": "ar", "pt": "ar", "ca": "ar", "fr": "er", "it": "are"}, "or", u"ārī", verify_lemma=verify_latin1_verb),
  Suffix({"es": "ecer", "pt": "ecer"}, u"ēscō", u"ēscere"),
  Suffix({"es": "ecer", "pt": "ecer"}, u"ēscor", u"ēscī"),
  Suffix({"es": "er", "pt": "er", "it": "ere"}, u"eō", u"ēre"),
  Suffix({"es": "er", "pt": "er", "it": "ere"}, "eor", u"ērī"),
  Suffix({"es": "ador", "pt": "ador", "ca": "ador", "fr": "eur", "it": "atore"}, u"ātor", u"ātōrem", [u"[aā]tōris"]),
  Suffix({"es": "dor", "pt": "dor", "ca": "dor", "fr": "eur", "it": "tore"}, u"tor", u"tōrem", [u"tōris"]),
  Suffix({"es": "triz", "pt": "triz", "ca": "triu", "fr": "trice", "it": "trice"}, u"trīx", u"trīcem", [u"trīcis"]),
  # Don't include -ĕre or -īre verbs because potentially either could produce an -ir or -ecer verb, so we wouldn't
  # be able to confidently extend '-iō' into either '-ere' or '-īre'.
]

deny_list_canonicalize_suffix = {
  "cata",
  "data",
  "datum",
  "sabbata",
  "sabbatum",
  "elephas",
  "stabilis",
  "datio",
  "circumdatio",
  "ratio",
  "satio",
  "duo",
  "Marius",
  "Macarius",
  "Hilarius",
  "varius",
  "tragemata",
  "Mosa",
  "purpura",
  "barium",
}

latin_etymon_should_match_acc_inf = "(m|[aei]r[ei]|i)$"
latin_etymon_should_match_acc_gen_inf = "(m|is|[aei]r[ei]|i)$"

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

  for k in range(2, len(subsections), 2):
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
      return str(temp1t)

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
      return str(temp1t)

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
        pagemsg("WARNING: When incorporating accusative singular or present active infinitive, saw existing gloss '%s': %s" %
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
            (pn, str(param.value), lemma_temp))
          return m.group(0)
      existing_lemma_gloss = getparam(lemmat, "t") or getparam(lemmat, "4") or getparam(lemmat, "gloss")
      temp1t.add("3", lemma)
      addparam_after(temp1t, "4", non_lemma, "3")
      if existing_lemma_gloss:
        temp1t.add("t", existing_lemma_gloss)
      notes.append("incorporate separate accusative singular or present active infinitive into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      return str(temp1t)

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
        pagemsg("WARNING: When incorporating probable accusative singular or present active infinitive, saw existing gloss '%s': %s" %
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
            (pn, str(param.value), non_lemma_temp))
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
        m.group(0), str(temp1t)))
      notes.append("incorporate probable separate accusative singular or present active infinitive into {{%s|%s|%s}}" %
        (tname(temp1t), getparam(temp1t, "1"), getparam(temp1t, "2")))
      return str(temp1t)

    subsections[k] = re.sub(r"(\{\{%s\|%s\|%s\|[^{}]*\}\}), (\{\{m\|la\|[^{}]*\}\})" %
      (etym_template_re, args.langcode, latin_langcode_re), replace_probable_acc_sg_pres_act_inf, subsections[k])
    
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn in etym_templates:
        if getp("1") != args.langcode:
          pagemsg("WARNING: Wrong language code in etymology template: %s" % str(t))
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
              (alt, str(t)))
            continue
          alt_lemma, alt_form = altparts
          forms_reversed = False
          if remove_macrons(lemma) != remove_macrons(alt_lemma):
            if remove_macrons(lemma) == remove_macrons(alt_form):
              pagemsg("In etymology template, lemma and non-lemma etymon are reversed, switching them: %s" % str(t))
              temp = alt_lemma
              alt_lemma = alt_form
              alt_form = temp
              forms_reversed = True
            else:
              pagemsg("WARNING: In etymology template, Latin lemma %s doesn't match alt text lemma %s: %s" %
                  (lemma, alt_lemma, str(t)))
              continue
          if alt_lemma.startswith("*") and not alt_form.startswith("*"):
            alt_form = "*" + alt_form
          if not re.search(latin_etymon_should_match_acc_gen_inf, remove_macrons(alt_form)):
            pagemsg("WARNING: Latin non-lemma etymon %s doesn't look like accusative, genitive or infinitive, not splitting: %s" %
              (alt_form, str(t)))
            if forms_reversed:
              t.add("4", "%s, %s" % (alt_lemma, alt_form))
              notes.append("switch reversed Latin lemma and non-lemma etymon")
            continue
          t.add("3", alt_lemma)
          addparam_after(t, "4", alt_form, "3")
          notes.append("split alt param '%s' in {{%s|%s}} into Latin lemma and non-lemma etymon" %
            (alt, tn, args.langcode))

        # now try to add some long vowels to suffixes
        lemma = getp("3")
        alt = getp("4")
        if remove_macrons(lemma) in deny_list_canonicalize_suffix:
          pagemsg("WARNING: Skipping lemma %s because in deny_list_canonicalize_suffix, review manually: %s" %
            (lemma, str(t)))
          continue
        if remove_macrons(alt) == remove_macrons(lemma):
          if number_of_macrons(lemma) > number_of_macrons(alt):
            pagemsg("WARNING: More macrons in link %s than alt text %s, not moving duplicative Latin lemma: %s"
              % (lemma, alt, str(t)))
            continue
          notes.append("move duplicative Latin lemma %s from 4= to 3= in {{%s|%s}}" %
            (alt, tn, args.langcode))
          rmparam(t, "4")
          t.add("3", alt)
        else:
          for suffix in romance_suffixes_to_latin_etym_suffixes:
            if args.langcode not in suffix.romance_suffix_dict:
              continue
            romance_suffixes = suffix.romance_suffix_dict[args.langcode]
            if type(romance_suffixes) is not list:
              romance_suffixes = [romance_suffixes]
            must_break = False
            for romance_suffix in romance_suffixes:
              if pagetitle.endswith(romance_suffix):
                if remove_macrons(lemma).endswith(remove_macrons(suffix.latin_lemma_suffix)):
                  if suffix.latin_deny_re and re.search(suffix.latin_deny_re, lemma):
                    pagemsg("WARNING: Skipping lemma %s because it matches latin_deny_re '%s', review manually: %s" %
                      (lemma, suffix.latin_deny_re, str(t)))
                    must_break = True
                    break
                  if suffix.latin_form_suffix:
                    if alt:
                      if suffix.canonicalize_to_form_re:
                        for refrom in suffix.canonicalize_to_form_re:
                          if type(refrom) is tuple:
                            refrom, reto = refrom
                          else:
                            reto = suffix.latin_form_suffix
                          newalt = re.sub(refrom, reto, alt)
                          if newalt != alt:
                            notes.append("canonicalize Latin non-lemma etymon %s -> %s in {{%s|%s}}" %
                              (alt, newalt, tn, args.langcode))
                            alt = newalt
                      if not remove_macrons(alt).endswith(remove_macrons(suffix.latin_form_suffix)):
                        pagemsg("WARNING: Canonicalized Latin non-lemma etymon %s doesn't match expected suffix %s: %s" %
                          (alt, suffix.latin_form_suffix, str(t)))
                      elif suffix.latin_form_suffix != remove_macrons(suffix.latin_form_suffix) and alt.endswith(remove_macrons(suffix.latin_form_suffix)):
                        newalt = alt[:-len(suffix.latin_form_suffix)] + suffix.latin_form_suffix
                        if newalt != alt:
                          notes.append("add missing long vowels in suffix -%s to Latin non-lemma etymon %s in {{%s|%s}}" %
                            (suffix.latin_form_suffix, alt, tn, args.langcode))
                          alt = newalt
                      elif remove_macrons(alt).endswith(remove_macrons(suffix.latin_form_suffix)):
                        newalt = alt[:-len(suffix.latin_form_suffix)] + suffix.latin_form_suffix
                        if newalt != alt and remove_non_macron_accents(newalt) != remove_non_macron_accents(alt):
                          pagemsg("WARNING: Possible wrong macrons in non-lemma etymon %s, expected suffix -%s, please verify: %s" %
                            (alt, suffix.latin_form_suffix, str(t)))
                      addparam_after(t, "4", alt, "3")
                    else:
                      if suffix.verify_lemma:
                        verified = suffix.verify_lemma(lemma, pagemsg)
                      else:
                        verified = True
                      if verified:
                        alt = lemma[:-len(suffix.latin_lemma_suffix)] + suffix.latin_form_suffix
                        notes.append("add presumably correct Latin non-lemma etymon %s for lemma %s to {{%s|%s}}" %
                          (alt, lemma, tn, args.langcode))
                        addparam_after(t, "4", alt, "3")
                  else:
                    if alt:
                      if suffix.canonicalize_to_form_re:
                        for refrom in suffix.canonicalize_to_form_re:
                          if type(refrom) is tuple:
                            refrom, reto = refrom
                          else:
                            reto = suffix.latin_form_suffix or suffix.latin_lemma_suffix
                          newalt = re.sub(refrom, reto, alt)
                          if newalt != alt:
                            notes.append("canonicalize Latin non-lemma etymon %s -> %s in {{%s|%s}}" %
                              (alt, newalt, tn, args.langcode))
                            alt = newalt
                      if remove_macrons(alt) == remove_macrons(lemma):
                        if number_of_macrons(lemma) > number_of_macrons(alt):
                          pagemsg("WARNING: More macrons in link %s than alt text %s, not moving duplicative Latin lemma: %s"
                            % (lemma, alt, str(t)))
                          must_break = True
                          break
                        # We may e.g. canonicalize -am to -a, making the non-lemma etymon duplicative.
                        notes.append("move duplicative Latin lemma %s from 4= to 3= in {{%s|%s}}" %
                          (alt, tn, args.langcode))
                        rmparam(t, "4")
                        t.add("3", alt)
                      else:
                        pagemsg("WARNING: Should be no Latin non-lemma etymon for lemma %s but saw %s: %s" %
                          (lemma, alt, str(t)))
                    elif suffix.latin_lemma_suffix != remove_macrons(suffix.latin_lemma_suffix) and lemma.endswith(remove_macrons(suffix.latin_lemma_suffix)):
                      newlemma = lemma[:-len(suffix.latin_lemma_suffix)] + suffix.latin_lemma_suffix
                      if newlemma != lemma:
                        if verify_suffix(lemma, suffix.latin_lemma_suffix, pagemsg):
                          notes.append("add missing long vowels in suffix -%s to Latin lemma %s in {{%s|%s}}" %
                            (suffix.latin_lemma_suffix, lemma, tn, args.langcode))
                          lemma = newlemma
                          t.add("3", lemma)
                    elif remove_macrons(lemma).endswith(remove_macrons(suffix.latin_lemma_suffix)):
                      newlemma = lemma[:-len(suffix.latin_lemma_suffix)] + suffix.latin_lemma_suffix
                      if newlemma != lemma and remove_non_macron_accents(newlemma) != remove_non_macron_accents(lemma):
                        pagemsg("WARNING: Possible wrong macrons in lemma %s, expected suffix -%s, please verify: %s" %
                          (lemma, suffix.latin_lemma_suffix, str(t)))

                  # Once we've seen the appropriage Romance and Latin suffixes, don't process further.
                  must_break = True
                  break
            if must_break:
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
        if alt and not re.search(latin_etymon_should_match_acc_inf, remove_macrons(alt)):
          pagemsg("WARNING: Latin non-lemma etymon %s doesn't look like accusative or infinitive: %s" %
            (alt, str(t)))

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

    subsections[k] = str(parsed)

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
