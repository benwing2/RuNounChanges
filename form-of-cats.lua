local cats = {}

--[=[

This contains categorization specs for specific languages. The particular
categories listed are listed without the preceding canonical language name,
which will automatically be prepended.

The value of an entry in the cats[] table is a list of specifications.
Each specification indicates the conditions under which a given category
is applied. Each specification is processed independently; if multiple
specifications apply, all the resulting categories will be added to the page.
(This is equivalent to wrapping the specifications in a {"multi", ...} clause;
see below.)

A specification is one of:

(1) A string:

	Always apply that category.

(2) A list {"has", TAG, SPEC} or {"has", TAG, SPEC, ELSESPEC}:

	TAG is an inflection tag, and can either be the full form or any
	abbreviation; if that tag is present among the user-supplied tags, SPEC is
	applied, otherwise ELSESPEC is applied if present. SPEC and ELSESPEC are
	specifications just as at the top level; i.e. they can be strings, nested
	conditions, etc.

(2) A list {"hasall", TAGS, SPEC} or {"hasall", TAGS, SPEC, ELSESPEC}:

	Similar to {"has", ...} but only activates if all of the tags in TAGS
	(a list) are present among the user-supplied tags (in any order, and
	other tags may be present, including between the tags in TAGS).

(3) A list {"hasany", TAGS, SPEC} or {"hasany", TAGS, SPEC, ELSESPEC}:

	Similar to {"has", ...} but activates if any of the tags in TAGS
	(a list) are present among the user-supplied tags.

(4) A list {"pos=", VALUE, SPEC} or {"pos=", VALUE, SPEC, ELSESPEC}:

	Similar to {"has", ...} but activates if the value supplied for the p=
	or POS= parameters is the specified value (which can be either the full
	form or any abbreviation).

(5) A list {"posany", VALUES, SPEC} or {"posany", VALUES, SPEC, ELSESPEC}:

	Similar to {"pos=", ...} but activates if the value supplied for the p=
	or POS= parameters is any of the specified values (which can be either
	the full forms or any abbreviation).

(6) A list {"posexists", SPEC} or {"posexists", SPEC, ELSESPEC}:

	Activates if any value was specified for the p= or POS= parameters.

(7) A list {"cond", SPEC1, SPEC2, ...}:

	If SPEC1 applies, it will be applied; otherwise, if SPEC2 applies, it
	will be applied; etc. This stops processing specifications as soon as it
	finds one that applies.

(8) A list {"multi", SPEC1, SPEC2, ...}:

	If SPEC1 applies, it will be applied; in addition, if SPEC2 applies, it
	will also be applied; etc. Unlike {"cond", ...}, this continues
	processing specifications even if a previous one has applied.

(9) A list {"not", CONDITION, SPEC} or {"not", CONDITION, SPEC, ELSESPEC}:

	If CONDITION does *NOT* apply, SPEC will be applied, otherwise ELSESPEC
	will be applied if present. CONDITION is one of:

	-- {"has", TAG}
	-- {"hasall", TAGS}
	-- {"hasany", TAGS}
	-- {"pos=", VALUE}
	-- {"not", CONDITION}
	-- {"and", CONDITION1, CONDITION2}
	-- {"or", CONDITION1, CONDITION2}
	-- A Lua function, which is passed a single argument (see (10) below) and
	   should return true or false

	That is, conditions are similar to if-else SPECS but without any
	specifications given.

(10) A list {"and", CONDITION1, CONDITION2, SPEC} or {"and", CONDITION1, CONDITION2, SPEC, ELSESPEC}:

	If CONDITION1 and CONDITION2 both apply, SPEC will be applied, otherwise
	ELSESPEC will be applied if present. CONDITION is as above for "not".

(11) A list {"or", CONDITION1, CONDITION2, SPEC} or {"or", CONDITION1, CONDITION2, SPEC, ELSESPEC}:

	 If either CONDITION1 or CONDITION2 apply, SPEC will be applied, otherwise
	 ELSESPEC will be applied if present. CONDITION is as above for "not".

(12) A Lua function, which is passed a single argument, a table containing the
	 parameters given to the template call, and which should return a
	 specification (a string naming a category, a list of any of the formats
	 described above, or even another function). In the table, the following
	 keys are present:

	 "lang": the structure describing the language (usually the first
	         parameter);
	 "tags": the list of tags (canonicalized to their full forms);
	 "term": the term to link to (will be missing if no term is given);
	 "alt": the display form of the term (will be missing if no display form
	        is given);
	 "t": the gloss of the term (will be missing if no gloss is given);

	 In addition, any other parameters specified will be located under a key
	 corresponding to the parameter name.


As a simple example, consider this:

cats["et"] = {
	{"has", "part", "participles"},
}

This says that, for language code "et" (Estonian), if the "part" tag is
present (or if "participle" is present, which is the equivalent full form),
the page will be categorized into [[:Category:Estonian participles]].

Another example:

cats["lt"] = {
	{"pos=", "part",
		{"has", "pron",
			"pronominal dalyvis participle forms",
			"dalyvis participle forms",
		}
	}
}

This says that, for language code "lt" (Lithuanian), if the "p=" parameter
was given with the value "part" (or "participle", the equivalent full form),
then if the "pron" tag is present (or the equivalent full form "pronominal"),
categorize into [[:Category:Lithuanian pronominal dalyvis participle forms]],
else categorize into [["Category:Lithuanian dalyvis participle forms]]. Note
that, if p= isn't specified, or has a value other than "part" or
"participle", no categories will be added to the page, because there is no
"else" specification associated with the "pos=" specification.

--]=]

cats["art-blk"] = {
	{"has", "past",
		{"multi", "verb simple past forms", "past participles"},
	}
}

cats["bg"] = {
	{"pos=", "a",
		{"multi",
			{"has", "m", "adjective masculine forms"},
			{"has", "f", "adjective feminine forms"},
			{"has", "n", "adjective neuter forms"},
			{"has", "p", "adjective plural forms"},
			{"has", "extended", "adjective vocative forms"},
			{"has", "def", "adjective definite forms"},
			{"has", "indef", "adjective indefinite forms"},
		}
	},
	{"pos=", "n",
		{"multi",
			{"has", "indef", "noun indefinite forms"},
			{"has", "def", "noun definite forms"},
			{"has", "voc", "noun vocative forms"},
			{"has", "count",
				{"multi", "noun count forms", "noun plural forms"},
			},
			{"has", "p", "noun plural forms"},
		}
	},
	{"cond",
		{"hasall", {"adv", "part"}, "adverbial participles"},
		{"has", "part",
			-- If this is a lemma participle form, categorize appropriately
			-- for the type of participle, otherwise put into
			-- "participle forms". We determine a lemma if all of the
			-- following apply:
			-- (1) either is masculine, or no gender listed; and
			-- (2) either is indefinite, or no definiteness listed; and
			-- (3) not listed as either subjective or objective form.
			{"and",
				{"or", {"has", "m"}, {"not", {"hasany", {"f", "n", "p"}}}},
				{"and",
					{"or", {"has", "indef"}, {"not", {"has", "def"}}}
					{"not", {"hasany", {"subje", "obj"}}}
				},
				{"cond",
					{"hasall", {"pres", "act"}, "present active participles"},
					{"hasall", {"past", "pass"}, "past passive participles"},
					{"hasall", {"past", "act", "aor"}, "past active aorist participles"},
					{"hasall", {"past", "act", "impf"}, "past active imperfect participles"},
				},
				-- FIXME: "participle forms" probably not necessary,
				-- should be handled by headword
				"participle forms"
			}
		}
	},
}

cats["br"] = {
	{"pos=", "n",
		{"has", "p", "noun plural forms"}
	},
}

-- Applies to ca, es, it, pt
local romance_adjective_categorization =
	{"pos=", "a",
		{"multi",
			{"has", "f", "adjective feminine forms"},
			{"has", "p", "adjective plural forms"},
			{"has", "aug", "adjective augmentative forms"},
			{"has", "dim", "adjective diminutive forms"},
			{"has", "comd", "adjective comparative forms"},
			{"has", "supd", "adjective superlative forms"},
		}
	}

cats["ca"] = {
	romance_adjective_categorization
}

cats["de"] = {
	{"pos=", "adv",
		{"multi",
			{"has", "comd", "adverb comparative forms"},
			{"has", "supd", "adverb superlative forms"},
		},
		{"multi",
			{"has", "comd", "adjective comparative forms"},
			{"has", "supd", "adjective superlative forms"},
		},
	},
}

cats["el"] = {
	{"has", "dat", "dative forms"},
	{"pos=", "v",
		{"cond",
			{"hasall", {"1", "s", "past"}, "verb past tense forms"},
			{"has", "nonfinite", "verb nonfinite forms"},
		},
	},
}

cats["enm"] = {
	{"hasall", {"1", "s", "pres", "ind"}, "first-person singular forms"},
	{"hasall", {"2", "s", "pres", "ind"}, "second-person singular forms"},
	{"hasall", {"3", "s", "pres", "ind"}, "third-person singular forms"},
	{"hasall", {"p", "pres", "ind"}, "plural forms"},
	{"hasall", {"13", "s", "past", "ind"}, "first/third-person singular past forms"},
	{"hasall", {"2", "s", "past", "ind"}, "second-person singular past forms"},
	{"hasall", {"p", "past", "ind"}, "plural past forms"},
	{"hasall", {"s", "pres", "sub"}, "singular subjunctive forms"},
	{"hasall", {"p", "pres", "sub"}, "plural subjunctive forms"},
	{"hasall", {"s", "sub", "past"}, "singular subjunctive past forms"},
	{"hasall", {"p", "sub", "past"}, "plural subjunctive past forms"},
}

cats["es"] = {
	romance_adjective_categorization
}

cats["et"] = {
	{"has", "part", "participles"},
}

cats["got"] = {
	{"hasall", {"pres", "part"}, "present participles"},
	{"hasall", {"past", "part"}, "past participles"},
}

cats["hu"] = {
	{"hasall", {"past", "part"}, "past participles"},
	{"hasall", {"pres", "part"}, "present participles"},
	{"hasall", {"fut", "part"}, "future participles"},
	{"hasall", {"adv", "part"}, "adverbial participles"},
}

cats["it"] = {
	romance_adjective_categorization
}

cats["ja"] = {
	{"pos=", "v",
		{"multi",
			{"has", "past", "past tense verb forms"},
			{"has", "conj", "conjunctive verb forms"},
		}
	},
}

cats["ku"] = {
	{"hasall", {"pres", "part"}, "present participles"},
	{"hasall", {"past", "part"}, "past participles"},
}

cats["liv"] = {
	{"hasany", {"1", "2", "3"},
		{"cond",
			{"hasall", {"pres", "ind"}, "verb forms (present indicative)"},
			{"hasall", {"past", "ind"}, "verb forms (past indicative)"},
			{"hasall", {"imp", "neg"}, "verb forms (imperative negative)"},
			{"has", "imp", "verb forms (imperative)"},
			{"has", "neg", "verb forms (negative)"},
			{"has", "cond", "verb forms (conditional)"},
			{"has", "juss", "verb forms (jussive)"},
			{"has", "quot", "verb forms (quotative)"},
		}
	},
	{"has", "part",
		{"cond",
			{"hasall", {"pres", "act"}, "present active participles"},
			{"hasall", {"pres", "pass"}, "present passive participles"},
			{"hasall", {"past", "act"}, "past active participles"},
			{"hasall", {"past", "pass"}, "past passive participles"},
		},
	},
	{"cond",
		{"has", "ger", "gerunds"},
		{"hasall", {"sup", "abe"}, "supine abessives"},
		{"has", "sup", "supines"},
		{"has", "deb", "debitives"},
	},
}

cats["lt"] = {
	{"pos=", "part",
		{"has", "pron",
			"pronominal dalyvis participle forms",
			"dalyvis participle forms",
		}
	},
	{"pos=", "a",
		{"has", "pron",
			{"cond",
				{"has", "comd", "comparative pronominal adjective forms"},
				{"has", "supd", "superlative pronominal adjective forms"},
			},
			{"cond",
				{"has", "comd", "comparative adjective forms"},
				{"has", "supd", "superlative adjective forms"},
			},
		}
	},
}

cats["lv"] = {
	{"has", "neg", "negative verb forms"},
	{"has", "comd",
		{"pos=", "part",
			{"has", "def",
				"definite comparative participles",
				"comparative participles"
			},
			{"has", "def",
				"definite comparative adjectives",
				"comparative adjectives",
			},
		}
	},
	{"has", "supd",
		{"pos=", "part",
			"superlative participles"
			"superlative adjectives",
		}
	},
}

cats["pt"] = {
	romance_adjective_categorization,
	{"pos=", "n",
		{"multi",
			{"has", "f", "noun feminine forms"},
			{"has", "p", "noun plural forms"},
			{"has", "aug", "noun augmentative forms"},
			{"has", "dim", "noun diminutive forms"},
		}
	},
}

cats["ru"] = {
	{"has", "part",
		{"multi",
			"participles",
			"verb forms",
			{"cond",
				{"hasall", {"pres", "act"}, "present active participles"},
				{"hasall", {"pres", "pass"}, "present passive participles"},
				{"hasall", {"pres", "adv"}, "present adverbial participles"},
				{"hasall", {"past", "act"}, "past active participles"},
				{"hasall", {"past", "pass"}, "past passive participles"},
				{"hasall", {"past", "adv"}, "past adverbial participles"},
			},
		}
	},
}

cats["sl"] = {
	{"has", "part", "participles"},
	{"hasany", {"sup", "ger"}, "verbal nouns"},
}

return cats

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
