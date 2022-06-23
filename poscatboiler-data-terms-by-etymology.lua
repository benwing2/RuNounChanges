local labels = {}
local raw_categories = {}
local handlers = {}
local raw_handlers = {}



-----------------------------------------------------------------------------
--                                                                         --
--                                  LABELS                                 --
--                                                                         --
-----------------------------------------------------------------------------


labels["terms by etymology"] = {
	description = "{{{langname}}} terms categorized by their etymologies.",
	umbrella_parents = "Fundamental",
	parents = {{name = "{{{langcat}}}", raw = true}},
}

labels["AABB-type reduplications"] = {
	description = "{{{langname}}} terms that underwent [[reduplication]] in an AABB pattern.",
	parents = {"reduplications"},
}

labels["alliterative compounds"] = {
	description = "{{{langname}}} noun phrases composed of two or more stems that alliterate.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words", "alliterative phrases"},
}

labels["antonymous compounds"] = {
	description = "{{{langname}}} compounds in which one part is an antonym of the other.",
	umbrella_parents = "Types of compound words by language",
	parents = {"dvandva compounds", sort = "antonym"},
}

labels["back-formations"] = {
	description = "{{{langname}}} words formed by reversing a supposed regular formation, removing part of an older term.",
	parents = {"terms by etymology"},
}

labels["bahuvrihi compounds"] = {
	description = "{{{langname}}} compounds in which the first part (A) modifies the second (B), and whose meaning follows a [[metonymic]] pattern: “<person> having a B that is A.”",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words", "exocentric compounds"},
}

labels["blends"] = {
	description = "{{{langname}}} words formed by combinations of other words.",
	parents = {"terms by etymology"},
}

labels["borrowed terms"] = {
	description = "{{{langname}}} terms that are loanwords, i.e. words that were directly incorporated from another language.",
	parents = {"terms by etymology"},
}

labels["catachreses"] = {
	description = "{{{langname}}} terms derived from misuses or misapplications of other terms.",
	parents = {"terms by etymology"},
}

labels["coinages"] = {
	description = "{{{langname}}} terms coined by an identifiable person, organization or other such entity.",
	parents = {"terms attributed to a specific source"},
	umbrella_parents = {name = "terms attributed to a specific source", is_label = true, sort = " "},
}

-- Add "compound POS" categories for various parts of speech.

local compound_poses = {
	"adjectives",
	"adverbs",
	"conjunctions",
	"determiners",
	"interjections",
	"nouns",
	"numerals",
	"particles",
	"postpositions",
	"prefixes",
	"prepositions",
	"pronouns",
	"proper nouns",
	"suffixes",
	"verbs",
}

for _, pos in ipairs(compound_poses) do
	labels["compound " .. pos] = {
		description = "{{{langname}}} " .. pos .. " composed of two or more stems.",
		umbrella_parents = "Types of compound words by language",
		parents = {{name = "compound words", sort = " "}, pos},
	}
end

labels["compound determinatives"] = {
	description = "{{{langname}}} determinatives composed of two or more stems.",
	parents = {"compound words", "determiners"},
}

labels["compound words"] = {
	description = "{{{langname}}} words composed of two or more stems.",
	parents = {"terms by etymology"},
}

labels["coordinated pairs"] = {
	description = "Terms in {{{langname}}} consisting of a pair of terms joined by a [[coordinating conjunction]].",
	parents = {"terms by etymology"},
}

labels["coordinated triples"] = {
	-- Avoid saying "a coordinating conjunction" or "coordinating conjunctions"
	-- because there can be one or more conjunctions.
	description = "Terms in {{{langname}}} consisting of three terms joined by [[coordinating conjunction]].",
	parents = {"terms by etymology"},
}

labels["coordinated quadruples"] = {
	-- Avoid saying "a coordinating conjunction" or "coordinating conjunctions"
	-- because there can be one or more conjunctions.
	description = "Terms in {{{langname}}} consisting of four terms joined by [[coordinating conjunction]].",
	parents = {"terms by etymology"},
}

labels["coordinated quintuples"] = {
	-- Avoid saying "a coordinating conjunction" or "coordinating conjunctions"
	-- because there can be one or more conjunctions.
	description = "Terms in {{{langname}}} consisting of five terms joined by [[coordinating conjunction]].",
	parents = {"terms by etymology"},
}

labels["denominals"] = {
	description = "{{{langname}}} terms derived from a noun.",
	parents = {"terms by etymology"},
}

labels["deverbals"] = {
	description = "{{{langname}}} terms derived from a verb.",
	parents = {"terms by etymology"},
}

labels["doublets"] = {
	description = "{{{langname}}} terms that trace their etymology from ultimately the same source as other terms in the same language, but by different routes, and often with subtly or substantially different meanings.",
	parents = {"terms by etymology"},
}

labels["dvandva compounds"] = {
	description = "{{{langname}}} words composed of two or more stems whose stems could be connected by an 'and'.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words"},
}

labels["elongated forms"] = {
	description = "{{{langname}}} terms where one or more letters or sounds is repeated for emphasis or effect.",
	parents = {"terms by etymology"},
}

labels["endocentric compounds"] = {
	description = "{{{langname}}} words composed of two or more stems, one of which is the [[w:head (linguistics)|head]] of that compound.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words"},
}

labels["endocentric noun-noun compounds"] = {
	description = "{{{langname}}} words composed of two or more stems, one of which is the [[w:head (linguistics)|head]] of that compound.",
	umbrella_parents = "Types of compound words by language",
	parents = {"endocentric compounds", "compound words"},
}

labels["endocentric verb-noun compounds"] = {
	description = "{{{langname}}} compounds in which the first element is a verbal stem, the second a nominal stem and the head of the compound.",
	umbrella_parents = "Types of compound words by language",
	parents = {"endocentric compounds", "verb-noun compounds"},
}

labels["eponyms"] = {
	description = "{{{langname}}} terms derived from names of real or fictitious people.",
	parents = {"terms by etymology"},
}

labels["exocentric compounds"] = {
	description = "{{{langname}}} words composed of two or more stems, none of which is the [[w:head (linguistics)|head]] of that compound.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words"},
}

labels["exocentric verb-noun compounds"] = {
	description = "{{{langname}}} compounds in which the first element is a transitive verb, the second a noun functioning as its direct object, and whose referent is the person or thing doing the action.",
	umbrella_parents = "Types of compound words by language",
	parents = {"exocentric compounds", "verb-noun compounds"},
}

labels["genericized trademarks"] = {
	description = "{{{langname}}} terms that originate from [[trademark]]s, [[brand]]s and company names which have become [[genericized]]; that is, fallen into common usage in the target market's [[vernacular]], even when referring to other competing brands.",
	parents = {"terms by etymology", "trademarks"},
}

labels["ghost words"] = {
	description = "{{{langname}}} terms that were originally erroneous or fictitious, published in a reference work as if they were genuine as a result of typographical error, misreading, or misinterpretation, or as [[:w:Fictitious entry|fictitious entries]], jokes, or hoaxes.",
	parents = {"terms by etymology"},
}

labels["karmadharaya compounds"] = {
	description = "{{{langname}}} words composed of two or more stems in which the main stem determines the case endings.",
	umbrella_parents = "Types of compound words by language",
	parents = {"tatpurusa compounds"},
}

labels["haplological forms"] = {
	description = "{{{langname}}} terms that underwent [[haplology]]: thus, their origin involved a loss or omission of a repeated sequence of sounds.",
	parents = {"terms by etymology"},
}

labels["homophonic translations"] = {
	description = "{{{langname}}} terms that were borrowed by matching the etymon phonetically, without regard for the sense; compare [[phono-semantic matching]] and [[Hobson-Jobson]].",
	parents = {"terms by etymology"}
}

labels["hybridisms"] = {
	description = "{{{langname}}} words formed by elements of different linguistic origins.",
	parents = {"terms by etymology"},
}

labels["inherited terms"] = {
	description = "{{{langname}}} terms that were inherited from an earlier stage of the language.",
	parents = {"terms by etymology"},
}

labels["internationalisms"] = {
	description = "{{{langname}}} loanwords which also exist in many other languages with the same or similar etymology.",
	additional = "Terms should be here preferably only if the immediate source language is not known for certain. Entries are added into this category by [[Template:internationalism]]; see it for more information.",
	parents = {"terms by etymology"},
}

labels["itaretara dvandva compounds"] = {
	description = "{{{langname}}} words composed of two or more stems whose stems could be connected by an 'and'.",
	umbrella_parents = "Types of compound words by language",
	parents = {"dvandva compounds"},
}

labels["legal doublets"] = {
	description = "{{{langname}}} legal [[doublet]]s &ndash; a legal doublet is a standardized phrase commonly use in legal documents, proceedings etc which includes two words that are near synonyms.",
	parents = {"coordinated pairs"},
}

labels["legal triplets"] = {
	description = "{{{langname}}} legal [[triplet]]s &ndash; a legal triplet is a standardized phrase commonly use in legal documents, proceedings etc which includes three words that are near synonyms.",
	parents = {"coordinated triples"},
}

labels["merisms"] = {
	description = "{{{langname}}} [[merism]]s &ndash; terms that are [[coordinate]]s that, combined, are a synonym for a totality.",
	parents = {"coordinated pairs"},
}

labels["metonyms"] = {
	description = "{{{langname}}} terms whose origin involves calling a thing or concept not by its own name, but by the name of something intimately associated with that thing or concept.",
	parents = {"terms by etymology"},
}

labels["neologisms"] = {
	description = "{{{langname}}} terms that have been only recently acknowledged.",
	parents = {"terms by etymology"},
}

labels["nonce terms"] = {
	description = "{{{langname}}} terms that have been invented for a single occasion.",
	parents = {"terms by etymology"},
}

labels["numeronyms"] = {
	description = "{{{langname}}} terms that serve as number-based names.",
	parents = {"terms by etymology"},
}

labels["onomatopoeias"] = {
	description = "{{{langname}}} words that were coined to sound like what they represent.",
	parents = {"terms by etymology"},
}

labels["piecewise doublets"] = {
	description = "{{{langname}}} terms that are [[Appendix:Glossary#piecewise doublet|piecewise doublets]].",
	parents = {"terms by etymology"},
}

for _, ism_and_langname in ipairs({
	{"anglicisms", "English"},
	{"Arabisms", "Arabic"},
	{"Gallicisms", "French"},
	{"Germanisms", "German"},
	{"Hispanisms", "Spanish"},
	{"Italianisms", "Italian"},
	{"Latinisms", "Latin"},
	{"Japonisms", "Japanese"},
}) do
	local ism, langname = unpack(ism_and_langname)
	labels["pseudo-" .. ism] = {
		description = "{{{langname}}} terms that appear to be " .. langname .. ", but are not used or have an unrelated meaning in " .. langname .. " itself.",
		parents = {"pseudo-loans"},
		umbrella_parents = {name = "pseudo-loans", is_label = true, sort = " "},
	}
end

labels["rebracketings"] = {
	description = "{{{langname}}} terms that have interacted with another word in such a way that the boundary between the words has been modified.",
	parents = {"terms by etymology"}
}

labels["reconstructed terms"] = {
	description = "{{{langname}}} terms that are not directly attested, but have been reconstructed through other evidence.",
	parents = {"terms by etymology"}
}

labels["reduplicated coordinated pairs"] = {
	description = "{{{langname}}} reduplicated coordinated pairs.",
	parents = {"coordinated pairs", "reduplications"},
}

labels["reduplicated coordinated triples"] = {
	description = "{{{langname}}} reduplicated coordinated triples.",
	parents = {"coordinated triples", "reduplications"},
}

labels["reduplicated coordinated quadruples"] = {
	description = "{{{langname}}} reduplicated coordinated quadruples.",
	parents = {"coordinated quadruples", "reduplications"},
}

labels["reduplicated coordinated quintuples"] = {
	description = "{{{langname}}} reduplicated coordinated quintuples.",
	parents = {"coordinated quintuples", "reduplications"},
}

labels["reduplications"] = {
	description = "{{{langname}}} terms that underwent [[reduplication]], so their origin involved a repetition of roots or stems.",
	parents = {"terms by etymology"},
}

labels["retronyms"] = {
	description = "{{{langname}}} terms that serve as new unique names for older objects or concepts whose previous names became ambiguous.",
	parents = {"terms by etymology"},
}

labels["rhyming compounds"] = {
	description = "{{{langname}}} noun phrases composed of two or more stems that rhyme.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words", "rhyming phrases"},
}

labels["roots"] = {
	description = "Basic morphemes from which {{{langname}}} words are formed.",
	parents = {"morphemes"},
}

labels["roots by shape"] = {
	description = "{{{langname}}} roots categorized by their shape.",
	parents = {{name = "roots", sort = "shape"}},
}

labels["Sanskritic formations"] = {
	description = "{{{langname}}} terms coined from [[tatsama]] [[word]]s and/or [[affix]]es.",
	umbrella_parents = "Sanskritic formations by language",
	parents = {"terms by etymology", "terms derived from Sanskrit"},
}

labels["samahara dvandva compounds"] = {
	description = "{{{langname}}} words composed of two or more stems whose stems could be connected by an 'and'.",
	umbrella_parents = "Types of compound words by language",
	parents = {"dvandva compounds"},
}

labels["shitgibbons"] = {
	description = "{{{langname}}} terms that consist of a single-syllable [[expletive]] followed by a two-syllable [[trochee]] that serves as a [[nominalizer]] or [[intensifier]].",
	parents = {"endocentric compounds"},
}

labels["sound-symbolic terms"] = {
	description = "{{{langname}}} terms that use {{w|sound symbolism}} to express ideas but which are not necessarily strictly speaking [[onomatopoeic]].",
	parents = {"terms by etymology"},
}

labels["spelled-out initialisms"] = {
	description = "{{{langname}}} initialisms in which the letter names are spelled out.",
	parents = {"terms by etymology"},
}

labels["spelling pronunciations"] = {
	description = "{{{langname}}} terms whose pronunciation was historically or presently affected by their spelling.",
	parents = {"terms by etymology"},
}

labels["spoonerisms"] = {
	description = "{{{langname}}} terms in which the initial sounds of component parts have been exchanged, as in \"crook and nanny\" for \"nook and cranny\".",
	parents = {"terms by etymology"},
}

labels["synonymous compounds"] = {
	description = "{{{langname}}} compounds in which one part is a synonym of the other.",
	umbrella_parents = "Types of compound words by language",
	parents = {"dvandva compounds", sort = "synonym"},
}

labels["tatpurusa compounds"] = {
	description = "{{{langname}}} words composed of two or more stems",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound words"},
}

labels["taxonomic eponyms"] = {
	description = "{{{langname}}} terms derived from names of real or fictitious people, used for [[taxonomy]].",
	parents = {"eponyms"},
}

labels["terms attributed to a specific source"] = {
	description = "{{{langname}}} terms coined by an identifiable person or deriving from a known work.",
	parents = {"terms by etymology"},
}

labels["terms containing fossilized case endings"] = {
	description = "{{{langname}}} words or expressions which preserve case morphology which is no longer analyzable within the contemporary grammatical system or which has been entirely lost from the language.",
	parents = {"terms by etymology"},
}

labels["terms derived from area codes"] = {
	description = "{{{langname}}} terms derived from [[area code]]s.",
	parents = {"terms by etymology"},
}

labels["terms derived from the shape of letters"] = {
	description = "{{{langname}}} terms derived from the shape of letters. This can include terms derived from the shape of any letter in any alphabet.",
	parents = {"terms by etymology"},
}

labels["terms by root"] = {
	description = "{{{langname}}} terms categorized by the root they originate from.",
	parents = {"terms by etymology", {name = "roots", sort = " "}},
}

labels["terms derived from fiction"] = {
	description = "{{{langname}}} terms that originate from works of [[fiction]].",
	parents = {"terms attributed to a specific source"},
}

for _, source_and_desc in ipairs({
	{"DC Comics", "[[w:DC Comics|DC Comics]]"},
	{"Duckburg and Mouseton", "[[w:The Walt Disney Company|Disney]]'s ''[[w:Duck universe|Duckburg]] and [[w:Mickey Mouse universe|Mouseton]]'' universe"},
	{"Harry Potter", "the ''[[w:Harry Potter|Harry Potter]]'' series"},
	{"Nineteen Eighty-Four", "[[w:George Orwell|George Orwell]]'s ''[[w:Nineteen Eighty-Four|Nineteen Eighty-Four]]''"},
	{"Star Trek", "''[[w:Star Trek|Star Trek]]''"},
	{"Star Wars", "''[[w:Star Wars|Star Wars]]''"},
	{"The Simpsons", "''[[w:The Simpsons|The Simpsons]]''"},
	{"Tolkien's legendarium", "the [[legendarium]] of [[w:J. R. R. Tolkien|J. R. R. Tolkien]]"},
}) do
	local source, desc = unpack(source_and_desc)
	labels["terms derived from " .. source] = {
		description = "{{{langname}}} terms that originate from " .. desc .. ".",
		parents = {"terms derived from fiction"},
	}
end

labels["terms derived from Greek mythology"] = {
	description = "{{{langname}}} terms derived from Greek mythology which have acquired an idiomatic meaning.",
	parents = {"terms attributed to a specific source"},
}

labels["terms derived from occupations"] = {
	description = "{{{langname}}} terms derived from names of occupations.",
	parents = {"terms by etymology"},
}

labels["terms derived from other languages"] = {
	description = "{{{langname}}} terms that originate from other languages.",
	parents = {"terms by etymology"},
}

labels["terms derived from the Bible"] = {
	description = "{{{langname}}} terms that originate from the [[Bible]].",
	parents = {"terms attributed to a specific source"},
}

labels["terms derived from Aesop's Fables"] = {
	description = "{{{langname}}} terms that originate from [[Aesop]]'s Fables.",
	parents = {"terms attributed to a specific source"},
}

labels["terms derived from toponyms"] = {
	description = "{{{langname}}} terms derived from names of real or fictitious places.",
	parents = {"terms by etymology"},
}

labels["terms making reference to character shapes"] = {
	description = "{{{langname}}} terms making reference to character shapes.",
	parents = {"terms by etymology"},
}

labels["terms derived from sport"] = {
	description = "{{{langname}}} terms that originate from sport.",
	parents = {"terms attributed to a specific source"},
}

labels["terms derived from baseball"] = {
	description = "{{{langname}}} terms that originate from baseball.",
	parents = {"terms derived from sport"},
}

labels["terms with Indo-Aryan extensions"] = {
	description = "{{{langname}}} terms extended with particular [[Indo-Aryan]] [[pleonastic]] affixes.",
	parents = {"terms by etymology"},
}

labels["terms with lemma and non-lemma form etymologies"] = {
	description = "{{{langname}}} terms consisting of both a lemma and non-lemma form, of different origins.",
	breadcrumb = "lemma and non-lemma form",
	parents = {"terms with multiple etymologies"},
}

labels["terms with multiple etymologies"] = {
	description = "{{{langname}}} terms that are derived from multiple origins.",
	parents = {"terms by etymology"},
}

labels["terms with multiple lemma etymologies"] = {
	description = "{{{langname}}} lemmas that are derived from multiple origins.",
	breadcrumb = "multiple lemmas",
	parents = {"terms with multiple etymologies"},
}

labels["terms with multiple non-lemma form etymologies"] = {
	description = "{{{langname}}} non-lemma forms that are derived from multiple origins.",
	breadcrumb = "multiple non-lemma forms",
	parents = {"terms with multiple etymologies"},
}

labels["terms with unknown etymologies"] = {
	description = "{{{langname}}} terms whose etymologies have not yet been established.",
	parents = {{name = "terms by etymology", sort = "unknown etymology"}},
}

labels["twice-borrowed terms"] = {
	description = "{{{langname}}} terms that were borrowed from another language that originally borrowed the term from {{{langname}}}.",
	parents = {"terms by etymology", "borrowed terms"},
}

labels["univerbations"] = {
	description = "{{{langname}}} terms that result from the agglutination of two or more words.",
	parents = {"terms by etymology"},
}

labels["verb-noun compounds"] = {
	description = "{{{langname}}} compounds in which the first element is a transitive verb, the second a noun functioning as its direct object, and whose referent is the person or thing doing the action.",
	umbrella_parents = "Types of compound words by language",
	parents = {"compound nouns"},
}

labels["vrddhi derivatives"] = {
	description = "{{{langname}}} terms derived from a Proto-Indo-European root by the process of [[w:vṛddhi|vṛddhi]] derivation.",
	umbrella_parents = "Types of compound words by language",
	parents = {"terms by etymology"},
}

labels["vrddhi gerundives"] = {
	description = "{{{langname}}} [[gerundive]]s derived from a Proto-Indo-European root by the process of [[w:vṛddhi|vṛddhi]] derivation.",
	umbrella_parents = "Types of compound words by language",
	parents = {"vrddhi derivatives"},
}

labels["vyadhikarana compounds"] = {
	description = "{{{langname}}} words composed of two or more stems in which the non-main stem determines the case endings.",
	umbrella_parents = "Types of compound words by language",
	parents = {"tatpurusa compounds"},
}

labels["words derived through metathesis"] = {
	description = "{{{langname}}} words that were created through [[metathesis]] from another word.",
	parents = {{name = "terms by etymology", sort = "metathesis"}},
}

for _, fixtype in ipairs({"circumfix", "infix", "interfix", "prefix", "suffix",}) do
	labels["words by " .. fixtype] = {
		description = "{{{langname}}} words categorized by their " .. fixtype .. "es.",
		parents = {{name = "terms by etymology", sort = fixtype}, fixtype .. "es"},
	}
end


-- Add 'umbrella_parents' key if not already present.
for key, data in pairs(labels) do
	if not data.umbrella_parents then
		data.umbrella_parents = "Terms by etymology subcategories by language"
	end
end



-----------------------------------------------------------------------------
--                                                                         --
--                              RAW CATEGORIES                             --
--                                                                         --
-----------------------------------------------------------------------------


raw_categories["Terms by etymology subcategories by language"] = {
	description = "Umbrella categories covering topics related to terms categorized by their etymologies, such as types of compounds or borrowings.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "terms by etymology", is_label = true, sort = " "},
	},
}

raw_categories["Borrowed terms subcategories by language"] = {
	description = "Umbrella categories covering topics related to borrowed terms.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "borrowed terms", is_label = true, sort = " "},
		{name = "Terms by etymology subcategories by language", sort = " "},
	},
}

raw_categories["Inherited terms subcategories by language"] = {
	description = "Umbrella categories covering topics related to inherited terms.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "inherited terms", is_label = true, sort = " "},
		{name = "Terms by etymology subcategories by language", sort = " "},
	},
}

raw_categories["Indo-Aryan extensions"] = {
	description = "Umbrella categories covering terms extended with particular [[Indo-Aryan]] [[pleonastic]] affixes.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "Terms by etymology subcategories by language", sort = " "},
	},
}

raw_categories["Multiple etymology subcategories by language"] = {
	description = "Umbrella categories covering topics related to terms with multiple etymologies.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "Terms by etymology subcategories by language", sort = " "},
	},
}

raw_categories["Sanskritic formations by language"] = {
	description = "Categories with terms coined from [[tatsama]] [[word]]s and/or [[affix]]es.",
	additional = "{{{umbrella_msg}}}",
	parents = {
		"Terms by etymology subcategories by language",
	},
}

raw_categories["Types of compound words by language"] = {
	description = "Umbrella categories covering topics related to types of compound words.",
	additional = "{{{umbrella_meta_msg}}}",
	parents = {
		"Umbrella metacategories",
		{name = "compound words", is_label = true, sort = " "},
		{name = "Terms by etymology subcategories by language", sort = " "},
	},
}


-----------------------------------------------------------------------------
--                                                                         --
--                                 HANDLERS                                --
--                                                                         --
-----------------------------------------------------------------------------

-----------------------------------------------------------------------------
------------------------------- word handlers -------------------------------
-----------------------------------------------------------------------------

-- Handlers for 'terms derived from the SOURCE word word' must go *BEFORE* the
-- more general 'terms derived from SOURCE' handler.

local function get_source_and_type_desc(source, term_type)
	if source:getCode() == "ine-pro" and term_type:find("^words?$") then
		return "[[w:Proto-Indo-European word|Proto-Indo-European " .. term_type .. "]]"
	else
		return "[[w:" .. source:getWikipediaArticle() .. "|" .. source:getCanonicalName() .. "]] " .. term_type
	end
end

-- Handler for e.g. [[:Category:Yola terms derived from the Proto-Indo-European word *h₂el- (grow)]] and
-- [[:Category:Russian terms derived from the Proto-Indo-European word *swé]], and corresponding umbrella
-- categories [[:Category:Terms derived from the Proto-Indo-European word *h₂el- (grow)]] and
-- [[:Category:Terms derived from the Proto-Indo-European word *swé]]. Replaces the former
-- [[Module:category tree/PIE word cat]], [[Module:category tree/word cat]] and [[Template:PIE word cat]].
table.insert(handlers, function(data)
	local source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (word) (.+)$")
	if not source_name then
		source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (word) (.+)$")
	end
	if not source_name then
		source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (term) (.+)$")
	end

	if source_name then
		local term, id = term_and_id:match("^(.+) %((.-)%)$")
		term = term or term_and_id
		local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs")

		local parents = {
			{ name = "terms by " .. source_name .. " " .. term_type, sort = source:makeSortKey(term) }
		}
		local umbrella_parents = {
			{ name = "Terms derived from " .. source_name .. " " .. term_type .. "s", sort = source:makeSortKey(term) }
		}
		if id then
			table.insert(parents, { name = "terms derived from the " .. source_name .. " " .. term_type .. " " .. term, sort = " "})
			table.insert(umbrella_parents, { name = "terms derived from the " .. source_name .. " " .. term_type .. " " .. term, is_label = true, sort = " "})
		end
		-- Italicize the word/word in the title.
		local function displaytitle(title, lang)
			return require("Module:string").plain_gsub(title, term, require("Module:script utilities").tag_text(term, source, nil, "term"))
		end
		local breadcrumb = require("Module:script utilities").tag_text(term, source, nil, "term") .. (id and " (" .. id .. ")" or "")
		return {
			description = "{{{langname}}} terms that originate ultimately from the " .. get_source_and_type_desc(source, term_type) .. " " ..
				require("Module:links").full_link({ term = term, lang = source, gloss = id, id = id }, "term") .. ".",
			displaytitle = displaytitle,
			breadcrumb = breadcrumb,
			parents = parents,
			umbrella = {
				no_by_language = true,
				displaytitle = displaytitle,
				breadcrumb = breadcrumb,
				parents = umbrella_parents,
			}
		}
	end
end)


table.insert(handlers, function(data)
	local word_and_id = data.label:match("^terms belonging to the word (.+)$")
	if word_and_id then
		local word, id = word_and_id:match("^(.+) %((.-)%)$")
		word = word or word_and_id

		-- See if the language is Semitic.
		local fam = data.lang
		local is_semitic = false
		while true do
			if not fam then
				break
			end
			if fam:getCode() == "qfa-not" then
				-- qfa-not is "not a family" and is its own parent
				break
			end
			if fam:getCode() == "sem" then
				is_semitic = true
				break
			end
			fam = fam:getFamily()
		end
		local word_desc = is_semitic and "[[w:Semitic word|word]]" or "word"
		local parents = {{name = "terms by word", sort = word_and_id}}
		local separators = "־ %-"
		local separator_c = "[" .. separators .. "]"
		local not_separator_c = "[^" .. separators .. "]"
		-- remove any leading or trailing separators (e.g. in PIE-style words)
		local word_no_prefix_suffix =
			mw.ustring.gsub(mw.ustring.gsub(word, separator_c .. "$", ""), "^" .. separator_c, "")
		local num_sep = mw.ustring.len(mw.ustring.gsub(word_no_prefix_suffix, not_separator_c, ""))
		local linked_word = data.lang and require("Module:links").full_link({ term = word, lang = data.lang, gloss = id, id = id }, "term") or word
		if num_sep > 0 then
			table.insert(parents, {name = "" .. (num_sep + 1) .. "-letter words", sort = word_and_id})
		end
		-- Italicize the word/word in the title.
		local function displaytitle(title, lang)
			return require("Module:string").plain_gsub(title, word, require("Module:script utilities").tag_text(word, lang, nil, "term"))
		end
		local breadcrumb = require("Module:script utilities").tag_text(word, data.lang, nil, "term") .. (id and " (" .. id .. ")" or "")
		return {
			description = "{{{langname}}} terms that belong to the " .. word_desc .. " " .. linked_word .. ".",
			displaytitle = displaytitle,
			breadcrumb = breadcrumb,
			parents = parents,
			umbrella = false,
		}
	end
end)

table.insert(handlers, function(data)
	local num_letters = data.label:match("^([0-9]+)-letter words$")
	if num_letters then
		return {
			description = "{{{langname}}} words with " .. num_letters .. " letters in them.",
			parents = {{name = "words", sort = "#" .. num_letters}},
			umbrella_parents = "Terms by etymology subcategories by language",
		}
	end
end)

table.insert(handlers, function(data)
	local source_name = data.label:match("^terms by (.+) word$")
	if source_name then
		local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs")
		local parents = {"terms by etymology"}
		-- In [[:Category:Proto-Indo-Iranian terms by Proto-Indo-Iranian word]],
		-- don't add parent [[:Category:Proto-Indo-Iranian terms derived from Proto-Indo-Iranian]].
		if not data.lang or data.lang:getCode() ~= source:getCode() then
			table.insert(parents, "terms derived from " .. source_name)
		end
		return {
			description = "{{{langname}}} terms categorized by the " .. get_source_and_type_desc(source, "word") .. " they originate from.",
			parents = parents,
			umbrella_parents = "Terms by etymology subcategories by language",
		}
	end
end)

table.insert(handlers, function(data)
	local word_shape = data.label:match("^(.+)-shape words$")
	if word_shape then
		local description = "{{{langname}}} words with the shape ''" .. word_shape .. "''."
		local additional
		if data.lang and data.lang:getCode() == "ine-pro" then
			additional = [=[
* '''e''' stands for the vowel of the word.
* '''C''' stands for any stop or ''s''.
* '''R''' stands for any resonant.
* '''H''' stands for any laryngeal.
* '''M''' stands for ''m'' or ''w'', when followed by a resonant.
* '''s''' stands for ''s'', when next to a stop.]=]
		end
		return {
			description = description,
			additional = additional,
			breadcrumb = word_shape,
			parents = {{name = "words by shape", sort = word_shape}},
			umbrella = false,
		}
	end
end)

-----------------------------------------------------------------------------
------------------------------- Root handlers -------------------------------
-----------------------------------------------------------------------------

-- Handlers for 'terms derived from the SOURCE root ROOT' must go *BEFORE* the
-- more general 'terms derived from SOURCE' handler.

local function get_source_and_type_desc(source, term_type)
	if source:getCode() == "ine-pro" and term_type:find("^roots?$") then
		return "[[w:Proto-Indo-European root|Proto-Indo-European " .. term_type .. "]]"
	else
		return "[[w:" .. source:getWikipediaArticle() .. "|" .. source:getCanonicalName() .. "]] " .. term_type
	end
end

-- Handler for e.g. [[:Category:Yola terms derived from the Proto-Indo-European root *h₂el- (grow)]] and
-- [[:Category:Russian terms derived from the Proto-Indo-European word *swé]], and corresponding umbrella
-- categories [[:Category:Terms derived from the Proto-Indo-European root *h₂el- (grow)]] and
-- [[:Category:Terms derived from the Proto-Indo-European word *swé]]. Replaces the former
-- [[Module:category tree/PIE root cat]], [[Module:category tree/root cat]] and [[Template:PIE word cat]].
table.insert(handlers, function(data)
	local source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (root) (.+)$")
	if not source_name then
		source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (word) (.+)$")
	end
	if not source_name then
		source_name, term_type, term_and_id = data.label:match("^terms derived from the (.+) (term) (.+)$")
	end

	if source_name then
		local term, id = term_and_id:match("^(.+) %((.-)%)$")
		term = term or term_and_id
		local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs")

		local parents = {
			{ name = "terms by " .. source_name .. " " .. term_type, sort = source:makeSortKey(term) }
		}
		local umbrella_parents = {
			{ name = "Terms derived from " .. source_name .. " " .. term_type .. "s", sort = source:makeSortKey(term) }
		}
		if id then
			table.insert(parents, { name = "terms derived from the " .. source_name .. " " .. term_type .. " " .. term, sort = " "})
			table.insert(umbrella_parents, { name = "terms derived from the " .. source_name .. " " .. term_type .. " " .. term, is_label = true, sort = " "})
		end
		-- Italicize the root/word in the title.
		local function displaytitle(title, lang)
			return require("Module:string").plain_gsub(title, term, require("Module:script utilities").tag_text(term, source, nil, "term"))
		end
		local breadcrumb = require("Module:script utilities").tag_text(term, source, nil, "term") .. (id and " (" .. id .. ")" or "")
		return {
			description = "{{{langname}}} terms that originate ultimately from the " .. get_source_and_type_desc(source, term_type) .. " " ..
				require("Module:links").full_link({ term = term, lang = source, gloss = id, id = id }, "term") .. ".",
			displaytitle = displaytitle,
			breadcrumb = breadcrumb,
			parents = parents,
			umbrella = {
				no_by_language = true,
				displaytitle = displaytitle,
				breadcrumb = breadcrumb,
				parents = umbrella_parents,
			}
		}
	end
end)


table.insert(handlers, function(data)
	local root_and_id = data.label:match("^terms belonging to the root (.+)$")
	if root_and_id then
		local root, id = root_and_id:match("^(.+) %((.-)%)$")
		root = root or root_and_id

		-- See if the language is Semitic.
		local fam = data.lang
		local is_semitic = false
		while true do
			if not fam then
				break
			end
			if fam:getCode() == "qfa-not" then
				-- qfa-not is "not a family" and is its own parent
				break
			end
			if fam:getCode() == "sem" then
				is_semitic = true
				break
			end
			fam = fam:getFamily()
		end
		local root_desc = is_semitic and "[[w:Semitic root|root]]" or "root"
		local parents = {{name = "terms by root", sort = root_and_id}}
		local separators = "־ %-"
		local separator_c = "[" .. separators .. "]"
		local not_separator_c = "[^" .. separators .. "]"
		-- remove any leading or trailing separators (e.g. in PIE-style roots)
		local root_no_prefix_suffix =
			mw.ustring.gsub(mw.ustring.gsub(root, separator_c .. "$", ""), "^" .. separator_c, "")
		local num_sep = mw.ustring.len(mw.ustring.gsub(root_no_prefix_suffix, not_separator_c, ""))
		local linked_root = data.lang and require("Module:links").full_link({ term = root, lang = data.lang, gloss = id, id = id }, "term") or root
		if num_sep > 0 then
			table.insert(parents, {name = "" .. (num_sep + 1) .. "-letter roots", sort = root_and_id})
		end
		-- Italicize the root/word in the title.
		local function displaytitle(title, lang)
			return require("Module:string").plain_gsub(title, root, require("Module:script utilities").tag_text(root, lang, nil, "term"))
		end
		local breadcrumb = require("Module:script utilities").tag_text(root, data.lang, nil, "term") .. (id and " (" .. id .. ")" or "")
		return {
			description = "{{{langname}}} terms that belong to the " .. root_desc .. " " .. linked_root .. ".",
			displaytitle = displaytitle,
			breadcrumb = breadcrumb,
			parents = parents,
			umbrella = false,
		}
	end
end)

table.insert(handlers, function(data)
	local num_letters = data.label:match("^([0-9]+)-letter roots$")
	if num_letters then
		return {
			description = "{{{langname}}} roots with " .. num_letters .. " letters in them.",
			parents = {{name = "roots", sort = "#" .. num_letters}},
			umbrella_parents = "Terms by etymology subcategories by language",
		}
	end
end)

table.insert(handlers, function(data)
	local source_name = data.label:match("^terms by (.+) root$")
	if source_name then
		local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs")
		local parents = {"terms by etymology"}
		-- In [[:Category:Proto-Indo-Iranian terms by Proto-Indo-Iranian root]],
		-- don't add parent [[:Category:Proto-Indo-Iranian terms derived from Proto-Indo-Iranian]].
		if not data.lang or data.lang:getCode() ~= source:getCode() then
			table.insert(parents, "terms derived from " .. source_name)
		end
		return {
			description = "{{{langname}}} terms categorized by the " .. get_source_and_type_desc(source, "root") .. " they originate from.",
			parents = parents,
			umbrella_parents = "Terms by etymology subcategories by language",
		}
	end
end)

table.insert(handlers, function(data)
	local root_shape = data.label:match("^(.+)-shape roots$")
	if root_shape then
		local description = "{{{langname}}} roots with the shape ''" .. root_shape .. "''."
		local additional
		if data.lang and data.lang:getCode() == "ine-pro" then
			additional = [=[
* '''e''' stands for the vowel of the root.
* '''C''' stands for any stop or ''s''.
* '''R''' stands for any resonant.
* '''H''' stands for any laryngeal.
* '''M''' stands for ''m'' or ''w'', when followed by a resonant.
* '''s''' stands for ''s'', when next to a stop.]=]
		end
		return {
			description = description,
			additional = additional,
			breadcrumb = root_shape,
			parents = {{name = "roots by shape", sort = root_shape}},
			umbrella = false,
		}
	end
end)


-----------------------------------------------------------------------------
-------------------- Derived/inherited/borrowed handlers --------------------
-----------------------------------------------------------------------------

-- Handler for categories of the form "LANG terms derived from SOURCE", where SOURCE is a language, etymology language
-- or family (e.g. "Indo-European languages"), along with corresponding umbrella categories of the form
-- "Terms derived from SOURCE".
table.insert(handlers, function(data)
	local source_name = data.label:match("^terms derived from (.+)$")
	if source_name then
		-- FIXME, should we allow 'terms derived from taxonomic names' when mul-tax has canonical name
		-- 'taxonomic name'? This is equivalent to what [[Module:category tree/derived cat]] did.
		-- Maybe fix mul-tax instead.
		local source = require("Module:languages").getByCanonicalName(source_name, true,
			"allow etym langs", "allow families")
		local source_desc = source:makeCategoryLink()

		-- Compute description.
		local desc = "{{{langname}}} terms that originate from " .. source_desc .. "."
		local additional
		if source:getType() == "family" then
			additional = "This category should, ideally, contain only other categories. Entries can be categorized here, too, when the proper subcategory is unclear. " ..
				"If you know the exact language from which an entry categorized here is derived, please edit its respective entry."
		end
		
		-- Compute parents.
		local derived_from_subvariety_of_self = false
		local parent
		local sortkey = source:getDisplayForm()
		if source:getType() == "etymology language" then
			local parcode = source:getParentCode()
			if parcode and parcode ~= "qfa-iso" and parcode ~= "qfa-not" and parcode ~= "qfa-und" then
				if data.lang and parcode == data.lang:getCode() then
					derived_from_subvariety_of_self = true
					parent = data.lang:getFamily():getDisplayForm()
				else
					-- Etymology language parent may be regular language, etymology language,
					-- or family
					parent = require("Module:languages").getByCode(parcode, true,
						"allow etym langs", "allow families"):getDisplayForm()
				end
			end
		else -- regular language or family
			local fam = source:getFamily()
			if fam and fam:getCode() ~= "qfa-iso" and fam:getCode() ~= "qfa-not" then
				parent = fam:getDisplayForm()
			end
		end
		parent = parent and "terms derived from " .. parent or "terms derived from other languages"
		local parents = {{name = parent, sort = sortkey}}
		if derived_from_subvariety_of_self then
			table.insert(parents, "Category:Categories for terms in a language derived from a term in a subvariety of that language")
		end

		-- Compute umbrella parents.
		local umbrella_parents = {
			source:getType() == "family" and {name = source:getCategoryName(), raw = true, sort = " "} or
			source:getType() == "etymology language" and {name = "Category:" .. source:getCategoryName(), sort = "terms derived from"} or
			{name = source:getCategoryName(), raw = true, sort = "terms derived from"}
		}

		return {
			description = desc,
			additional = additional,
			breadcrumb = source_name,
			parents = parents,
			umbrella = {
				no_by_language = true,
				description = "Categories with terms that originate from " .. source_desc .. ".",
				parents = umbrella_parents,
			},
		}
	end
end)


local function get_source_and_source_desc(source_name)
	local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs", "allow families")
	local source_desc = source:makeCategoryLink()
	if source:getType() == "family" then
		source_desc = "unknown " .. source_desc
	end
	return source, source_desc
end


-- Handler for categories of the form "LANG terms inherited/borrowed from SOURCE", where SOURCE is a language,
-- etymology language or family (e.g. "Indo-European languages"). Also handles umbrella categories of the form
-- "Terms inherited/borrowed from SOURCE".
local function inherited_borrowed_handler(etymtype)
	return function(data)
		local source_name = data.label:match("^terms " .. etymtype .. " from (.+)$")
		if source_name then
			local source, source_desc = get_source_and_source_desc(source_name)
			return {
				description = "{{{langname}}} terms " .. etymtype .. " from " .. source_desc .. ".",
				breadcrumb = source_name,
				parents = {
					{ name = etymtype .. " terms", sort = source_name },
					{ name = "terms derived from " .. source_name, sort = " "},
				},
				umbrella = {
					no_by_language = true,
					parents = {
						{ name = "terms derived from " .. source_name, is_label = true, sort = " " },
						etymtype == "inherited" and
							{ name = "Inherited terms subcategories by language", sort = source_name }
						-- There are several types of borrowings mixed into the following holding category,
						-- so keep these ones sorted under 'Terms borrowed from SOURCE_NAME' instead of just
						-- 'SOURCE_NAME'.
						or "Borrowed terms subcategories by language",
					}
				},
			}
		end
	end
end

table.insert(handlers, inherited_borrowed_handler("borrowed"))
table.insert(handlers, inherited_borrowed_handler("inherited"))


-----------------------------------------------------------------------------
------------------------ Borrowing subtype handlers -------------------------
-----------------------------------------------------------------------------

local function borrowing_subtype_handler(source_name, parent_cat, desc, no_by_language)
	local source, source_desc = get_source_and_source_desc(source_name)
	return {
		description = "{{{langname}}} " .. desc:gsub("SOURCE", source_desc),
		breadcrumb = source_name,
		parents = {
			{ name = parent_cat, sort = source_name },
			{ name = "terms borrowed from " .. source_name, sort = " " },
		},
		umbrella = {
			no_by_language = no_by_language,
			parents = {
				{ name = "terms borrowed from " .. source_name, is_label = true, sort = " " },
				"Borrowed terms subcategories by language",
			}
		},
	}
end

-- Specs describing types of borrowings.
-- `from_source_desc` is the English description used in categories of the form "LANGUAGE BORTYPE from SOURCE",
--    e.g. "Arabic semantic loans from English". "SOURCE" in the description is replaced by the source language.
-- `umbrella_desc` is the English description used in categories of the form "LANGUAGE BORTYPE", e.g.
--    "Arabic semantic loans". This is an umbrella category grouping all the source-language-specific categories.
-- `uses_subtype_handler`, if true, means that the handler for "LANGUAGE BORTYPE from SOURCE" categories is
--    implemented by a generic "TYPE borrowings" handler (at the bottom of this section), so we don't need to
--    create a BORTYPE-specific handler.
-- `umbrella_parent`, if given, is the parent category of the umbrella categories of the form "LANGUAGE BORTYPE".
--    By default it is "borrowed terms". Some borrowing types replace this with "terms by etymology". (FIXME:
--    Review whether this is correct.)
-- `label_pattern`, if given, is a Lua pattern that matches the category name minus the language at the beginning.
--    It should have one capture, which is the source language. An example is "^terms partially calqued from (.+)$".
--    If omitted, it is generated from BORTYPE.
-- `no_by_language`, if true, means that the umbrella category grouping borrowings of the appropriate type from a
--    specific source language is named "BORTYPE from SOURCE" in place of "BORTYPE from SOURCE by language"
--    (e.g. "Semantic loans from English" in place of "Semantic loans from English by language").
--
local borrowing_specs = {
	["learned borrowings"] = {
		from_source_desc = "terms that are learned [[loanword]]s from SOURCE, that is, words that were directly incorporated from SOURCE instead of through normal language contact.",
		umbrella_desc = "terms that are learned [[loanword]]s, that is, words that were directly incorporated from another language instead of through normal language contact.",
		uses_subtype_handler = true,
	},
	["semi-learned borrowings"] = {
		from_source_desc = "terms that are [[semi-learned borrowing|semi-learned]] [[loanword]]s from SOURCE, that is, words borrowed from SOURCE (a [[classical language]]) into the target language (a modern language) and partly reshaped based on later [[sound change]]s or by analogy with [[inherit]]ed words in the language.",
		umbrella_desc = "terms that are [[semi-learned borrowing|semi-learned]] [[loanword]]s, that is, words borrowed from a [[classical language]] into a modern language and partly reshaped based on later [[sound change]]s or by analogy with [[inherit]]ed words in the language.",
		uses_subtype_handler = true,
	},
	["orthographic borrowings"]	= {
		from_source_desc = "orthographic loans from SOURCE, i.e. terms that were borrowed from SOURCE in their script forms, not their pronunciations.",
		umbrella_desc = "orthographic loans, i.e. terms that were borrowed in their script forms, not their pronunciations.",
		uses_subtype_handler = true,
	},
	["unadapted borrowings"] = {
		from_source_desc = "[[loanword]]s from SOURCE that have not been conformed to the morpho-syntactic, phonological and/or phonotactical rules of the target language.",
		umbrella_desc = "[[loanword]]s that have not been conformed to the morpho-syntactic, phonological and/or phonotactical rules of the target language.",
		uses_subtype_handler = true,
	},
	["semantic loans"] = {
		from_source_desc = "terms that are [[Appendix:Glossary#semantic loan|semantic loans]] from SOURCE.",
		umbrella_desc = "terms one or more of whose definitions was borrowed from a term in another language.",
		umbrella_parent = "terms by etymology",
		no_by_language = true,
	},
	["partial calques"] = {
		from_source_desc = "terms that were [[Appendix:Glossary#partial calque|partially calqued]] from SOURCE.",
		umbrella_desc = "[[Appendix:Glossary#partial calque|partial calques]], i.e. terms formed partly by piece-by-piece translations of terms from other languages and partly by direct borrowing.",
		umbrella_parent = "terms by etymology",
		label_pattern = "^terms partially calqued from (.+)$",
		no_by_language = true,
	},
	["calques"] = {
		from_source_desc = "terms that were [[Appendix:Glossary#calque|calqued]] from SOURCE.",
		umbrella_desc = "[[Appendix:Glossary#calque|calques]], i.e. terms formed by piece-by-piece translations of terms from other languages.",
		umbrella_parent = "terms by etymology",
		label_pattern = "^terms calqued from (.+)$",
		no_by_language = true,
	},
	["phono-semantic matchings"] = {
		from_source_desc = "terms that are [[w:Phono-semantic matching|phono-semantic matchings]] from SOURCE.",
		umbrella_desc = "terms that were borrowed by matching the etymon phonetically and semantically.",
		no_by_language = true,
	},
	["pseudo-loans"] = {
		from_source_desc = "[[Appendix:Glossary#pseudo-loan|pseudo-loans]] from SOURCE, i.e. are terms that appear to be SOURCE, but are not used or have an unrelated meaning in SOURCE itself.",
		umbrella_desc = "[[Appendix:Glossary#pseudo-loan|pseudo-loans]], i.e. terms that appear to be derived from another language, but are not used or have an unrelated meaning in that language itself.",
	},
}

for bortype, spec in pairs(borrowing_specs) do
	labels[bortype] = {
		description = "{{{langname}}} " .. spec.umbrella_desc,
		parents = {spec.umbrella_parent or "borrowed terms"},
	}
	if not spec.uses_subtype_handler then
		-- If the label pattern isn't specifically given, generate it from the `bortype`; but make sure to
		-- escape hyphens in the pattern.
		local label_pattern = spec.label_pattern or "^" .. bortype:gsub("%-", "%%-") .. " from (.+)$"
		table.insert(handlers, function(data)
			local source_name = data.label:match(label_pattern)
			if source_name then
				return borrowing_subtype_handler(source_name, bortype,
					spec.from_source_desc, spec.no_by_language)
			end
		end)
	end
end

table.insert(handlers, function(data)
	local borrowing_type, source_name = data.label:match("^(.+ borrowings) from (.+)$")
	if borrowing_type then
		return borrowing_subtype_handler(source_name, borrowing_type,
			borrowing_descriptions[borrowing_type].from_source_desc)
	end
end)


-----------------------------------------------------------------------------
------------------------------ Affix handlers -------------------------------
-----------------------------------------------------------------------------

table.insert(handlers, function(data)
	local labelpref, pos, affixtype, term_and_id = data.label:match("^(([a-z -]+) ([a-z]+fix)ed with )(.+)$")
	if affixtype then
		local term, id = term_and_id:match("^(.+) %(([^()]+)%)$")
		term = term or term_and_id

		-- Convert term/alt into affixes if needed
		local desc = {
			["prefix"]		= "beginning with the prefix",
			["suffix"]		= "ending with the suffix",
			["circumfix"]	= "bookended with the circumfix",
			["infix"]		= "spliced with the infix",
			["interfix"]	= "joined with the interfix",
			["transfix"]	= "patterned with the transfix",
		}
		if not desc[affixtype] then
			return nil
		end

		local params = {
			["alt"] = {},
			["sc"] = {},
			["sort"] = {},
			["tr"] = {},
		}
		local args = require("Module:parameters").process(data.args, params)
		local sc = data.sc or args.sc and require("Module:scripts").getByCode(args.sc, "sc") or nil
		local m_compound = require("Module:compound")
		term = m_compound.make_affix(term, data.lang, sc, affixtype)
		alt = m_compound.make_affix(args.alt, data.lang, sc, affixtype)
		local tr = m_compound.make_affix(args.tr, data.lang, require("Module:scripts").getByCode("Latn"), affixtype)
		local m_script_utilities = require("Module:script utilities")
		local id_text = id and " (" .. id .. ")" or ""

		-- Compute parents.
		local parents = {}
		if id then
			if pos == "words" then
				table.insert(parents, {name = labelpref .. term, sort = id, args = args})
			else
				table.insert(parents, {name = "words " .. affixtype .. "ed with " .. term_and_id, sort = id .. ", " .. pos, args = args})
				table.insert(parents, {name = labelpref .. term, sort = id, args = args})
			end
		elseif pos ~= "words" then
			table.insert(parents, {name = "words " .. affixtype .. "ed with " .. term, sort = pos, args = args})
		end
		table.insert(parents, {name = "words by " .. affixtype, sort = data.lang:makeSortKey(data.lang:makeEntryName(args.sort or term))})

		return {
			description = "{{{langname}}} " .. pos .. " " .. desc[affixtype] .. " " .. require("Module:links").full_link({
				lang = data.lang, term = term, alt = alt, sc = sc, id = id, tr = tr}, "term") .. ".",
			breadcrumb = pos == "words" and m_script_utilities.tag_text(alt or term, data.lang, sc, "term") .. id_text or pos,
			displaytitle = "{{{langname}}} " .. labelpref .. m_script_utilities.tag_text(term, data.lang, sc, "term") .. id_text,
			parents = parents,
			umbrella = false,
		}, true -- true = args handled
	end
end)


-----------------------------------------------------------------------------
---------------------- Indo-Aryan extension handlers ------------------------
-----------------------------------------------------------------------------

table.insert(handlers, function(data)
	local labelpref, extension = data.label:match("^(terms extended with Indo%-Aryan )(.+)$")
	if extension then
		local lang_inc_ash = require("Module:languages").getByCode("inc-ash")
		local linked_term = require("Module:links").full_link({lang = lang_inc_ash, term = extension}, "term")
		local tagged_term = require("Module:script utilities").tag_text(extension, lang_inc_ash, nil, "term")
		return {
			description = "{{{langname}}} terms extended with the [[Indo-Aryan]] [[pleonastic]] affix " .. linked_term .. ".",
			displaytitle = "{{{langname}}} " .. labelpref .. tagged_term,
			breadcrumb = tagged_term,
			parents = {{name = "terms with Indo-Aryan extensions", sort = extension}},
			umbrella = {
				no_by_language = true,
				parents = "Indo-Aryan extensions",
				displaytitle = "Terms extended with Indo-Aryan " .. tagged_term,
			}
		}
	end
end)


-----------------------------------------------------------------------------
---------------------------- Coined-by handlers -----------------------------
-----------------------------------------------------------------------------

table.insert(handlers, function(data)
	local coiner = data.label:match("^terms coined by (.+)$")
	if coiner then
		-- Sort by last name per request from [[User:Metaknowledge]]
		local last_name = coiner:match(".* ([^ ]+)$")
		return {
			description = "{{{langname}}} terms coined by " .. coiner .. ".",
			breadcrumb = coiner,
			parents = {{
				name = "coinages",
				sort = last_name and last_name .. ", " .. coiner or coiner,
			}},
			umbrella = false,
		}
	end
end)


-----------------------------------------------------------------------------
------------------------ Multiple etymology handlers ------------------------
-----------------------------------------------------------------------------

table.insert(handlers, function(data)
	local pos = data.label:match("^terms with multiple (.+) etymologies$")
	if pos and pos ~= "lemma" and pos ~= "non-lemma form" then
		local plpos = require("Module:string utilities").pluralize(pos)
		local postype = require("Module:headword").pos_lemma_or_nonlemma(plpos, "guess")
		return {
			description = "{{{langname}}} " .. plpos .. " that are derived from multiple origins.",
			umbrella_parents = "Multiple etymology subcategories by language",
			breadcrumb = "multiple " .. plpos,
			parents = {{
				name = "terms with multiple " .. postype .. " etymologies",
				sort = pos,
			}},
		}
	end
end)

table.insert(handlers, function(data)
	local pos1, pos2 = data.label:match("^terms with (.+) and (.+) etymologies$")
	if pos1 and pos1 ~= "lemma" and pos2 ~= "non-lemma form" then
		local m_strutil = require("Module:string utilities")
		local m_headword = require("Module:headword")
		local plpos1 = m_strutil.pluralize(pos1)
		local plpos2 = m_strutil.pluralize(pos2)
		local pos1type = m_headword.pos_lemma_or_nonlemma(plpos1, "guess")
		local pos2type = m_headword.pos_lemma_or_nonlemma(plpos2, "guess")
		local a_pos1 = m_strutil.add_indefinite_article(pos1)
		local a_pos2 = m_strutil.add_indefinite_article(pos2)
		
		return {
			description = "{{{langname}}} terms consisting of " .. a_pos1 .." of one origin and " ..
				a_pos2 .. " of a different origin.",
			umbrella_parents = "Multiple etymology subcategories by language",
			breadcrumb = pos1 .. " and " .. pos2,
			parents = {{
				name = pos1type == pos2type and "terms with multiple " .. pos1type .. " etymologies" or
					"terms with lemma and non-lemma form etymologies",
				sort = pos1 .. " and " .. pos2,
			}},
		}
	end
end)



-----------------------------------------------------------------------------
--                                                                         --
--                                RAW HANDLERS                             --
--                                                                         --
-----------------------------------------------------------------------------


-- Handler for umbrella metacategories of the form e.g. [[:Category:Terms derived from Proto-Indo-Iranian roots]]
-- and [[:Category:Terms derived from Proto-Indo-European words]]. Replaces the former
-- [[Module:category tree/PIE root cat]], [[Module:category tree/root cat]] and [[Template:PIE word cat]].
table.insert(raw_handlers, function(data)
	local source_name, terms_type = data.category:match("^Terms derived from (.+) (roots)$")
	if not source_name then
		source_name, terms_type = data.category:match("^Terms derived from (.+) (words)$")
	end
	if not source_name then
		source_name, terms_type = data.category:match("^Terms derived from (.+) (terms)$")
	end
	if source_name then
		local source = require("Module:languages").getByCanonicalName(source_name, true, "allow etym langs")

		return {
			description = "Umbrella categories covering terms derived from particular " .. get_source_and_type_desc(source, terms_type) .. ".",
			additional = "{{{umbrella_meta_msg}}}",
			parents = {
				"Umbrella metacategories",
				{ name = terms_type == "roots" and "roots" or "lemmas", is_label = true, lang = source:getCode(), sort = " " },
				{ name = "terms derived from " .. source_name, is_label = true, sort = " " .. terms_type },
			},
		}
	end
end)

return {LABELS = labels, RAW_CATEGORIES = raw_categories, HANDLERS = handlers, RAW_HANDLERS = raw_handlers}
