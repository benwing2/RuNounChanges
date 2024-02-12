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
  if not m:
    m = re.search(r"^Page ([0-9]+) (.*?): Found match for regex:.*?\{\{(?:alternative spelling of|alt sp|alt spell|altspell|altsp|alt sp of|alt spelling of)\|en(?:\|from=[^{}=|]*)?\|(.*?)[|}]", line)
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
  if to_page.lower() == from_page.lower():
    pagemsg("Saw from-page '%s' same as to-page with capitalization ignored" % from_page)
    continue
  def check_for_accented_ed(term):
    return not not re.search(r"[èé]d\b", term)
  def remove_accents(txt):
    return re.sub("[\u0300-\u036F]", "", unicodedata.normalize("NFD", txt))
  def ie_to_y(txt):
    return re.sub("ie$", "y", txt)
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
  def ph_to_f(txt):
    return txt.replace("ph", "f")
  def re_to_er(txt):
    return re.sub(r"re\b", "er", txt)
  def or_to_er(txt):
    return re.sub(r"or\b", "er", txt)
  def ey_to_y(txt):
    return re.sub(r"ey\b", "y", txt)
  def gue_to_g(txt):
    return re.sub(r"gue\b", "g", txt)
  def our_to_or(txt):
    return re.sub(r"our(s|e[dr]s?|ing|(?:ful|al|ous|less)?(?:ly)?)\b", r"or\1", txt)
  def common_our_to_or(txt):
    return re.sub(r"(col|[fs]av|lab|vap|od|succ|harb|arb|tum|rig|behavi|enam|endeav)our", r"\1or", txt)
  def ll_to_l(txt):
    return re.sub(r"ll(|er'?s?'?|ed|ing|ful)\b", r"l\1", txt)
  def grey_to_gray(txt):
    return re.sub("([Gg])rey", r"\1ray", txt)
  def plough_to_plow(txt):
    return re.sub("([Pp])lough", r"\1low", txt)
  if remove_accents(to_page) == remove_accents(from_page):
    if check_for_accented_ed(to_page) or check_for_accented_ed(from_page):
      pagemsg("WARNING: Saw from-page '%s' same as to-page with accents removed and needs manual checking for accented -ed" % from_page)
    else:
      pagemsg("Saw from-page '%s' same as to-page with accents removed" % from_page)
    continue
  if ie_to_y(to_page) == ie_to_y(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ie -> -y" % from_page)
    continue
  if ey_to_y(to_page) == ey_to_y(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ey -> -y" % from_page)
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
  if ll_to_l(to_page) == ll_to_l(from_page):
    pagemsg("Saw from-page '%s' same as to-page with -ll/-lled/-ller/-lling -> same with -l-" % from_page)
    continue
  if grey_to_gray(to_page) == grey_to_gray(from_page):
    pagemsg("Saw from-page '%s' same as to-page with grey -> gray" % from_page)
    continue
  if plough_to_plow(to_page) == plough_to_plow(from_page):
    pagemsg("Saw from-page '%s' same as to-page with plough -> plow" % from_page)
    continue
  def canonicalize(txt):
    txt = txt.lower().replace("-", "").replace(" ", "").replace("'", "").replace(".", "")
    txt = remove_accents(txt)
    txt = ey_to_y(txt)
    txt = ie_to_y(txt)
    txt = ise_to_ize(txt, omit_extra_e=True)
    txt = ise_to_ize(txt, omit_extra_e=True, with_y=True)
    txt = ae_oe_to_e(txt)
    txt = l_bar_to_l(txt)
    txt = ph_to_f(txt)
    txt = common_our_to_or(txt)
    txt = our_to_or(txt)
    txt = re_to_er(txt)
    txt = or_to_er(txt)
    txt = gue_to_g(txt)
    txt = ll_to_l(txt)
    txt = grey_to_gray(txt)
    txt = plough_to_plow(txt)
    txt = ible_eable_to_able(txt)
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
  pagemsg("Saw from-page '%s' not same as to-page, can't convert to {{alt spell}}" % from_page)
