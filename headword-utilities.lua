local export = {}

local rfind = mw.ustring.find
local rmatch = mw.ustring.match
local rsplit = mw.text.split


-- Auto-add links to a "space word" (after splitting on spaces). We split off
-- final punctuation, and then split on hyphens if split_hyphen is given.
-- Code ported from [[Module:fr-headword]].
local function add_space_word_links(space_word, split_hyphen)
	local space_word_no_punct, punct = rmatch(space_word, "^(.*)([,;:?!])$")
	space_word_no_punct = space_word_no_punct or space_word
	punct = punct or ""
	local words
	-- don't split prefixes and suffixes
	if not split_hyphen or rfind(space_word_no_punct, "^%-") or rfind(space_word_no_punct, "%-$") then
		words = {space_word_no_punct}
	else
		words = rsplit(space_word_no_punct, "%-")
	end
	local linked_words = {}
	for _, word in ipairs(words) do
		word = "[[" .. word .. "]]"
		table.insert(linked_words, word)
	end
	return table.concat(linked_words, "-") .. punct
end


-- Auto-add links to a lemma. We split on spaces, and also on hyphens
-- if split_hyphen is given or the word has no spaces. We don't always
-- split on hyphens because of cases like "आदान-प्रदान करना" where
-- "आदान-प्रदान" should be linked as a whole. If there's no space, however, then
-- it makes sense to split on hyphens by default.
function export.add_lemma_links(lemma, split_hyphen)
	if rfind(lemma, "[%[%]]") then
		return lemma
	end
	if not rfind(lemma, " ") then
		split_hyphen = true
	end
	local words = rsplit(lemma, " ")
	local linked_words = {}
	for _, word in ipairs(words) do
		table.insert(linked_words, add_space_word_links(word, split_hyphen))
	end
	local retval = table.concat(linked_words, " ")
	-- If we ended up with a single link consisting of the entire lemma,
	-- remove the link.
	local unlinked_retval = rmatch(retval, "^%[%[([^%[%]]*)%]%]$")
	return unlinked_retval or retval
end


return export
