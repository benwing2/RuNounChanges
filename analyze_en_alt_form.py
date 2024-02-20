#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
import unicodedata

import blib
from blib import getparam, rmparam, tname, pname, msg, site

parser = blib.create_argparser("Analyze uses of {{alt form}} for English terms")
parser.add_argument("--direcfile", help="Output from 'find_regex.py --all' on a dump file.")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for lineno, line in blib.iter_items_from_file(args.direcfile, start, end):
  def linemsg(txt):
    msg("Line %s: %s" % (lineno, txt))
  m = re.search(r"^Page ([0-9]+) (.*?): Found match for regex:.*?\{\{(?:alternative form of|alt form|altform|alt form of)\|en\|(.*?)[|}]", line)
  if m:
    from_template = "altform"
  if not m:
    m = re.search(r"^Page ([0-9]+) (.*?): Found match for regex:.*?\{\{(?:alternative spelling of|alt sp|alt spell|altspell|altsp|alt sp of|alt spelling of)\|en(?:\|from=[^{}=|]*)?\|(.*?)[|}]", line)
    if m:
      from_template = "altsp"
  if not m:
    linemsg("WARNING: Unrecognized line: %s" % line)
    continue
  pageind, to_page, from_page = m.groups()
  from_page = re.sub("#.*$", "", from_page)
  from_page = from_page.replace("[", "").replace("]", "")
  def pagemsg(txt):
    msg("Page %s %s: %s" % (pageind, to_page, txt))
  if to_page == from_page:
    pagemsg("WARNING: Saw from-page '%s' same as to-page" % from_page)
    continue
  if to_page.replace("-", "") == from_page.replace("-", ""):
    pagemsg("Saw from-page '%s' same as to-page with hyphens removed" % from_page)
    continue
  if to_page.replace("-", " ") == from_page.replace("-", " "):
    pagemsg("Saw from-page '%s' same as to-page with hyphens converted to spaces" % from_page)
    continue
  if to_page.replace(" ", "") == from_page.replace(" ", ""):
    pagemsg("Saw from-page '%s' same as to-page with spaces removed" % from_page)
    continue
  def check_for_pronounced_schwa(term):
    return not not re.search(r"([sx]e?|ce|[sc]he?)'s\b", term)
  if to_page.replace("'", "") == from_page.replace("'", ""):
    if check_for_pronounced_schwa(to_page) or check_for_pronounced_schwa(from_page):
      pagemsg("WARNING: Saw from-page '%s' same as to-page with apostrophes removed and needs manual checking for pronounced schwa" % from_page)
    else:
      pagemsg("Saw from-page '%s' same as to-page with apostrophes removed" % from_page)
    continue
  if to_page.replace(".", "") == from_page.replace(".", ""):
    pagemsg("Saw from-page '%s' same as to-page with periods removed" % from_page)
    continue
  if to_page.replace(",", "") == from_page.replace(",", ""):
    pagemsg("Saw from-page '%s' same as to-page with commas removed" % from_page)
    continue
  if to_page.replace("/", "") == from_page.replace("/", ""):
    pagemsg("Saw from-page '%s' same as to-page with slashes removed" % from_page)
    continue
  if to_page.lower() == from_page.lower():
    pagemsg("Saw from-page '%s' same as to-page with capitalization ignored" % from_page)
    continue
  def check_for_accented_ed(term):
    return not not re.search(r"[èé]d\b", term)
  def remove_accents(txt):
    return re.sub("[\u0300-\u036F]", "", unicodedata.normalize("NFD", txt))
  def ie_to_y(txt):
    return re.sub(r"ie\b", "y", txt)
  def ey_to_y(txt):
    return re.sub(r"ey\b", "y", txt)
  def ah_eh_to_a_e(txt):
    return re.sub(r"([ae])h\b", r"\1", txt)
  def ise_to_ize(txt, omit_extra_e=False, with_y=False):
    iy = "y" if with_y else "i"
    txt = re.sub(r"%ss(e[sdr]?|e?ing|e?ation|e?ational|e?able|e?ability)\b" % iy, r"%sz\1" % iy, txt)
    if omit_extra_e:
      txt = re.sub(r"%sze(ing|ation|ational|able|ability)\b" % iy, r"%sz\1" % iy, txt)
    return txt
  def ible_eable_to_able(txt):
    return re.sub(r"e?[ai](ble|bility)\b", r"a\1", txt)
  def ae_oe_to_e(txt):
    return txt.replace("ae", "e").replace("oe", "e").replace("æ", "e").replace("œ", "e")
  def l_bar_to_l(txt):
    return txt.replace("ł", "l")
  def y_to_i(txt):
    return txt.replace("y", "i")
  def ph_to_f(txt):
    return txt.replace("ph", "f")
  def re_to_er(txt):
    return re.sub(r"re\b", "er", txt)
  def or_to_er(txt):
    return re.sub(r"or\b", "er", txt)
  def gue_to_g(txt):
    return re.sub(r"gue\b", "g", txt)
  def ck_to_k(txt):
    return txt.replace("ck", "k")
  def q_to_k(txt):
    return txt.replace("q", "k")
  def k_to_c(txt):
    return re.sub(r"[Cc]?[KkCc]([abcdfgjklmnopqrstuvwxz])", r"c\1", txt)
  def gh_to_g(txt):
    return re.sub(r"[Gg]h([aou]|\b)", r"g\1", txt)
  def our_to_or(txt):
    return re.sub(r"our(s|e[dr]s?|ing|(?:ful|al|ous|less)?(?:ly)?)\b", r"or\1", txt)
  def common_our_to_or(txt):
    return re.sub(r"(col|[fs]av|lab|vap|od|succ|harb|arb|tum|rig|behavi|enam|endeav)our", r"\1or", txt)
  def ll_to_l(txt):
    return re.sub(r"ll(|er'?s?'?|ed|ing|ful|ate(?:[drs]|rs)?)\b", r"l\1", txt)
  def grey_to_gray(txt):
    return re.sub("([Gg])rey", r"\1ray", txt)
  def tyre_to_tire(txt):
    return re.sub(r"\b([Tt])yre", r"\1ire", txt)
  def arse_to_ass(txt):
    return re.sub(r"\b([Aa])rse", r"\1ss", txt)
  def plough_to_plow(txt):
    return re.sub("([Pp])lough", r"\1low", txt)
  def mould_to_mold(txt):
    return re.sub("([Mm])ould", r"\1old", txt)
  def defence_offence_licence_to_defense_offense_license(txt):
    return re.sub("(Def|def|Off|off|Lic|lic)ence", r"\1ense", txt)
  if remove_accents(to_page) == remove_accents(from_page):
    if check_for_accented_ed(to_page) or check_for_accented_ed(from_page):
      pagemsg("WARNING: Saw from-page '%s' same as to-page with accents removed and needs manual checking for accented -ed" % from_page)
    else:
      pagemsg("Saw from-page '%s' same as to-page with accents removed" % from_page)
    continue
  # These should go near the top in preference to more general changes like y -> i.
  if grey_to_gray(to_page) == grey_to_gray(from_page):
    pagemsg("Saw from-page '%s' same as to-page with grey -> gray" % from_page)
    continue
  if tyre_to_tire(to_page) == tyre_to_tire(from_page):
    pagemsg("Saw from-page '%s' same as to-page with tyre -> tire" % from_page)
    continue
  if arse_to_ass(to_page) == arse_to_ass(from_page):
    pagemsg("Saw from-page '%s' same as to-page with arse -> ass" % from_page)
    continue
  if plough_to_plow(to_page) == plough_to_plow(from_page):
    pagemsg("Saw from-page '%s' same as to-page with plough -> plow" % from_page)
    continue
  if mould_to_mold(to_page) == mould_to_mold(from_page):
    pagemsg("Saw from-page '%s' same as to-page with mould -> mold" % from_page)
    continue
  if defence_offence_licence_to_defense_offense_license(to_page) == defence_offence_licence_to_defense_offense_license(from_page):
    pagemsg("Saw from-page '%s' same as to-page with defence/offence/licence -> defense/offense/license" % from_page)
    continue
  if ie_to_y(to_page) == ie_to_y(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ie -> -y" % from_page)
    continue
  if ey_to_y(to_page) == ey_to_y(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ey -> -y" % from_page)
    continue
  if ah_eh_to_a_e(to_page) == ah_eh_to_a_e(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ah/-eh -> -a/-e" % from_page)
    continue
  if ise_to_ize(to_page) == ise_to_ize(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ise/-iser/-ises/-ised/-is(e)ing/-is(e)ation(al)/is(e)able/is(e)ability -> same with -iz-" % from_page)
    continue
  if ise_to_ize(to_page, omit_extra_e=True) == ise_to_ize(from_page, omit_extra_e=True):
    pagemsg("Saw from-page '%s' same as to-page with -iseing/-iseation(al)/iseable/iseability -> same with -iz- and omit extra -e-" % from_page)
    continue
  if ise_to_ize(to_page, with_y=True) == ise_to_ize(from_page, with_y=True):
    pagemsg("Saw from-page '%s' same as to-page with -yse/-yser/-yses/-ysed/-ys(e)ing/-ys(e)ation(al)/ys(e)able/ys(e)ability -> same with -yz-" % from_page)
    continue
  if ise_to_ize(to_page, omit_extra_e=True, with_y=True) == ise_to_ize(from_page, omit_extra_e=True, with_y=True):
    pagemsg("Saw from-page '%s' same as to-page with -yseing/-yseation(al)/yseable/yseability -> same with -yz- and omit extra -e-" % from_page)
    continue
  if ible_eable_to_able(to_page) == ible_eable_to_able(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ible/-eable/-ibility/-eability -> -able/-ability" % from_page)
    continue
  if ae_oe_to_e(to_page) == ae_oe_to_e(from_page):
    pagemsg("Saw from-page '%s' same as to-page with æ/œ/ae/oe -> e" % from_page)
    continue
  if l_bar_to_l(to_page) == l_bar_to_l(from_page):
    pagemsg("Saw from-page '%s' same as to-page with ł -> l" % from_page)
    continue
  if ph_to_f(to_page) == ph_to_f(from_page):
    pagemsg("Saw from-page '%s' same as to-page with ph -> f" % from_page)
    continue
  if y_to_i(to_page) == y_to_i(from_page):
    pagemsg("Saw from-page '%s' same as to-page with y -> i" % from_page)
    continue
  if common_our_to_or(to_page) == common_our_to_or(from_page):
    pagemsg("Saw from-page '%s' same as to-page with common-word -our -> -or" % from_page)
    continue
  if our_to_or(to_page) == our_to_or(from_page):
    pagemsg("Saw from-page '%s' same as to-page with misc-word -our -> -or" % from_page)
    continue
  if re_to_er(to_page) == re_to_er(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -re -> -er" % from_page)
    continue
  if or_to_er(to_page) == or_to_er(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -or -> -er" % from_page)
    continue
  if gue_to_g(to_page) == gue_to_g(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -gue -> -g" % from_page)
    continue
  if ck_to_k(to_page) == ck_to_k(from_page):
    pagemsg("Saw from-page '%s' same as to-page with ck -> k" % from_page)
    continue
  if q_to_k(to_page) == q_to_k(from_page):
    pagemsg("Saw from-page '%s' same as to-page with q -> k" % from_page)
    continue
  if k_to_c(to_page) == k_to_c(from_page):
    pagemsg("Saw from-page '%s' same as to-page with (c)ka/(c)ko/(c)ku/(c)kk/(c)kt/etc. -> same with c" % from_page)
    continue
  if gh_to_g(to_page) == gh_to_g(from_page):
    pagemsg("Saw from-page '%s' same as to-page with gha/gho/ghu/gh$ -> same with g" % from_page)
    continue
  if ll_to_l(to_page) == ll_to_l(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ll(ed)/-ller(s)/-lling/-llate(d)/-llater(s) -> same with -l-" % from_page)
    continue
  def canonicalize(txt):
    txt = txt.lower()
    txt = txt.replace("-", "").replace(" ", "").replace("'", "").replace(".", "").replace(",", "").replace("/", "")
    txt = remove_accents(txt)
    txt = grey_to_gray(txt)
    txt = tyre_to_tire(txt)
    txt = arse_to_ass(txt)
    txt = plough_to_plow(txt)
    txt = ible_eable_to_able(txt)
    txt = defence_offence_licence_to_defense_offense_license(txt)
    txt = ey_to_y(txt)
    txt = ie_to_y(txt)
    txt = y_to_i(txt)
    txt = ise_to_ize(txt, omit_extra_e=True)
    txt = ise_to_ize(txt, omit_extra_e=True, with_y=True)
    txt = ae_oe_to_e(txt)
    txt = l_bar_to_l(txt)
    txt = ph_to_f(txt)
    txt = common_our_to_or(txt)
    txt = our_to_or(txt)
    txt = re_to_er(txt)
    txt = or_to_er(txt)
    txt = ck_to_k(txt)
    txt = q_to_k(txt)
    txt = k_to_c(txt)
    txt = gue_to_g(txt)
    txt = gh_to_g(txt)
    txt = ll_to_l(txt)
    txt = ah_eh_to_a_e(txt)
    return txt
  if canonicalize(to_page) == canonicalize(from_page):
    nomsg = False
    if check_for_pronounced_schwa(to_page) or check_for_pronounced_schwa(from_page):
      pagemsg("WARNING: Saw from-page '%s' same as to-page with apostrophes removed and needs manual checking for pronounced schwa" % from_page)
      nomsg = True
    if check_for_accented_ed(to_page) or check_for_accented_ed(from_page):
      pagemsg("WARNING: Saw from-page '%s' same as to-page with accents removed and needs manual checking for accented -ed" % from_page)
      nomsg = True
    if not nomsg:
      pagemsg("Saw from-page '%s' same as to-page with full canonicalization applied" % from_page)
    continue
  pagemsg("Saw from-page '%s' not same as to-page, can't convert ||| {{%s}} ||| " % (from_page, from_template))
