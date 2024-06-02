#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse

parser = argparse.ArgumentParser(description="Generate script to run a bot script in parallel.")
parser.add_argument('--num-parts', help="Number of parallel parts.", type=int, default=10)
parser.add_argument('--command', help="Command to run.", required=True)
parser.add_argument('--output-prefix', help="Prefix for output files.")
parser.add_argument('--num-terms', help="Approximate number of terms that will be run on.", type=int, required=True)
parser.add_argument('--overlap-offset', help="Value to add (or subtract if negative) to the beginning of the next run to get the last term that this run will run on. Set to -1 for no overlap.", type=int, default=5)
parser.add_argument('--no-sleep', help="Don't sleep at beginning of runs (normally done so offsets will remain true; not necessary if offsets won't change as files are saved).", action="store_true")
args = parser.parse_args()

print("#!/bin/sh")
print()

num_terms_per_run = args.num_terms // args.num_parts
# MediaWiki allows 1000 terms listed per second; multiply by 1.1 so we start a bit after all terms are listed,
# to make sure the term listing isn't affected by a run that has already started and saved some terms, which
# changes the category or references.
sleep_increment = int(num_terms_per_run / 1000 * 1.1)
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
  print("%s%s --save %s %s > %s.out.%s.%s-%s &"
    % (sleep_prefix, args.command, first_term_index, last_term_index, args.output_prefix,
       run + 1, first_term_index, last_term_index))

print()
print("wait")
