local cats = {}

cats["lv"] = {
	{"has", "neg", "negative verb forms"},
}

cats["sl"] = {
	{"has", "participle", "participles"},
	{"hasany", {"supine", "gerund"}, "verbal nouns"},
}

return cats

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
