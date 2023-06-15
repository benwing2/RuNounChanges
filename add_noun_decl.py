#!/usr/bin/env python
# -*- coding: utf-8 -*-

# Fix ru-noun headers to be ru-noun+ and ru-proper noun to ru-proper noun+
# for multiword nouns by looking up the individual declensions of the words.

# Example page:
#
# ==Russian==
#
# ===Pronunciation===
# * {{ru-IPA|са́харная ва́та}}
#
# ===Noun===
# {{ru-noun|[[сахарный|са́харная]] [[вата|ва́та]]|f-in}}
#
# # [[cotton candy]], [[candy floss]], [[fairy floss]]
#
# ====Declension====
# {{ru-decl-noun-see|сахарный|вата}}
#
# [[Category:ru:Foods]]

# FIXME:
#
# 1. (DONE, NEEDS TESTING) Warnings like this should be fixable:
#    Page 99 Дедушка Мороз: WARNING: Can't sub word link [[мороз|Моро́з]] into decl lemma моро́з
# 2. (DONE) This warning should be fixable:
#    Page 756 десертное вино: WARNING: case nom_sg, existing forms [[десе́ртный|десе́ртное]] [[вино́]] not same as proposed [[десертный|десе́ртное]] [[вино́]]
# 3. (DONE, DEFINITELY NEEDS TESTING) Plural nouns
# 4. (DONE, NEEDS TESTING) Multiple inflected nouns, esp. in hyphenated compounds
# 5. (DONE) Don't choke when found notes= as long as there's only one
#    (choke if multiple because the footnote symbols might be duplicated),
#    instead issue warning
# 6. (DONE) Check that all parts of ru-decl-noun-see are used, error if not
# 7. (DONE) Handle all_parts_declined
# 8. Check on гей-брак, do both parts decline?
# 9. If there's a loc with на or в or something similar, warn about it because
#    it may not convert well as a single-word override, cf. ось зла
# 10. (DONE) Implement use_given_page_decl
# 11. (DONE) Adding declension to proper nouns, should use n=sg if proper noun
#    is singular-only

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

import rulib
import runounlib

# [singular ending, plural ending, gender, requires special case (1)]
pl_data = [
    ["", u"ы", "m", False],
    ["", u"и", "m", False],
    [u"ь", u"и", "mf", False],
    [u"й", u"и", "m", False],
    ["", u"а", "m", True],
    [u"а", u"ы", "f", False],
    [u"а", u"и", "f", False],
    [u"я", u"и", "f", False],
    [u"о", u"а", "n", False],
    [u"е", u"а", "n", False],
    [u"е", u"я", "n", False],
    [u"о", u"и", "n", True]
]

infer_adj_lemma = [
    [u"ая", u"ый"],
    [u"а́я", u"о́й"],
    [u"яя", u"ий"],
    [u"ое", u"ый"],
    [u"о́е", u"о́й"],
    [u"ее", u"ий"],
]

consonant_re = u"[бдфгклмнпрствхзшщчжц]"

particles = [
  # List of prepositions and particles, from ru-pron.lua
  u"по", u"в", u"на", u"до",
  u"без", u"близ", u"в", u"во", u"до",
  u"из-под", u"из-за", u"за", u"из", u"изо",
  u"к", u"ко", u"меж", u"на", u"над", u"надо", u"о", u"об", u"обо", u"от",
  u"по", u"под", u"подо", u"пред", u"предо", u"при", u"про", u"перед", u"передо",
  u"через", u"с", u"со", u"у", u"не",
  # Others
  u"и", u"де"
  ]

# List of words where we use the specified declension, to deal with cases
# where there are multiple declensions; we have to be careful here to make
# sure more than one declension isn't actually used in different lemmas
use_given_decl = {u"туз": u"{{ru-noun-table|b}}",
    u"род": u"{{ru-noun-table|e}}",
    u"лев": u"{{ru-noun-table|b||*|a=an}}",
    u"ключ": u"{{ru-noun-table|b}}",
    u"плата": u"{{ru-noun-table|пла́та}}",
    u"брак": u"{{ru-noun-table}}",
}

use_given_page_decl = {
    u"двоюродный дед": {u"дед":u"{{ru-noun-table|a=an}}"},
    u"двоюродный дядя": {u"дядя":u"{{ru-noun-table|дя́дя|(2)|or|c|дя́дя|-ья|a=an}}"},
    u"шах и мат": {u"мат":u"{{ru-noun-table}}"},
    u"ионический ордер": {u"ордер":u"{{ru-noun-table|о́рдер|or|c||(1)}}"},
    u"ионический орден": {u"орден":u"{{ru-noun-table|c|о́рден|(1)}}"},
    u"коринфский ордер": {u"ордер":u"{{ru-noun-table|о́рдер|or|c||(1)}}"},
    u"коринфский орден": {u"орден":u"{{ru-noun-table|c|о́рден|(1)}}"},
    u"корпус турбины": {u"корпус":u"{{ru-noun-table|ко́рпус}}"},
    u"бронирование кабины": {u"бронирование":u"{{ru-noun-table|бронирова́ние}}"},
    u"троюродный дядя": {u"дядя":u"{{ru-noun-table|дя́дя|(2)|or|c|дя́дя|-ья|a=an}}"},
    u"половой орган": {u"орган":u"{{ru-noun-table|о́рган}}"},
    u"вес нетто": {u"вес":u"{{ru-noun-table|c||(1)}}"},
    u"древесный уголь": {u"уголь":u"{{ru-noun-table|a,b|у́голь|m*}}"},
    u"ось зла": {u"ось":u"{{ru-noun-table|f''||f|loc=на +}}"},
    u"свет очей": {u"свет":u"{{ru-noun-table|par=све́ту|loc=свету́|n=sg}}"},
    u"дорожный чек": {u"чек":u"{{ru-noun-table}}"},
    u"зелёный лук": {u"лук":u"{{ru-noun-table}}"},
    u"воздушное судно": {u"судно":u"{{ru-noun-table|c|су́дно|(2)|суд}}"},
    u"Пепельная среда": {u"среда":u"{{ru-noun-table|f|среда́}}"},
    u"зелёный свет": {u"свет":u"{{ru-noun-table|par=све́ту|loc=свету́|n=sg}}"},
    u"окружающая среда": {u"среда":u"{{ru-noun-table|d|среда́}}"},
    u"парусное судно": {u"судно":u"{{ru-noun-table|c|су́дно|(2)|суд}}"},
    u"барабанный бой": {u"бой":u"{{ru-noun-table|c|loc=бою́}}"},
    u"ордер на арест": {u"ордер":u"{{ru-noun-table|c|о́рдер|(1)}}"},
    u"чёрная американка": {u"американка":u"{{ru-noun-table|америка́нка|*|a=an}}"},
    u"красный свет": {u"свет":u"{{ru-noun-table|par=све́ту|loc=свету́|n=sg}}"},
    u"жёлтый свет": {u"свет":u"{{ru-noun-table|par=све́ту|loc=свету́|n=sg}}"},
    u"амарантовый цвет": {u"цвет":u"{{ru-noun-table|c||(1)|par=+}}"},
    u"противоположный пол": {u"пол":u"{{ru-noun-table|e}}"},
    u"звуковая волна": {u"волна":u"{{ru-noun-table|f,d|волна́}}"},
    u"ночной клуб": {u"клуб":u"{{ru-noun-table}}"},
    u"правоохранительные органы": {u"орган":u"{{ru-noun-table|о́рган}}"},
    u"негласное правило": {u"правило":u"{{ru-noun-table|пра́вило}}"},
    u"степная рысь": {u"рысь":u"{{ru-noun-table||f|a=an}}"},
    u"ход конём": {u"ход":u"{{ru-noun-table|c|n=sg|par=+|loc=в +,на +}}"},
    u"Ростов-на-Дону": {u"Ростов":u"{{ru-noun-table|Росто́в|n=sg}}"},
}

allow_no_inflected_noun = [
    u"крайний нападающий",
    u"придыхательный согласный",
    u"разрисованный Пикассо",
    u"Пикассо прямоугольчатый",
    u"сербско-хорватский",
]

is_short_adj = [
    u"ахиллесов",
    u"крокодилов"
]

is_uninflected = [
    u"фибоначчи",
]

all_parts_declined = [
    u"э оборотное",
    u"апельсиновый сок",
    u"бульбоуретральная железа",
    u"земляной волк",
    u"отложительный падеж",
    u"снежный человек",
    u"крайний нападающий",
    u"шапка-невидимка",
]

keep_locative = [
    u"социальная сеть",
    u"Западный берег реки Иордан",
    u"Западный берег"
]
    
def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  subpagetitle = re.sub("^.*:", "", pagetitle)

  notes = []

  parsed = blib.parse_text(text)

  # Find the declension arguments for LEMMA and inflected form INFL,
  # the WORDINDth word in the expression. Return value is a tuple of
  # four items: a list of (NAME, VALUE) tuples for the arguments, whether
  # the word is an adjective, the value of n= (if given), and the value
  # of a= (if given).
  def find_decl_args(lemma, infl, wordind):
    declpage = pywikibot.Page(site, lemma)
    if rulib.remove_accents(infl) == lemma:
      wordlink = "[[%s]]" % infl
    else:
      wordlink = "[[%s|%s]]" % (lemma, infl)

    if not declpage.exists():
      if lemma in is_short_adj or re.search(u"(ий|ый|ой)$", lemma):
        pagemsg("WARNING: Page doesn't exist, assuming word #%s adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return [("1", wordlink), ("2", "+")], True, None, None
      else:
        pagemsg("WARNING: Page doesn't exist, can't locate decl for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
    parsed = blib.parse_text(declpage.text)
    decl_templates = []
    headword_templates = []
    decl_z_templates = []
    for t in parsed.filter_templates():
      tname = unicode(t.name)
      if tname in ["ru-noun-table", "ru-decl-adj"]:
        pagemsg("find_decl_args: Found decl template: %s" % unicode(t))
        decl_templates.append(t)
      if tname in ["ru-noun", "ru-proper noun"]:
        pagemsg("find_decl_args: Found headword template: %s" % unicode(t))
        headword_templates.append(t)
      if tname in ["ru-decl-noun-z"]:
        pagemsg("find_decl_args: Found z-decl template: %s" % unicode(t))
        decl_z_templates.append(t)

    if not decl_templates:
      if decl_z_templates:
        # {{ru-decl-noun-z|звезда́|f-in|d|ё}}
        # {{ru-decl-noun-z|ёж|m-inan|b}}
        if len(decl_z_templates) > 1:
          pagemsg("WARNING: Multiple decl-z templates during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          return None
        else:
          decl_z_template = decl_z_templates[0]
          headword_template = None
          pagemsg("find_decl_args: Using z-decl template: %s" %
              unicode(decl_z_template))
          if len(headword_templates) == 0:
            pagemsg("WARNING: find_decl_args: No headword templates for use with z-decl template conversion during decl lookup for word #%s: lemma=%s, infl=%s, zdecl=%s" %
                (wordind, lemma, infl, unicode(decl_z_template)))
          elif len(headword_templates) > 1:
            pagemsg("WARNING: find_decl_args: Multiple headword templates for use with z-decl template conversion during decl lookup for word #%s, ignoring: lemma=%s, infl=%s, zdecl=%s" %
                (wordind, lemma, infl, unicode(decl_z_template)))
          else:
            headword_template = headword_templates[0]
            pagemsg("find_decl_args: For word #%s, lemma=%s, infl=%s, using headword template %s for use with z-decl template %s" %
                (wordind, lemma, infl, unicode(headword_template),
                  unicode(decl_z_template)))
          decl_template = runounlib.convert_zdecl_to_ru_noun_table(decl_z_template,
              subpagetitle, pagemsg, headword_template=headword_template)
          decl_templates = [decl_template]

      elif "[[Category:Russian indeclinable nouns]]" in declpage.text or [
        x for x in headword_templates if getparam(x, "3") == "-"]:
        return [("1", wordlink), ("2", "$")], False, None, None
      else:
        pagemsg("WARNING: No decl template during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None

    if len(decl_templates) == 1:
      decl_template = decl_templates[0]
    else:
      # Multiple decl templates
      for t in decl_templates:
        if unicode(t.name) == "ru-decl-adj" and re.search(u"(ий|ый|ой)$", lemma):
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s, assuming adjectival: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
          decl_template = t
          break
      else:
        if lemma in use_given_decl:
          overriding_decl = use_given_decl[lemma]
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, using overriding declension %s: lemma=%s, infl=%s" %
              (wordind, overriding_decl, lemma, infl))
          decl_template = blib.parse_text(overriding_decl).filter_templates()[0]
        elif pagetitle in use_given_page_decl:
          overriding_decl = use_given_page_decl[pagetitle].get(lemma, None)
          if not overriding_decl:
            pagemsg("WARNING: Missing entry for ambiguous-decl lemma for word #%s, skipping: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
            return
          else:
            pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, using overriding declension %s: lemma=%s, infl=%s" %
                (wordind, overriding_decl, lemma, infl))
            decl_template = blib.parse_text(overriding_decl).filter_templates()[0]
        else:
          pagemsg("WARNING: Multiple decl templates during decl lookup for word #%s and not adjectival, skipping: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          return None

    pagemsg("find_decl_args: Using decl template: %s" % unicode(decl_template))
    if unicode(decl_template.name) == "ru-decl-adj":
      if re.search(ur"\bь\b", getparam(decl_template, "2"), re.U):
        return [("1", wordlink), ("2", u"+ь")], True, None, None
      else:
        return [("1", wordlink), ("2", "+")], True, None, None

    # ru-noun-table
    assert unicode(decl_template.name) == "ru-noun-table"

    # Split out the arg sets in the declension and check the
    # lemma of each one, taking care to handle cases where there is no lemma
    # (it would default to the page name).

    highest_numbered_param = 0
    for p in decl_template.params:
      pname = unicode(p.name)
      if re.search("^[0-9]+$", pname):
        highest_numbered_param = max(highest_numbered_param, int(pname))

    # Now gather the numbered arguments into arg sets. Code taken from
    # ru-noun.lua.
    offset = 0
    arg_sets = []
    arg_set = []
    for i in range(1, highest_numbered_param + 2):
      end_arg_set = False
      val = getparam(decl_template, str(i))
      if i == highest_numbered_param + 1:
        end_arg_set = True
      elif val == "_" or val == "-" or re.search("^join:", val):
        pagemsg("WARNING: Found multiword decl during decl lookup for word #%s, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None
      elif val == "or":
        end_arg_set = True

      if end_arg_set:
        arg_sets.append(arg_set)
        arg_set = []
        offset = i
      else:
        arg_set.append(val)

    canon_infl = rulib.remove_accents(infl).lower()
    canon_lemma = lemma.lower()
    ispl = False
    need_sc1 = False
    found_gender = None
    if canon_infl != canon_lemma:
      for sgend, plend, gender, is_sc1 in pl_data:
        if sgend:
          check_sgend = sgend
        else:
          check_sgend = consonant_re
        if re.search(check_sgend + "$", canon_lemma) and canon_infl == re.sub(sgend + "$", plend, canon_lemma):
          ispl = True
          found_gender = gender
          need_sc1 = is_sc1
          break
      else:
        pagemsg("WARNING: For word#%s, inflection not same as lemma, not recognized as plural, can't handle, skipping: lemma=%s, infl=%s" %
            (wordind, lemma, infl))
        return None

    # Substitute the wordlink for any lemmas in the declension.
    # If plural, also add gender and verify special case (1) as necessary.
    # Concatenate all the numbered params, substituting the wordlink into
    # the lemma as necessary.
    numbered_params = []
    for arg_set in arg_sets:
      lemma_arg = 0
      if len(arg_set) > 0 and runounlib.arg1_is_stress(arg_set[0]):
        lemma_arg = 1
      if len(arg_set) <= lemma_arg:
        arg_set.append("")
      arglemma = arg_set[lemma_arg]
      manualtr = ""
      if "//" in arglemma:
        arglemma, manualtr = re.search("^(.*?)(//.*?)$", arglemma).groups()
      if (not arglemma or arglemma.lower() == infl.lower() or
          rulib.is_monosyllabic(infl) and rulib.remove_accents(arglemma).lower() ==
          rulib.remove_accents(infl).lower() or
          ispl and rulib.remove_accents(arglemma).lower() == lemma.lower()
          ):
        arg_set[lemma_arg] = wordlink + manualtr
      else:
        pagemsg("WARNING: Can't sub word link %s into decl lemma %s%s" % (
          wordlink, arg_set[lemma_arg], ispl and ", skipping" or ""))
        if ispl:
          return None

      if ispl:
        # Add the gender
        if len(arg_set) <= lemma_arg + 1:
          arg_set.append("")
        declarg = arg_set[lemma_arg + 1]

        # First, sub in gender
        m = re.search("(3f|[mfn])", declarg)
        if found_gender == "mf":
          if not m:
            pagemsg(u"WARNING: For singular in -ь and plural in -и, need gender in singular and don't have it, word #%s, skipping: lemma=%s, infl=%s" %
                (wordinfl, lemma, infl))
            return None
          decl_gender = m.group(1)
          if decl_gender == "n":
            pagemsg(u"WARNING: For singular in -ь and plural in -и, can't have neuter gender for word #%s, skipping: lemma=%s, infl=%s" %
                (wordinfl, lemma, infl))
            return None
          elif decl_gender in ["m", "3f"]:
            pagemsg(u"Singular in -ь and plural in -и, already found gender %s in decl for word #%s, taking no action: lemma=%s, infl=%s" %
                (decl_gender, wordind, lemma, infl))
          else:
            assert gender == "f"
            pagemsg(u"Singular in -ь and plural in -и, replacing f with 3f so singular will be recognized for word #%s: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
            declarg = re.sub("f", "3f", declarg, 1)
        else:
          if m:
            decl_gender = m.group(1)
            if decl_gender == found_gender:
              pagemsg("Already found gender %s in decl for word #%s, taking no action: lemma=%s, infl=%s" %
                  (found_gender, wordind, lemma, infl))
            else:
              pagemsg("WARNING: Found wrong gender %s in decl for word #%s, forcibly replacing with lemma-form-derived gender %s: lemma=%s, infl=%s" %
                  (decl_gender, wordind, found_gender, lemma, infl))
              declarg = re.sub("(3f|[mfn])", found_gender, declarg, 1)
          else:
            pagemsg("No gender in decl for word #%s, adding gender %s: lemma=%s, infl=%s" %
                (wordind, found_gender, lemma, infl))
            declarg = found_gender + declarg

        # Now check special case 1
        if need_sc1 != ("(1)" in declarg):
          if need_sc1:
            pagemsg("WARNING: Irregular plural calls for special case (1), but not present in decl arg for word #%s, skipping: declarg=%s, lemma=%s, infl=%s" % (
              wordind, declarg, lemma, infl))
            return None
          else:
            pagemsg("WARNING: Special case (1) present in decl arg but plural for word #%s is regular, skipping: declarg=%s, lemma=%s, infl=%s" % (
              wordind, declarg, lemma, infl))
            return None

        arg_set[lemma_arg + 1] = declarg

      if numbered_params:
        numbered_params.append("or")
      numbered_params.extend(arg_set)

    # Now gather all params, including named ones.
    params = []
    params.extend((str(i+1), val) for i, val in zip(range(len(numbered_params)), numbered_params))
    num = None
    anim = None
    for p in decl_template.params:
      pname = unicode(p.name)
      val = unicode(p.value)
      if pname == "a":
        anim = val
      elif pname == "n":
        num = val
      elif pname == "notes":
        params.append((pname, val))
      elif pname == "title":
        pagemsg("WARNING: Found explicit title= for word #%s, ignoring: lemma=%s, infl=%s, title=%s" %
            (wordind, lemma, infl, val))
      elif re.search("^[0-9]+$", pname):
        pass
      else:
        keepparam = True
        if pname == "loc":
          if pagetitle in keep_locative:
            pagemsg("Keeping locative for word #%s because page in keep_locative: loc=%s, lemma=%s, infl=%s" % (
            wordind, val, lemma, infl))
          else:
            pagemsg("WARNING: Discarding locative for word #%s: loc=%s, lemma=%s, infl=%s" % (
            wordind, val, lemma, infl))
            keepparam = False
        if pname == "par":
          pagemsg("WARNING: Discarding partitive for word #%s: par=%s, lemma=%s, infl=%s" % (
            wordind, val, lemma, infl))
          keepparam = False
        if pname == "voc":
          pagemsg("WARNING: Discarding vocative for word #%s: voc=%s, lemma=%s, infl=%s" % (
            wordind, val, lemma, infl))
          keepparam = False
        if keepparam:
          if pname == "loc" and re.search(ur"^(на|в)\b", val, re.U):
            pagemsg(u"WARNING: на or в found in loc= for word #%s, may not work in multi-word lemma: loc=%s, lemma=%s, infl=%s" %
                (wordind, val, lemma, infl))
          pname += str(wordind)
          params.append((pname, val))

    return params, False, num, anim


  headword_template = None
  see_template = None
  for t in parsed.filter_templates():
    tname = unicode(t.name)
    if tname == "ru-decl-noun-see":
      if see_template:
        pagemsg("WARNING: Multiple ru-decl-noun-see templates, skipping")
        return
      see_template = t
    if tname in ["ru-noun+", "ru-proper noun+"]:
      pagemsg("Found %s, skipping" % tname)
      return
    if tname in ["ru-noun", "ru-proper noun"]:
      if headword_template:
        pagemsg("WARNING: Multiple ru-noun or ru-proper noun templates, skipping")
        return
      headword_template = t
    if tname == "ru-pre-reform":
      pagemsg("WARNING: Found ru-pre-reform template, skipping")
      return

  if not headword_template:
    pagemsg("WARNING: Can't find headword template, skipping")
    return

  pagemsg("Found headword template: %s" % unicode(headword_template))

  headword_is_proper = unicode(headword_template.name) == "ru-proper noun"

  if getparam(headword_template, "3") == "-" or "[[Category:Russian indeclinable nouns]]" in page.text:
    pagemsg("WARNING: Indeclinable noun, skipping")
    return

  headword_trs = blib.fetch_param_chain(headword_template, "tr", "tr")
  if headword_trs:
    pagemsg("WARNING: Found headword manual translit, skipping: %s" %
        ",".join(headword_trs))
    return

  headword = getparam(headword_template, "1")
  for badparam in ["head2", "gen2", "pl2"]:
    val = getparam(headword_template, badparam)
    if val:
      pagemsg("WARNING: Found extra param, can't handle, skipping: %s=%s" % (
        badparam, val))
      return

  # Here we use a capturing split, and treat what we want to capture as
  # the splitting text, backwards from what you'd expect. The separators
  # will fall at 0, 2, ... and the headwords as 1, 3, ... There will be
  # an odd number of items, and the first and last should be empty.
  headwords_separators = re.split(r"(\[\[.*?\]\]|[^ \-]+)", headword)
  if headwords_separators[0] != "" or headwords_separators[-1] != "":
    pagemsg("WARNING: Found junk at beginning or end of headword, skipping")
    return
  headwords = []
  # Separator at index 0 is the separator that goes after the first word
  # and before the second word.
  separators = []
  wordind = 0
  # FIXME, Here we try to handle hyphens, but we'll still have problems with
  # words like изба́-чита́льня with conjoined nouns, both inflected, because
  # we assume only one inflected noun (should be fixable without too much
  # work). We'll also have problems with e.g. пистолет-пулемёт Томпсона,
  # because the words are linked individually but the ru-decl-noun-see
  # has пистолет-пулемёт given as a single entry. We have a check below
  # to try to catch this case, because no inflected nouns will show up.
  for i in range(1, len(headwords_separators), 2):
    hword = headwords_separators[i]
    separator = headwords_separators[i+1]
    if i < len(headwords_separators) - 2 and separator != " " and separator != "-":
      pagemsg("WARNING: Separator after word #%s isn't a space or hyphen, can't handle: word=<%s>, separator=<%s>" %
          (wordind + 1, hword, separator))
      return
    # Canonicalize link in headword
    m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]$", hword)
    if m:
      lemma, infl = m.groups()
      lemma = rulib.remove_accents(re.sub("#Russian$", "", lemma))
      if lemma == rulib.remove_accents(infl):
        hword = "[[%s]]" % infl
      else:
        hword = "[[%s|%s]]" % (lemma, infl)
    headwords.append(hword)
    separators.append(separator)
    wordind += 1

  pagemsg("Found headwords: %s" % " @@ ".join(headwords))

  # Get headword genders (includes animacy and number)
  genders = blib.fetch_param_chain(headword_template, "2", "g")
  genders_include_pl = len([x for x in genders if re.search(r"\bp\b", x)]) > 0

  # Extract lemmas and inflections for each word in headword
  lemmas_infls = []
  saw_unlinked_word = False
  for word in headwords:
    m = re.search(r"^\[\[([^\[\]|]+)\|([^\[\]|]+)\]\]$", word)
    if m:
      lemma, infl = m.groups()
    else:
      m = re.search(r"^\[\[([^\[\]|]+)\]\]$", word)
      if m:
        infl = m.group(1)
        lemma = rulib.remove_accents(infl)
      elif pagetitle in all_parts_declined:
        infl = word
        lemma = rulib.remove_accents(infl)
        for inflsuffix, lemmasuffix in infer_adj_lemma:
          if re.search(inflsuffix + "$", infl):
            lemma = rulib.remove_accents(re.sub(inflsuffix + "$", lemmasuffix, infl))
            lemma = re.sub(u"([кгхшжчщ])ый$", r"\1ий", lemma)
            pagemsg("WARNING: Inferring adjectival lemma from inflection, please check: lemma=%s, infl=%s" %
                (lemma, infl))
            break
        else:
          pagemsg("WARNING: Assuming word is inflected adj or noun, please check: lemma=%s, infl=%s" %
              (lemma, infl))
      else:
        infl = word
        lemma = rulib.remove_accents(infl)
        saw_unlinked_word = True
    lemmas_infls.append((lemma, infl))

  if see_template:
    pagemsg("Found decl-see template: %s" % unicode(see_template))
    inflected_words = set(rulib.remove_accents(blib.remove_links(unicode(x.value)))
        for x in see_template.params)
    if saw_unlinked_word:
      pagemsg("WARNING: Unlinked word(s) in headword, found decl-see template, proceeding, please check: %s" % headword)
  else:
    # Try to figure out which words are inflected and which words aren't
    pagemsg("No ru-decl-noun-see template, inferring which headword words are inflected")
    if saw_unlinked_word:
      pagemsg("WARNING: Unlinked word(s) in headword, no decl-see template, skipping: %s" % headword)
      return
    inflected_words = set()
    saw_noun = False
    reached_uninflected = False
    wordind = 0
    for word, lemmainfl in zip(headwords, lemmas_infls):
      wordind += 1
      is_inflected = False
      lemma, infl = lemmainfl
      canon_infl = rulib.remove_accents(infl).lower()
      canon_lemma = lemma.lower()
      if lemma in is_short_adj:
          is_inflected = True
          pagemsg("Assuming word #%s is short adjectival, inflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if saw_noun:
            pagemsg("WARNING: Word #%s is adjectival inflected and follows inflected noun: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
      elif re.search(u"(ый|ий|ой)$", lemma):
        if re.search(u"(ый|ий|о́й|[ая]́?я|[ое]́?е|[ыи]́?е|ь[яеи])$", infl):
          is_inflected = True
          pagemsg("Assuming word #%s is adjectival, inflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if saw_noun:
            pagemsg("WARNING: Word #%s is adjectival inflected and follows inflected noun: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
        else:
          pagemsg("Assuming word #%s is adjectival, uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
      elif canon_lemma == canon_infl:
        if canon_lemma in particles:
          pagemsg("Assuming word #%s is an uninflected particle: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
        elif canon_lemma in is_uninflected:
          pagemsg("Assuming word #%s is an uninflected non-particle because listed as uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
        else:
          is_inflected = True
          pagemsg("Assuming word #%s is noun, inflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if saw_noun:
            if pagetitle in all_parts_declined:
              pagemsg("Saw second apparently inflected noun at word #%s, allowed because pagetitle in all_parts_declined: lemma=%s, infl=%s" %
                  (wordind, lemma, infl))
            else:
              pagemsg("WARNING: Saw second apparently inflected noun at word #%s, skipping: lemma=%s, infl=%s" %
                  (wordind, lemma, infl))
              return
          else:
            saw_noun = True
      else:
        # FIXME, be smarter about nouns conjoined with и, e.g. Адам и Ева,
        # (might not be worth it, only five such nouns)
        if genders_include_pl and not saw_noun and not reached_uninflected:
          # Check for plural inflection
          for sgend, plend, gender, is_sc1 in pl_data:
            if sgend:
              check_sgend = sgend
            else:
              check_sgend = consonant_re
            if re.search(check_sgend + "$", canon_lemma) and canon_infl == re.sub(sgend + "$", plend, canon_lemma):
              pagemsg("Assuming word #%s is plural noun, inflected: lemma=%s, infl=%s" %
                  (wordind, lemma, infl))
              saw_noun = True
              is_inflected = True
              break
        if not is_inflected:
          pagemsg("Assuming word #%s is non-adjectival, uninflected: lemma=%s, infl=%s" %
              (wordind, lemma, infl))
          if not saw_noun:
            pagemsg("WARNING: No inflected noun in headword, skipping: %s" %
                headword)
            return
      if is_inflected:
        if reached_uninflected:
          if separators[wordind - 2] == "-":
            # Cases like сербско-хорватский, Народно-Демократическая,
            # Центрально-Африканская, военно-морские
            pagemsg("WARNING: Word #%s is apparently inflected and follows uninflected word after hyphen, allowed, please check: lemma=%s, infl=%s" %
                (wordind, lemma, infl))
          else:
            pagemsg("WARNING: Word #%s is apparently inflected and follows uninflected words, something might be wrong (or could be accusative after preposition), skipping: lemma=%s, infl=%s" %
                  (wordind, lemma, infl))
            # FIXME, compile list where this is allowed
            return
        inflected_words.add(lemma)
      else:
        reached_uninflected = True
        if lemma in inflected_words:
          pagemsg("WARNING: Lemma appears both in inflected and uninflected words, can't handle skipping: lemma=%s (infl=%s at second appearance at word#%s)" %
              (lemma, infl, wordind))

  params = []
  saw_noun = False
  overall_num = None
  overall_anim = None

  wordind = 0
  offset = 0
  decl_notes = []
  for word, lemmainfl in zip(headwords, lemmas_infls):
    wordind += 1
    lemma, infl = lemmainfl
    # If not first word, add _ separator between words
    if wordind > 1:
      if separators[wordind - 2] == "-":
        separator = "-"
      elif separators[wordind - 2] == " ":
        separator = "_"
      else:
        pagemsg("WARNING: Something wrong, separator for word #%2 isn't space or hyphen: <%s>" %
            separators[wordind - 2])
        return
      params.append((str(offset + 1), separator))
      offset += 1

    if lemma in inflected_words:
      inflected_words.remove(lemma)
      pagemsg("Looking up declension for lemma %s, infl %s" % (lemma, infl))
      retval = find_decl_args(lemma, infl, wordind)
      if not retval:
        pagemsg("WARNING: Can't get declension for %s, skipping" % headword)
        return
      wordparams, isadj, num, anim = retval
      num_numbered_params = 0
      if not isadj:
        if saw_noun:
          if wordind == 2 and len(headwords) == 2 and separator == "-":
            pagemsg("WARNING: Found apparent coordinate noun headword A-B, using first noun for overall num and anim, please check")
          elif see_template:
            pagemsg("WARNING: Multiple inflected nouns with ru-decl-noun-see template, allowing but please check")
          else:
            pagemsg("WARNING: Multiple inflected nouns without ru-decl-noun-see template, can't handle, skipping")
            return
        else:
          overall_num = num
          overall_anim = anim
          saw_noun = True
      for name, val in wordparams:
        if name == "notes":
          decl_notes.append(val)
        else:
          if re.search("^[0-9]+$", name):
            name = str(int(name) + offset)
            num_numbered_params += 1
          params.append((name, val))
      offset += num_numbered_params

    else:
      # Invariable
      if rulib.is_unstressed(infl):
        word = "*" + word
      if infl == u"и":
        pagemsg(u"WARNING: Found и, check number args")
      params.append((str(offset + 1), word))
      params.append((str(offset + 2), "$"))
      offset += 2

  if inflected_words:
    pagemsg("WARNING: Some inflected words left over, something wrong, skipping: %s" %
        ", ".join(inflected_words))
    return

  if len(decl_notes) > 1:
    pagemsg("WARNING: Found multiple notes=, can't handle, skipping: notes=%s" %
        " // ".join("<%s>" % x for x in decl_notes))
    return
  elif len(decl_notes) == 1:
    pagemsg("WARNING: Found notes=, need to check: notes=<%s>" % decl_notes[0])
    params.append(("notes", decl_notes[0]))
  if not saw_noun and not pagetitle in allow_no_inflected_noun:
    pagemsg(u"WARNING: No inflected nouns, something might be wrong (e.g. the пистоле́т-пулемёт То́мпсона problem), can't handle, skipping")
    return

  if overall_anim in ["i", "in", "inan"] or not overall_anim:
    overall_anim = "in"
  elif overall_anim in ["a", "an", "anim"]:
    overall_anim = "an"
  elif overall_anim in ["b", "bi", "bian", "both"]:
    overall_anim = "bi"

  saw_in = -1
  saw_an = -1
  for i,g in enumerate(genders):
    if re.search(r"\bin\b", g) and saw_in < 0:
      saw_in = i
    if re.search(r"\ban\b", g) and saw_an < 0:
      saw_an = i
  if saw_in >= 0 and saw_an >= 0 and saw_in < saw_an:
    headword_anim = "ia"
  elif saw_in >= 0 and saw_an >= 0:
    headword_anim = "ai"
  elif saw_an >= 0:
    headword_anim = "an"
  elif saw_in >= 0:
    headword_anim = "in"
  else:
    headword_anim = overall_anim

  if overall_anim != headword_anim:
    pagemsg("WARNING: Overriding decl anim %s with headword anim %s" % (
      overall_anim, headword_anim))
  if headword_anim and headword_anim != "in":
    params.append(("a", headword_anim))

  if overall_num:
    overall_num = overall_num[0:1]
    canon_nums = {"s":"sg", "p":"pl", "b":"both"}
    if overall_num in canon_nums:
      overall_num = canon_nums[overall_num]
    else:
      pagemsg("WARNING: Bogus value for overall num in decl, skipping: %s" % overall_num)
      return
    if headword_is_proper:
      plval = getparam(headword_template, "4")
      if plval and plval != "-":
        if overall_num != "both":
          pagemsg("WARNING: Proper noun is apparently sg/pl but main noun not, skipping: %s" %
              headword)
          return
      elif overall_num == "both":
        pagemsg("WARNING: Proper noun has sg/pl main noun underlying it, assuming singular: %s" %
            headword)
        overall_num = None
      elif overall_num == "sg":
        overall_num = None
    if overall_num:
      params.append(("n", overall_num))

  generate_template = (
      blib.parse_text("{{ru-generate-noun-args}}").filter_templates()[0])
  for name, value in params:
    generate_template.add(name, value)
  proposed_template_text = unicode(generate_template)
  if headword_is_proper:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-proper noun+", proposed_template_text)
  else:
    proposed_template_text = re.sub(r"^\{\{ru-generate-noun-args",
        "{{ru-noun+", proposed_template_text)
  proposed_decl = blib.parse_text("{{ru-noun-table}}").filter_templates()[0]
  for param in generate_template.params:
    proposed_decl.add(param.name, param.value)

  def pagemsg_with_proposed(text):
    pagemsg("Proposed new template (WARNING, omits explicit gender and params to preserve from old template): %s" % proposed_template_text)
    pagemsg(text)

  if headword_is_proper:
    generate_template.add("ndef", "sg")
  generate_result = expand_text(unicode(generate_template))
  if not generate_result:
    pagemsg_with_proposed("WARNING: Error generating noun args, skipping")
    return
  genargs = blib.split_generate_args(generate_result)
  if headword_is_proper and genargs["n"] == "s" and not getparam(proposed_decl, "n"):
    proposed_decl.add("n", "sg")

  # This will check number mismatch (and animacy mismatch, but that shouldn't
  # occur as we've taken the animacy directly from the headword)
  new_genders = runounlib.check_old_noun_headword_forms(headword_template, genargs,
      subpagetitle, pagemsg_with_proposed, laxer_comparison=True)
  if new_genders == None:
    return None

  orig_headword_template = unicode(headword_template)
  params_to_preserve = runounlib.fix_old_headword_params(headword_template,
      params, new_genders, pagemsg_with_proposed)
  if params_to_preserve == None:
    return None

  headword_template.params.extend(params_to_preserve)

  notes = []
  ru_noun_changed = 0
  ru_proper_noun_changed = 0
  if unicode(headword_template.name) == "ru-noun":
    headword_template.name = "ru-noun+"
    notes.append("convert multi-word ru-noun to ru-noun+ by looking up decls")
  else:
    headword_template.name = "ru-proper noun+"
    notes.append("convert multi-word ru-proper noun to ru-proper noun+ by looking up decls")

  pagemsg("Replacing headword %s with %s" % (orig_headword_template, unicode(headword_template)))
  newtext = unicode(parsed)

  if see_template:
    orig_see_template = unicode(see_template)
    del see_template.params[:]
    see_template.name = "ru-noun-table"
    for param in proposed_decl.params:
      see_template.add(param.name, param.value)
    pagemsg("Replacing see-template %s with decl %s" % (orig_see_template, unicode(see_template)))
    notes.append("replace see-template with declension")
    newtext = unicode(parsed)
  else:
    if "==Declension==" in newtext:
      pagemsg("WARNING: No ru-decl-noun-see template, but found declension section, not adding new declension, proposed declension follows: %s" %
          unicode(proposed_decl))
    else:
      nounsecs = re.findall("^===(?:Noun|Proper noun)===$", newtext, re.M)
      if len(nounsecs) == 0:
        pagemsg("WARNING: Found no noun sections, not adding new declension, proposed declension follows: %s" %
            unicode(proposed_decl))
      elif len(nounsecs) > 1:
        pagemsg("WARNING: Found multiple noun sections, not adding new declension, proposed declension follows: %s" %
            unicode(proposed_decl))
      else:
        text = newtext
        newtext = re.sub(r"\n*$", "\n\n", newtext)
        # Sub in after Noun or Proper noun section, before a following section
        # (====Synonyms====) or a wikilink ([[pl:гонка вооружений]]) or
        # a category ([[Category:...]]).
        newtext = re.sub(r"^(===(?:Noun|Proper noun)===$.*?)^(==|\[\[|\Z)",
            r"\1====Declension====\n%s\n\n\2" % unicode(proposed_decl), newtext,
            1, re.M|re.S)
        if text == newtext:
          pagemsg("WARNING: Something wrong, can't sub in new declension, proposed declension follows: %s" %
              unicode(proposed_decl))
        else:
          pagemsg("Subbed in new declension: %s" % unicode(proposed_decl))
          notes.append("create declension from headword")
          if args.verbose:
            pagemsg("Replaced <%s> with <%s>" % (text, newtext))

  return newtext, notes

parser = blib.create_argparser("Convert ru-noun to ru-noun+, ru-proper noun to ru-proper noun+ for multiword nouns",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

refs = []
#for pos in ["proper nouns"]:
for pos in ["nouns", "proper nouns"]:
  for refpage in ["Template:tracking/ru-headword/space-in-headword/%s" % pos,
      "Template:tracking/ru-headword/hyphen-no-space-in-headword/%s" % pos]:
    refs.append(refpage)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_refs=refs)
