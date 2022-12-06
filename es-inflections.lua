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
local m_es_verb = require("Module:User:Benwing2/es-verb")

local lang = require("Module:languages").getByCode("es")

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub

local function track(page)
	require("Module:debug/track")("es-inflections/" .. page)
	return true
end

local function generate_inflection_of(tags, lemma)
	local has_multiple_tag_sets = #tags > 1

	-- If only one tag set, extract out the "combined with ..." text and move into posttext=, which goes after the lemma.
	local posttext
	if #tags == 1 then
		local tag_set_without_posttext
		tag_set_without_posttext, posttext = tags[1]:match("^(.*)|(combined with .*)$")
		if tag_set_without_posttext then
			tags[1] = tag_set_without_posttext
			posttext = " " .. posttext
		end
	end

	tags = table.concat(tags, "|;|")
	if tags:find("comb") then
		track("comb")
	end
	tags = rsplit(tags, "|")

	local function hack_clitics(text)
		return text:gsub("%[%[(.-)%]%]", function(pronoun) return m_links.full_link({term = pronoun, lang = lang}, "term") end)
	end

	-- Hack to convert raw-linked pronouns e.g. in 'combined with [[te]]' to Spanish-linked pronouns.
	for i, tag in ipairs(tags) do
		if tag:find("%[%[") then
			tags[i] = hack_clitics(tag)
		end
	end
	posttext = posttext and hack_clitics(posttext) or nil

	local terminfo = {
		lang = lang,
		term = lemma,
	}

	if has_multiple_tag_sets then
		tags = require("Module:accel").combine_tag_sets_into_multipart(tags)
	end
	local categories = m_form_of.fetch_lang_categories(lang, tags, terminfo, "verb")
	local cat_text = #categories > 0 and require("Module:utilities").format_categories(categories, lang) or ""
	return m_form_of.tagged_inflections({
		tags = tags, terminfo = terminfo, terminfo_face = "term", posttext = posttext
	}) .. cat_text
end

function export.verb_form_of(frame)
	local parargs = frame:getParent().args
	local alternant_multiword_spec = m_es_verb.do_generate_forms(parargs, false, "from verb form of")
	local non_lemma_form = alternant_multiword_spec.verb_form_of_form

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
	local function loop_over_verb_slots(verb_slots)
		for _, slot_accel in ipairs(verb_slots) do
			local slot, accel = unpack(slot_accel)
			local forms = alternant_multiword_spec.forms[slot]
			if forms then
				for _, formobj in ipairs(forms) do
					local form = m_links.remove_links(formobj.form)
					-- Skip "combined forms" for reflexive verbs; otherwise e.g. ''ámate'' gets identified as a combined form of [[amarse]].
					if non_lemma_form == form and (not alternant_multiword_spec.refl or not slot:find("comb")) then
						m_table.insertIfNot(tags, accel)
					end
				end
			end
		end
	end
	loop_over_verb_slots(alternant_multiword_spec.verb_slots_basic)
	loop_over_verb_slots(alternant_multiword_spec.verb_slots_combined)
	if #tags > 0 then
		return generate_inflection_of(tags, lemma)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	if alternant_multiword_spec.refl and not lemma:find(" ") then
		local refl_forms_to_tags = {}
		-- Only basic verb forms (not combined forms) have non-reflexive parts generated.
		for _, slot_accel in ipairs(alternant_multiword_spec.verb_slots_basic) do
			local slot, accel = unpack(slot_accel)
			local part_forms = alternant_multiword_spec.forms[slot .. "_non_reflexive"]
			local full_forms = alternant_multiword_spec.forms[slot]
			local variant_forms = alternant_multiword_spec.forms[slot .. "_variant"]
			-- Make sure same number of part and full forms, otherwise we can't match them up.
			if part_forms and full_forms and #part_forms == #full_forms and (
				not variant_forms or #part_forms == #variant_forms) then
				-- Find part form the same as the non-lemma form we're generating the inflection(s) of,
				-- and accumulate properties into refl_forms_to_tags.
				for i, part_form in ipairs(part_forms) do
					if part_form.form == non_lemma_form then
						local saw_existing = false
						for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
							if refl_form_to_tags.form == full_forms[i].form then
								table.insert(refl_form_to_tags.tags, accel)
								saw_existing = true
								break
							end
						end
						if not saw_existing then
							table.insert(refl_forms_to_tags, {
								form = full_forms[i].form,
								tags = {accel},
								variant = variant_forms and variant_forms[i].form,
							})
						end
					end
				end
			end
		end

		if #refl_forms_to_tags > 0 then
			local parts = {}
			for _, refl_form_to_tags in ipairs(refl_forms_to_tags) do
				local only_used_in
				local tags = refl_forms_to_tags.tags
				if refl_form_to_tags.variant then
					only_used_in =
						frame:preprocess(("{{only used in|es|%s|nocap=1}}, <span class='use-with-mention'>syntactic variant of {{m|es|%s}}</span>"):format(
							refl_form_to_tags.variant, refl_form_to_tags.form))
				else
					only_used_in =
						frame:preprocess(("{{only used in|es|%s|nocap=1}}"):format(refl_form_to_tags.form))
				end
				if refl_form_to_tags.form == lemma then
					table.insert(parts, only_used_in)
				else
					local inflection_of = generate_inflection_of(refl_form_to_tags.tags, lemma)
					table.insert(parts, ("%s, %s"):format(only_used_in, inflection_of))
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, table.concat(lemmas, "/")))
end

return export
