local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{es-verb form of}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the infinitive; see {{es-conj}}
and {{es-verb}}).
]=]

local m_links = require("Module:links")
local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local m_es_verb = require("Module:es-verb")

local lang = require("Module:languages").getByCode("es")
local PAGENAME = mw.title.getCurrentTitle().text

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug/track")("es-inflections/" .. page)
	return true
end

local function generate_inflection_of(tags, lemma)
	tags = table.concat(tags, "|;|")
	if tags:find("comb") then
		track("comb")
	end
	tags = rsplit(tags, "|")
	-- Hack to convert raw-linked pronouns e.g. in 'combined with [[te]]' to Spanish-linked pronouns.
	for i, tag in ipairs(tags) do
		if tag:find("%[%[") then
			tags[i] = tag:gsub("%[%[(.-)%]%]", function(pronoun) return m_links.full_link({term = pronoun, lang = lang}, "term") end)
		end
	end

	local terminfo = {
		lang = lang,
		term = lemma,
	}

	local categories = m_form_of.fetch_lang_categories(lang, tags, terminfo, "verb")
	return m_form_of.tagged_inflections({ tags = tags, terminfo = terminfo, terminfo_face = "term" }) .. 
		require("Module:utilities").format_categories(categories, lang)
end

function export.verb_form_of(frame)
	local parargs = frame:getParent().args
	local alternant_multiword_spec = m_es_verb.do_generate_forms(parargs)

	local pagename = alternant_multiword_spec.args.pagename or
		mw.title.getCurrentTitle().text
	if pagename == "es-verb form of" and mw.title.getCurrentTitle().nsText == "Template" then
		pagename = "ame"
	end

	local lemmas = {}
	if not alternant_multiword_spec.forms.infinitive then
		error("Internal error: No infinitive?")
	end
	for _, formobj in ipairs(alternant_multiword_spec.forms.infinitive) do
		m_table.insertIfNot(lemmas, m_links.remove_links(formobj.form))
	end

	-- FIXME: Consider supporting multiple lemmas.
	local lemma = lemmas[1]

	local tags = {}
	for _, slot_accel in ipairs(m_es_verb.all_verb_slots) do
		local slot, accel = unpack(slot_accel)
		local forms = alternant_multiword_spec.forms[slot]
		if forms then
			for _, formobj in ipairs(forms) do
				local form = m_links.remove_links(formobj.form)
				-- Skip "combined forms" for reflexive verbs; otherwise e.g. ''ámate'' gets identified as a combined form of [[amarse]].
				if pagename == form and (not alternant_multiword_spec.refl or not slot:find("comb")) then
					if accel == "-" then
						accel = m_es_verb.overriding_slot_accel[slot]
					end
					m_table.insertIfNot(tags, accel)
				end
			end
		end
	end
	if #tags > 0 then
		return generate_inflection_of(tags, lemma)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	if alternant_multiword_spec.refl and not lemma:find(" ") then
		local refl_prons = {"me", "te", "se", "nos", "os"}
		local tags_by_refl_pron = {}
		local form_by_refl_pron = {}
		local saw_matching_form = false
		for _, slot_accel in ipairs(m_es_verb.all_verb_slots) do
			local slot, accel = unpack(slot_accel)
			local forms = alternant_multiword_spec.forms[slot]
			-- Skip "combined forms" for reflexive verbs; see above.
			if forms and not slot:find("comb") then
				for _, formobj in ipairs(forms) do
					local form = m_links.remove_links(formobj.form)
					for _, refl_pron in ipairs(refl_prons) do
						local form_no_refl = form:match("^" .. refl_pron .. " (.*)$")
						if pagename == form_no_refl then
							saw_matching_form = true
							if accel == "-" then
								accel = m_es_verb.overriding_slot_accel[slot]
							end
							if tags_by_refl_pron[refl_pron] then
								m_table.insertIfNot(tags_by_refl_pron[refl_pron], accel)
							else
								tags_by_refl_pron[refl_pron] = {accel}
								form_by_refl_pron[refl_pron] = formobj.form
							end
							break
						end
					end
				end
			end
		end
		if saw_matching_form then
			local parts = {}
			for _, refl_pron in ipairs(refl_prons) do
				if tags_by_refl_pron[refl_pron] then
					local only_used_in =
						frame:preprocess(("{{only used in|es|%s|nocap=1}}"):format(form_by_refl_pron[refl_pron]))
					local inflection_of = generate_inflection_of(tags_by_refl_pron[refl_pron], lemma)
					table.insert(parts, ("%s, %s"):format(only_used_in, inflection_of))
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(pagename, table.concat(lemmas, "/")))
end

return export
