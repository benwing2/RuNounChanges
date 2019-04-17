#!/usr/bin/env python
# -*- coding: utf-8 -*-

ase_rfp = [
  ("ase-rfp", (
    "rfi",
    ("error-if", ("present-except", ["1"])),
    ("set", "1", [
      "ase",
      ("copy", "1"),
    ]),
  )),
]

misc_templates_to_rewrite = (
  ase_rfp +
  []
)
