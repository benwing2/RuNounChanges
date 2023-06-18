#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import blib
from blib import getparam, rmparam, msg, errmsg, errandmsg, site

import pywikibot, re, sys, argparse
import rulib

def process_page(index, page, contents, verbose, comment):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  def errandpagemsg(txt):
    errandmsg("Page %s %s: %s" % (index, pagetitle, txt))

  if verbose:
    pagemsg("For [[%s]]:" % pagename)
    pagemsg("------- begin text --------")
    msg(contents.rstrip("\n"))
    msg("------- end text --------")

  if not contents.endswith("\n"):
    contents += "\n"
  tables = re.split(r"^--+\n", contents, 0, re.M)

  def table_to_template(table_index):
    outlines = []
    outlines.append("{{ru-derived verbs")
    table_lines = tables[table_index].rstrip("\n").split("\n")
    for table_line in table_lines:
      if not table_line.startswith("#"):
        outlines.append("|" + table_line)
    outlines.append("}}")
    return outlines

  def do_process():
    if not page.exists():
      pagemsg("WARNING: Page doesn't exist")
      return
    else:
      text = page.text
      retval = blib.find_modifiable_lang_section(text, "Russian", pagemsg, force_final_nls=True)
      if retval is None:
        return
      sections, j, secbody, sectail, has_non_lang = retval

      outlines = []
      curtab_index = 0
      lines = secbody.split("\n")
      saw_top = False
      saw_impf = False
      saw_pf = False
      in_table = False
      header = None
      for line in lines:
        m = re.search("^==+(.*?)==+$", line)
        if m:
          header = m.group(1)
          outlines.append(line)
          continue
        if line in ["{{top2}}", "{{der-top}}"] and header == "Derived terms":
          if saw_top:
            pagemsg("WARNING: Saw {{top2}}/{{der-top}} line twice")
            return
          saw_top = True
          continue
        if line in ["''imperfective''", "''perfective''"]:
          if header == "Conjugation":
            outlines.append(line)
            continue
          if header != "Derived terms":
            pagemsg("WARNING: Apparent derived-terms table in header '%s' rather than 'Derived terms'" % header)
            return
          if not saw_top:
            pagemsg("WARNING: Saw imperfective/perfective line without {{top2}}/{{der-top}} line")
            return
          if line == "''imperfective''":
            if saw_impf:
              pagemsg("WARNING: Saw imperfective table portion twice")
              return
            saw_impf = True
          else:
            if saw_pf:
              pagemsg("WARNING: Saw perfective table portion twice")
              return
            saw_pf = True
          in_table = True
          continue
        elif line in ["{{bottom2}}", "{{bottom}}", "{{der-bottom}}"]:
          if in_table:
            if not saw_top or not saw_impf or not saw_pf:
              pagemsg("WARNING: Didn't see top, imperfective header or perfective header; saw_top=%s, saw_impf=%s, saw_pf=%s"
                  % (saw_top, saw_impf, saw_pf))
              return
            if curtab_index >= len(tables):
              pagemsg("WARNING: Too many existing manually-formatted tables, saw %s existing table(s) but only %s replacement(s)"
                  % (curtab_index + 1, len(tables)))
              return
            outlines.extend(table_to_template(curtab_index))
            curtab_index += 1
          saw_top = False
          saw_impf = False
          saw_pf = False
          in_table = False
        elif in_table:
          continue
        else:
          outlines.append(line)

      if curtab_index != len(tables):
        pagemsg("WARNING: Wrong number of existing manually-formatted tables, saw %s existing table(s) but %s replacement(s)"
            % (curtab_index, len(tables)))
        return

      secbody = "\n".join(outlines)
      sections[j] = secbody.rstrip("\n") + sectail
      return "".join(sections), comment

  retval = do_process()
  if retval is None:
    for table_index in range(len(tables)):
      msg("------------------ Table #%s -----------------------" % (table_index + 1))
      if len(tables) > 1:
        msg("=====Derived terms=====")
      else:
        msg("====Derived terms====")
      outlines = table_to_template(table_index)
      msg("\n".join(outlines))
  return retval

if __name__ == "__main__":
  parser = blib.create_argparser("Push new Russian derived-verb tables from infer_ru_derverb_prefixes.py",
    suppress_start_end=True)
  parser.add_argument('files', nargs='*', help="Files containing directives.")
  parser.add_argument("--direcfile", help="File containing entries.")
  parser.add_argument("--comment", help="Comment to use.", required=True)
  parser.add_argument("--pagefile", help="File to restrict list of pages done.")
  args = parser.parse_args()

  if args.pagefile:
    pages = set(blib.yield_items_from_file(args.pagefile))
  else:
    pages = set()

  if args.direcfile:
    lines = open(args.direcfile, "r", encoding="utf-8")

    index_pagename_text_comment = blib.yield_text_from_find_regex(lines, args.verbose)
    for _, (index, pagename, text, comment) in blib.iter_items(index_pagename_text_comment,
        get_name=lambda x:x[1], get_index=lambda x:x[0]):
      if pages and pagename not in pages:
        continue
      if comment:
        comment = "%s; %s" % (comment, args.comment)
      else:
        comment = args.comment
      def do_process_page(page, index, parsed):
        return process_page(index, page, text, args.verbose, comment)
      blib.do_edit(pywikibot.Page(site, pagename), index, do_process_page,
          save=args.save, verbose=args.verbose, diff=args.diff)
  else:
    for index, extfn in enumerate(args.files):
      lines = list(blib.yield_items_from_file(extfn))
      pagename = re.sub(r"\.der$", "", rulib.recompose(extfn))
      def do_process_page(page, index, parsed):
        return process_page(index, page, "\n".join(lines), args.verbose, args.comment)
      blib.do_edit(pywikibot.Page(site, pagename), index + 1, do_process_page,
          save=args.save, verbose=args.verbose, diff=args.diff)
