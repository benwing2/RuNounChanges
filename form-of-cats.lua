local cats = {}

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

cats["lv"] = {
	{"has", "neg", "negative verb forms"},
}

cats["sl"] = {
	{"has", "part", "participles"},
	{"hasany", {"sup", "ger"}, "verbal nouns"},
}

return cats

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
