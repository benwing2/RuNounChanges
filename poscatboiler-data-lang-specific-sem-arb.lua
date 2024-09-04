local export = {}

local m_table = require("Module:table")

local rmatch = mw.ustring.match
local u = mw.ustring.char

--[=[
This module handles language-specific categories for all Arabic varieties. The individual variety-specific modules
should do nothing but invoke this module; see [[Module:category tree/poscatboiler/data/lang-specific/ar]] for an
example. Most of the code here is generic, but in a few places we conditionalize on the language code, which is passed
into the various functions that add labels and handlers (e.g. in the noun and adjective nisba endings). If you need to
add a module for a new variety, DO NOT copy the code in this module (even in part), but add appropriate conditional
statements as required. It does not matter if the module adds labels and handlers for categories that don't exist in
a given variety (e.g. forms XI through XV).
]=]

-----------------------------------------------------------------------------
--                                                                         --
--                           NOUNS AND ADJECTIVES                          --
--                                                                         --
-----------------------------------------------------------------------------


---------------------------------- Noun/adjective labels ---------------------------------

local function add_noun_adjective_labels(labels, lang)
	local langcode = lang:getCode()
	-- FIXME! Create variety-specific verb appendices.
	local nominal_appendix = langcode == "mt" and "Appendix:Maltese nominals" or "Appendix:Arabic nominals"
	-- FIXME! No current [[Appendix:Maltese nominals]]. Create it!
	local remove_appendix_links = langcode == "mt"

	local function make_appendix_link(text, anchor)
		anchor = anchor or mw.getContentLanguage():ucfirst(text)
		local retval = ("[[%s#%s|%s]]"):format(nominal_appendix, anchor, text)
		if remove_appendix_links then
			return require("Module:links").remove_links(retval)
		else
			return retval
		end
	end

	------------------- Noun labels --------------------

	labels["nouns by derivation type"] = {
		description = "{{{langname}}} nouns categorized by type of derivation.",
		parents = {{name = "nouns", sort = "derivation type"}},
		breadcrumb = "by derivation type",
	}

	labels["instance nouns"] = {
		description = "{{{langname}}} " .. make_appendix_link("instance nouns") .. ", i.e. nouns having the meaning \"an instance of doing X\" for some verb.",
		parents = {{name = "nouns by derivation type", sort = "instance nouns"}},
		breadcrumb = "instance nouns",
	}

	labels["nouns of place"] = {
		description = "{{{langname}}} " .. make_appendix_link("nouns of place") .. ", i.e. nouns having the approximate meaning \"the place for doing X\" for some verb.",
		parents = {{name = "nouns by derivation type", sort = "nouns of place"}},
		breadcrumb = "nouns of place",
	}

	labels["occupational nouns"] = {
		description = "{{{langname}}} " .. make_appendix_link("occupational nouns") .. ", i.e. nouns referring to people employed in doing something.",
		parents = {{name = "nouns by derivation type", sort = "occupational nouns"}},
		breadcrumb = "occupational nouns",
	}

	local noun_nisba_ending =
		langcode == "ar" and "{{m|" .. langcode .. "|ـِيَّة}}" or
		langcode == "ajp" and "{{m|" .. langcode .. "|ـية|tr=-iyye}}" or
		"{{m|" .. langcode .. "|ـية|tr=-iyya}}"

	labels["relative nouns (nisba)"] = {
		description = "{{{langname}}} " .. make_appendix_link("relative (nisba) nouns", "Relative nouns (nisba)") .. ", i.e. abstract nouns formed with the suffix " .. noun_nisba_ending .. " and derived from an adjective or other noun (or occasionally other parts of speech).",
		parents = {{name = "nouns by derivation type", sort = "relative nouns (nisba)"}},
		breadcrumb = "relative nouns (nisba)",
	}

	labels["tool nouns"] = {
		description = "{{{langname}}} " .. make_appendix_link("tool nouns") .. ", i.e. nouns having the approximate meaning \"tool for doing X\" for some verb.",
		parents = {{name = "nouns by derivation type", sort = "tool nouns"}},
		breadcrumb = "tool nouns",
	}

	local fem_ending_text = langcode == "ar" and
		"the feminine endings {{m|ar|ـَة}}&lrm;, {{m|ar||ـَاء}}&lrm;, {{m|ar||ـَا}}&lrm;{{,}} or {{m|ar|ـَى}}" or
		"one of the recognized feminine endings"
	local module_additional = (langcode == "ar" or langcode == "acw" or langcode == "ajp" or langcode == "arz") and
		"It is automatically added by [[Module:" .. langcode .. "-headword]] to lemma entries." or nil

	labels["feminine terms lacking feminine ending"] = {
		description = "{{{langname}}} feminine terms that do not end in " .. fem_ending_text .. ".",
		additional = module_additional,
		parents = {"nouns", "terms by lexical property", "feminine nouns"},
	}

	labels["masculine terms with feminine ending"] = {
		description = "{{{langname}}} masculine terms ending in one of " .. fem_ending_text .. ".",
		additional = module_additional,
		parents = {"nouns", "terms by lexical property", "masculine nouns"},
	}

	------------------- Adjective labels --------------------

	labels["adjectives by derivation type"] = {
		description = "{{{langname}}} adjectives categorized by type of derivation.",
		parents = {{name = "adjectives", sort = "derivation type"}},
		breadcrumb = "by derivation type",
	}

	labels["characteristic adjectives"] = {
		description = "{{{langname}}} " .. make_appendix_link("characteristic adjectives", "Characteristic nouns and adjectives") .. ", i.e. adjectives meaning \"habitually doing X\" for some verb.",
		parents = {{name = "adjectives", sort = "characteristic"}},
		breadcrumb = "characteristic",
	}

	labels["color/defect adjectives"] = {
		description = "{{{langname}}} " .. make_appendix_link("color/defect adjectives", "Color or defect adjectives") .. ", i.e. adjectives generally referring to colors and physical defects.",
		parents = {{name = "adjectives", sort = "color/defect"}},
		breadcrumb = "color/defect",
	}

	local adj_nisba_ending =
		langcode == "ar" and "{{m|" .. langcode .. "|ـِيّ}}" or
		"{{m|" .. langcode .. "|ـي|tr=-i}}"

	labels["relative adjectives (nisba)"] = {
		description = "{{{langname}}} " .. make_appendix_link("relative (nisba) adjectives", "Relative adjectives (nisba)") .. ", i.e. adjectives formed with the suffix " .. adj_nisba_ending .. " and meaning \"related to X\" for some noun (or occasionally other parts of speech).",
		parents = {{name = "adjectives", sort = "relative (nisba)"}},
		breadcrumb = "relative (nisba)",
	}
end


--------------------------------- Noun/adjective handlers --------------------------------

local function add_noun_adjective_handlers(handlers, lang)
	-- Only fire if the part of speech is one of these.
	local allowed_pos = m_table.listToSet {"noun", "pronoun", "numeral", "adjective", "participle"}
	-- Only fire if one of these words occurs.
	local required_words = {"triptote", "diptote", "singular", "plural", "dual", "paucal", "singulative", "collective"}

	table.insert(handlers, function(data)
		local pos, typ = data.label:match("^([a-z]+)s with (.+)$")
		if not pos or not allowed_pos[pos] then
			return nil
		end
		local spaced_typ = " " .. typ .. " "
		local ok = false
		for _, required_word in ipairs(required_words) do
			if spaced_typ:find(" " .. required_word .. " ") then
				ok = true
				break
			end
		end
		if not ok then
			return nil
		end

		local parents = {{name = pos .. "s by inflection type", sort = typ}}
		if typ ~= "broken plural" and typ:find("broken plural") then
			table.insert(parents, {name = pos .. "s with broken plural", sort = typ})
		end
		if typ:find("irregular") then
			table.insert(parents, {name = "irregular " .. pos .. "s", sort = typ})
		end

		return {
			description = "{{{langname}}} " .. data.label .. ".",
			breadcrumb = typ,
			parents = parents,
		}
	end)
end



-----------------------------------------------------------------------------
--                                                                         --
--                                   VERBS                                 --
--                                                                         --
-----------------------------------------------------------------------------


--------------------------------- Verb labels --------------------------------

local function add_verb_labels(labels, lang)
	labels["verbs with quadriliteral roots"] = {
		description = "{{{langname}}} verbs built on roots consisting of four radicals (instead of the more common triliteral roots), categorized by form.",
		parents = {{name = "verbs by inflection type", sort = "quadriliteral roots"}},
		breadcrumb = "with quadriliteral roots",
	}

	labels["verbs by conjugation"] = {
		description = "{{{langname}}} verbs categorized by type of weakness displayed in their conjugation (as opposed to weakness determined by form, i.e. by the presence of certain \"weak\" radicals in certain positions).",
		parents = {{name = "verbs by inflection type", sort = "conjugation"}},
		breadcrumb = "by conjugation",
	}

	labels["verbs by type of passive"] = {
		description = "{{{langname}}} verbs categorized by type of passive available.",
		parents = {{name = "verbs", sort = "type of passive"}},
		breadcrumb = "by type of passive",
	}

	labels["verbs with full passive"] = {
		description = "{{{langname}}} verbs with passive forms in all persons and numbers.",
		parents = {{name = "verbs by type of passive", sort = "full passive"}},
		breadcrumb = "full passive",
	}

	labels["verbs with impersonal passive"] = {
		description = "{{{langname}}} verbs with impersonal passive forms only, i.e. only in the third-person masculine singular.",
		parents = {{name = "verbs by type of passive", sort = "impersonal passive"}},
		breadcrumb = "impersonal passive",
	}

	labels["verbs lacking passive forms"] = {
		description = "{{{langname}}} verbs without passive forms.",
		parents = {{name = "verbs by type of passive", sort = "lacking passive forms"}},
		breadcrumb = "lacking passive",
	}

	labels["verbs lacking imperative forms"] = {
		description = "{{{langname}}} verbs without imperative forms.",
		parents = {{name = "defective verbs", sort = "imperative"}},
		breadcrumb = "lacking imperative forms",
	}

	-- Normally only for Maltese, but could be e.g. for Moroccan Arabic as well.
	labels["unadapted loan verbs"] = {
		description = "{{{langname}}} borrowed verbs that are not assimilated to the triliteral or quadriliteral structure of typical {{{langname}}} verbs.",
		parents = {"verbs by inflection type"},
		breadcrumb = "unadapted loan",
	}

	-- Normally only for Maltese, but could be e.g. for Moroccan Arabic as well.
	for _, typ in ipairs { "i-type", "a-type" } do
		labels[typ .. " unadapted loan verbs"] = {
			description = "{{{langname}}} " .. typ .. " borrowed verbs that are not assimilated to the triliteral or quadriliteral structure of typical {{{langname}}} verbs.",
			parents = {"unadapted loan verbs"},
			breadcrumb = {name = typ, nocap = true},
		}
	end
end


--------------------------------- Verb handlers --------------------------------

local function add_verb_handlers(labels, handlers, lang)
	local langcode = lang:getCode()
	-- FIXME! Create variety-specific verb appendices.
	local verb_appendix = langcode == "mt" and "Appendix:Maltese verbs" or "Appendix:Arabic verbs"
	-- FIXME! No current [[Appendix:Maltese verbs]]. Create it!
	local remove_appendix_links = langcode == "mt"

	local W = langcode == "mt" and "{{lang|mt|w}}" or "{{lang|{{{langcode}}}|و}}"
	local Y = langcode == "mt" and "{{lang|mt|j}}" or "{{lang|{{{langcode}}}|ي}}"
	local HAMZA = "{{lang|{{{langcode}}}|ء}}"

	local weakness_desc = {
		["geminate"] = "the second and third radicals are identical, which causes an intervening short vowel to drop in some forms",
		["assimilated"] = "the first radical is " .. W .. ", which disappears in the non-past",
		["hollow"] = "the second radical is " .. W .. " or " .. Y .. ", which is replaced with a long or short vowel in some forms",
		["third-weak"] = "the third of four radicals is " .. W .. " or " .. Y .. " (normally not leading to significant irregularities)",
		["final-weak"] = "the last radical is " .. W .. " or " .. Y .. ", normally leading to irregular endings",
		["assimilated+final-weak"] = "the first radical is " .. W .. " or " .. Y .. " and the last radical is " .. W .. " or " .. Y .. ", normally leading to irregular endings",
		["sound"] = "none of the radicals is " .. W .. " or " .. Y .. (langcode == "mt" and "" or " or " .. HAMZA) .. ", nor are the second and third radicals identical",
		["hamzated"] = "one of the radicals is " .. HAMZA .. ", leading to spelling and occasionally conjugation irregularities",
	}

	local weakness_english = {
		["assimilated+final-weak"] = "both assimilated and final-weak",
	}

	local weakness_desc_by_conjugation = {
		["geminate"] = "This includes verbs where the second and third radicals are identical and the vowel between them is deleted in some parts of the conjugation. This is not the same as [[:Category:{{{langname}}} geminate verbs|geminate verbs]] by form, which is determined purely by the second and third radicals being identical, regardless of the conjugation. (For example, form-II verbs that are geminate by form are sound by conjugation.)",
		["assimilated"] = "Generally this only includes form-I verbs where the first radical is " .. W .. ", leading to a shortened non-past stem. This is not the same as [[:Category:{{{langname}}} assimilated verbs|assimilated verbs]] by form, which is determined purely by the first radical being " .. W .. " or " .. Y .. ", regardless of the conjugation. (All verbs that are assimilated by form but not form-I are sound by conjugation, as are form-I verbs whose first radical is " .. Y .. ", and a few form-I verbs whose first radical is " .. W .. ".)",
		["hollow"] = "This includes verbs where the second radical is " .. W .. " or " .. Y .. " and appears as a vowel in most parts of the conjugation. This is not the same as [[:Category:{{{langname}}} hollow verbs|hollow verbs]] by form, which is determined only by the second radical being " .. W .. " or " .. Y .. ", regardless of the conjugation. (For example, form-II verbs that are hollow by form are sound by conjugation.)",
		["final-weak"] = "This includes verbs where the the last radical is " .. W .. " or " .. Y .. ", leading to irregular endings. This is not the same as [[:Category:{{{langname}}} final-weak verbs|final-weak verbs]] by form, which is determined only by the last radical being " .. W .. " or " .. Y .. ", regardless of the conjugation, although the two categories largely coincide.",
		["assimilated+final-weak"] = "Generally this only includes form-I verbs where the first radical is " .. W .. " and the last radical is " .. W .. " or " .. Y .. ", leading to irregular endings and a shortened non-past stem. This is not the same as verbs that are [[:Category:{{{langname}}} assimilated verbs|assimilated]] and [[:Category:{{{langname}}} final-weak verbs|final-weak]] by form, which is determined purely by both the first and last radical being " .. W .. " or " .. Y .. ", regardless of the conjugation. (All verbs that are assimilated+final-weak by form but not form-I are just final-weak by conjugation, as are form-I verbs whose first radical is " .. Y .. ".)",
		["sound"] = "This includes regular verbs without any irregularities caused by weak (" .. W .. " or " .. Y .. ") radicals. This is not the same as [[:Category:{{{langname}}} sound verbs|sound verbs]] by form, which is determined purely by lacking any weak radicals, regardless of the conjugation. Some verbs with weak radicals are nonetheless sound by conjugation; an example is form-II verbs that are [[:Category:{{{langname}}} hollow verbs|hollow verbs]] by form, i.e. with the second radical being " .. W .. " or " .. Y .. ".",
	}

	local trilit_form_to_number = {
		["I"] = 1,
		["II"] = 2,
		["III"] = 3,
		["IV"] = 4,
		["V"] = 5,
		["VI"] = 6,
		["VII"] = 7,
		["VIII"] = 8,
		["IX"] = 9,
		["X"] = 10,
		["XI"] = 11,
		["XII"] = 12,
		["XIII"] = 13,
		["XIV"] = 14,
		["XV"] = 15,
	}

	local quadlit_form_to_number = {
		["Iq"] = 1,
		["IIq"] = 2,
		["IIIq"] = 3,
		["IVq"] = 4,
	}

	local function form_to_sort_key(form, with_space)
		if trilit_form_to_number[form] then
			if with_space then
				return (" %02d"):format(trilit_form_to_number[form])
			else
				return "" .. trilit_form_to_number[form]
			end
		elseif quadlit_form_to_number[form] then
			if with_space then
				return (" %02dq"):format(quadlit_form_to_number[form])
			else
				return "" .. quadlit_form_to_number[form]
			end
		else
			return nil
		end
	end

	local function form_link(form)
		local retval = "[[" .. verb_appendix .. "#Form " .. form .. "|form-" .. form .. "]]"
		if remove_appendix_links then
			return require("Module:links").remove_links(retval)
		else
			return retval
		end
	end

	local function weakness_link(weakness)
		local retval
		if weakness == "hamzated" then
			retval = "[[" .. verb_appendix .. "#Hamzated verbs|hamzated]]"
		elseif weakness == "geminate" then
			retval = "[[" .. verb_appendix .. "#Geminate verbs|geminate]]"
		elseif weakness == "sound" then
			retval = "sound"
		else
			retval = "[[" .. verb_appendix .. "#Weak verbs|" .. (weakness_english[weakness] or weakness) .. "]]"
		end
		if remove_appendix_links then
			return require("Module:links").remove_links(retval)
		else
			return retval
		end
	end

	-- Entries for e.g. [[:Category:Arabic final-weak verbs]]. Use entries instead of a handler
	-- so that children show up in [[:Category:Arabic verbs by inflection type]].
	for weakness, desc in pairs(weakness_desc) do
		labels[weakness .. " verbs"] = {
			description = "{{{langname}}} verbs with " .. weakness_link(weakness) .. " roots, where " .. desc .. ".",
			parents = {
				{name = "verbs by inflection type", sort = weakness},
			},
			breadcrumb = weakness,
		}
	end

	-- Entries for e.g. [[:Category:Arabic final-weak verbs by conjugation]]. Use entries instead of a handler
	-- so that children show up in [[:Category:Arabic verbs by conjugation].
	for weakness, desc in pairs(weakness_desc_by_conjugation) do
		labels[weakness .. " verbs by conjugation"] = {
			description = "{{{langname}}} verbs conjugated as " .. weakness_link(weakness) .. ". " .. weakness_desc_by_conjugation[weakness],
			parents = {
				{name = "verbs by conjugation", sort = weakness},
			},
			breadcrumb = weakness,
		}
	end

	-- Handler for e.g. [[:Category:Arabic form-VIII verbs]].
	table.insert(handlers, function(data)
		local form = data.label:match("^form%-([IVX]+q?) verbs$")
		if not form then
			return nil
		end
		local form_sort_key = form_to_sort_key(form, "with space")
		if not form_sort_key then
			return nil
		end
		local parents = {
			{name = "verbs by inflection type", sort = form_sort_key},
		}
		if form:find("q$") then
			table.insert(parents, {name = "verbs with quadriliteral roots", sort = form_sort_key})
		end
		return {
			description = "{{{langname}}} " .. form_link(form) .. " verbs.",
			parents = parents,
			breadcrumb = "form " .. form,
		}
	end)

	-- Handler for e.g. [[:Category:Arabic final-weak form-VIII verbs]].
	table.insert(handlers, function(data)
		local weakness, form = data.label:match("^([a-z+-]+) form%-([IVX]+q?) verbs$")
		if not weakness or not weakness_desc[weakness] then
			return nil
		end
		local form_sort_key = form_to_sort_key(form)
		if not form_sort_key then
			return nil
		end
		return {
			description = "{{{langname}}} " .. form_link(form) .. " verbs with " .. weakness_link(weakness) ..
			" roots, where " .. weakness_desc[weakness] .. ".",
			parents = {
				{name = "form-" .. form .. " verbs", sort = weakness},
				{name = weakness .. " verbs", sort = form_sort_key},
			},
			breadcrumb = weakness,
		}
	end)

	local radical_ordinals = m_table.listToSet {"first", "second", "third", "fourth"}
	local weak_radicals = m_table.listToSet(langcode == "mt" and {"w", "j"} or {"و", "ي", "ء"})

	-- Handler for e.g. [[:Category:Arabic form-IV verbs with و as second radical]].
	table.insert(handlers, function(data)
		local form, breadcrumb, radical, ordinal = rmatch(data.label, "^form%-([IVX]+q?) verbs with ((.) as ([a-z]+) radical)$")
		if not form then
			return nil
		end
		local form_sort_key = form_to_sort_key(form)
		if not form_sort_key then
			return nil
		end
		if not weak_radicals[radical] or not radical_ordinals[ordinal] then
			return nil
		end
		local weakness = radical == "ء" and "hamzated" or
			ordinal == "first" and "assimilated" or
			ordinal == "second" and "hollow" or
			ordinal == "third" and form:match("q$") and "third-weak" or
			"final-weak"
		return {
			description = "{{{langname}}} " .. form_link(form) .. " verbs with " .. weakness_link(weakness) ..
				" roots having {{lang|{{{langcode}}}|" .. radical .. "}} as their " .. ordinal .. " radical.",
			parents = {
				{name = weakness .. " form-" .. form .. " verbs", sort = " "},
				{name = weakness .. " verbs", sort = form_sort_key .. radical},
			},
			breadcrumb = breadcrumb,
		}
	end)

	local vowels_to_desc = {
		["a-u"] = "This is the most common pattern and is used mostly for non-stative verbs.",
		["a-i"] = "This is a very common pattern and is used mostly for non-stative verbs.",
		["a-a"] = "This is a common pattern and is a variant of the ''a~u'' and ''a~i'' patterns, used especially when the second or third radical is a guttural ({{lang|{{{langcode}}}|ع}}, {{lang|{{{langcode}}}|ح}}, {{lang|{{{langcode}}}|ه}}, {{lang|{{{langcode}}}|ء}} or sometimes {{lang|{{{langcode}}}|غ}} or {{lang|{{{langcode}}}|خ}}), and used mostly for non-stative verbs.",
		["i-a"] = "This is a common pattern for stative verbs but sometimes is also used for non-stative verbs.",
		["i-i"] = "This is a rare pattern, a variant of the ''i~a'' pattern often found especially when " .. W .. " is the first radical.",
		["u-u"] = "This is a relatively common pattern, used almost exclusively for intransitive stative verbs.",
	}
	local A  = u(0x064E) -- fatḥa
	local U  = u(0x064F) -- ḍamma
	local I  = u(0x0650) -- kasra
	local vowel_to_diacritic = {
		a = A,
		i = I,
		u = U,
	}

	labels["form-I verbs by vowel"] = {
		description = "{{{langname}}} " .. form_link("I") .. " verbs categorized by the particular vowel (''a'', ''i'' or " ..
			"''u'') occurring as the last vowel of the past and non-past verb stems.",
		parents = {{name = "form-I verbs", sort = " "}},
		breadcrumb = "by vowel",
	}

	-- Handler for e.g. [[:Category:Arabic form-I verbs with past vowel a and non-past vowel u]]
	table.insert(handlers, function(data)
		local past_vowel, nonpast_vowel = data.label:match("^form%-I verbs with past vowel ([aiu]) and non%-past vowel ([aiu])$")
		if not past_vowel then
			return nil
		end
		local sort_key = ("%s-%s"):format(past_vowel, nonpast_vowel)
		local desc = vowels_to_desc[sort_key]
		if not desc then
			return nil
		end
		return {
			description = ("{{{langname}}} %s verbs with their past vowel ''%s'' ({{m|{{{langcode}}}||فَع%sلَ}}) and their " ..
				"non-past vowel ''%s'' ({{m|{{{langcode}}}||يَفْع%sلُ}}). In both cases, the vowel in question is the last " ..
				"vowel in the stem, which varies from verb to verb. " .. desc):format(form_link("I"), past_vowel,
				vowel_to_diacritic[past_vowel], nonpast_vowel, vowel_to_diacritic[nonpast_vowel]),
			parents = {{name = "form-I verbs by vowel", sort = sort_key}},
			displaytitle = ("{{{langname}}} form-I verbs with past vowel ''%s'' and non-past vowel ''%s''"):format(
				past_vowel, nonpast_vowel),
			breadcrumb = ("past ''%s'', non-past ''%s''"):format(past_vowel, nonpast_vowel),
		}
	end)
end



-----------------------------------------------------------------------------
--                                                                         --
--                                 WRAPPERS                                --
--                                                                         --
-----------------------------------------------------------------------------

function export.add_labels_and_handlers(labels, handlers, lang)
	-- labels
	add_noun_adjective_labels(labels, lang)
	add_verb_labels(labels, lang)
	-- handlers
	add_noun_adjective_handlers(handlers, lang)
	add_verb_handlers(labels, handlers, lang)
end


return export
