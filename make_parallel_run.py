#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse

parser = argparse.ArgumentParser(description="Generate script to run a bot script in parallel.")
parser.add_argument('--num-parts', help="Number of parallel parts.", type=int, default=10)
parser.add_argument('--command', help="Command to run.", required=True)
parser.add_argument('--output-prefix', help="Prefix for output files.", required=True)
parser.add_argument('--num-terms', help="Approximate number of terms that will be run on.", type=int, required=True)
parser.add_argument('--overlap-offset', help="Value to add (or subtract if negative) to the beginning of the next run to get the last term that this run will run on. Set to -1 for no overlap.", type=int, default=5)
parser.add_argument('--no-sleep', help="Don't sleep at beginning of runs (normally done so offsets will remain true; not necessary if offsets won't change as files are saved).", action="store_true")
parser.add_argument('--no-save', help="Don't add --save to the commands.", action="store_true")
args = parser.parse_args()

print("#!/bin/sh")
print()

num_terms_per_run = args.num_terms // args.num_parts
# MediaWiki allows 1000 terms listed per second; multiply by 1.2 so we start a bit after all terms are listed,
# to make sure the term listing isn't affected by a run that has already started and saved some terms, which
# changes the category or references.
sleep_increment = int(num_terms_per_run / 1000 * 1.2 + 0.5)
# FIXME, use log_10()
part_width = 4 if args.num_parts >= 1000 else 3 if args.num_parts >= 100 else 2 if args.num_parts >= 10 else 1
for run in range(args.num_parts):
  sleep_prefix = ""
  if not args.no_sleep:
    sleep = (args.num_parts - run - 1) * sleep_increment
    if sleep > 0:
      sleep_prefix = "sleep %s && " % sleep
  first_term_index = max(1, run * num_terms_per_run)
  if run + 1 == args.num_parts:
    last_term_index = args.num_terms
  else:
    last_term_index = (run + 1) * num_terms_per_run + args.overlap_offset
  save = "--save" if not args.no_save else ""
  command_with_indices = args.command
  if "%SAVE" not in command_with_indices:
    command_with_indices += " %SAVE"
  if "%START" not in command_with_indices:
    command_with_indices += " %START %END"
  if "%SLEEP" not in command_with_indices:
    command_with_indices = "%SLEEP " + command_with_indices
  command_with_indices = (
    command_with_indices.replace("%START", str(first_term_index)).replace("%END", str(last_term_index))
    .replace("%SAVE", save).replace("%SLEEP", sleep_prefix)
  )
  run_num = ("%%0%dd" % part_width) % (run + 1)
  print("%s > %s.out.%s.%s-%s &" % (
    command_with_indices, args.output_prefix, run_num, first_term_index, last_term_index))

print()
print("wait")
