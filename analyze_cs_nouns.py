#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname

import cslib as cs

def is_undefined(word):
  return word in ["", "-", u"-", u"—"]

noun_endings = {
  "gen_sg": ["a", "u", "e", u"ě", "y", "i", u"í"],
  "dat_sg": ["u", "ovi", "i", u"í", "e", u"ě"],
  "voc_sg": ["e", u"ě", "u", "i", "o", u"í", ""],
  "loc_sg": ["u", "ovi", "e", u"ě", "i", u"í"],
  "ins_sg": ["em", u"ěm", "ou", u"ím", u"í"],
  "nom_pl": ["i", "y", u"é", u"ové", "e", u"ě", "a", u"í"],
  "gen_pl": [u"ů", u"í", ""],
  "dat_pl": [u"ům", u"ím", u"ám", "em", u"ěm"],
  "loc_pl": ["ech", u"ěch", u"ích", u"ách"],
  "ins_pl": [u"ími", "ami", "emi", u"ěmi", "mi", "y", "i", "ama"],
}

adj_endings = {
  "gen_sg": [u"ého", u"é", u"ího", u"í"],
  "dat_sg": [u"ému", u"é", u"ímu", u"í"],
  "voc_sg": [u"ý", u"á", u"é", u"í"],
  "loc_sg": [u"ém", u"é", u"ím", u"í"],
  "ins_sg": [u"ým", "ou", u"ím", u"í"],
  "nom_pl": [u"í", u"é", u"á"],
  "gen_pl": [u"ých", u"ích"],
  "dat_pl": [u"ým", u"ím"],
  "loc_pl": [u"ých", u"ích"],
  "ins_pl": [u"ými", u"ími"],
}

slot_to_param = {
  "nom_sg":"1",
  "gen_sg":"2",
  "dat_sg":"3",
  "acc_sg":"4",
  "voc_sg":"5",
  "loc_sg":"6",
  "ins_sg":"7",
  "nom_pl":"8",
  "gen_pl":"9",
  "dat_pl":"10",
  "acc_pl":"11",
  "voc_pl":"12",
  "loc_pl":"13",
  "ins_pl":"14",
}

pl_tantum_slot_to_param = {
  "nom_pl":"1",
  "gen_pl":"2",
  "dat_pl":"3",
  "acc_pl":"4",
  "voc_pl":"5",
  "loc_pl":"6",
  "ins_pl":"7",
}

def process_text_on_page(index, pagetitle, text):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")

  if " " in pagetitle:
    pagemsg("Multiword lemma, skipping")
    return

  parsed = blib.parse_text(text)
  heads = None
  plurale_tantum = False
  animacy = "unknown"
  gender = "unknown"
  for t in parsed.filter_templates():
    tn = tname(t)
    if tn in ["cs-noun", "cs-proper noun"]:
      heads = blib.fetch_param_chain(t, "head")
      gender_and_animacy = blib.fetch_param_chain(t, "1", "g")
      plurale_tantum = False
      animacy = []
      gender = []
      if gender_and_animacy:
        for ga in gender_and_animacy:
          gender_and_animacy_parts = ga.split("-")
          g = gender_and_animacy_parts[0]
          if g not in gender:
            gender.append(g)
          if len(gender_and_animacy_parts) > 1:
            a = gender_and_animacy_parts[1]
            if a not in animacy:
              animacy.append(a)
          if len(gender_and_animacy_parts) > 2 and gender_and_animacy_parts[2] == "p":
            plurale_tantum = True
      if not animacy:
        animacy = "unknown"
      else:
        if len(animacy) > 1:
          pagemsg("WARNING: Multiple animacies: %s" % ",".join(animacy))
        animacy = animacy[0]
      if not gender:
        gender = "unknown"
      else:
        if len(gender) > 1:
          pagemsg("WARNING: Multiple genders: %s" % ",".join(gender))
        gender = gender[0]
        if gender not in ["m", "f", "n"]:
          pagemsg("WARNING: Unknown gender: %s" % gender)
          gender = "unknown"

    def fetch(param, pl_tantum=False):
      slot_map = pl_tantum_slot_to_param if pl_tantum else slot_to_param
      numparam = slot_map.get(param, param)
      pref = re.sub("^(.).*?_(.).*$", r"\1\2", param)
      vals = blib.fetch_param_chain(t, numparam, pref)
      newvals = []
      for thisval in vals:
        thisval = thisval.strip()
        thisval = blib.remove_links(thisval)
        thisvals = re.split(r"\s*[,/]\s*", thisval)
        newvals.extend(thisvals)
      vals = newvals
      retval = []
      for v in vals:
        # Remove final footnote symbols are per [[Module:table tools]]
        v = re.sub(ur"[*~@#$%^&+0-9_\u00A1-\u00BF\u00D7\u00F7\u2010-\u2027\u2030-\u205E\u2070-\u20CF\u2100-\u2B5F\u2E00-\u2E3F]*$", "", v)
        retval.append(v)
      return ", ".join(retval)

    def fetch_endings(param, is_adj=False, pl_tantum=False, uniquify=True):
      ending_set = adj_endings if is_adj else noun_endings
      endings = ending_set[param]
      endings = sorted(endings, key=lambda x:-len(x))
      paramval = fetch(param, pl_tantum)
      values = re.split(", *", paramval)
      found_endings = []
      for v in values:
        for ending in endings:
          if v.endswith(ending):
            if not uniquify or ending not in found_endings:
              found_endings.append(ending)
            break
        else: # no break
          pagemsg("WARNING: Couldn't recognize ending for %s=%s: %s" % (
            param, paramval, unicode(t)))
      return ":".join(found_endings)

    def canon(val):
      return re.sub(", *", "/", val)

    def truncate_extra_forms(form):
      return re.sub(",.*", "", form)

    def infer_basic_decl(lemma):
      overrides = []
      decl = None
      # * Nouns ending in a consonant are generally masculine, but can be feminine of the -e/ě type (e.g. [[dlaň]]
      #   "palm (of the hand) or the i-stem type (e.g. [[kost]] "bone"), both of which have instrumental singular in
      #   -í instead of -em. Masculine nouns are animate if acc_sg = gen_sg, inanimate if acc_sg = nom_sg. Nouns
      #   ending in -on and -um can be neuter foreign; ins_sg ends in -em + stem without -on/-um.
      # * Nouns ending in -o are generally neuter except for some foreign nouns.
      # * Nouns ending in -a are generally feminine, except for -a viriles like [[přednosta]] "chief, head", which has
      #   dative plural in -ům instead of -ám, and -ma neuters like [[drama]] "drama", which has acc_sg = nom_sg and
      #   dative plural in -matům.
      # * Nouns ending in -e are most often feminine, except for -e viriles like [[zachránce]] "savior", which has
      #   instrumental singular in -em and nominative plural in -i, and soft -e/ě neuters, which have instrumental
      #   singular in -em/-ěm and nominative plural in -e/ě or -a.
      # * Nouns ending in -í are most often neuter, but could be soft adjectival nouns of any gender. Masculine and
      #   neuter adjectival nouns are distinguished by genitive -ího instead of -í, while feminine adjectival nouns
      #   have instrumental singular -í instead of -ím. Masculine inanimate and neuter soft adjectival nouns are
      #   identical in all respects, but masculine animate soft adjectival nouns have accusative singular in -ího.
      # * Nouns in -ý are masculine adjectival, animate if acc_sg = gen_sg, inanimate if acc_sg = nom_sg.
      # * Nouns in -á are feminine adjectival.
      # * Nouns in -é are neuter adjectival.
      if lemma.endswith("o"):
        decl = "n"
      elif lemma.endswith("a"):
        if fetch("acc_sg") == fetch("nom_sg"):
          decl = "n.foreign"
        elif fetch("dat_pl").endswith(u"ům"):
           decl = "m.an"
        else:
          decl = "f"
      elif re.search(u"[eě]$", lemma):
        if re.search(u"[eě]m$", fetch("ins_sg")):
          if fetch("nom_pl").endswith("i"):
            decl = "m.an"
          elif fetch("nom_pl").endswith("ata"):
            decl = "n.tstem"
          else:
            decl = "n"
        else:
          decl = "f"
      elif lemma.endswith(u"í"):
        if fetch("gen_sg").endswith(u"ího"):
          if fetch("acc_sg").endswith(u"ího"):
            decl = "m.an.+"
          else:
            decl = "n.+"
        elif fetch("ins_sg").endswith(u"í"):
          decl = "f.+"
        else:
          decl = "n"
      elif lemma.endswith(u"ý"):
        if fetch("acc_sg") == fetch("gen_sg"):
          decl = "m.an.+"
        else:
          decl = "m.+"
      elif lemma.endswith(u"á"):
        decl = "f.+"
      elif lemma.endswith(u"é"):
        decl = "n.+"
      elif re.search(cs.cons_c + "$", lemma):
        if fetch("ins_sg").endswith(u"í"):
          if fetch("gen_sg").endswith("i"):
            decl = "f.istem"
          else:
            decl = "f"
        else:
          if re.search("(on|um)$", lemma):
            # [[enklitikon]], [[museum]]
            stem = lemma[:-2]
            if fetch("ins_sg") == stem + "em":
              decl = "n.foreign"
          elif re.search("[ueo]s$", lemma):
            # [[komunismus]], [[hádes]], [[kosmos]]
            stem = lemma[:-2]
            if fetch("ins_sg") == stem + "em":
              if fetch("acc_sg") == fetch("gen_sg"):
                decl = "m.an.foreign"
              else:
                decl = "m.foreign"
          if not decl:
            gen_sg_endings = fetch_endings("gen_sg")
            dat_sg_endings = fetch_endings("dat_sg")
            voc_sg_endings = fetch_endings("voc_sg")
            nom_pl_endings = fetch_endings("nom_pl")
            loc_pl_endings = fetch_endings("loc_pl")
            ins_pl_endings = fetch_endings("ins_pl")
            is_soft = ins_pl_endings == "i" or dat_sg_endings == "i"
            if fetch("acc_sg") == fetch("gen_sg"):
              decl = "m.an"
            else:
              decl = "m"
            if not is_soft:
              if decl == "m" and gen_sg_endings != "u":
                overrides.append("gen" + gen_sg_endings)
              velar = re.search("[ghk]$", lemma)
              expected_voc_sg_ending = "u" if velar else "e"
              expected_loc_pl_ending = u"ích" if velar else "ech"
              if voc_sg_endings != expected_voc_sg_ending:
                overrides.append("voc" + voc_sg_endings)
              if decl == "m.an" and nom_pl_endings != "i":
                overrides.append("nompl" + nom_pl_endings)
              if loc_pl_endings != expected_loc_pl_ending:
                overrides.append("locpl" + loc_pl_endings)

      if not decl:
        pagemsg("WARNING: Unrecognized lemma ending: %s" % lemma)
      return decl, ".".join(overrides)

    def infer_decl(lemma):
      decl, overrides = infer_basic_decl(lemma)
      if decl is None:
        return None
      alternation = infer_alternations(decl, fetch("nom_sg"), fetch("gen_sg"), fetch("gen_pl"))
      if alternation:
        decl += "." + alternation
      if overrides:
        decl += "." + overrides
      return decl

    # Determine the default value for the 'reducible' flag.
    def determine_default_reducible(lemma):
      m = re.search("^(.*" + cs.cons_c + ")$", lemma)
      if m:
        # FIXME, investigate whether we need to default reducible to true (e.g. in -ec or -ek?).
        return False
      m = re.search("^(.*)" + cs.vowel_c + "$", lemma)
      if not m:
        pagemsg("WARNING: Something wrong, lemma '%s' doesn't end in consonant or vowel" % lemma)
        return False
      stem = m.group(1)
      # Substitute 'ch' with a single character to make the following code simpler.
      stem = stem.replace("ch", cs.TEMP_CH)
      if re.search(cs.cons_c + "[lr]" + cs.cons_c + "$", stem):
        # [[vrba]], [[slha]]; not reducible.
        return False
      elif re.search(cs.cons_c + "[bkhlrmnv]$", stem):
        return True
      else:
        return False

    def infer_alternations(inferred_decl, nom_sg, gen_sg, gen_pl):
      if "+" in inferred_decl:
        # Adjectival nouns don't have vowel alternations or reducibility
        return ""
      nom_sg = truncate_extra_forms(nom_sg)
      gen_sg = truncate_extra_forms(gen_sg)
      gen_pl = gen_pl and truncate_extra_forms(gen_pl)
      m = re.search(u"^(.*)([aeoě])$", nom_sg)
      reducible = None
      vowelalt = ""
      if m:
        if inferred_decl.startswith("m"):
          # Virile in -a or -e aren't reducible and have non-null genitive plural ending
          return ""
        vowel_stem, ending = m.groups()
        vowel_stem = cs.convert_paired_plain_to_palatal(vowel_stem, ending)
        if not gen_pl:
          return ""
        nonvowel_stem = gen_pl
        altspec = ""
        if nonvowel_stem == vowel_stem:
          reducible = False
        else:
          dereduced_stem = cs.dereduce(vowel_stem)
          if dereduced_stem and dereduced_stem == nonvowel_stem:
            reducible = True
          else:
            vowelalts = ["quant", u"quant-ě"]
            vowelalt_to_spec = {"quant": "#", u"quant-ě": u"#ě"}
            for vowelalt in vowelalts:
              if cs.apply_vowel_alternation(vowelalt, vowel_stem) == nonvowel_stem:
                altspec = vowelalt_to_spec[vowelalt]
                reducible = False
                break
              else:
                altstem = cs.apply_vowel_alternation(vowelalt, vowel_stem)
                if altstem and cs.dereduce(altstem) == nonvowel_stem:
                  altspec = vowelalt_to_spec[vowelalt]
                  reducible = True
                  break
            else: # no break
              pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_pl %s" %
                (nom_sg, gen_pl))
              return None
        default_reducible = determine_default_reducible(nom_sg)
        if reducible == default_reducible:
          return altspec
        elif reducible:
          return "*" + altspec
        else:
          return "-*" + altspec
      else:
        nonvowel_stem = nom_sg
        if "foreign" in inferred_decl:
          nonvowel_stem = re.sub("([ueo]s|um|on)$", "", nonvowel_stem)
        m = re.search(u"^(.*)([aueěyií])$", gen_sg)
        if not m:
          pagemsg("WARNING: Unrecognized genitive singular ending: %s" % gen_sg)
          return None
        vowel_stem, ending = m.groups()
        vowel_stem = cs.convert_paired_plain_to_palatal(vowel_stem, ending)
        if vowel_stem == nonvowel_stem:
          return ""
        elif cs.reduce(nonvowel_stem) == vowel_stem:
          return "*"
        elif cs.apply_vowel_alternation("quant", nonvowel_stem) == vowel_stem:
          return "#"
        elif cs.apply_vowel_alternation(u"quant-ě", nonvowel_stem) == vowel_stem:
          return u"#ě"
        else:
          pagemsg("WARNING: Unable to determine relationship between nom_sg %s and gen_sg %s" %
            (nom_sg, gen_sg))
          return None

    if tn == "cs-decl-noun":
      if not heads:
        heads = [pagetitle]
      lemma = heads[0]
      decl = infer_decl(lemma)

      nom_sg = fetch("nom_sg")
      gen_sg = fetch("gen_sg")
      dat_sg = fetch("dat_sg")
      acc_sg = fetch("acc_sg")
      voc_sg = fetch("voc_sg")
      loc_sg = fetch("loc_sg")
      ins_sg = fetch("ins_sg")
      nom_pl = fetch("nom_pl")
      gen_pl = fetch("gen_pl")
      dat_pl = fetch("dat_pl")
      acc_pl = fetch("acc_pl")
      voc_pl = fetch("voc_pl")
      loc_pl = fetch("loc_pl")
      ins_pl = fetch("ins_pl")
      is_adj = decl and "+" in decl
      gen_sg_endings = fetch_endings("gen_sg", is_adj, uniquify=False)
      dat_sg_endings = fetch_endings("dat_sg", is_adj, uniquify=False)
      voc_sg_endings = fetch_endings("voc_sg", is_adj, uniquify=False)
      loc_sg_endings = fetch_endings("loc_sg", is_adj, uniquify=False)
      ins_sg_endings = fetch_endings("ins_sg", is_adj, uniquify=False)
      nom_pl_endings = fetch_endings("nom_pl", is_adj, uniquify=False)
      gen_pl_endings = fetch_endings("gen_pl", is_adj, uniquify=False)
      dat_pl_endings = fetch_endings("dat_pl", is_adj, uniquify=False)
      loc_pl_endings = fetch_endings("loc_pl", is_adj, uniquify=False)
      ins_pl_endings = fetch_endings("ins_pl", is_adj, uniquify=False)

      cases = [
        "gen_sg", "dat_sg", "voc_sg", "loc_sg", "ins_sg",
        "nom_pl", "gen_pl", "dat_pl", "loc_pl", "ins_pl"
      ]
      ending_header = "\t".join("%s:%%s" % case for case in cases)
      form_header = " || ".join("%s" for case in cases)
      pagemsg(("%%s\tgender:%%s\tanimacy:%%s\tnumber:both\t%s\t| %s\t%%s" % (ending_header, form_header)) % (
        "/".join(heads), gender, animacy,
        gen_sg_endings, dat_sg_endings, voc_sg_endings, loc_sg_endings, ins_sg_endings,
        nom_pl_endings, gen_pl_endings, dat_pl_endings, loc_pl_endings, ins_pl_endings,
        canon(nom_sg), canon(gen_sg), canon(voc_sg), canon(loc_sg), canon(ins_sg),
        canon(nom_pl), canon(gen_pl), canon(dat_pl), canon(loc_pl), canon(ins_pl),
        decl))
      if len(heads) > 1:
        pagemsg("WARNING: Multiple heads: %s" % ",".join(heads))
      if decl is None:
        pagemsg("Unable to infer declension")
        continue
      pagemsg("Inferred declension %s<%s>" % (lemma, decl))
      declgender = decl[0]
      declan = "an" if ".an" in decl else "in"
      if animacy != "unknown" and (gender == "m" or declgender == "m") and declan != animacy:
        pagemsg("WARNING: Headword animacy %s differs from inferred declension animacy %s" % (animacy, declan))
      if gender != "unknown" and gender != declgender:
        pagemsg("WARNING: Headword gender %s differs from inferred declension gender %s" % (gender, declgender))

    elif tn == "cs-decl-noun-sg":
      pagemsg("WARNING: Singular-only unimplemented")
      continue
      nom_sg = fetch("nom_sg")
      gen_sg = fetch("gen_sg")
      dat_sg = fetch("dat_sg")
      acc_sg = fetch("acc_sg")
      voc_sg = fetch("voc_sg")
      loc_sg = fetch("loc_sg")
      ins_sg = fetch("ins_sg")
      if not heads:
        heads = [pagetitle]
      lemma = heads[0]
      gen_sg_endings = fetch_endings("2", genitive_singular_endings)
      dat_sg_endings = fetch_endings("3", dative_singular_endings)
      ins_sg_endings = fetch_endings("5", instrumental_singular_endings)
      loc_sg_endings = fetch_endings("6", locative_singular_endings)
      voc_sg_endings = fetch_endings("7", vocative_singular_endings)

      pagemsg("%s\tgender:%s\tanimacy:%s\tnumber:sg\tgen_sg:%s\tdat_sg:%s\tloc_sg:%s\tvoc_sg:%s\tnom_pl:-\tgen_pl:-\t| %s || \"?\" || %s || %s || %s || - || - || - || %s|| " % (
        "/".join(heads), gender, animacy, ":".join(seen_patterns),
        gen_sg_endings, dat_sg_endings, loc_sg_endings, voc_sg_endings,
        canon(nom_sg), canon(gen_sg), canon(loc_sg), canon(voc_sg), ins_sg_note(ins_sg)))

      if len(heads) > 1:
        pagemsg("WARNING: Multiple heads, not inferring declension: %s" % ",".join(heads))
        continue
      if gender == "unknown" or animacy == "unknown":
        pagemsg("WARNING: Unknown gender or animacy, not inferring declension")
        continue
      parts = []
      defg = infer_gender(lemma)
      if gender != defg:
        parts.append(gender)
      alternation = infer_alternations(nom_sg, gen_sg, None)
      reducible = alternation == "reducible"
      defaulted_seen_patterns = construct_defaulted_seen_patterns(seen_patterns, lemma, gender, reducible)
      if defaulted_seen_patterns:
        parts.append(",".join(defaulted_seen_patterns))
      if animacy != "in":
        parts.append(animacy)
      parts.append("sg")
      if alternation in ["i", "ie", "io"]:
        parts.append(alternation)
      if gender == "m" and re.search("^" + cs.uppercase_c, lemma):
        if re.search(u"у́?$", gen_sg):
          parts.append("genu")
        elif re.search(u"ю́?$", gen_sg):
          parts.append("genju")
      pagemsg("Inferred declension %s<%s>" % (lemma, ".".join(parts)))

    elif tn == "cs-decl-noun-pl":
      pagemsg("WARNING: Plural-only unimplemented")
      continue
      nom_pl = fetch("1")
      gen_pl = fetch("2")
      ins_pl = fetch("5")
      loc_pl = fetch("6")
      nom_pl_endings = fetch_endings("1", nominative_plural_endings)
      gen_pl_endings = fetch_endings("2", genitive_plural_endings)

      if not heads:
        heads = [pagetitle]
      pagemsg("%s\tgender:%s\tanimacy:%s\tnumber:pl\tgen_sg:-\tdat_sg:-\tloc_sg:-\tvoc_sg:-\tnom_pl:%s\tgen_pl:%s\t| %s || \"?\" || - || - || - || %s || %s || %s || || " % (
        "/".join(heads), gender, animacy,
        nom_pl_endings, gen_pl_endings,
        canon(nom_pl), canon(nom_pl), canon(gen_pl), canon(ins_pl)))


parser = blib.create_argparser("Analyze Czech noun declensions",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, default_cats=["Czech nouns"], stdin=True)
