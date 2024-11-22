#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse, json, unicodedata

import blib
from blib import getparam, rmparam, getrmparam, tname, pname, msg, errandmsg, site

# Rules for converting old declension templates to new ones:
# 1. Masculines:
# 1a. nom in -ur:
#    - gen -s, pl -ar:
#      {{is-decl-noun-m-s1|h|e|st|ur|i=i}}
#      - 4=ur; u-mutation happens automatically if 2=a
#      - i=i specifies dati/i
#      - i=i? specifies dati/i:-, but is also used for dati/-:i
#      - i=i- specifies dati/-
#      - i=?i specifies dati:-/i, but is also used for dat-:i/i
#      - i=? specifies dati:-/i:-; but is also used for dati:-/-:i, etc.
#      - i=?- specifies dati:-/-, but is also used for dat-:i/-
#      - i=-i specifies dat-/i
#      - i=-? specifies dat-/i:-, but is also used for dat-/-:i
#      - i=- specifies dat-/-
#      - i=[unspecified] usually specifies dat-/- (see code below)
#      - (NOTE: All of the above are frequently wrongly used and need manual review)
#    - gen -s, sg-only:
#      {{is-decl-noun-m-s1|h|a|mp|ur|i=i|pl=-}}
#    - gen -s, sg-only, indef-only:
#      {{is-decl-noun-m-s2|Nor|e|g|i=i|pl=-|def=-}} [THIS COULD USE s1 as well]
#    - gens:ar or genar:s, pl -ar:
#      {{is-decl-noun-m-s1|kr|a|ft|ur|i=i|ar=?}}
#    - genar, pl -ar:
#      {{is-decl-noun-m-s1|gr|au|t|ur|ar=ar|i=?-}}
#    - v-insertion:
#      {{is-decl-noun-m-s1|s|ö|ng|ur|v=v}}
#    - gen -s, pl -ir:
#      {{is-decl-noun-m-s2|bl|u|nd|i=i}}
#      {{is-decl-noun-m-s2|s|e|l|ur|i=i}}
#      {{is-decl-noun-m-s2|k|i|pp}}
#      {{is-decl-noun-m-s2|s|jó|ð|i=i?}}
#    - gen -s, pl -ir, i-mut in dat sg and nom/acc pl:
#      {{is-decl-noun-m-s3|sp|ó|n|u=u|s=s}}
#    - gen -s, pl -ir with j-insertion:
#      {{is-decl-noun-m-s2|sm|e|kk|j=?}}
#      - this is supposed to have optional j-insertion but the code to do this seems not written
#    - gen -ar, pl -ir:
#      {{is-decl-noun-m-s3|skuldun|au|t|u=u}} [THIS ONE IS WRONG]
#      {{is-decl-noun-m-s3|hl|u|t}}
#      - NOTE: empty 4th param would be needed to not get -ur in nominative
#    - gen -ar, pl -ir, uUmut to [[mörkuðum]]:
#      {{is-decl-noun-m-s3|m|a|rk|a|ð}}
#    - gen -ar, pl -ir, unuUmut to [[mánaðar]] (lemma [[mánuður]]):
#      {{is-decl-noun-m-s3|m|á|n|a|ð|u=u}}
#    - gen -ar, pl -ir, i-mut in dat sg and nom/acc pl:
#      {{is-decl-noun-m-s3|h|á|tt|u=u}}
#      {{is-decl-noun-m-s3|s|o|n|u=u}}
#    - gen -ar, pl -ir, unumut to e.g. katt- followed by i-mut to e.g. kett- (lemma [[köttur]]):
#      {{is-decl-noun-m-s3|k|a|tt|u=u}}
#      {{is-decl-noun-m-s3|k|a|kk|u=u}} (lemma [[kökkur]])
#      {{is-decl-noun-m-s3|f|ja|rð|u=u}} (lemma [[fjörður]])
#      {{is-decl-noun-m-s3|k|ja|l|u=u}} (lemma [[kjölur]])
#    - gen -s/ar, pl -ir:
#      {{is-decl-noun-m-s2|br|a|g|ar=?}}
#    - gen -s/ar, pl -ir, j-insertion:
#      {{is-decl-noun-m-s2|b|e|ð|i=i?|j=j|ar=?}}
#      {{is-decl-noun-m-s2|b|e|kk|j=j|ar=?}}
#    - gen -s, pl -ar/-ir like [[gígur]] "crater" need two declension tables:
#      {{is-decl-noun-m-s2|g|í|g|ur}}
#      {{is-decl-noun-m-s1|g|í|g|ur}}
#    - proper names with gen -ar:
#      {{is-decl-noun-m-s1|B|á|rð|ur|i=i|ar=ar|def=-|pl=-}}
#    - those pl-only in -ar:
#      {{is-decl-noun-m-s1|tónl|ei|k|sg=-}}
# 1b. empty nominative:
#    - gen -s, pl -ar:
#      {{is-decl-noun-m-s1|l|í|kjör}}
#      {{is-decl-noun-m-s1|m|au|r}}
#      {{is-decl-noun-m-s1||au|r|i=?-}}
#      {{is-decl-noun-m-s1|kl|á|r}}
#      {{is-decl-noun-m-s1|b|jó|r}}
#      {{is-decl-noun-m-s1|b|o|tn|i=i}}
#      {{is-decl-noun-m-s1|bisk|u|p|i=i}}
#      {{is-decl-noun-m-s1|str|æ|tó|ur=-|i=-}}
#    - gen -s, sg-only:
#      {{is-decl-noun-m-s1|s|au|r|pl=-}}
#    - gen lost after -Cs or -x, pl -ar:
#      {{is-decl-noun-m-s1|f|o|ss|i=i}}
#      {{is-decl-noun-m-s1|l|a|x|i=i}}
#      - happens automatically
#    - proper names with gen -ar:
#      {{is-decl-noun-m-s1|Neptún|u|s|i=i|ar=ar|pl=-|def=-}}
#    - gen -s, pl -ir:
#      {{is-decl-noun-m-s2|g|u|ð||i=i}}
#      - NOTE: empty 4th param is needed (?!) because otherwise you get 'guður' in nominative
#    - gen -s, pl -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|h|e|r||j=j}}
#      - NOTE: empty 4th param is needed (?!) because otherwise you get 'herur' in nominative
#    - gen -s/ar, pl -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|bl|æ||r|j=j|ar=?}}
#    - gen -ar, pl -ir, unumut to e.g. knarr- followed by i-mut to e.g. knerr- (lemma [[knörr]]):
#      {{is-decl-noun-m-s3|kn|a|rr|u=u|ur=}}
#      {{is-decl-noun-m-s3||a|rn|u=u}} (lemma [[örn]])
#      {{is-decl-noun-m-s3|b|ja|rn|u=u}} (lemma [[björn]])
# 1c. empty nominative in -ur that's part of the stem and contracts:
#    - dati/i:
#      {{is-decl-noun-m-s1|b|a|kst|u|r}}
#      - note 5th param; i/i is the default when contracts
#    - dati/i, sg-only:
#      {{is-decl-noun-m-s1|far|a|ng|u|r|pl=-}}
#    - dati/i, gen -s/ar:
#      {{is-decl-noun-m-s1|hl|á|t|u|r|ar=?}}
# 1d. empty nominative in -ar that's part of the stem and contracts:
#      {{is-decl-noun-m-s1|h|a|m|a|r}}
# 1e. empty nominative in -ar that's part of the stem and doesn't contract:
#    - gen in -s:
#      {{is-decl-noun-m-s1|rad|a|r}}
#    - gen in -ar, sg-only:
#      {{is-decl-noun-m-s3|m|a|r|ur=|i=?|pl=-}}
#    - gen in -s, pl in -ar:
#      {{is-decl-noun-m-s1|m|a|r|i=?}}
#    - gen in -s, pl in -ir:
#      {{is-decl-noun-m-s2|m|a|r||i=?}}
# 1f. nominative is -l:
#    - not preceded by a/i/u:
#      {{is-decl-noun-m-s1|b|í|l|l}}
#    - preceded by a/i/u, with contraction:
#      {{is-decl-noun-m-s1|g|a|ff|a|l}}
#    - preceded by a/i/u, without contraction:
#      {{is-decl-noun-m-s1|raf|a|l|l}}
#    - names in -kell:
#      {{is-decl-noun-kell|Þor}}
#    - special handling for [[ketill]]:
#      {{is-decl-noun-m-s1|k|a|t|i|l|l}}
#      - 6th param may be being ignored
#    - special handling for [[Ketill]]:
#      {{is-decl-noun-m-s1|K|a|t|i|l}}
#    - special handling for [[Egill]]:
#      {{is-decl-noun-m-s1||A|g|i|l|pl=-|def=-}}
# 1g. nominative is -n:
#    - not preceded by a/i/u:
#      {{is-decl-noun-m-s1|fl|ei|n|n|i=i}}
#    - preceded by a/i/u, with contraction:
#      {{is-decl-noun-m-s1|h|i|m|i|n}}
#    - proper names:
#      {{is-decl-noun-m-s2|Sk|á|n|n|i=i|def=-|pl=-}}
# 1h. nominative is -r:
#    - gen in -s, pl in -ar:
#      {{is-decl-noun-m-s1|h|ó||r}}
#    - gen in -s, pl in -ar, v-insertion in plural:
#      {{is-decl-noun-m-s1|hj|ö|r|v=v}}
#    - gen in -s, pl in -ir:
#      {{is-decl-noun-m-s2|n|á||r}}
#      - note: this wrongly produces two dative plurals, nám/náum, but only náunum in the definite
#      {{is-decl-noun-m-s2|sk|jó||r}}
#      - note: for some reason, this does not produce a dative plural skjóm
#    - gen in -s, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|gn|ý||r|j=j}}
#    - gen in -s/ar, pl in -ar:
#      {{is-decl-noun-m-s1|snj|ó||r|ar=?}}
#    - gen in -s/ar, pl in -ir:
#      {{is-decl-noun-m-s2|sj|ó||r|ar=?}}
#      - note: for some reason, this does not produce a dative plural sjóm
#    - gen in -s/ar, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|bl|æ||r|j=j|ar=?}}
#    - gen in -s, pl in -var:
#      {{is-decl-noun-m-s1|m|á||r|v=v}}
#      {{is-decl-noun-m-s1|snj|ó||r|ar=ar|v=v}}
#    - gen in -s, sg-only:
#      {{is-decl-noun-m-s2|gl|æ||r|pl=-}}
#      {{is-decl-noun-m-s1|þ|ey||r|pl=-}}
#    - gen in -var, sg-only:
#      {{is-decl-noun-m-s1|sj|á||r|v=v|ar=ar|pl=-}}
#      {{is-decl-noun-m-s3|s|æ|||v|ur=r|pl=-}}
#      - the latter marked as "incorrect use of template, although display is correct (for now)"
#    - gen in -s/var, sg-only:
#      {{is-decl-noun-m-s1|sn|æ||r|v=v|ar=?|i=?-|pl=-}}
#      - this generates dative snævi/snæ
#    - gen in -ar, pl in -ir, j-insertion in plural:
#      {{is-decl-noun-m-s2|b|æ||r|j=j|ar=ar}}
#    - proper name [[Már]]:
#      {{is-decl-noun-m-s1||M|á|r|def=-|pl=-}}

imut_vowel_re = "^([aáóuúoöAÁÓUÚOÖ]|j[úóa])$"

def generate_old_noun_forms(template, errandpagemsg, expand_text):
  result = expand_text(template)
  if not result:
    errandpagemsg("WARNING: Error generating forms, skipping")
    return None
  args = {}

  number = None
  definiteness = None
  if '\n! colspan="2" | singular\n' in result and '\n! colspan="2" | plural\n' in result:
    number = "both"
  elif '\n! colspan="2" | singular\n' in result:
    number = "s"
  elif '\n! colspan="2" | plural\n' in result:
    number = "p"
  else:
    errandpagemsg("WARNING: Can't determine number from HTML output, skipping")
    return None
  if "[[Appendix:Glossary#indefinite|indefinite]]" in result and "[[Appendix:Glossary#definite|definite]]" in result:
    definiteness = "both"
  elif "[[Appendix:Glossary#indefinite|indefinite]]" in result:
    definiteness = "ind"
  elif "[[Appendix:Glossary#definite|definite]]" in result:
    definiteness = "def"
  else:
    errandpagemsg("WARNING: Can't determine definiteness from HTML output, skipping")
    return None

  curcase = None
  caseind = None
  full_indices_to_number_def = {0: ("s", "ind"), 1: ("s", "def"), 2: ("p", "ind"), 3: ("p", "def")}
  full_number_indices_to_number = {0: "s", 1: "p"}
  full_def_indices_to_def = {0: "ind", 1: "def"}
  for line in result.split("\n"):
    m = re.search(r"\[\[Appendix:Glossary#(nominative|accusative|dative|genitive)\|\1\]\]", line)
    if m:
      curcase = m.group(1)[0:3]
      caseind = 0
      continue
    m = re.search('<span class="Latn" lang="is">(.*)</span>', line)
    if m:
      raw_forms = m.group(1)
      forms = re.findall(r"\[\[(.*?)#Icelandic\|\1\]\]", raw_forms)
      if not forms:
        errandpagemsg("WARNING: Couldn't parse line with forms: %s" % line.strip())
        return None
      if curcase is None or caseind is None:
        errandpagemsg("WARNING: Found line with forms before encountering case heading: %s" % line.strip())
        return None
      if number == "both" and definiteness == "both":
        if caseind >= 4:
          errandpagemsg("WARNING: Found line with too many forms after encountering case heading: %s" % line.strip())
          return None
        this_num, this_def = full_indices_to_number_def[caseind]
        key = "%s_%s_%s" % (this_def, curcase, this_num)
        caseind += 1
      elif number == "both" or definiteness == "both":
        if caseind >= 2:
          errandpagemsg("WARNING: Found line with too many forms after encountering case heading: %s" % line.strip())
          return None
        if number == "both":
          this_num = full_number_indices_to_number[caseind]
          key = "%s_%s_%s" % (definiteness, curcase, this_num)
        else:
          this_def = full_def_indices_to_def[caseind]
          key = "%s_%s_%s" % (this_def, curcase, number)
        caseind += 1
      else:
        if caseind >= 1:
          errandpagemsg("WARNING: Found line with too many forms after encountering case heading: %s" % line.strip())
          return None
        key = "%s_%s_%s" % (definiteness, curcase, number)
        caseind += 1
      args[key] = ",".join(forms)
  msg("From %s, returning %s" % (template, args))
  return args

def compare_new_and_old_templates(origt, newt, pagetitle, pagemsg, errandpagemsg):
  global args
  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, args.verbose)

  def sort_multiple(v):
    return ",".join(sorted(v.split(",")))

  def generate_old_forms():
    args = generate_old_noun_forms(origt, errandpagemsg, expand_text)
    if args is None:
      return args
    args = {k: sort_multiple(v) for k, v in args.items()}
    return args

  def generate_new_forms():
    new_generate_template = re.sub(r"^\{\{is-ndecl([|}])", r"{{User:Benwing2/is-ndecl\1", newt)
    new_generate_template = re.sub(r"\}\}$", "|json=1}}", new_generate_template)
    new_result = expand_text(new_generate_template)
    if not new_result:
      return None
    raw_args = json.loads(new_result)
    args = raw_args["forms"]
    def flatten_values(values):
      retval = []
      for v in values:
        if "footnotes" in v:
          # Skip proscribed note for r-stems to make the comparison work.
          if "[proscribed]" in v["footnotes"]:
            pass
          else:
            retval.append(v["form"])
        else:
          retval.append(v["form"])
      return ",".join(retval)
    args = {
      k: blib.remove_links(unicodedata.normalize("NFC", flatten_values(v))) for k, v in args.items()
      if not k.endswith("_linked")
    }
    args = {k: sort_multiple(v) for k, v in args.items()}
    return args, raw_args["genders"], raw_args["number"]

  retval = generate_new_forms()
  if retval is None:
    new_forms_for_compare, new_forms, new_genders, new_number = None, {}, [], ""
  else:
    new_forms, new_genders, new_number = retval
    new_forms_for_compare = new_forms

  return blib.compare_new_and_old_template_forms(origt, newt, generate_old_forms, lambda: new_forms_for_compare,
    pagemsg, errandpagemsg, already_split=True, show_all=True), new_forms, new_genders, new_number

def convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes):
  global args
  origt = str(t)
  tn = tname(t)
  def getp(param):
    return getparam(t, param)
  u = ""
  v = ""
  i = ""
  j = ""
  extra_candidates = [""]
  parts_candidates = [""]
  sg = getp("sg")
  pl = getp("pl")
  def_ = getp("def")
  indef = getp("indef")
  skapur_nadur = tn.startswith("is-decl-noun-m") and re.search("(skapur|naður)$", pagetitle)
  if indef:
    pagemsg("WARNING: Don't yet know how to handle indef=%s: %s" % (indef, origt))
    return None
  if re.search("(dagur|dyr|son|sonur|bylur)$", pagetitle):
    parts = ["@"]
  elif tn in ["is-decl-noun-m-s1", "is-decl-noun-m-s2", "is-decl-noun-m-s3"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    p4 = getp("4")
    p5 = getp("5")
    i = getp("i")
    j = getp("j")
    if tn == "is-decl-noun-m-s1" and p4 == "i" and p5 == "r" and re.search("^(k|kk|lk|nk|rk|sk|g|gg|lg|ng|rg)$", p3):
      j = j or "j"
    u = getp("u")
    v = getp("v")
    s = getp("s")
    ar = getp("ar")
    parts = ["m"]
    if sg != "-":
      if not skapur_nadur:
        pls = "" if pl == "-" or tn == "is-decl-noun-m-s1" else ",%sir" % v
        if ar == "?" or tn == "is-decl-noun-m-s3" and s == "?":
          parts_candidates = ["", ",s:%sar" % (j or v) + pls]
        elif ar == "ar" or tn == "is-decl-noun-m-s3" and not s:
          parts_candidates = ["", ",%sar" % (j or v) + pls]
        elif pls:
          parts_candidates = ["", "," + pls]
    if pagetitle.endswith("ur"):
      extra_candidates = ["", ".#"]
    elif pagetitle.endswith("r"):
      extra_candidates = ["", ".#", ".##"]
    if p2 in ["a", "i", "u"] and p3 == p4 and p3 in ["l", "n"]:
      # [[rafall]], [[Auðunn]] which don't contract, contrary to the norm for words in a/i/u + -ll/-nn
      parts_candidates = [p + ".-con" for p in parts_candidates]
    if u:
      if p4:
        extra_candidates = ["", ".unuUmut"]
      else:
        extra_candidates = ["", ".unumut.imut", ".imut"]
    if sg != "-":
      if i == "i":
        datspec = "dati" if def_ == "-" else "dati/i"
      elif i == "i?":
        datspec = "dati/i:-"
      elif i == "i-":
        datspec = "dati/-"
      elif i == "?i":
        datspec = "dati:-/i"
      elif i == "?":
        datspec = "dati:-" if def_ == "-" else "dati:-/i:-"
      elif i == "?-":
        datspec = "dati:-/-"
      elif i == "-i":
        datspec = "dat-/i"
      elif i == "-?":
        datspec = "dat-/i:-"
      elif i == "-":
        datspec = "dat-" if def_ == "-" else "dat-/-"
      elif i:
        pagemsg("WARNING: Unrecognized value i=%s: %s" % (i, origt))
        return None
      elif tn == "is-decl-noun-m-s3" and (p4 or u == "u"):
        datspec = "dati" if def_ == "-" else "dati/i"
      else:
        datspec = "dat-" if def_ == "-" else "dat-/-"
      datspec = "." + datspec
      extra_candidates.extend([ec + datspec for ec in extra_candidates])
  elif tn in ["is-decl-noun-m-w1", "is-decl-noun-m-w1a"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    p4 = getp("4")
    p5 = getp("5")
    i = getp("i")
    j = getp("j")
    parts = ["m"]
    if p5 in ["r", "st", "l", "n"]:
      extra_candidates = ["", ".uUmut", ".umut,uUmut"]
  elif tn in ["is-decl-noun-m-w2"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    parts = ["m"]
    extra_candidates = ["", ".imut"]
  elif tn in ["is-decl-noun-f-s1", "is-decl-noun-f-s2", "is-decl-noun-f-s3"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    p4 = getp("4")
    p5 = getp("5")
    i = getp("i")
    j = getp("j")
    u = getp("u")
    v = getp("v")
    ar = getp("ar")
    ur = getp("ur")
    parts = ["f"]
    if sg != "-":
      imut_prefix = tn == "is-decl-noun-f-s3" and re.search(imut_vowel_re, p2) and "^" or ""
      pls = ("" if pl == "-" or re.search("[áóú]$", pagetitle) or tn == "is-decl-noun-f-s2" else
             ",%sar" % (j or v) if tn == "is-decl-noun-f-s1" else ",%s%sur" % (imut_prefix, j or v))
      if tn == "is-decl-noun-f-s1" and not p3:
        if ar == "?":
          parts_candidates = ["", ",r:%sar" % (j or v) + pls]
        elif not ar and not j and not v:
          parts_candidates = ["", ",r" + pls]
        elif pls:
          parts_candidates = ["", "," + pls]
      elif tn == "is-decl-noun-f-s1" and p4 == "i":
        # strong feminines in -i like [[ermi]] "sleeve" and [[heiði]] "heath"; we need to override the gen (and pl,
        # which happens above), otherwise the genitive gets -i and plural gets -ir like weak feminines in -i
        parts_candidates = ["", ",%sar" % (j or v) + pls]
      elif ur == "?":
        parts_candidates = ["", ",%sar:%sur" % (j or v, imut_prefix) + pls]
      elif ur == "ur":
        parts_candidates = ["", ",%sur" % imut_prefix + pls]
      elif pls:
        parts_candidates = ["", "," + pls]
    if u == "u":
      extra_candidates = ["", ".acc+dat%su" % (j or v)]
    elif i == "i":
      extra_candidates = ["", ".acc+dat%si" % (j or v)]
  elif tn in ["is-decl-noun-f-w1", "is-decl-noun-f-w2"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    if tn == "is-decl-noun-f-w2":
      # in f-w1, the nom sg also contains the -j- so we don't need to specify it ever
      j = getp("j")
    n = getp("n")
    ar = getp("ar")
    parts = ["f"]
    if sg != "-" and pl != "-":
      if ar == "ar":
        parts_candidates = ["", ",,%sar" % j]
    # Put these overrides after things like .pl
    if pl != "-":
      if n == "n":
        extra_candidates = [".genplna"]
      elif n == "?":
        extra_candidates = [".genpla:na"]
  elif tn in ["is-decl-noun-n-s"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    p4 = getp("4")
    p5 = getp("5")
    j = getp("j")
    if j == "-":
      j = ""
    parts = ["n"]
  elif tn in ["is-decl-noun-n-w"]:
    p1 = getp("1")
    p2 = getp("2")
    p3 = getp("3")
    n = getp("n")
    parts = ["n"]
    # Put these overrides after things like .pl
    if pl != "-":
      if n == "n":
        extra_candidates = [".genplna"]
      elif n == "?":
        extra_candidates = [".genpla:na"]
  elif tn in ["is-decl-noun-alin", "is-decl-noun-altari", "is-decl-noun-bróðir", "is-decl-noun-dóttir",
              "is-decl-noun-faðir", "is-decl-noun-fingur", "is-decl-noun-faðir", "is-decl-noun-fé",
              "is-decl-noun-fótur", "is-decl-noun-hönd", "is-decl-noun-kona", "is-decl-noun-læti",
              "is-decl-noun-maður", "is-decl-noun-móðir", "is-decl-noun-nátt", "is-decl-noun-nótt",
              "is-decl-noun-systir", "is-decl-noun-vetur", "is-decl-noun-öxi"]:
    parts = ["@"]
  else:
    pagemsg("WARNING: Unrecognized Icelandic old noun declension template: %s" % origt)
    return None
  pagetitle_for_proper_check = re.sub("^.*[ -](.)", r"\1", pagetitle)
  isproper = pagetitle_for_proper_check[0].isupper()
  builtin_plural = tn == "is-decl-noun-læti" or pagetitle.endswith("dyr")
  def append_parts(part):
    nonlocal parts_candidates
    parts_candidates = [p + part for p in parts_candidates]
  if pl == "-" and def_ == "-":
    if isproper:
      pass
    elif skapur_nadur:
      append_parts(".indef")
    else:
      append_parts(".sg.indef")
  elif pl == "-":
    if isproper:
      append_parts(".def")
    elif skapur_nadur:
      pass
    else:
      append_parts(".sg")
  elif sg == "-" and def_ == "-":
    if isproper:
      append_parts(".pl")
    elif builtin_plural:
      append_parts(".indef")
    else:
      append_parts(".pl.indef")
  elif sg == "-":
    if isproper:
      append_parts(".pl.def")
    elif builtin_plural:
      pass
    else:
      append_parts(".pl")
  else:
    if isproper:
      append_parts(".common")
    elif skapur_nadur:
      append_parts(".both")
    else:
      pass

  candidate_pref = "".join(parts)
  if v:
    append_parts(".v")
  def generate_candidates(parts_candidates, extra_candidate):
    prefix = candidate_pref + parts_candidates
    if j:
      return [prefix + extra_candidate, prefix + ".j" + extra_candidate]
    else:
      return [prefix + extra_candidate]
  candidates = [candidate
    for extra_candidate in extra_candidates
    for parts_candidate in parts_candidates
    for candidate in generate_candidates(parts_candidate, extra_candidate)
  ]
  good_candidate = None
  for candidate in candidates:
    newt = "{{is-ndecl|%s}}" % candidate
    pagemsg("Considering replacing %s with %s" % (origt, newt))
    is_same, new_forms, new_genders, new_number = compare_new_and_old_templates(
        origt, newt, pagetitle, pagemsg, errandpagemsg)
    if is_same:
      pagemsg("Replaced %s with %s" % (origt, newt))
      good_candidate = candidate
      break
  else: # no break
    pagemsg("WARNING: No candidate checks out, not changing: %s" % origt)
    return None
  notes.append("convert %s to %s" % (origt, newt))
  # Erase all params
  del t.params[:]
  blib.set_template_name(t, "is-ndecl")
  t.add("1", good_candidate)
  return t, new_forms, new_genders, new_number

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  if "is-decl-noun-" not in text:
    return

  parsed = blib.parse_text(text)

  headt = None
  saw_headt = False

  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["is-noun", "is-proper noun", "is-noun/old", "is-proper noun/old"]:
      pagemsg("Saw %s" % str(t))
      saw_headt = True
      if headt:
        pagemsg("WARNING: Saw multiple head templates: %s and %s" % (str(headt), str(t)))
        return
      headt = t
    elif tn.startswith("is-decl-noun-"):
      #if not headt:
      #  pagemsg("WARNING: Saw declension template without {{is-noun}} head template: %s" % str(t))
      #  return
      #headt_as_decl_str = re.sub(r"^\{\{is-noun\|", "{{is-ndecl|", str(headt))
      #if str(t) != headt_as_decl_str:
      #  pagemsg("WARNING: Saw head template %s with different params from declension template %s" % (
      #    str(headt), str(t)))
      #  return
      retval = convert_template_to_new(t, pagetitle, pagemsg, errandpagemsg, notes)
      if retval is not None:
        newt, new_forms, new_genders, new_number = retval
        if headt:
          #if new_number == "pl":
          #  new_genders = ["%s-p" % g for g in new_genders]
          def convert_empty_to_hyphen(val):
            if not val:
              return "-"
            return val
          headt_genders = blib.fetch_param_chain(headt, ["1", "g", "gen"], "g")
          headt_gens = blib.fetch_param_chain(headt, "2", "gen")
          headt_pls = blib.fetch_param_chain(headt, ["3", "pl"], "pl")
          headt_genders = sorted(headt_genders)
          headt_gens = convert_empty_to_hyphen(",".join(sorted(headt_gens)))
          headt_pls = convert_empty_to_hyphen(",".join(sorted(headt_pls)))
          new_genders = sorted(new_genders)
          new_gens = convert_empty_to_hyphen(new_forms.get("ind_gen_s", ""))
          new_pls = convert_empty_to_hyphen(new_forms.get("ind_nom_p", ""))
          if headt_genders != new_genders:
            pagemsg("WARNING: Head gender(s) %s don't match new decl gender(s) %s: head=%s, newdecl=%s" % (
              ",".join(headt_genders), ",".join(new_genders), str(headt), str(newt)))
            return
          if headt_gens != "-" and headt_gens != new_gens:
            pagemsg("WARNING: Head genitive(s) %s don't match new decl genitive(s) %s: head=%s, newdecl=%s" % (
              headt_gens, new_gens, str(headt), str(newt)))
            return
          if headt_pls != "-" and headt_pls != new_pls:
            pagemsg("WARNING: Head plural(s) %s don't match new decl plural(s) %s: head=%s, newdecl=%s" % (
              headt_pls, new_pls, str(headt), str(newt)))
            return
          orig_headt = str(headt)
          headtn = tname(headt)
          if headtn.endswith("/old"):
            headtn = re.sub("/old$", "", headtn)
            blib.set_template_name(headt, headtn)
          # Erase all params
          del headt.params[:]
          headt.add("1", getparam(t, "1"))
          words = re.split("[ -]", pagetitle)
          if headtn == "is-noun" and any(word.isupper() for word in words):
            pagemsg("WARNING: Uppercase term with {{is-noun}}, review manually: %s" % str(headt))
          elif headtn == "is-proper noun" and any(word.islower() for word in words):
            pagemsg("WARNING: Lowercase term with {{is-proper noun}}, review manually: %s" % str(headt))
          #if pagetitle in manual_decls:
          #  headt.add("1", manual_decls[pagetitle])
          notes.append("convert %s to %s" % (orig_headt, str(headt)))
      headt = None

  #if not saw_headt:
  #  pagemsg("WARNING: Didn't see {{is-noun}} head template")
  #  return

  return str(parsed), notes

parser = blib.create_argparser("Convert Icelandic noun decl templates to new form",
    include_pagefile=True, include_stdin=True)
parser.add_argument("--direcfile", help="File containing manually specified declensions")
parser.add_argument("--ignore-differences", action="store_true", help="Convert even when new-old comparison doesn't check out. BE CAREFUL!")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

manual_decls = {}
if args.direcfile:
  for index, line in blib.iter_items_from_file(args.direcfile):
    if " " not in line:
      msg("WARNING: Line %s: No space in line: %s" % (index, line))
    elif " ||| " in line:
      noun, decl = line.split(" ||| ")
    else:
      noun, decl = line.split(" ", 1)
    if noun in manual_decls:
      msg("WARNING: Line %s: Saw noun %s twice" % noun)
    else:
      manual_decls[noun] = decl

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page,
  default_cats=["Icelandic nouns"], edit=True, stdin=True)
