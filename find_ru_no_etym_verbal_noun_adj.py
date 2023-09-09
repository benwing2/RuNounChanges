#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Try to construct etymologies of verbal nouns in -ние and verbal adjectives
# in -тельный.

# NOTES on how past passive participles are formed and when they're present:
#
# Participles exist only in transitive verbs, in perfective verbs as well
# as imperfective verbs not marked with the shaded circle sign. However,
# verbs marked with an x form participles with difficulty, and verbs marked
# with an x inside of a square lack participles.
#
# Verbs in -ать and -ять (except type 14) form participles by replacing -ть
# in the infinitive with -нный. If the stress is on the last syllable of the
# infinitive, it is one syllable to the left in the participle (if possible),
# else on the same syllable as the infinitive. However, verbs in -а́ть and
# -я́ть with the circled-7 mark have participles in -а́нный and -я́нный (there
# aren't very many of these). When the stress is moved relative to the
# infinitive, е changes to ё if the ё symbol is present.
#
# Verbs of type 4 and verbs in -еть of type 5 form participles by adding
# -енный (stressed -ённый) to the base of the 1sg present/future (i.e.
# iotated in the same way as the 1sg, if it is iotated). Verbs of type 4 have
# the stress on the same syllable as in the 3sg present/future (i.e. -ённый
# if type b, else somewhere on the stem with -енный); but verbs of type 4b
# with the circled-8 mark have the ending -енный with the stress on the last
# syllable of the stem, i.e. one syllable to the left compared with the
# infinitive). Verbs of type 5 have the stress as in -ать verbs (one syllable
# to the left of the infinitive if the infinitive stress is on the ending and
# the circled-7 mark isn't present, else in the same place as the infinitive).
#
# Verbs of type 1 in -еть form participles by replacing -еть with -ённый.
# The only such verbs with participles are одоле́ть, преодоле́ть, and verbs
# in -печатле́ть.
#
# Verbs of type 7 and 8 form participles by adding -енный (stressed -ённый)
# to the base of the 3sg present/future. The stress is on the same syllable
# as in the feminine singular past.
#
# Verbs of type 3 (3˚) and 10 form participles by adding -тый to the base
# of the infinitive. These verbs have the stress as in -ать verbs (one
# syllable to the left of the infinitive if the infinitive stress is on the
# ending, else in the same place as the infinitive).
#
# Verbs of type 9, 11, 12, 14, 15, 16 form participles by adding -тый to
# the masculine singular past (minus final -л if it's present). Stress is
# as in the masculine singular past.

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

import rulib

# FIXME, not used
def iotate(word):
  if re.search("[бвфпм]$", word):
    return [word + "л"]
  if re.search("[зг]$", word):
    return [re.sub("[зг]$", "ж", word)]
  if re.search("[сш]$", word):
    return [re.sub("[сш]$", "ш", word)]
  if re.search("с[тк]$", word):
    return [re.sub("с[тк]$", "щ", word)]
  if re.search("д$", word):
    return [re.sub("д$", "ж", word), re.sub("д$", "жд", word)]
  if re.search("т$", word):
    return [re.sub("т$", "ч", word), re.sub("т$", "щ", word)]
  if re.search("к$", word):
    return [re.sub("к$", "ч", word)]
  return [word]

def find_noun(pagename, pagemsg, errandpagemsg, expand_text):
  section = blib.find_lang_section_from_page(pagename, "Russian", pagemsg, errandpagemsg)
  if not section:
    return None
  if "==Etymology" in section:
    return -1
  parsed = blib.parse_text(section)
  nouns = []
  for t in parsed.filter_templates():
    if tname(t) == "ru-noun+":
      generate_template = re.sub(r"^\{\{ru-noun\+",
          "{{ru-generate-noun-forms", str(t))
      generate_result = expand_text(generate_template)
      if not generate_result:
        pagemsg("WARNING: Error generating noun forms")
        return None
      args = blib.split_generate_args(generate_result)
      lemma = args["nom_sg"] if "nom_sg" in args else args["nom_pl"]
      if "," in lemma:
        pagemsg("WARNING: Lemma has multiple forms: %s" % lemma)
        return None
      if lemma not in nouns:
        nouns.append(lemma)
  if len(nouns) > 1:
    pagemsg("WARNING: Multiple lemmas for noun: %s" % ",".join(nouns))
  if not nouns:
    return None
  return nouns[0]

def find_adj(pagename, pagemsg, errandpagemsg, expand_text):
  section = blib.find_lang_section_from_page(pagename, "Russian", pagemsg, errandpagemsg)
  if not section:
    return None
  if "==Etymology" in section:
    return -1
  parsed = blib.parse_text(section)
  adjs = []
  for t in parsed.filter_templates():
    if tname(t) == "ru-adj":
      heads = blib.fetch_param_chain(t, "1", "head", pagename)
      if len(heads) > 1:
        pagemsg("WARNING: Multiple lemmas for adjective: %s" % ",".join(heads))
        return None
      if heads[0] not in adjs:
        adjs.append(heads[0])
  if len(adjs) > 1:
    pagemsg("WARNING: Multiple lemmas for adjective: %s" % ",".join(adjs))
  if not adjs:
    return None
  return adjs[0]

# Form the past passive participle from the verb type, infinitive and
# other parts. For the moment we don't try to get the stress right,
# and return a form without stress or ё.
def form_ppp(conjtype, pagetitle, args):
  def form_ppp_1(conjtype, pagetitle, args):
    def first_entry(forms):
      forms = re.sub(",.*", "", forms)
      return re.sub("//.*", "", forms)
    if not re.search("^[0-9]+", conjtype):
      return None
    conjtype = int(re.sub("^([0-9]+).*", r"\1", conjtype))
    if ((pagetitle.endswith("ать") or pagetitle.endswith("ять")) and
        conjtype != 14):
      return re.sub("ть$", "нный", pagetitle)
    if pagetitle.endswith("еть") and conjtype == 1:
      return re.sub("ть$", "нный", pagetitle)
    if conjtype in [4, 5]:
      sg1 = (
        args["pres_1sg"] if "pres_1sg" in args else
        args["futr_1sg"] if "futr_1sg" in args else
        None
      )
      if not sg1 or sg1 == "-" or sg1.startswith("бу́ду "):
        return None
      sg1 = first_entry(sg1)
      assert re.search("[ую]́?$", sg1)
      return re.sub("[ую]́?$", "енный", sg1)
    if conjtype in [7, 8]:
      sg3 = args["pres_3sg"] if "pres_3sg" in args else args["futr_3sg"]
      sg3 = first_entry(sg3)
      assert re.search("[её]́?т$", sg3)
      return re.sub("[её]́?т$", "енный", sg3)
    if conjtype in [3, 10]:
      if pagetitle.endswith("чь"):
        return re.sub("чь", "гнутый", pagetitle)
      return re.sub("ть$", "тый", pagetitle)
    assert conjtype in [9, 11, 12, 14, 15, 16]
    if "past_m" not in args: # occurs with e.g. impersonal verbs e.g. спереть
      return None
    pastm = first_entry(args["past_m"])
    return re.sub("л?$", "тый", pastm)

  retval = form_ppp_1(conjtype, pagetitle, args)
  if retval:
    return rulib.make_unstressed_ru(retval)
  else:
    return None

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  notes = []

  if re.search("с[яь]$", pagetitle):
    pagemsg("Skipping reflexive verb")
    return

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn == "ru-conj":
      if [x for x in t.params if str(x.value) == "or"]:
        pagemsg("WARNING: Skipping multi-arg conjugation: %s" % str(t))
        continue
      conjtype = getparam(t, "2")
      tempcall = re.sub(r"\{\{ru-conj", "{{ru-generate-verb-forms", str(t))
      result = expand_text(tempcall)
      if not result:
        pagemsg("WARNING: Error generating forms, skipping")
        continue
      args = blib.split_generate_args(result)
      if "infinitive" not in args: # e.g. обнимать
        pagemsg("WARNING: No infinitive")
        continue
      infinitive = args["infinitive"]
      if "," in infinitive:
        pagemsg("WARNING: Infinitive has multiple forms: %s" % infinitive)
        continue
      if "//" in infinitive:
        pagemsg("WARNING: Infinitive has translit: %s" % infinitive)
        continue
      ppp = form_ppp(conjtype, pagetitle, args)
      if not ppp:
        continue
      if ppp.endswith("тый"):
        verbal_noun = re.sub("тый$", "тие", ppp)
        verbal_noun_suffix = "тие"
        verbal_adj = re.sub("тый$", "тельный", ppp)
        verbal_adj_suffix = "тельный"
      elif ppp.endswith("ённый"):
        verbal_noun = re.sub("ённый$", "ение", ppp)
        verbal_noun_suffix = "ение"
        verbal_adj = re.sub("ённый$", "ительный", ppp)
        verbal_adj_suffix = "ительный"
      elif ppp.endswith("енный"):
        verbal_noun = re.sub("енный$", "ение", ppp)
        verbal_noun_suffix = "ение"
        verbal_adj = re.sub("енный$", "ительный", ppp)
        verbal_adj_suffix = "ительный"
      else:
        assert ppp.endswith("анный") or ppp.endswith("янный")
        verbal_noun = re.sub("нный$", "ние", ppp)
        verbal_adj = re.sub("нный$", "тельный", ppp)
        m = re.search("(.)нный$", ppp)
        suffix_start = m.group(1)
        verbal_noun_suffix = suffix_start + "ние"
        verbal_adj_suffix = suffix_start + "тельный"
      agent_noun = re.sub("ный$", "", verbal_adj)
      agent_noun_suffix = re.sub("ный$", "", verbal_adj_suffix)
      stressed_verbal_noun_suffix = re.sub("^([аяеи])", r"\1́", verbal_noun_suffix)
      stressed_verbal_adj_suffix = re.sub("^([аяеи])", r"\1́", verbal_adj_suffix)
      stressed_agent_noun_suffix = re.sub("ный$", "", stressed_verbal_adj_suffix)
      if conjtype.startswith("7"):
        stem = getparam(t, "4")
        if infinitive.endswith("ть"):
          stem = stem.replace("ё", "е́")
        else:
          stem = rulib.make_unstressed_ru(stem)
        stem = rulib.remove_accents(infinitive) + "+alt1=" + stem + "-"
      elif conjtype.startswith("8"):
        stem = rulib.remove_accents(infinitive) + "+alt1=" + getparam(t, "3").replace("ё", "е́") + "-"
      else:
        stem = rulib.remove_monosyllabic_accents(infinitive)

      if verbal_noun in nouns:
        stressed_noun = find_noun(verbal_noun, pagemsg, errandpagemsg, expand_text)
        if not stressed_noun:
          msg("%s no-etym FIXME" % verbal_noun)
        elif stressed_noun == -1:
          pagemsg("Would add etym for %s but already has one" % verbal_noun)
        else:
          if stressed_noun.endswith(stressed_verbal_noun_suffix):
            suffix = stressed_verbal_noun_suffix
          else:
            suffix = verbal_noun_suffix
          msg("%s %s+-%s no-etym verbal-noun" % (verbal_noun, stem, suffix))

      if agent_noun in nouns:
        stressed_noun = find_noun(agent_noun, pagemsg, errandpagemsg, expand_text)
        if stressed_noun == -1:
          pagemsg("Would add etym for %s but already has one" % agent_noun)
        else:
          msg("%s %s+-тель no-etym agent-noun" % (agent_noun, stem))

      if verbal_adj in adjectives:
        stressed_adj = find_adj(verbal_adj, pagemsg, errandpagemsg, expand_text)
        if stressed_adj == -1:
          pagemsg("Would add etym for %s but already has one" % verbal_adj)
        else:
          msg("%s %s+-тельный no-etym verbal-adj" % (verbal_adj, stem))

# Pages specified using --pages or --pagefile may have accents, which will be stripped.
parser = blib.create_argparser("Find etymologies for Russian verbal nouns in -ние and verbal adjectives in -тельный",
    include_pagefile=True, include_stdin=True, canonicalize_pagename=rulib.remove_accents)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

nouns = []
for i, page in blib.cat_articles("Russian nouns"):
  nouns.append(page.title())
adjectives = []
for i, page in blib.cat_articles("Russian adjectives"):
  adjectives.append(page.title())

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
  default_cats=["Russian verbs"])
