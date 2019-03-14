#!/usr/bin/env python
#coding: utf-8

#    revert_bad_back_formation_changes.py is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

import pywikibot, re, sys, codecs, argparse, time
import blib
from blib import site, msg, errmsg, group_notes, iter_items

# clean_etym_templates.py had a bug in it that it wasn't idempotent w.r.t. adding a
# period after back-formation templates without nodot=, leading it to add extraneous
# periods in some cases. This script undoes the damage.

def process_page(index, pagetitle, save, verbose):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  def errpagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
    errmsg("Page %s %s: %s" % (index, pagetitle, txt))

  page = pywikibot.Page(site, pagetitle)
  revisions = list(page.revisions(total=1))
  for rev in revisions:
    if rev['user'] != 'WingerBot' or (
        not rev['comment'].startswith('add period to back-formation template without nodot=')):
      errpagemsg("WARNING: Can't revert page, another change happened since then")
    else:
      oldrevid = rev['_parent_id']
      if oldrevid:
        oldtext = page.getOldVersion(oldrevid)
        if verbose:
          pagemsg("Replacing <%s> with <%s>" % (unicode(page.text), unicode(oldtext)))
        notes = ['Undo faulty addition of period after back-formation template']
        comment = "; ".join(group_notes(notes))
        if save:
          pagemsg("Saving with comment = %s" % comment)
          page.text = oldtext
          page.save(comment=comment)
        else:
          pagemsg("Would save with comment = %s" % comment)

parser = blib.create_argparser(u"Undo extraneously-added periods after back-formation templates")
parser.add_argument("--lemmafile",
    help=u"""List of lemmas to process, without accents.""")
parser.add_argument("--lemmas",
    help=u"""Comma-separated list of lemmas to process.""")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

if args.lemmafile:
  lemmas_to_process = [x.strip() for x in codecs.open(args.lemmafile, "r", "utf-8")]
elif args.lemmas:
  lemmas_to_process = re.split(",", args.lemmas.decode("utf-8"))
else:
  assert False, "Need to specify --lemmafile or --lemmas"

for i, pagetitle in blib.iter_items(lemmas_to_process, start, end):
  process_page(i, pagetitle, args.save, args.verbose)
