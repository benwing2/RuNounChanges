#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# Convert fr-conj-* templates to fr-conj-auto, checking in the process that
# the conjugation doesn't change.

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site

# List of verbs are conjugated using 'être' in the passé composé.
etre = [
  "aller",
  "alterner",
  "apparaître",
  "arriver",
  "décéder",
  "entrer", "rentrer",
  "mourir",
  "naitre", "naître", "renaitre", "renaître",
  "partir", "départir",
  "rester",
  "surmener",
  "tomber", "retomber",
  "venir", "advenir", "bienvenir", "devenir", "intervenir", "parvenir", "provenir", "redevenir", "revenir", "survenir"
]

# List of verbs that can be conjugated using either 'avoir' or 'être' in the
# passé composé.
local avoir_or_etre = {
  "abdiquer", "abonnir","absconder","abuser","abâtardir","accommoder","acculturer","adapter","adhærer","admirer","aguerrir","aider","aliter","alourdir","alphabétiser","amerrir","anémier","apparenter","aspirer","attrouper","ausculter",
  "balbutier","barbeler","batailler","bloguer","bosseler","bouillir","bouturer","buer",
  "cagouler","candir","cartonner","cascader","caserner","cauchemarder","ceindre","cintrer","circuler","coincer","commercer","commémorer","comparaître","confectionner","connaitre","consentir","conspuer","consterner","constituer","contorsionner","contrister","convoyer","couver","couvrir","crever",
  "demeurer","déchoir","descendre","diplômer","disparaitre","disparaître","dormir","déborder","décapitaliser","déceler","découvrir","déficeler","défier","dégeler","déglutir","délaver","délecter","démanteler","démasquer","dénationaliser","dénoncer","dépendre","dépuceler","déshabituer","désister","déstabiliser","détériorer","dévaler","dévitaliser",
  "effoirer","emmener","encabaner","encapsuler","encaquer","encartonner","encartoucher","encaster","encommencer","endetter","endormir","enferrer","engrisailler","enlever","enserrer","envier","envoiler",
  "fasciner","ferrer","filigraner","fouetter","fourmiller","fringuer","fucker","fureter",
  "gargariser","gascher","gausser","geler","gnoquer","grincer","gémir",
  "haleter","harasser","hâter","hæsiter","hésiter",
  "identifier","impartir","inquieter","insonoriser",
  "larder","larmoyer","lemmatiser","lever","lier",
  "malmener","marketer","marteler","matter","maugréer","mener","mentir","microprogrammer","mincir","modeler","modéliser","monitorer","monter","muloter","multiplier","méconnaître",
  "niveler","obvenir","omettre","orner",
  "pailler","paraitre","paraître","parfumer","parjurer","parsemer","passer","permettre","perpétuer","peser","poiler","promettre","præsumer","prætendre","prélever","préserver",
  "qualifier","rainurer","ramener","rebattre","reboiser","reclasser","recoiffer","recoller","recomparaître","redormir","redécouvrir","refusionner","regeler","relancer","relever","relier","remonter","rendormir","repartir","repasser","repatrier","repentir","respitier","ressentir","ressortir","ressouvenir","restaurer","restreindre","restructurer","retourner","retransmettre","retweeter","réagir","réapparaitre","réapparaître","réentendre","référencer",
  "savourer","sentir","siffler","simplifier","sortir","soupeser","spammer","subvenir","suspecter","synchroniser",
  "taire","tiédir",
  "volleyer","ædifier",
  "élancer","élever","éloigner","étriver"
}

templates_to_change = [
"fr-conj-er",
"fr-conj-ir",
"fr-conj-re",
"fr-conj-aillir",
"fr-conj-aitre",
"fr-conj-aître",
"fr-conj-aller",
"fr-conj-avoir",
"fr-conj-ayer",
"fr-conj-boire",
"fr-conj-bruire",
"fr-conj-cer",
"fr-conj-cevoir",
"fr-conj-circoncire",
"fr-conj-clure (es)",
"fr-conj-clure (se)",
"fr-conj-coudre",
"fr-conj-courir",
"fr-conj-cre",
"fr-conj-crire",
"fr-conj-croire",
"fr-conj-croitre",
"fr-conj-croitre (décroitre)",
"fr-conj-devoir",
"fr-conj-confire",
"fr-conj-dire",
"fr-conj-dire (sez)",
"fr-conj-douloir",
"fr-conj-e-er",
"fr-conj-é-er",
"fr-conj-éger",
"fr-conj-envoyer",
"fr-conj-eoir",
"fr-conj-estre",
"fr-conj-être",
"fr-conj-xx-er",
"fr-conj-chauvir",
"fr-conj-faillir",
"fr-conj-faire",
"fr-conj-foutre",
"fr-conj-frire",
"fr-conj-fuir",
"fr-conj-ger",
"fr-conj-gésir",
"fr-conj-haïr",
"fr-conj-ir (e)",
"fr-conj-ir (s)",
"fr-conj-lire",
"fr-conj-luire",
"fr-conj-maudire",
"fr-conj-mettre",
"fr-conj-moudre",
"fr-conj-mourir",
"fr-conj-mouvoir",
"fr-conj-mouvoir (u)",
"fr-conj-naitre",
"fr-conj-naître",
"fr-conj-ouïr",
"fr-conj-oître",
"fr-conj-paître",
"fr-conj-plaire",
"fr-conj-pleuvoir",
"fr-conj-pourvoir",
"fr-conj-pouvoir",
"fr-conj-pre",
"fr-conj-prendre",
"fr-conj-prévoir",
"fr-conj-prévaloir",
"fr-conj-quérir",
"fr-conj-re (gn)",
"fr-conj-repleuvoir",
"fr-conj-repouvoir",
"fr-conj-résoudre",
"fr-conj-revouloir",
"fr-conj-rir",
"fr-conj-rire",
"fr-conj-saillir",
"fr-conj-savoir",
"fr-conj-souvenir",
"fr-conj-suffire",
"fr-conj-ensuivre",
"fr-conj-suivre",
"fr-conj-taire",
"fr-conj-tenir",
"fr-conj-traire",
"fr-conj-ttre",
"fr-conj-uire",
"fr-conj-valoir",
"fr-conj-venir",
"fr-conj-vêtir",
"fr-conj-vivre",
"fr-conj-voir",
"fr-conj-vouloir",
"fr-conj-yer"
]

refl_templates_to_change = [
    "fr-conj-er-refl-vowel",
    "fr-conj-er-refl-cons"
]

all_verb_props = [
  "inf", "pp", "ppr",
  #"inf_nolink", "pp_nolink", "ppr_nolink",
  "ind_p_1s", "ind_p_2s", "ind_p_3s", "ind_p_1p", "ind_p_2p", "ind_p_3p",
  "ind_i_1s", "ind_i_2s", "ind_i_3s", "ind_i_1p", "ind_i_2p", "ind_i_3p",
  "ind_ps_1s", "ind_ps_2s", "ind_ps_3s", "ind_ps_1p", "ind_ps_2p", "ind_ps_3p",
  "ind_f_1s", "ind_f_2s", "ind_f_3s", "ind_f_1p", "ind_f_2p", "ind_f_3p",
  "cond_p_1s", "cond_p_2s", "cond_p_3s", "cond_p_1p", "cond_p_2p", "cond_p_3p",
  "sub_p_1s", "sub_p_2s", "sub_p_3s", "sub_p_1p", "sub_p_2p", "sub_p_3p",
  "sub_pa_1s", "sub_pa_2s", "sub_pa_3s", "sub_pa_1p", "sub_pa_2p", "sub_pa_3p",
  "imp_p_2s", "imp_p_1p", "imp_p_2p"
]

cached_template_calls = {}

def find_old_template_props(template, pagemsg, verbose):
  name = str(template.name)
  if name in cached_template_calls:
    template_text = cached_template_calls[name]
  else:
    template_page = pywikibot.Page(site, "Template:%s" % name)
    if not page.exists():
      pagemsg("WARNING: Can't locate template 'Template:%s'" % name)
      return None
    template_text = str(template_page.text)
    cached_template_calls[name] = template_text
  if verbose:
    pagemsg("Found template text: %s" % template_text)
  for t in blib.parse_text(template_text).filter_templates():
    tname = str(t.name).strip() # template name may have spaces
    if tname == "fr-conj" or tname == "#invoke:fr-conj" and getparam(t, "1").strip() == "frconj":
      args = {}
      # Yuck. Template param names sometimes have spaces in them; must strip.
      tparams = [(str(param.name.strip()), str(param.value.strip())) for param in t.params]
      tparamdict = dict(tparams)
      debug_args = []
      def sub_template(val):
        val = re.sub(r"\{\{\{1\|?\}\}\}", getparam(template, "1"), val)
        val = re.sub(r"\{\{\{2\|?\}\}\}", getparam(template, "2"), val)
        val = re.sub(r"\{\{\{pp\|(.*?)\}\}\}", lambda m:getparam(template, "pp") or m.group(1), val)
        return val
      for pname, pval in tparams:
        canonpname = re.sub(r"\.", "_", pname)
        if canonpname in all_verb_props:
          pval = sub_template(pval)
          pnamealt = pname + ".alt"
          pvalalt = tparamdict.get(pnamealt, "")
          pvalalt = sub_template(pvalalt)
          if pval in ["N/A", "-"]:
            pval = ""
          if pvalalt in ["N/A", "-"]:
            pvalalt = ""
          vals = [x for x in [pval, pvalalt] if x]
          pval = ",".join(vals)
          if pval and not re.search(r"—", pval):
            debug_args.append("%s=%s" % (canonpname, pval))
            args[canonpname] = pval
      pagemsg("Found args: %s" % "|".join(debug_args))
      return args
  pagemsg("WARNING: Can't find {{fr-conj}} in template definition for %s" %
      str(template))
  return None

def compare_conjugation(index, page, template, refl, pagemsg, expand_text,
    verbose):
  # Force reflexive templates to succeed since they don't use {{fr-conj}}
  if str(template.name) in refl_templates_to_change:
    return []
  generate_result = expand_text("{{fr-generate-verb-forms%s}}" %
      ("|refl=yes" if refl else ""))
  if not generate_result:
    return None
  args = {}
  for arg in re.split(r"\|", generate_result):
    name, value = re.split("=", arg)
    args[name] = re.sub("<!>", "|", value)
  existing_args = find_old_template_props(template, pagemsg, verbose)
  if existing_args is None:
    return None
  difvals = []
  for prop in all_verb_props:
    curval = existing_args.get(prop, "").strip()
    newval = args.get("forms." + prop, "").strip()
    if curval == newval:
      continue
    elif "," in curval and "," in newval:
      curvalset = set(re.split(",", curval))
      newvalset = set(re.split(",", newval))
      if curvalset == newvalset:
        continue
    difvals.append((prop, (curval, newval)))
  return difvals

def process_page(page, index, parsed):
  pagetitle = str(page.title())
  subpagetitle = re.sub("^.*:", "", pagetitle)
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def expand_text(tempcall):
    return blib.expand_text(tempcall, pagetitle, pagemsg, verbose)

  pagemsg("Processing")

  if ":" in pagetitle:
    pagemsg("WARNING: Colon in page title, skipping")
    return

  text = str(page.text)

  notes = []
  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    name = str(t.name)
    if name in templates_to_change or name in refl_templates_to_change:
      refl = name in refl_templates_to_change
      difvals = compare_conjugation(index, page, t, refl, pagemsg, expand_text, verbose)
      if difvals is None:
        pass
      elif difvals:
        difprops = []
        for prop, (oldval, newval) in difvals:
          difprops.append("%s=%s vs. %s" % (prop, oldval or "(missing)", newval or "(missing)"))
        pagemsg("WARNING: Different conjugation when changing template %s to {{fr-conj-auto}}: %s" %
            (str(t), "; ".join(difprops)))
      else:
        aux = ""
        for param in t.params:
          pname = str(param.name)
          pval = str(param.value)
          if not pval.strip():
            continue
          if (pname not in ["1", "2", "3", "aux", "sort", "cat"] or
              pname == "3" and pval not in ["avoir", "être", "avoir or être"]):
            pagemsg("WARNING: Found extra param %s=%s in %s" %
                (pname, pval, str(t)))
          if pname == "aux" and pval != "avoir":
            aux = pval
            pagemsg("Found non-avoir auxiliary aux=%s in %s" % (
              pval, str(t)))
          auxpname = ("3" if name in ["fr-conj-e-er", "fr-conj-ir (s)"] else
              "aux" if name in ["fr-conj-xx-er", "fr-conj-é-er"] else "2")
          if pname == auxpname and pval != "avoir":
            aux = pval
            pagemsg("Found non-avoir auxiliary %s=%s in %s" % (
              pname, pval, str(t)))
        oldt = str(t)
        del t.params[:]
        t.name = "fr-conj-auto"
        if refl:
          t.add("refl", "yes")
        if aux:
          t.add("aux", aux)
        newt = str(t)
        pagemsg("Replacing %s with %s" % (oldt, newt))
        notes.append("replaced {{%s}} with %s" % (name, newt))

  return str(parsed), notes

parser = blib.create_argparser("Convert old fr-conj-* to fr-conj-auto",
  include_pagefile=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_page, edit=True,
  default_cats=["French verbs"])
