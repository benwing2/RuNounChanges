local export = {}


local pronunciation_spelling_posttext = {
	func = function pronunciation_spelling_posttext(data)
		if data.args.from then
			return ", representing " .. data.formatted_from .. " " .. data.lang:getCanonicalName()
		end
	end,
	desc = "if {{para|from}} given, {{cd|, representing <var>from</var> <var>lang</var>}} where " ..
		"<code><var>from</var></code> is the display form of the label specified in {{para|from}} and " ..
		"<code><var>lang</var></code> is the name of the language specified in {{para|1}}",
}

--[==[
Specification of known form-of templates.

The key is the canonical form of the form-of template. The value is an object with the following fields:
* `text`: The text to be displayed prior to the main term(s). If omitted and `tags` is not present, the text is the
		  same as the key. Text enclosed in `<<...>>` links to the glossary; use `<<``link``|``display``>>` to link to
		  ``link`` in the glossary while displaying as ``display``. As a special case, text of the form
		  `<<FROM:``default``>>` enables the {{para|from}}/{{para|from2}}/etc. parameters, which specify one or more
		  labels to display in place of the `<<...>>` notation and categorize appropriately unless {{para|nocat|1}} is
		  given. If no label is given, ``default`` is displayed. ``default`` can be blank for no default. Note that the
		  text in `text` should normally be lowercase, and the first letter will be capitalized automatically if the
		  language is English, unless {{para|nocap|1}} is given. If the text begins with a `<<...>>` spec, the first
		  letter of the generated text will be capitalized appropriately (even if inside a link or label).
* `tags`: List of inflection tags to display in place of the text in `text`; normally followed by the word "of".
		  Inflection tags are appropriately linked and canonicalized, just as with {{tl|infl of}}.
* `cat`: Category or (if a list) categories to place the form into. If the special value {true}, the category is
		 derived from the key by chopping off the word "of" and pluralizing the rest. If the category contains text of
		 the form `<<POS:``default``>>`, the value of either the {{para|POS}} or {{para|p}} parameters is fetched,
		 normalized, pluralized and substituted. If neither parameter is given, ``default`` is pluralized and
		 substituted.
* `aliases`: Aliases recognized for use in {{para|ann}} parameters in {{tl|place}}, {{tl|infl of}}, etc. You are free
             to create additional redirecting templates (but generally should not; the aliases should be kept in sync
			 with the actual templates).
* `default`: Object containing default values of inline modifiers/separate parameters for the form-of template. The most
			 common entry is {tr = "-"}, to disable transliteration in certain cases where it doesn't make sense (e.g.
			 romanizations).
* `allow_from`: Allow {{para|from}}, {{para|from2}}, etc. for specifying labels. If `<<FROM:``default``>>` occurs in
				`text`, this is true by default, otherwise false.
* `noprimaryentrycat`: If the main term (aka primary entry) does not exist, put the form into this category.
* `lemma_is_sort_key`: If the user didn't specify a sort key, use the main term (aka lemma) as the sort key, instead of
					   the form's page itself.
* `posttext`: Text to display after the main term but before any user-specific {{para|addl}} text.

Any value can be a function object instead of its normal value. A function object is an object with two fields, `func`,
a function of one argument `data` to calculate the field's value, and `desc`, an English description of what the
function's output is, which can contain template calls; used for documentation purposes. The `data` object passed into
the function has the following fields:
* `args`: Processed arguments.
* `lang`: Language object.
* `should_ucfirst`: True if the first letter of the text should be capitalized.
* `formatted_from`: Formatted labels from {{para|from}}, {{para|from2}}, etc. if `allow_from` is given or
					`<<FROM:...>>` is found in `text`, or {nil} if no labels were specified.
]==]
export.templates = {
	-- adj form of
	-- form of
	-- inflection of
	-- noun form of
	-- participle of
	-- verb form of
	["abbreviation of"] = {
		text = "<<abbreviation>> of",
		cat = true,
		aliases = {"abbrev of", "abbr of"},
	},
	["abstract noun of"] = {
		cat = true,
	},
	["acronym of"] = {
		cat = true,
	},
	["active participle of"] = {
		tags = {"act", "part"},
		-- (Internally we categorize into "LANG active participles".) -- maybe not true?
	},
	["agent noun of"] = {
		text = "<<agent noun>> of",
		cat = true,
	},
	["akkadogram of"] = {
		text = "[[Akkadogram]] of",
	},
	["alternative case form of"] = {
		text = "alternative <<letter case|letter-case>> form of",
	},
	["alternative form of"] = {
		text = "<<FROM:alternative>> form of",
	},
	-- alternative plural of: should be removed
	["alternative reconstruction of"] = {
		text = "<<FROM:alternative>> reconstruction of",
	},
	["alternative spelling of"] = {
		text = "<<FROM:alternative>> spelling of",
	},
	["alternative typography of"] = {
	},
	["aphetic form of"] = {
		text = "<<aphetic>> form of",
		cat = true,
	},
	["apocopic form of"] = {
		text = "<<apocopic>> form of",
		cat = true,
	},
	["arabicization of"] = {
		default = {tr = "-"},
		noprimaryentrycat = "arabicizations without a main entry",
	},
	["archaic form of"] = {
		text = "<<archaic>> form of",
		cat = true,
	},
	-- archaic inflection of: should be removed
	["archaic spelling of"] = {
		text = "<<archaic>> spelling of",
		cat = "archaic forms",
	},
	["aspirate mutation of"] = {
		cat = "aspirate-mutation forms",
		lemma_is_sort_key = true,
	},
	["assimilated harmonic variant of"] = {
	},
	["attributive form of"] = {
		tags = {"attr", "form"},
	},
	["augmentative of"] = {
		tags = {"aug"},
		cat = "augmentative <<POS:noun>>",
	},
	["broad form of"] = {
	},
	["causative of"] = {
		tags = {"caus"},
		cat = "causative <<POS:verb>>",
	},
	["censored spelling of"] = {
		cat = true,
	},
	["clipping of"] = {
		cat = true,
	},
	["combining form of"] = {
		text = "<<combining form>> of",
		cat = true,
	},
	["comparative of"] = {
		text = "<<comparative|comparative degree>> of",
		cat = "comparative <<POS:adjective>>",
		-- Also categorizes into [[Category:Comparative of lang=en]] if English; FIXME: remove this.
	},
	["continuative of"] = {
		tags = {"continuative"},
		cat = "continuative <<POS:verb>>",
	},
	["contraction of"] = {
		-- FIXME: Currently supports mandatory= and optional= params.
		cat = true,
	},
	["conversion of"] = {
		-- FIXME: What is this?
		cat = true,
	},
	["dated form of"] = {
		text = "<<dated>> form of",
		cat = true,
	},
	["dated spelling of"] = {
		text = "<<dated>> spelling of",
		cat = "dated forms",
	},
	["deliberate misspelling of"] = {
		cat = "intentional misspellings",
	},
	["desiderative of"] = {
		-- FIXME: used in one entry; delete
		tags = {"desid"},
		cat = "desiderative verbs",
	},
	["diminutive of"] = {
		tags = {"dim"},
		cat = "diminutive <<POS:noun>>",
	},
	["eclipsis of"] = {
		text = "eclipsed form of",
		cat = "eclipsed forms",
		lemma_is_sort_key = true,
	},
	["eggcorn of"] = {
		text = "[[eggcorn]] of",
		cat = true,
	},
	["ellipsis of"] = {
		text = "<<ellipsis>> of",
		cat = "ellipses",
	},
	["elongated form of"] = {
		text = "<<elongated>> form of",
		cat = true,
	},
	["endearing diminutive of"] = {
		text = "endearing <<diminutive>> of",
		cat = {"diminutive <<POS:noun>>", "endearing terms"},
	},
	["endearing form of"] = {
		cat = "endearing terms",
	},
	["euphemistic form of"] = {
		cat = "euphemisms",
	},
	["eye dialect of"] = {
		text = "<<eye dialect>> spelling of",
		cat = "eye dialect",
		allow_from = true,
		posttext = pronunciation_spelling_posttext,
	},
	["female equivalent of"] = {
		tags = {"female", "equivalent"},
		cat = "female equivalent <<POS:noun>>",
	},
	["feminine of"] = {
		tags = {"f"},
	},
	["feminine plural of"] = {
		tags = {"f", "p"},
	},
	["feminine plural past participle of"] = {
		-- FIXME: deprecated.
		tags = {"f", "p", "of the", "past", "part"},
		cat = "past participle forms",
	},
	["feminine singular of"] = {
		tags = {"f", "s"},
	},
	["feminine singular past participle of"] = {
		-- FIXME: deprecated.
		tags = {"f", "s", "of the", "past", "part"},
		cat = "past participle forms",
	},
	["filter-avoidance spelling of"] = {
		text = "[[w:Wordfilter|filter]]-avoidance spelling of",
		cat = true,
	},
	["former name of"] = {
	},
	["frequentative of"] = {
		tags = {"freq"},
		cat = "frequentative <<POS:verb>>",
	},
	["gerund of"] = {
		tags = {"ger"},
		cat = "gerunds",
	},
	["h-prothesis of"] = {
		text = "[[h-prothesis|h-prothesized]] form of",
		cat = "h-prothesized forms",
		lemma_is_sort_key = true,
	},
	["hard mutation of"] = {
		cat = "hard mutation forms",
		lemma_is_sort_key = true,
	},
	["harmonic variant of"] = {
	},
	["hiatus-filler form of"] = {
		text = "[[hiatus]]-filler form of",
	},
	["honorific alternative case form of"] = {
		text = "[[honorific]] alternative <<letter case|letter-case>> form of",
		cat = "honorific terms",
		posttext = ", sometimes used when referring to [[God]] or another important figure who is understood from context",
	},
	["imperfective form of"] = {
		tags = {"impfv", "form"},
		cat = "imperfective <<POS:verb>>",
	},
	["informal form of"] = {
		cat = true,
	},
	["informal spelling of"] = {
		cat = "informal forms",
	},
	["initialism of"] = {
		cat = true,
	},
	["iterative of"] = {
		tags = {"iter"},
		cat = "iterative <<POS:verb>>",
	},
	-- IUPAC-1: FIXME: delete
	-- IUPAC-3: FIXME: delete
	["lenition of"] = {
		text = "[[lenition|lenited]] form of",
		cat = "lenited forms",
		lemma_is_sort_key = true,
	},
	["literary form of"] = {
		cat = true,
	},
	["male equivalent of"] = {
		tags = {"male", "equivalent"},
		cat = "male equivalent <<POS:noun>>",
	},
	["masculine noun of"] = {
		-- FIXME: deprecate and delete
		tags = {"m", "equivalent"},
	},
	["masculine of"] = {
		tags = {"m"},
	},
	["masculine plural of"] = {
		tags = {"m", "p"},
	},
	["masculine plural past participle of"] = {
		-- FIXME: deprecated.
		tags = {"m", "p", "of the", "past", "part"},
		cat = "past participle forms",
	},
	["medieval spelling of"] = {
		cat = true,
	},
	["mediopassive of"] = {
		tags = {"mpass"},
		cat = true,
	},
	["men's speech form of"] = {
		text = "<<men's speech>> form of",
		cat = "men's speech terms",
	},
	["misconstruction of"] = {
		cat = true,
	},
	["misromanization of"] = {
		cat = true,
	},
	["misspelling of"] = {
		cat = true,
	},
	["mixed mutation after 'th of"] = {
		-- FIXME: Do we really need this? It sounds language-specific.
		cat = "mixed-mutation forms",
		lemma_is_sort_key = true,
	},
	["mixed mutation of"] = {
		cat = "mixed-mutation forms",
		lemma_is_sort_key = true,
	},
	["momentane of"] = {
		-- FIXME: Do we really need this? It sounds language-specific.
		tags = {"momentane"},
		cat = "momentane <<POS:verb>>",
	},
	["nasal mutation of"] = {
		cat = "nasal-mutation forms",
		lemma_is_sort_key = true,
	},
	["negative of"] = {
		-- FIXME: Do we really need this? Replace with {{infl of}}.
		tags = {"neg", "form"},
		cat = "negative <<POS:verb>>",
	},
	["neuter equivalent of"] = {
		tags = {"n", "equivalent"},
		cat = "neuter equivalent <<POS:noun>>",
	},
	["neuter plural of"] = {
		tags = {"n", "p"},
	},
	["neuter singular of"] = {
		tags = {"n", "s"},
	},
	["neuter singular past participle of"] = {
		-- FIXME: deprecated.
		tags = {"n", "s", "of the", "past", "part"},
		cat = "past participle forms",
	},
	["nomen sacrum form of"] = {
		text = {
			func = function(data)
				-- FIXME: Fix ucfirst so this isn't necessary.
				if data.should_ucfirst then
					return "[[nomen sacrum|''Nomen sacrum'']] form of"
				else
					return "[[nomen sacrum|''nomen sacrum'']] form of"
				end,
			end,
			desc = "[[nomen sacrum|''nomen sacrum'']] form of",
		},
		cat = "nomina sacra",
	},
	["nominalization of"] = {
		tags = {"nomzn"},
		-- (Internally we categorize into "LANG nominalized adjectives".) -- maybe not true?
	},
	["nonstandard form of"] = {
		text = "<<nonstandard>> form of",
		cat = true,
	},
	["nonstandard spelling of"] = {
		text = "<<nonstandard>> spelling of",
		cat = "nonstandard forms",
	},
	["nuqtaless form of"] = {
		-- FIXME: Convert to lang-specific inflection tags
		text = "[[nuqta]]less form of",
		cat = true,
	},
	["obsolete form of"] = {
		text = "<<obsolete>> form of",
		cat = true,
	},
	["obsolete spelling of"] = {
		text = "<<obsolete>> spelling of",
		cat = "obsolete forms",
	},
	["obsolete typography of"] = {
		text = "<<obsolete>> typography of",
		cat = "obsolete forms",
	},
	["paragogic form of"] = {
		text = "<<paragogic>> form of",
		cat = true,
	},
	["passive participle of"] = {
		tags = {"pass", "part"},
		-- (Internally we categorize into "LANG passive participles".) -- maybe not true?
	},
	["past participle of"] = {
		tags = {"past", "part"},
		cat = true,
	},
	["pejorative of"] = {
		tags = {"pej"},
		cat = "derogatory terms", -- FIXME, should maybe be 'pejorative terms'
	},
	["perfective form of"] = {
		tags = {"pfv", "form"},
		cat = "perfective <<POS:verb>>",
	},
	["plural of"] = {
		tags = {"p"},
	},
	["present participle of"] = {
		tags = {"pres", "part"},
		cat = {
			func = function(data)
				-- FIXME: Why are we doing this?
				if data.lang:getCode() == "en" then
					return nil
				else
					return "present participles"
				end
			end,
			desc = "{{cd|present participles}} if language not English",
		},
	},
	["pronunciation spelling of"] = {
		text = "[[pronunciation spelling]] of",
		cat = true,
		allow_from = true,
		posttext = pronunciation_spelling_posttext,
	},
	["pronunciation variant of"] = {
		cat = true,
		allow_from = true,
		posttext = pronunciation_spelling_posttext,
	},
	["prothetic form of"] = {
		text = "<<prothetic>> form of",
		cat = true,
	},
	["pseudo-acronym of"] = {
		-- FIXME, what is this?
		cat = true,
	},
	["rare form of"] = {
		cat = true,
	},
	["rare spelling of"] = {
		cat = "rare forms",
	},
	["reflexive of"] = {
		tags = {"refl"},
		cat = "reflexive <<POS:verb>>",
	},
	["relational adjective of"] = {
		text = "<<relational>> <<adjective>> of",
		cat = true,
	},
	["rfform"] = {
		text = "a form of",
		posttext = " <sup>(''please '''specify''' which form!'')</sup>",
	},
	["romanization of"] = {
		default = {tr = "-"},
		noprimaryentrycat = "romanizations without a main entry",
	},
	["runic spelling of"] = {
		cat = true,
	},
	["scribal abbreviation of"] = {
		cat = true,
	},
	["short for"] = {
		cat = "short forms",
	},
	["singular of"] = {
		tags = {"s"},
	},
	["slender form of"] = {
	},
	["soft mutation of"] = {
		cat = "soft-mutation forms",
		lemma_is_sort_key = true,
	},
	-- ["spelling of"] = {
	-- 	...
	-- 	-- FIXME
	-- },
	["spoonerism of"] = {
		text = "<<FROM:spoonerism>> of",
		cat = true,
	},
	["standard form of"] = {
		-- text will be stripped of whitespace after processing <<FROM:>>
		text = "<<FROM:>> standard form of",
	},
	["standard spelling of"] = {
		-- text will be stripped of whitespace after processing <<FROM:>>
		text = "<<FROM:>> standard spelling of",
	},
	["sumerogram of"] = {
		text = "[[Sumerogram]] of",
	},
	["superlative of"] = {
		text = "<<superlative|superlative degree>> of",
		cat = "superlative <<POS:adjective>>",
		-- Also categorizes into [[Category:Superlative of lang=en]] if English; FIXME: remove this.
	},
	-- ["superseded spelling of"] = {
	-- 	...
	-- 	-- FIXME
	-- },
	["syncopic form of"] = {
		text = "<<syncopic>> form of",
		cat = true,
	},
	["synonym of"] = {
	},
	["t-prothesis of"] = {
		text = "[[t-prothesis|t-prothesized]] form of",
		cat = "t-prothesized forms",
		lemma_is_sort_key = true,
	},
	["topicalized form of"] = {
		-- FIXME: remove this
	},
	["uncommon form of"] = {
		cat = true,
	},
	["uncommon spelling of"] = {
		cat = "uncommon forms",
	},
	["verbal noun of"] = {
		tags = {"vnoun"},
		cat = true,
	},
	["word-final anusvara form of"] = {
		-- FIXME: remove this
		text = "word-final [[anusvara]] form of",
	},
}

return export















