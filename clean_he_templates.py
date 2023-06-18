#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pywikibot, re, sys, argparse

import blib
from blib import getparam, rmparam, msg, errandmsg, site, tname

# Tuple of (ORIGTEMPLATE, NEWNAME, ADD_NOCAP). NEWNAME is special-cased
# for he-verb form of and he-noun form of.
all_he_form_of_template_specs = [
#  Uncomment the ones you want changed. BE CAREFUL, SOME OF THE CHANGES AREN'T
#  IDEMPOTENT. 
#  ("he-Cohortative of", "he-verb form of|coho", False),
#  ("he-Defective spelling of", "he-defective spelling of", False),
#  ("he-Excessive spelling of", "he-excessive spelling of", False),
#  ("he-Form of adj", "he-adj form of", False),
#  ("he-Form of noun", "he-noun form of", False),
#  ("he-Form of prep", "he-prep form of", False),
#  ("he-Form of sing cons", "he-noun form of|n=s", False),
#  ("he-Future of", "he-verb form of|fut", False),
#  ("he-Imperative of", "he-verb form of|imp", False),
#  ("he-Infinitive of", "he-infinitive of", False),
#  ("he-Jussive of", "he-verb form of|juss", False),
#  ("he-Past of", "he-verb form of|past", False),
#  ("he-Present of", "he-verb form of|pres", False),
#  ("he-Vav-imperfect of", "he-verb form of|vavi", False),
#  ("he-Vav imperfect of", "he-verb form of|vavi", False),
#  ("he-Vav-perfect of", "he-verb form of|vavp", False),
#  ("he-Vav perfect of", "he-verb form of|vavp", False),
#  ("he-Cohortative of", "he-verb form of|coho", True),
#  ("he-defective spelling of", "he-defective spelling of", True),
#  ("he-excessive spelling of", "he-excessive spelling of", True),
#  ("he-form of adj", "he-adj form of", True),
#  ("he-form of noun", "he-noun form of", True),
#  ("he-form of prep", "he-prep form of", True),
#  ("he-form of sing cons", "he-noun form of|n=s", True),
#  ("he-future of", "he-verb form of|fut", True),
#  ("he-imperative of", "he-verb form of|imp", True),
#  ("he-infinitive of", "he-infinitive of", True),
#  ("he-jussive of", "he-verb form of|juss", True),
#  ("he-past of", "he-verb form of|past", True),
#  ("he-present of", "he-verb form of|pres", True),
#  ("he-vav-imperfect of", "he-verb form of|vavi", True),
#  ("he-vav imperfect of", "he-verb form of|vavi", True),
#  ("he-vav-perfect of", "he-verb form of|vavp", True),
#  ("he-vav perfect of", "he-verb form of|vavp", True),
]
all_he_form_of_template_map = {
  x[0]: (x[1], x[2]) for x in all_he_form_of_template_specs
}
all_he_form_of_templates = [x[0] for x in all_he_form_of_template_specs]

def process_page(page, index, parsed, move_dot, rename):
  pagetitle = str(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing")
  notes = []

  text = str(page.text)

  if ":" in pagetitle and not re.search(
      "^(Citations|Appendix|Reconstruction|Transwiki|Talk|Wiktionary|[A-Za-z]+ talk):", pagetitle):
    pagemsg("WARNING: Colon in page title and not a recognized namespace to include, skipping page")
    return None, None

  if move_dot:
    templates_to_replace = []

    for t in parsed.filter_templates():
      tn = tname(t)
      if tn in all_he_form_of_templates:
        dot = getparam(t, ".")
        if dot:
          origt = str(t)
          rmparam(t, ".")
          newt = str(t) + dot
          templates_to_replace.append((origt, newt))

    for curr_template, repl_template in templates_to_replace:
      found_curr_template = curr_template in text
      if not found_curr_template:
        pagemsg("WARNING: Unable to locate template: %s" % curr_template)
        continue
      found_repl_template = repl_template in text
      if found_repl_template:
        pagemsg("WARNING: Already found template with period: %s" % repl_template)
        continue
      newtext = text.replace(curr_template, repl_template)
      newtext_text_diff = len(newtext) - len(text)
      repl_curr_diff = len(repl_template) - len(curr_template)
      ratio = float(newtext_text_diff) / repl_curr_diff
      if ratio == int(ratio):
        if int(ratio) > 1:
          pagemsg("WARNING: Replaced %s occurrences of curr=%s with repl=%s"
              % (int(ratio), curr_template, repl_template))
      else:
        pagemsg("WARNING: Something wrong, length mismatch during replacement: Expected length change=%s, actual=%s, ratio=%.2f, curr=%s, repl=%s"
            % (repl_curr_diff, newtext_text_diff, ratio, curr_template,
              repl_template))
      text = newtext
      notes.append("move .= outside of {{he-*}} template")

  if rename:
    parsed = blib.parse_text(text)
    for t in parsed.filter_templates():
      origt = str(t)
      tn = tname(t)
      if tn in all_he_form_of_template_map:
        newname, add_nocap = all_he_form_of_template_map[tn]
        add_nocap_msg = "|nocap=1" if add_nocap else ""
        newspecs = None
        if "|" in newname:
          newname, newspecs = newname.split("|")
        blib.set_template_name(t, newname)
        # Fetch all params.
        params = []
        old_1 = getparam(t, "1")
        for param in t.params:
          pname = str(param.name)
          if pname.strip() in ["1", "lang", "sc"]:
            continue
          if pname.strip() in (
            newname == "he-infinitive of" and ["3", "4"] or ["2", "3", "4"]
          ):
            errandmsg("WARNING: Found %s= in %s" % (pname.strip(), origt))
          params.append((pname, param.value, param.showkey))
        # Erase all params.
        del t.params[:]
        # Put back basic params
        t.add("1", old_1)
        if newname == "he-verb form of":
          assert newspecs
          t.add("2", newspecs)
          notes.append("rename {{%s}} to {{%s|{{{1}}}|%s%s}}" %
              (tn, newname, newspecs, add_nocap_msg))
        elif newname == "he-noun form of" and newspecs:
          newparam, newval = newspecs.split("=")
          t.add(newparam, newval)
          notes.append("rename {{%s}} to {{%s|{{{1}}}|%s=%s%s}}" %
              (tn, newname, newparam, newval, add_nocap_msg))
        else:
          notes.append("rename {{%s}} to {{%s%s}}" % (tn, newname, add_nocap_msg))
        # Put remaining parameters in order.
        for name, value, showkey in params:
          # More hacking for 'he-form of sing cons': p -> pp, g -> pg, n -> pn
          if newname == "he-noun form of" and newspecs:
            if name in ["p", "g", "n"]:
              name = "p" + name
          t.add(name, value, showkey=showkey, preserve_spacing=False)
        # Finally add nocap=1 if requested.
        if add_nocap:
          t.add("nocap", "1")

      if str(t) != origt:
        pagemsg("Replaced <%s> with <%s>" % (origt, str(t)))

    text = str(parsed)

  return text, notes

parser = blib.create_argparser("Clean up {{he-*}} templates")
parser.add_argument('--move-dot', help="Move .= outside of template",
    action="store_true")
parser.add_argument('--rename', help="Rename templates",
    action="store_true")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

for template in all_he_form_of_templates:
  for i, page in blib.references("Template:%s" % template, start, end):
    blib.do_edit(page, i,
      lambda page, index, parsed:
        process_page(page, index, parsed, args.move_dot, args.rename),
      save=args.save, verbose=args.verbose
    )
