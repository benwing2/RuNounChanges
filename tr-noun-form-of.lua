local export = {}

local m_harmony = require("Module:tr-harmony")
local m_form_of = require("Module:form of")

local lang = require("Module:languages").getByCode("tr")

function concat(tab1, tab2)
	local result = {}
	for i = 1, #tab1 do
		result[#result + 1] = tab1[i]
	end
	for i = 1, #tab2 do
		result[#result + 1] = tab2[i]
	end
	return result
end

function has_value(tab, val)
	for _, v in ipairs(tab) do
		if v == val then
			return true
		end
	end
	return false
end

function export.show(frame)
   	local args = require "Module:parameters".process(frame:getParent().args, {
		[1] = { required = true },
		["poss"] = { default = "0", type = "boolean" },
		["pred"] = { default = "0", type = "boolean" },
		["title"] = { default = nil },
	})

	local nonlemma = args["title"] or mw.title.getCurrentTitle().text

	local lemma = args[1]
	local soft_lemma = m_harmony.soften(lemma)
	local has_soft_lemma = lemma ~= soft_lemma

	forms = {}
	local lemma_obj = {
		lang = lang,
		term = lemma,
	}
	
	function add_form_to_base(base, suffixes, tags)
		suffixed = m_harmony.attach_suffixes(base, suffixes, nil, could_have_2_way_aorist, true)
		for _, form in ipairs(suffixed) do
			if forms[form] == nil then
				forms[form] = tags
			else
				forms[form] = concat(forms[form], { ";" })
				forms[form] = concat(forms[form], tags)
			end
		end
	end
	function add_form(suffixes, tags)
		add_form_to_base(lemma, suffixes, tags)
		if has_soft_lemma then -- here, more checks could potentially be added based on the suffixes
			add_form_to_base(soft_lemma, suffixes, tags)
		end
	end
	
	function add_case_forms(prior_suffixes, tags)
		YN = has_value(tags, "poss") and "N" or "Y"
		
		add_form(prior_suffixes .. "",        concat({ "nom" }, tags))
		add_form(prior_suffixes .. YN .. "I", concat({ "def", "acc" }, tags))
		add_form(prior_suffixes .. YN .. "A", concat({ "dat" }, tags))
		add_form(prior_suffixes .. "DA",      concat({ "loc" }, tags))
		add_form(prior_suffixes .. "DAn",     concat({ "abl" }, tags))
		add_form(prior_suffixes .. "NIn",     concat({ "gen" }, tags))
	end
	
	function add_possessive_forms(prior_suffixes, tags)
		-- has_value(tags, "p") should be false
		
		-- single-possession
		add_case_forms(prior_suffixes .. "Jm",      concat(tags, { "1", "s", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "Jn",      concat(tags, { "2", "s", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "SI",      concat(tags, { "3", "s", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "JmIz",    concat(tags, { "1", "p", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "JnIz",    concat(tags, { "2", "p", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "lArI",    concat(tags, { "3", "p", "spos//mpos", "poss" }))
		
		-- multiple-possession
		add_case_forms(prior_suffixes .. "lArIm",   concat(tags, { "1", "s", "mpos", "poss" }))
		add_case_forms(prior_suffixes .. "lArIn",   concat(tags, { "2", "s", "mpos", "poss" }))
		add_case_forms(prior_suffixes .. "lArI",    concat(tags, { "3", "s", "mpos", "poss" }))
		add_case_forms(prior_suffixes .. "lArImIz", concat(tags, { "1", "p", "spos", "poss" }))
		add_case_forms(prior_suffixes .. "lArInIz", concat(tags, { "2", "p", "spos", "poss" }))
		-- 3|p|mpos is already in the single-possession section by using //
	end
	
	function add_predicative_forms(prior_suffixes, tags)
		thirdp = has_value(tags, "p") and "DIr" or "lAr"
		
		add_form(prior_suffixes .. "YIm",   concat({ "1", "s", "pred", "of the" }, tags))
		add_form(prior_suffixes .. "sIn",   concat({ "2", "s", "pred", "of the" }, tags))
		add_form(prior_suffixes,            concat({ "3", "s", "pred", "of the" }, tags))
		add_form(prior_suffixes .. "DIr",   concat({ "3", "s", "pred", "of the" }, tags))
		add_form(prior_suffixes .. "YIz",   concat({ "1", "p", "pred", "of the" }, tags))
		add_form(prior_suffixes .. "sInIz", concat({ "2", "p", "pred", "of the" }, tags))
		add_form(prior_suffixes .. thirdp,  concat({ "3", "p", "pred", "of the" }, tags))
	end

	function add_number_forms(prior_suffixes, tags, chain)
		chain(prior_suffixes .. "",    { "s" })
		chain(prior_suffixes .. "lAr", { "p" })
	end
	
	-- basic
	add_number_forms("", {}, add_case_forms)
	
	-- possessive
	if args["poss"] == true then
		add_possessive_forms("", {})
	end
	
	-- predicative
	if args["pred"] == true then
		add_number_forms("", {}, add_predicative_forms)
	end
	
	tags = forms[nonlemma]
	if tags then
		return m_form_of.tagged_inflections {
			lang = lang, tags = tags, lemmas = {lemma_obj}, lemma_face = "term", POS = "noun"
		}
	else
		error("unknown noun form")
	end
end

return export
