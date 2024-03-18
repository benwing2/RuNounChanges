#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, tname, pname, msg, errandmsg, site

blib.getData()

lects_to_codes = {
  "Hainanese": "nan-hnm",
  "Jinjiang Hokkien": "nan-jin",
  "Malaysia Hokkien": "nan-hbl-MY",
  "Philippine Hokkien": "nan-hbl-PH",
  "Puxian Min": "cpx",
  "Quanzhou Hokkien": "nan-qua",
  "Singaporean Hokkien": "nan-hbl-SG",
  "Singapore Hokkien": "nan-hbl-SG",
  "Taiwanese Hakka": "hak-TW",
  "Taiwanese Hokkien": "nan-hbl-TW",
  "Teochew": "nan-tws",
  "Xiamen Hokkien": "nan-xia",
  "Zhongshan Min": "zhx-zho",
  "Zhangzhou Hokkien": "nan-zha",
  "Hokkien": "nan-hbl",
  "Leizhou Min": "nan-luh",
  "Xiamen & Zhangzhou Hokkien": ["nan-xia", "nan-zha"],
  "Xiamen and Zhangzhou Hokkien": ["nan-xia", "nan-zha"],
  "Quanzhou & Xiamen Hokkien": ["nan-qua", "nan-xia"],
  "Zhangzhou & Taiwanese Hokkien": ["nan-zha", "nan-hbl-TW"],
  "Xiamen & Taiwanese Hokkien": ["nan-xia", "nan-hbl-TW"],
  "Xiamen and Taiwanese Hokkien": ["nan-xia", "nan-hbl-TW"],
  "Taiwanese Min Nan and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Malaysia and Singapore Hokkien": ["nan-hbl-MY", "nan-hbl-SG"],
  # others
  "Cantonese": "yue",
  "Hong Kong Cantonese": "yue-HK",
  "Hakka": "hak",
  "Mandarin": "cmn",
  "Guilin Mandarin": "cmn-gui",
  "Xining": "cmn-xin",
  "Northern Min": "mnp",
  "Eastern Min": "cdo",
  "Central Min": "czo",
  "Jin": "cjy",
  "Gan": "gan",
  "Xiang": "hsn", # FIXME: convert to more specific?
  "Wu": "wuu", # FIXME: convert to more specific?
  "Sichuanese": "zhx-sic",
  "Sichuan": "zhx-sic",
  "Dungan": "dng",
  "Wenzhounese": "wuu-wen",
  "Wenzhou": "wuu-wen",
  "Ningbo Wu": "wuu-ngb", # FIXME: Rename code
  "Ningbo": "wuu-ngb", # FIXME: Rename code
  "Shanghainese Wu": "wuu-sha",
  "Shanghainese": "wuu-sha",
  "Shanghai": "wuu-sha",
  "Zhao'an Hakka": "hak-zha",
  "Shao'an Hakka": "hah-zha", # FIXME: I assume this is a mistake for Zhao'an
  "Yangzhou Mandarin": "cmn-yan",
  "Beijing": "cmn-bei",
  "Beijing Mandarin": "cmn-bei",
  "Northeastern Mandarin": "cmn-noe",
  "Taiwanese Mandarin": "cmn-TW",
  "Taiwan Mandarin": "cmn-TW",
  "Huizhou": "czh",
  # occurring only once:
  "Waxiang": "wxa",
  "Taishanese": "zhx-tai",
  "Suzhounese": "wuu-szh", # FIXME: Maybe rename code
  "Loudi": "hsn-lou",
  "Tianjin": "cmn-tia",
  "Northern Wu": "wuu-nor",
  "Lanyin Mandarin": "cmn-lan",
  "Central Plains Mandarin": "cmn-cep",
  # needed:
  # "Xinzhou": "?",
  # "Pingxiang Gan": "?",
  # "Luoyang": "?",
  # "Luoyang Mandarin": "?",
  # "Southwestern Mandarin": "?",
  # "Longyan Min": "?",
  # "Liuzhou Mandarin": "?",
  # "Liuzhou": "?",
  # "Huizhou": "?",
  # "Anxi Hokkien": "?",
  # "Tainan Hokkien": "?",
  # "Taichung & Tainan Hokkien": "?",
  # "Muping": "?",
  # "Muping Mandarin": "?",
  # "Mandalay Taishanese": "?",
  # "Harbin": "?",
  # "Harbin Mandarin": "?",
  # "Urumqi": "?",
  # needed, occurring only once:
  # "Yudu Hakka": "?",
  # "Yongchun Hokkien": "?",
  # "Yinchuan": "?",
  # "Xi'an Mandarin": "?",
  # "Xi'an": "?",
  # "Wanrong": "?",
  # "Taiyuan": "?",
  # "Pinghua": "?",
  # "Nanchang Gan": "?",
  # "Jinhua Wu": "?",
  # "Jilu Mandarin": "?",
  # "Hsinchu & Taichung Hokkien": "?",
  # "Guiyang": "?",
  # skipped:
  # "Classical Chinese": # ambiguous
  # "Hong Kong": ambiguous,
  # "Taiwan": # ambiguous
  # "Singapore": # ambiguous
  # "Malaysia": # ambiguous
  # "Internet slang":
  # "Classical": # ambiguous
  # "Buddhist temple":
  # "Buddhism":
  # "TCM":
  # "Thailand": # ambiguous?
  # "Taiwanese": # ambiguous
  # "Son of Heaven":
  # "Northern Mandarin": # ambiguous?
  # "Mainland": # ambiguous
  # "Macau":
  # "Internet":
  # skipped, occurring only once:
  # "Southeast Asia; dated or dialectal in Mainland China",
  # "Sichuanese or Internet slang",
  # "Qing Dynasty":
  # "Philippines": # ambiguous
  # "Northern China": # ambiguous
  # "Korean calligraphy":
  # "Japanese calligraphy":
  # "Guangdong": # ambiguous?
  # "Fuzhou": # ambiguous
  # "Eastern Min; Southern Min": # ambiguous
  # "Classical Chinese or in compounds":
  # "Christianity":
  # "Chinese landscape garden":
  # "Australia":
  # "ACG":
}

# Hokkien varieties, not including nan-hbl itself.
hokkien_varieties = {
  "nan-jin",
  "nan-qua",
  "nan-xia",
  "nan-zha",
  "nan-hbl-MY",
  "nan-hbl-PH",
  "nan-hbl-SG",
  "nan-hbl-TW",
}

lects_to_codes_from_label_module = {
  "Beijing": "cmn-bei",
  "Peking": "cmn-bei",
  "Pekingese": "cmn-bei",
  "Beijing Mandarin": "cmn-bei",
  "Cantonese": "yue",
  "Central Min": "czo",
  "Min Zhong": "czo",
  "Central Plains Mandarin": "cmn-cep",
  "Zhongyuan Mandarin": "cmn-cep",
  "Dungan": "dng",
  "Eastern Min": "cdo",
  "Min Dong": "cdo",
  "Gan": "gan",
  "Guilin Mandarin": "cmn-gui",
  "Hainanese": "nan-hnm",
  "Hainan Min": "nan-hnm",
  "Hainan Min Chinese": "nan-hnm",
  "Hakka": "hak",
  "Hangzhounese Wu": "wuu-hzh",
  "Hangzhounese": "wuu-hzh",
  "Hangzhou Wu": "wuu-hzh",
  "Hangzhou dialect": "wuu-hzh",
  "Hokkien": "nan-hbl",
  "Hong Kong Cantonese": "yue-HK",
  "HKC": "yue-HK",
  "Jin": "cjy",
  "Lanyin Mandarin": "cmn-lan",
  "Lan-Yin Mandarin": "cmn-lan",
  "Leizhou Min": "nan-luh",
  "Mandarin": "cmn",
  "Ningbonese Wu": "wuu-ngb",
  "Ningbonese": "wuu-ngb",
  "Ningbo Wu": "wuu-ngb",
  "Ningbo dialect": "wuu-ngb",
  "Ningbo": "wuu-ngb",
  "Northeastern Mandarin": "cmn-noe",
  "northeastern Mandarin": "cmn-noe",
  "NE Mandarin": "cmn-noe",
  "Northern Min": "mnp",
  "Min Bei": "mnp",
  "Northern Wu": "wuu-nor",
  "Taihu": "wuu-nor",
  "Taihu Wu": "wuu-nor",
  "Penang Hokkien": "nan-pen",
  "Philippine Hokkien": "nan-hbl-PH",
  "PH Hokkien": "nan-hbl-PH",
  "Ph Hokkien": "nan-hbl-PH",
  "PH": "nan-hbl-PH",
  "PHH": "nan-hbl-PH",
  "Puxian Min": "cpx",
  "Puxian": "cpx",
  "Pu-Xian Min": "cpx",
  "Pu-Xian": "cpx",
  "Xinghua": "cpx",
  "Hinghwa": "cpx",
  "Quanzhou": "nan-qua",
  "Quanzhou dialect": "nan-qua",
  "Chinchew": "nan-qua",
  "Chinchew dialect": "nan-qua",
  "Choanchew": "nan-qua",
  "Choanchew dialect": "nan-qua",
  "Shanghainese Wu": "wuu-sha",
  "Shanghainese": "wuu-sha",
  "Shanghai dialect": "wuu-sha",
  "Sichuanese": "zhx-sic",
  "Sichuan": "zhx-sic",
  "Singaporean Hokkien": "nan-hbl-SG",
  "Singapore Hokkien": "nan-hbl-SG",
  "Suzhounese Wu": "wuu-szh",
  "Suzhounese": "wuu-szh",
  "Suzhou Wu": "wuu-szh",
  "Suzhounese dialect": "wuu-szh",
  "Taishanese": "zhx-tai",
  "Toishanese": "zhx-tai",
  "Hoisanese": "zhx-tai",
  "Taiwanese Hakka": "hak-TW",
  "Taiwan Hakka": "hak-TW",
  "Taiwanese Hokkien": "nan-hbl-TW",
  "Taiwanese Southern Min": "nan-hbl-TW",
  "Taiwanese Min Nan": "nan-hbl-TW",
  "Taiwan Hokkien": "nan-hbl-TW",
  "Taiwan Southern Min": "nan-hbl-TW",
  "Taiwan Min Nan": "nan-hbl-TW",
  "Taiwanese Hokkien and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hokkien & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka and Hokkien": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka & Hokkien": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Southern Min and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Southern Min & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka and Southern Min": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka & Southern Min": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Min Nan and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Min Nan & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka and Min Nan": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Hakka & Min Nan": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hokkien and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hokkien & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka and Hokkien": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka & Hokkien": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Southern Min and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Southern Min & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka and Southern Min": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka & Southern Min": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Min Nan and Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Min Nan & Hakka": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka and Min Nan": ["nan-hbl-TW", "hak-TW"],
  "Taiwan Hakka & Min Nan": ["nan-hbl-TW", "hak-TW"],
  "Taiwanese Mandarin": "cmn-TW",
  "Taiwan Mandarin": "cmn-TW",
  "Teochew": "nan-tws",
  "Tianjin": "cmn-tia",
  "Tianjin dialect": "cmn-tia",
  "Tianjin Mandarin": "cmn-tia",
  "Tianjinese": "cmn-tia",
  "Waxiang": "wxa",
  "Wenzhou Wu": "wuu-wen",
  "Wenzhounese": "wuu-wen",
  "Wenzhou": "wuu-wen",
  "Oujiang": "wuu-wen",
  "Wu": "wuu",
  "Wuhan": "cmn-wuh",
  "Hankou": "cmn-wuh",
  "Hankow": "cmn-wuh",
  "Wuhan dialect": "cmn-wuh",
  "Xiamen": "nan-xia",
  "Xiamen dialect": "nan-xia",
  "Amoy": "nan-xia",
  "Amoy dialect": "nan-xia",
  "Xiang": "hsn",
  "Zhongshan Min": "zhx-zho",
  "Zhangzhou": "nan-zha",
  "Zhangzhou dialect": "nan-zha",
  "Changchew": "nan-zha",
  "Changchew dialect": "nan-zha",
}

for lect, code in lects_to_codes_from_label_module.items():
  if lect not in lects_to_codes:
    lects_to_codes[lect] = code

def link_term(term):
  if "[" in term:
    return term
  return "[[%s]]" % term

def get_params_from_zh_l(t):
  # This is an utter piece of shit. Ported from lines 53-74 of [[Module:zh/link]].
  def getp(param):
    return getparam(t, param)
  arg1 = getp("1")
  arg2 = getp("2")
  arg3 = getp("3")
  arg4 = getp("4")
  arggloss = getp("gloss")
  argtr = getp("tr")
  text = None
  tr = None
  gloss = None
  if arg2 and re.search("[一-龯㐀-䶵]", arg2):
    gloss = arg4
    tr = arg3
    text = arg1 + "/" + arg2
  else:
    text = arg1
    if arggloss:
      tr = arg2
      gloss = arggloss
    else:
      if arg3 or (arg2 and (re.search("[āōēīūǖáóéíúǘǎǒěǐǔǚàòèìùǜâêîôû̍ⁿ]", arg2) or re.search("[bcdfghjklmnpqrstwz]h?y?[aeiou][aeiou]?[iumnptk]?g?[1-9]", arg2))):
        tr = arg2
        gloss = arg3
      else:
        gloss = arg2
  if argtr:
    tr = argtr
    gloss = gloss or arg2
  return text, tr, gloss

def find_southern_min_types(index, pagetitle, linkt, linkpage, linkgloss, all_types=False):
  def make_msg_txt(txt):
    return "Page %s %s: Link page %s%s in %s: %s" % (
        index, pagetitle, link_term(linkpage), linkgloss and " (glossed as '%s')" % linkgloss or "", str(linkt), txt)
  def errandpagemsg(txt):
    errandmsg(make_msg_txt(txt))
  def pagemsg(txt):
    msg(make_msg_txt(txt))
  canon_pagename = re.sub("//.*", "", blib.remove_links(linkpage))
  page = pywikibot.Page(site, canon_pagename)
  linkmsg = "synonym/antonym %s (template %s)" % (linkpage, str(linkt))
  if not blib.safe_page_exists(page, errandpagemsg):
    return "Found %s but page doesn't exist" % linkmsg
  text = blib.safe_page_text(page, errandpagemsg)
  if not text:
    return "Error fetching text for %s" % linkmsg
  chinese_text = blib.find_lang_section(text, "Chinese", pagemsg)
  if chinese_text is None:
    return "Could locate Chinese section for %s" % linkmsg

  def find_section_min_types(sectext):
    parsed = blib.parse_text(sectext)
    lects_seen = [] # sets don't remember the order of addition
    def add(lect):
      if lect not in lects_seen:
        lects_seen.append(lect)
    saw_zh_pron = False
    saw_zh_label = False
    for t in parsed.filter_templates():
      tn = tname(t)
      def getp(param):
        return getparam(t, param)
      if tn == "zh-pron":
        if getp("mn"):
          add("Hokkien")
        if getp("mn-t"):
          add("Teochew")
        if getp("mn-l"):
          add("Leizhou Min")
        saw_zh_pron = True

      if tn in blib.label_templates and getp("1") == "zh":
        for i in range(2, 30):
          label = getp(str(i))
          if label in lects_to_codes:
            add(label)
          elif re.search("(Hainanese|Hainan Min)", label): # or Hainan Min Chinese
            add("Hainanese")
          elif re.search("(Philippine Hokkien|PH Hokkien|Ph Hokkien|^PH$|^PHH$)", label):
            add("Philippine Hokkien")
          elif re.search("(Puxian|Pu-Xian|Xinghua|Hinghwa)", label): # or Puxian Min or Pu-Xian Min
            add("Puxian Min")
          elif re.search("(Quanzhou|Chinchew|Choanchew)", label): # or Quanzhou dialect or Chinchew dialect or Choanchew dialect
            add("Quanzhou Hokkien")
          elif re.search("(Singaporean Hokkien|Singapore Hokkien)", label):
            add("Singaporean Hokkien")
          elif re.search("(Taiwanese Hakka|Taiwan Hakka)", label):
            add("Taiwanese Hakka")
          elif re.search("(Taiwanese Hokkien|Taiwan Hokkien)", label):
            add("Taiwanese Hakka")
          elif re.search("(Taiwan[a-z]* Hokkien .* Hakka|Taiwan[a-z]* Hakka .* Hokkien|Taiwan[a-z]* (Southern Min|Min Nan) .* Hakka|Taiwan[a-z]* Hakka .* (Southern Min|Min Nan))", label):
            add("Taiwanese Hokkien")
            add("Taiwanese Hakka")
          elif "Teochew" in label:
            add("Teochew")
          elif re.search("(Xiamen|Amoy)", label): # or Xiamen dialect or Amoy dialect
            add("Xiamen Hokkien")
          elif "Zhongshan Min" in label:
            add("Zhongshan Min")
          elif re.search("(Zhangzhou|Changchew)", label): # or Zhangzhou dialect or Changchew dialect
            add("Zhangzhou Hokkien")
          elif label == "Hokkien":
            add("Hokkien")
          elif "Hokkien" in label:
            add("Hokkien")
            pagemsg("WARNING: Saw label '%s' with Hokkien in it, treating as Hokkien, needs review: %s" % (
              label, str(t)))
          elif "Leizhou" in label:
            add("Leizhou Min")
        saw_zh_label = True

    # canonicalize lects
    canon_lects_seen = []
    for lect in lects_seen:
      if lect not in lects_to_codes:
        raise ValueError("Unrecognized lect type '%s' generated" % lect)
      code = lects_to_codes[lect]
      lang_obj = blib.languages_byCode[code] if code in blib.languages_byCode else blib.etym_languages_byCode[code]
      canon_name = lang_obj["canonicalName"]
      if canon_name not in canon_lects_seen:
        canon_lects_seen.append(canon_name)
    if canon_lects_seen != lects_seen:
      pagemsg("Canonicalizing derived lect(s) %s to %s" % (",".join(lects_seen), ",".join(canon_lects_seen)))
    if not all_types:
      # Pare down to only nan-* types.
      pared_lects_seen = []
      for lect in lects_seen:
        if lect not in lects_to_codes:
          raise ValueError("Unrecognized lect type '%s' generated" % lect)
        code = lects_to_codes[lect]
        if code.startswith("nan-"):
          pared_lects_seen.append(lect)
      if pared_lects_seen != lects_seen:
        pagemsg("Paring derived lect(s) %s to Southern-Min-only %s" % (",".join(lects_seen), ",".join(pared_lects_seen)))
        lects_seen = pared_lects_seen
    return lects_seen, saw_zh_pron, saw_zh_label

  if "Etymology 1" in chinese_text or "Pronunciation 1" in chinese_text:
    subsections, subsections_by_header, subsection_headers, subsection_levels = (
      blib.split_text_into_subsections(chinese_text, pagemsg)
    )
    etym_pron_sectext = []
    index_of_secbegin = None
    for k in range(2, len(subsections), 2):
      if re.search("= *(Etymology|Pronunciation) +[0-9]+ *=", subsections[k - 1]):
        if index_of_secbegin:
          etym_pron_sectext.append((subsections[index_of_secbegin].strip(), "".join(subsections[index_of_secbegin: k - 1])))
        index_of_secbegin = k - 1
    if not index_of_secbegin:
      return ("Something wrong, can't find any Etymology N or Pronunciation N sections in Chinese section for %s" %
              linkmsg)
    etym_pron_sectext.append((subsections[index_of_secbegin].strip(), "".join(subsections[index_of_secbegin:])))

    southern_min_types = None
    header_for_southern_min_types = None
    for stage in [1, 2]:
      for secheader, sectext in etym_pron_sectext:
        if stage == 1 and linkgloss and not re.search(re.escape(blib.remove_links(linkgloss)), sectext):
          pagemsg("Stage 1 processing section header %s, skipping because bare link gloss '%s' not found in section text" %
                  (secheader, blib.remove_links(linkgloss)))
          continue
        section_min_types, _, _ = find_section_min_types(sectext)
        if section_min_types:
          if not southern_min_types:
            southern_min_types = section_min_types
            header_for_southern_min_types = secheader
          elif set(southern_min_types) != set(section_min_types):
            return "Saw multiple Etymology/Pronunciation sections with different Southern Min Types for %s: section %s has %s while section %s has %s; skipping" % (
              linkmsg, header_for_southern_min_types, ",".join(southern_min_types), secheader, ",".join(section_min_types))
      if southern_min_types:
        break

    if not southern_min_types:
      return "Multiple Etymology or Pronunciation sections for %s and couldn't identify any Southern Min lect from scraping page" % (
          linkmsg)
    return southern_min_types

  section_min_types, saw_zh_pron, saw_zh_label = find_section_min_types(chinese_text)
  if not section_min_types:
    saw_msgs = []
    if saw_zh_pron:
      saw_msgs.append("saw {{zh-pron}}")
    else:
      saw_msgs.append("didn't see {{zh-pron}}")
    if saw_zh_label:
      saw_msgs.append("saw {{lb|zh|...}}")
    else:
      saw_msgs.append("didn't see any {{lb|zh|...}}")
    parsed = blib.parse_text(chinese_text)
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "zh-see":
        canon = getparam(t, "1")
        pagemsg(
            "WARNING (may be ignorable): Couldn't identify any Southern Min lect from scraping page (%s), but saw %s, redirecting"
            % ("; ".join(saw_msgs), str(t)))
        return find_southern_min_types(index, pagetitle, linkt, canon, linkgloss, all_types=all_types)
    return "Couldn't identify any Southern Min lect from scraping page %s (%s)" % (linkmsg, "; ".join(saw_msgs))
  return section_min_types

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    def getp(param):
      return getparam(t, param)
    if tn in ["col1", "col2", "col3", "col4", "col5", "col-auto"] and getp("1") == "zh":
      def lect_types_to_codes(lect_types):
        new_lang_codes = []
        for lect_type in lect_types:
          if lect_type not in lects_to_codes:
            raise ValueError("Unrecognized lect type '%s' generated" % lect_type)
          code = lects_to_codes[lect_type]
          if type(code) is list:
            new_lang_codes.extend(code)
          else:
            new_lang_codes.append(code)
        return new_lang_codes
      terms = blib.fetch_param_chain(t, "2")
      modified_terms = []
      lect_types = None
      for term in terms:
        m = re.search("^(?:([a-z][a-z][a-zA-Z.,-]*):)?([^ ].*?)(<.*>)?$", term)
        if m:
          langcodes, actual_term, modifiers = m.groups()
          linked_term = link_term(actual_term)
          langcodes = langcodes or ""
          modifiers = modifiers or ""
          modified_langcodes = []
          def add_code(code):
            if code not in modified_langcodes:
              modified_langcodes.append(code)
          def append_nan_lang_codes(existing_code, lect_types):
            new_lang_codes = lect_types_to_codes(lect_types)
            nan_new_lang_codes = [x for x in new_lang_codes if x.startswith("nan-")]
            if not nan_new_lang_codes:
              pagemsg("WARNING: Unable to convert '%s' in {{%s}} to more specific lang code by looking up term %s because no matching lang codes found (found %s)" % (
                existing_code, tn, linked_term, ",".join(new_lang_codes)))
              modified_langcodes.extend("nan")
            else:
              msg_body = "'%s' to '%s' in {{%s}} by looking up term %s" % (
                  existing_code, ",".join(nan_new_lang_codes), tn, linked_term)
              for code in nan_new_lang_codes:
                add_code(code)
              pagemsg("Converting %s" % msg_body)
              notes.append("convert %s" % msg_body)
          if langcodes:
            langcodes = langcodes.split(",")
            for langcode in langcodes:
              if langcode == "nan": # or langcode == "nan-hbl":
                # FIXME: Extract gloss if present
                lect_types = find_southern_min_types(index, pagetitle, t, actual_term, None)
                if type(lect_types) is str:
                  pagemsg("WARNING: Unable to convert '%s' to correct lang code (reason: %s)" % (langcode, lect_types))
                  modified_langcodes.append(langcode)
                else:
                  append_nan_lang_codes(langcode, lect_types)
              else:
                modified_langcodes.append(langcode)
          if modifiers:
            m = re.search("^(.*?)<qq:(.*)>(.*)$", modifiers)
            before_modified_langcodes = []
            if m:
              before, qqs, after = m.groups()
              qq_parts = qqs.split(", ")
              new_qq_parts = []
              for qq_part in qq_parts:
                if qq_part in ["Min Nan", "Southern Min",
                               # "Coastal Min", "Min", "Hokkien",
                               #"Taiwan", "Taiwanese", "Hong Kong", "Singapore", "Malaysia", "Philippines"
                              ]:
                  if lect_types is None:
                    lect_types = find_southern_min_types(index, pagetitle, t, actual_term, None)
                    if type(lect_types) is str:
                      pagemsg("WARNING: Unable to convert '%s' to correct lang code (reason: %s)" % (qq_part, lect_types))
                  if type(lect_types) is list:
                    append_nan_lang_codes(qq_part, lect_types)
                  elif qq_part in ["Min Nan", "Southern Min"]:
                    pagemsg("WARNING: Unable to convert '%s' to something more specific, converting to code 'nan' (term %s)" %
                            (qq_part, linked_term))
                    add_code("nan")
                  elif qq_part == "Hokkien":
                    pagemsg("WARNING: Unable to convert 'Hokkien' to something more specific, converting to code 'nan-hbl' (term %s)" %
                            linked_term)
                    add_code("nan-hbl")
                  else:
                    pagemsg("WARNING: Unable to convert '%s' to something more specific, leaving as-is (term %s)" %
                            (qq_part, linked_term))
                    new_qq_parts.append(qq_part)
                elif qq_part in lects_to_codes:
                  code = lects_to_codes[qq_part]
                  if type(code) is list:
                    pagemsg("Converting qualifier '%s' to codes '%s' (term %s)" % (
                      qq_part, ",".join(code), linked_term))
                    for cd in code:
                      add_code(cd)
                  else:
                    pagemsg("Converting qualifier '%s' to code '%s' (term %s)" % (qq_part, code, linked_term))
                    add_code(code)
                else:
                  if re.search("^[A-Z]", qq_part):
                    pagemsg("WARNING: Saw unhandled lect qualifier %s (term %s): <qq:%s>" % (qq_part, linked_term, qqs))
                  new_qq_parts.append(qq_part)
              if new_qq_parts:
                new_modifiers = "%s<qq:%s>%s" % (before, ", ".join(new_qq_parts), after)
              else:
                new_modifiers = "%s%s" % (before, after)
              if new_modifiers != modifiers:
                new_text = []
                if new_modifiers:
                  new_text.append("new modifiers %s" % new_modifiers)
                if modified_langcodes:
                  new_text.append("new lang codes %s" % ",".join(modified_langcodes))
                msg_body = "modifiers %s%s to %s (term %s)" % (
                  modifiers,
                  " and lang codes %s" % ",".join(before_modified_langcodes) if before_modified_langcodes else "",
                  " and ".join(new_text),
                  linked_term
                )
                pagemsg("Converting %s" % msg_body)
                notes.append("converted %s" % msg_body)
            else:
              new_modifiers = modifiers
          else:
            new_modifiers = modifiers
          if modified_langcodes:
            if "nan-hbl" in modified_langcodes:
              has_specific_hokkien_variety = any(x in hokkien_varieties for x in modified_langcodes)
              if has_specific_hokkien_variety:
                pagemsg("Removing generic Hokkien code nan-hbl from derived langcodes %s because saw more specific Hokkien variety" %
                        ",".join(modified_langcodes))
                modified_langcodes = [x for x in modified_langcodes if x != "nan-hbl"]
            if len(modified_langcodes) > 3:
              pagemsg("WARNING: Generating %s > 3 prefixed language codes %s (term %s)" % (
                len(modified_langcodes), ",".join(modified_langcodes), linked_term))
            modified_langcodes = "%s:" % ",".join(modified_langcodes)
          else:
            modified_langcodes = ""
          if langcodes != modified_langcodes or modifiers != new_modifiers:
            term = "%s%s%s" % (modified_langcodes, actual_term, new_modifiers)
        modified_terms.append(term)
      if terms != modified_terms:
        blib.set_param_chain(t, modified_terms, "2")
  text = str(parsed)

  lines = text.split("\n")
  new_lines = []
  for line in lines:
    if re.search(r"(Min Nan|Southern Min).*\{\{zh-l *\|", line):
      line_parts = re.split(
          r"(\{\{(?:%s)\|[^{}]*(?:Min Nan|Southern Min)[^{}]*\}\} *\{\{zh-l\|[^{}]*\}\}(?:, *\{\{zh-l\|[^{}]*\}\})*)" %
          "|".join(blib.qualifier_templates), line)
      if len(line_parts) == 1:
        pagemsg("WARNING: Couldn't parse apparent synonyms/antonyms line: %s" % line)
        new_lines.append(line)
        continue
      frobbed_parts = []
      for line_part_no in range(len(line_parts)):
        line_part = line_parts[line_part_no]
        if line_part_no % 2 == 0:
          frobbed_parts.append(line_part)
        else:
          parsed = blib.parse_text(line_part)
          q_t = None
          zh_l_ts = []
          for t in parsed.filter_templates(recursive=False):
            tn = tname(t)
            if tn in blib.qualifier_templates:
              if q_t is not None:
                pagemsg("WARNING: Found two qualifier templates %s and %s in synonyms/antonyms line part %s, can't parse: %s" %
                        (str(q_t), str(t), line_part_no, line))
                break
              else:
                q_t = t
            elif tn == "zh-l":
              zh_l_ts.append(t)
          else: # no break
            if not q_t:
              pagemsg("WARNING: Couldn't find qualifier template in synonyms/antonyms line part %s, can't parse: %s" %
                      (line_part_no, line))
            elif not zh_l_ts:
              pagemsg("WARNING: Couldn't find {{zh-l}} link(s) in synonyms/antonyms line part %s, can't parse: %s" %
                      (line_part_no, line))
            else:
              all_min_types = []
              all_linkpages = []
              min_warnings = []
              for zh_l_t in zh_l_ts:
                linkpage, linktr, linkgloss = get_params_from_zh_l(zh_l_t)
                if linkpage.startswith("*"):
                  linkpage = linkpage[1:]
                if "/" in linkpage:
                  linkpage = re.sub("/.*", "", linkpage)
                all_linkpages.append((linkpage, linkgloss))
                min_types = find_southern_min_types(index, pagetitle, zh_l_t, linkpage, linkgloss)
                if type(min_types) is str:
                  min_warnings.append(min_types)
                elif min_types:
                  pagemsg("For link page %s, found %s: %s" % (link_term(linkpage), ", ".join(min_types), line))
                  for min_type in min_types:
                    if min_type not in all_min_types:
                      all_min_types.append(min_type)
              all_linkpage_txt = ",".join(
                "%s:%s" % (link_term(page), gloss) if gloss else link_term(page) for page, gloss in all_linkpages)
              if not all_min_types:
                pagemsg("WARNING: Couldn't locate any Southern Min types among link page(s) %s (reason(s): %s): %s" % (
                  all_linkpage_txt, "; ".join(min_warnings), line))
              else:
                if min_warnings:
                  pagemsg("WARNING (may be ignorable): Was able to locate Southern Min type(s) %s among link page(s) %s, but with some warnings (%s): %s" % (
                    ", ".join(all_min_types), all_linkpage_txt, "; ".join(min_warnings), line))
                qualifier_vals = blib.fetch_param_chain(q_t, "1")
                frobbed_qualifier_vals = []
                saw_min_nan = False
                for val in qualifier_vals:
                  if val in ["Min Nan", "Southern Min", "Coastal Min"]:
                    if saw_min_nan:
                      pagemsg("WARNING: Saw 'Min Nan/Southern Min/Coastal Min' multiple times in qualifier template %s, not changing: %s" %
                              (str(q_t), line))
                      break
                    saw_min_nan = val
                    frobbed_qualifier_vals.extend(all_min_types)
                  else:
                    frobbed_qualifier_vals.append(val)
                else: # no break
                  if saw_min_nan:
                    blib.set_param_chain(q_t, frobbed_qualifier_vals, "1")
                    note = ("qualifier '%s' with '%s' in Synonyms/Antonyms section by examining associated term(s) %s" %
                            (saw_min_nan, "|".join(all_min_types), all_linkpage_txt))
                    pagemsg("Replacing %s: %s" % (note, line))
                    notes.append("replace %s" % note)
                    line_part = str(parsed)
                  else:
                    pagemsg("WARNING: Couldn't find 'Min Nan' or 'Southern Min' qualifier in template %s: %s" % (
                      str(q_t), line))
          frobbed_parts.append(line_part)
      line = "".join(frobbed_parts)
    new_lines.append(line)

  text = "\n".join(new_lines)
  return text, notes

parser = blib.create_argparser("Convert 'Min Nan' and 'Southern Min' in qualifiers to appropriate lects",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True)
