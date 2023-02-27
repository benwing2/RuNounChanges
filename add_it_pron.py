#!/usr/bin/env python
# -*- coding: utf-8 -*-

import pywikibot, re, sys, codecs, argparse

import blib
from blib import getparam, rmparam, msg, site, tname, pname
from snarf_it_pron import apply_default_pronun

refs_re = "(Olivetti|DiPI|Treccani|DOP|Internazionale|Garzanti)"

# FIXME: Handle two 'n:' references for the same pronunciation. Separate with " !!! " in a single param and fix the
# underlying code to support this format. (DONE)

seen_pages = set()

def process_page(index, page, spec):
  global args
  pagetitle = unicode(page.title())
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))

  pagemsg("Processing pronunciation spec: %s" % spec)
  m = re.search("^([a-z0-9]*): (.*)$", spec)
  if not m:
    pagemsg("WARNING: Unrecognized pronunciation spec: %s" % spec)
    return
  location, pronspecs = m.groups()
  if (pagetitle, location) in seen_pages:
    pagemsg("WARNING: Already saw page, skipping")
    return
  seen_pages.add((pagetitle, location))
  pronspecs = [pronspec.replace("_", " ") for pronspec in pronspecs.split(" ")]
  if args.old_it_ipa:
    prons = []
    refs = []
    have_footnotes = False
    next_num_pron = 0
    last_num_pron = None
    last_footnote_param_index = None

    for pronspec in pronspecs:
      if pronspec.startswith("r:"):
        ref = pronspec[2:]
        if not re.search(r"^%s\b" % refs_re, ref):
          pagemsg("WARNING: Unrecognized reference %s: pronspec=%s" % (pronspec, spec))
          return
        refs.append("{{R:it:%s}}" % ref)
      elif pronspec.startswith("n:"):
        ref = pronspec[2:]
        if not re.search(r"^%s\b" % refs_re, ref):
          pagemsg("WARNING: Unrecognized reference %s: pronspec=%s" % (pronspec, spec))
          return
        if next_num_pron == 0:
          pagemsg("WARNING: No preceding pronunciations for footnote %s: %s" % (pronspec, spec))
          return
        reftemp = "{{R:it:%s}}" % ref
        if next_num_pron == last_num_pron:
          prons[last_footnote_param_index] += " !!! " + reftemp
        else:
          last_footnote_param_index = len(prons)
          last_num_pron = next_num_pron
          prons.append("ref%s=%s" % ("" if next_num_pron == 1 else next_num_pron, reftemp))
        have_footnotes = True
      else:
        if re.search("^ref[0-9]*=", pronspec):
          have_footnotes = True
        if "=" not in pronspec:
          respellings, msgs = apply_default_pronun(pronspec)
          if "NEED_ACCENT" in msgs:
            pagemsg("WARNING: Missing accent for pronunciation %s" % pronspec)
            return
          if "Z" in msgs:
            pagemsg("WARNING: Unconverted z in pronunciation %s" % pronspec)
            return
          next_num_pron += 1
        prons.append(pronspec)
  else:
    prons = []
    refs = []
    have_footnotes = False
    for pronspec in pronspecs:
      pronspec_parts = re.split("(<r:[^<>]*)", pronspec)
      for i, pronspec_part in enumerate(pronspec_parts):
        if i % 2 == 1: # a reference
          if pronspec_part == "<r:": # a cross-reference to another reference, e.g. <r:<<name:dipi>>>
            pass
          else:
            ref_template_text = pronspec_part[3:]
            # If the argument to the reference template is the page title, remove it.
            m = re.search(r"^([^:]*):(.*)$", ref_template_text)
            if m and m.group(2) == pagetitle:
              ref_template_text = m.group(1)
            pronspec_parts[i] = "<r:%s" % ref_template_text
      pronspec = "".join(pronspec_parts)
      if "<r:" in pronspec or "<ref:" in pronspec:
        have_footnotes = True # <r: or original <ref:
      # FIXME: Verify respellings checking for NEED_ACCENT and Z, as above.
      prons.append(pronspec)
  if not re.search("^[0-9]+$", location) and location not in ["top", "all"]:
    pagemsg("WARNING: Unrecognized location %s: pronspec=%s" % (location, spec))
    return

  notes = []

  text = unicode(page.text)
  retval = blib.find_modifiable_lang_section(text, "Italian", pagemsg, force_final_nls=True)
  if retval is None:
    return
  sections, j, secbody, sectail, has_non_lang = retval

  subsections = re.split("(^==+[^=\n]+==+\n)", secbody, 0, re.M)

  has_etym_sections = "==Etymology 1==" in secbody
  if has_etym_sections and location == "all":
    pagemsg("WARNING: With ==Etymology 1==, location cannot be 'all': %s" % spec)
    return
  if not has_etym_sections and location != "all":
    pagemsg("WARNING: Without split etymology sections, location must be 'all': %s" % spec)
    return

  def construct_new_pron_template():
    pron_arg = "|".join(prons)
    if pron_arg == pagetitle:
      pron_arg = ""
    else:
      pron_arg = "|" + pron_arg
    if args.old_it_ipa:
      return "{{it-IPA%s}}" % pron_arg, "* "
    else:
      return "{{it-pr%s}}" % pron_arg, ""

  def insert_into_existing_pron_section(k):
    parsed = blib.parse_text(subsections[k])
    for t in parsed.filter_templates():
      tn = tname(t)
      if tn == "it-IPA" and args.old_it_ipa:
        origt = unicode(t)
        # Compute set of current reference params
        current_refs = set()
        for param in t.params:
          pn = pname(param)
          m = re.search("^n([0-9]*)$", pn)
          if m:
            current_refs.add(m.group(1) or "1")
        # Compute params to add along with set of new reference params
        params_to_add = []
        new_refs = set()
        nextparam = 0
        for param in prons:
          if "=" in param:
            pn, pv = param.split("=", 1)
          else:
            nextparam += 1
            pn = str(nextparam)
            pv = param
          m = re.search("^n([0-9]*)$", pn)
          if m:
            new_refs.add(m.group(1) or "1")
          params_to_add.append((pn, pv))

        # Make sure we're not removing references
        if len(current_refs - new_refs) > 0 and not args.override_refs:
          pagemsg("WARNING: Saw existing refs not in new refs, not removing: existing=%s, new=%s" % (
            origt, "{{it-IPA|%s}}" % "|".join(prons)))
          return False

        # Now change the params
        del t.params[:]
        for pn, pv in params_to_add:
          t.add(pn, pv)
        if origt != unicode(t):
          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
          notes.append("replace existing %s with %s (manually assisted)" % (origt, unicode(t)))
          subsections[k] = unicode(parsed)
        break
      if tn == "it-pr" and not args.old_it_ipa:
        origt = unicode(t)
        # Now change the params
        del t.params[:]
        for pn, pv in enumerate(prons):
          t.add(str(pn + 1), pv)
        if origt != unicode(t):
          # Make sure we're not removing references
          if re.search("<r(ef)?:", origt) and not args.override_refs:
            origrefs = set()
            newrefs = set()
            ref_regex = r"<r(?:ef)?:(?:[^<>]*|<<[^<>]*>>|<[^<>]*>)*>"
            for m in re.finditer(ref_regex, origt):
              origrefs.add(m.group(0))
            for m in re.finditer(ref_regex, unicode(t)):
              newrefs.add(m.group(0))
            orig_refs_not_in_new = origrefs - newrefs
            if len(orig_refs_not_in_new) > 0:
              pagemsg("WARNING: Saw existing refs %s not in new refs, not removing: existing=%s, new=%s" % (
                "".join(orig_refs_not_in_new), origt, unicode(t)))
              return False

          # Make sure we're not removing audio or other modifiers
          if re.search("<(audio|hmp|rhyme|hyph|pre|post):", origt) and not args.override_refs:
            pagemsg("WARNING: Saw existing audio/hmp/rhyme/hyph/pre/post not in new refs, not removing: existing=%s, new=%s" % (
              origt, unicode(t)))
            return False

          pagemsg("Replaced %s with %s" % (origt, unicode(t)))
          notes.append("replace existing %s with %s (manually assisted)" % (origt, unicode(t)))
          subsections[k] = unicode(parsed)
        break 
    else: # no break
      new_pron_template, pron_prefix = construct_new_pron_template()
      if not args.old_it_ipa:
        # Remove existing rhymes/hyphenation/it-IPA lines
        for template in ["rhyme|it", "rhymes|it", "it-IPA", "hyph|it", "hyphenation|it"]:
          re_template = template.replace("|", r"\|")
          regex = r"^([* ]*\{\{%s(?:\|[^{}]*)*\}\}\n)" % re_template
          m = re.search(regex, subsections[k], re.M)
          if m:
            pagemsg("Removed existing %s" % m.group(1).strip())
            notes.append("remove existing {{%s}}" % template)
            subsections[k] = re.sub(regex, "", subsections[k], 0, re.M)
      subsections[k] = pron_prefix + new_pron_template + "\n" + subsections[k]
      notes.append("insert %s into existing Pronunciation section (manually assisted)" % new_pron_template)
    return True

  def insert_new_l3_pron_section(k):
    new_pron_template, pron_prefix = construct_new_pron_template()
    subsections[k:k] = ["===Pronunciation===\n", pron_prefix + new_pron_template + "\n\n"]
    notes.append("add top-level Italian pron %s (manually assisted)" % new_pron_template)

  if location == "all":
    for k in xrange(2, len(subsections), 2):
      if "==Pronunciation==" in subsections[k - 1]:
        if not insert_into_existing_pron_section(k):
          return
        break
    else: # no break
      k = 2
      while k < len(subsections) and re.search("==(Alternative forms|Etymology)==", subsections[k - 1]):
        k += 2
      if k -1 >= len(subsections):
        pagemsg("WARNING: No lemma or non-lemma section at top level")
        return
      insert_new_l3_pron_section(k - 1)
  elif location == "top":
    for k in xrange(2, len(subsections), 2):
      if "==Pronunciation==" in subsections[k - 1]:
        if not insert_into_existing_pron_section(k):
          return
        break
    else: # no break
      for k in xrange(2, len(subsections), 2):
        if "==Etymology 1==" in subsections[k - 1]:
          insert_new_l3_pron_section(k - 1)
          break
      else: # no break
        pagemsg("WARNING: Something wrong, location == 'top' but can't find Etymology 1 section")
        return
  else:
    begin_etym_n_section = None

    def insert_pron_section_in_etym_section():
      k = begin_etym_n_section + 2
      while k < len(subsections) and re.search("==Alternative forms==", subsections[k - 1]):
        k += 2
      if k -1 >= len(subsections):
        pagemsg("WARNING: No lemma or non-lemma section in Etymology N section: %s" % subsections[begin_etym_n_section].strip())
        return
      new_pron_template, pron_prefix = construct_new_pron_template()
      subsections[k - 1:k - 1] = ["====Pronunciation====\n", pron_prefix + new_pron_template + "\n\n"]
      notes.append("add Italian pron %s to Etymology %s (manually assisted)" % (new_pron_template, location))

    for k in xrange(2, len(subsections), 2):
      if "==Etymology %s==" % location in subsections[k - 1]:
        begin_etym_n_section = k
      elif re.search("==Etymology [0-9]", subsections[k - 1]):
        if begin_etym_n_section:
          # We encountered the next Etymology section and didn't see Pronunciation; insert a Pronunciation section.
          insert_pron_section_in_etym_section()
          break
      elif begin_etym_n_section and "==Pronunciation==" in subsections[k - 1]:
        if not insert_into_existing_pron_section(k):
          return
        break
    else: # no break
      # We reached the end.
      if begin_etym_n_section:
        # We found the Etymology section to insert in; it was the last one and didn't see Pronunciation.
        # Insert a pronunciation section.
        insert_pron_section_in_etym_section()
      else:
        pagemsg("WARNING: Didn't find Etymology N section for location=%s: spec=%s" % (location, spec))
        return

    if refs or have_footnotes:
      # Check for refs in References or Further reading embedded in Etym section
      begin_etym_n_section = None
      for k in xrange(2, len(subsections), 2):
        if "==Etymology %s==" % location in subsections[k - 1]:
          begin_etym_n_section = k - 1
        elif re.search("==Etymology [0-9]", subsections[k - 1]):
          # next etym section
          break
        elif begin_etym_n_section:
          if refs and re.search(r"====\s*(References|Further reading)\s*====", subsections[k - 1]):
            # Found References or Further reading embedded in Etym section
            pagemsg("Found %s in Etymology %s section" % (subsections[k - 1].strip(), location))
            needed_refs = []
            for ref in refs:
              if ref in subsections[k]:
                pagemsg("Already found %s in %s section %s under Etymology %s" % (ref, subsections[k - 1].strip(), k // 2, location))
              else:
                needed_refs.append(ref)
            refs = needed_refs
          if have_footnotes and re.search(r"====\s*References\s*====", subsections[k - 1]):
            # Check for <references/> in References embedded in Etym section
            if re.search(r"<references\s*/?\s*>", subsections[k]):
              pagemsg("Already found <references /> in ===References=== section %s under Etymology %s" % (k // 2, location))
              have_footnotes = False

  if refs:
    # Check for references already present
    for k in xrange(2, len(subsections), 2):
      if re.search("^===(References|Further reading)===\n", subsections[k - 1]):
        needed_refs = []
        for ref in refs:
          if ref in subsections[k]:
            pagemsg("Already found %s in %s section %s" % (ref, subsections[k - 1].strip(), k // 2))
          else:
            needed_refs.append(ref)
        refs = needed_refs
    if refs:
      added_ref_text = "\n".join("* " + ref for ref in refs) + "\n\n"
      # Still some references, need to add them to existing References section or create new one
      for k in xrange(2, len(subsections), 2):
        if re.search("^===References===\n", subsections[k - 1]):
          subsections[k] = subsections[k].rstrip("\n") + "\n" + added_ref_text
          notes.append("add Italian pronun reference%s %s to existing ===References=== section" % ("s" if len(refs) > 1 else "", ", ".join(refs)))
          break
      else: # no break
        k = len(subsections) - 1
        while k >= 2 and re.search(r"==\s*(Anagrams|Further reading)\s*==", subsections[k - 1]):
          k -= 2
        if k < 2:
          pagemsg("WARNING: No lemma or non-lemma section")
          return
        subsections[k + 1:k + 1] = ["===References===\n", added_ref_text]
        notes.append("add new ===References=== section for pron reference%s %s" % ("s" if len(refs) > 1 else "", ", ".join(refs)))

  if have_footnotes:
    # Need <references/>; check if already present
    for k in xrange(len(subsections) - 1, 2, -2):
      if re.search(r"^===\s*References\s*===$", subsections[k - 1].strip()):
        if re.search(r"<references\s*/?\s*>", subsections[k]):
          pagemsg("Already found <references /> in ===References=== section %s" % (k // 2))
        else:
          subsections[k] += "<references />\n"
          notes.append("add <references /> to existing ===References=== section for pron footnotes")
        break
    else: # no break
      k = len(subsections) - 1
      while k >= 2 and re.search(r"==\s*(Anagrams|Further reading)\s*==", subsections[k - 1]):
        k -= 2
      if k < 2:
        pagemsg("WARNING: No lemma or non-lemma section")
        return
      subsections[k + 1:k + 1] = ["===References===\n", "<references />\n\n"]
      notes.append("add new ===References=== section for pron footnotes")

  secbody = "".join(subsections)
  # Strip extra newlines added to secbody
  sections[j] = secbody.rstrip("\n") + sectail
  return "".join(sections), notes

parser = blib.create_argparser("Add Italian pronunciations based on file of directives")
parser.add_argument("--direcfile", required=True, help="File containing pronunciations, as output from snarf_it_pron.py and modified")
parser.add_argument("--override-refs", action="store_true", help="Override reference params (n:Foo), even if some get deleted in the process")
parser.add_argument("--old-it-ipa", action="store_true", help="Store as {{it-IPA}} instead of {{it-pr}}")
args = parser.parse_args()
start, end = blib.parse_start_end(args.start, args.end)

lines = blib.yield_items_from_file(args.direcfile, include_original_lineno=True)

def get_items(lines):
  for lineno, line in lines:
    m = re.search("^Page ([0-9]+) (.*): <respelling> *(.*?) *<end>", line)
    if not m:
      # Not a warning, there will be several of these from output of snarf_it_pron.py
      msg("Line %s: Unrecognized line: %s" % (lineno, line))
    else:
      yield m.groups()

for _, (index, pagetitle, spec) in blib.iter_items(get_items(lines), start, end, get_name=lambda x:x[1], get_index=lambda x:int(x[0])):
  def pagemsg(txt):
    msg("Page %s %s: %s" % (index, pagetitle, txt))
  page = pywikibot.Page(site, pagetitle)
  if not page.exists():
    pagemsg("WARNING: Page doesn't exist, skipping")
  else:
    def do_process_page(page, index, parsed):
      return process_page(index, page, spec)
    blib.do_edit(page, index, do_process_page, save=args.save, verbose=args.verbose, diff=args.diff)

blib.elapsed_time()
