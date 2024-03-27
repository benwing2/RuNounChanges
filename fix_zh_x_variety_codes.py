#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse
from collections import defaultdict

import blib
from blib import getparam, rmparam, tname, pname, msg, site

old_to_std_code_mapping = {
  "MSC": "cmn",
  "M-BJ": "cmn-bei",
  "M-TW": "cmn-TW",
  "M-MY": "cmn-MY",
  "M-SG": "cmn-SG",
  "M-PH": "cmn-PH",
  "M-TJ": "cmn-tia",
  "M-NE": "cmn-noe",
  "M-CP": "cmn-cep",
  "M-GZ": "cmn-gua",
  "M-LY": "cmn-lan",
  "M-S": "zhx-sic",
  "M-NJ": "cmn-nan",
  "M-YZ": "cmn-yan",
  "M-W": "cmn-wuh",
  "M-GL": "cmn-gui",
  "M-XN": "cmn-xin",
  "M-UIB": "cmn-bec",
  "M-DNG": "dng",
  
  "CL": "lzh",
  "CL-TW": "lzh-cmn-TW",
  "CL-C": "lzh-yue",
  "CL-C-T": "lzh-tai",
  "CL-VN": "lzh-VI",
  "CL-KR": "lzh-KO",
  "CL-PC": "lzh-pre",
  "CL-L": "lzh-lit",

  "CI": "lzh-cii",
  
  "WVC": "cmn-wvc",
  "WVC-C": "yue-wvc",
  "WVC-C-T": "zhx-tai-wvc",

  "C": "yue",
  "C-GZ": "yue-gua",
  "C-LIT": "yue-lit",
  "C-HK": "yue-HK",
  "C-T": "zhx-tai",
  "C-DZ": "zhx-dan",

  "J": "cjy",
  
  "MB": "mnp",
  
  "MD": "cdo",
  
  "MN": "nan-hbl",
  "TW": "nan-hbl-TW",
  "MN-PN": "nan-pen",
  "MN-PH": "nan-hbl-PH",
  "MN-T": "nan-tws",
  "MN-L": "nan-luh",
  "MN-HLF": "nan-hlh",
  "MN-H": "nan-hnm",
  
  "W": "wuu",
  "SH": "wuu-sha",
  "W-SZ": "wuu-suz",
  "W-HZ": "wuu-han",
  "W-CM": "wuu-chm",
  "W-NB": "wuu-nin",
  "W-N": "wuu-nor",
  "W-WZ": "wuu-wen",
  
  "G": "gan",

  "X": "hsn",
  
  "H": "hak-six",
  "H-HL": "hak-hai",
  "H-DB": "hak-dab",
  "H-MX": "hak-mei",
  "H-MY-HY": "hak-hui-MY",
  "H-EM": "hak-eam",
  "H-ZA": "hak-zha",
  
  "WX": "wxa",
}

def process_text_on_page(index, pagetitle, text):
  global args
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  notes = []

  parsed = blib.parse_text(text)
  for t in parsed.filter_templates():
    tn = tname(t)
    origt = str(t)
    if tn in ["zh-x", "zh-usex"]:
      old_code = getparam(t, "3")
      if old_code:
        if old_code in old_to_std_code_mapping:
          std_code = old_to_std_code_mapping[old_code]
          t.add("3", std_code)
          pagemsg("Replaced %s with %s" % (origt, str(t)))
          notes.append("replace bespoke {{zh-x}} code '%s' with '%s'" % (old_code, std_code))

  return str(parsed), notes

parser = blib.create_argparser("Convert bespoke {{zh-x}} variety labels to standard codes",
  include_pagefile=True, include_stdin=True)
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

blib.do_pagefile_cats_refs(args, start, end, process_text_on_page, edit=True, stdin=True,
                           default_refs=["Template:zh-x"])
