local export = {}

--[=[

Authorship: Ben Wing <benwing2>

This module implements {{it-verb form of}}, which automatically generates the appropriate inflections of a non-lemma
verb form given the form and the conjugation spec for the verb (which is usually just the infinitive; see {{it-conj}}
and {{it-verb}}).
]=]

local m_table = require("Module:table")
local m_form_of = require("Module:form of")
local m_links = require("Module:links")
local m_it_verb = require("Module:User:Benwing2/it-verb")
local iut_module = "Module:inflection utilities"
local headword_module = "Module:headword"

local lang = require("Module:languages").getByCode("it")

local rmatch = mw.ustring.match
local rfind = mw.ustring.find
local rsplit = mw.text.split
local usub = mw.ustring.sub
-- Assigned to `require("Module:inflection utilities")` as necessary.
local iut

local function get_iut()
	if not iut then
		iut = require(iut_module)
	end
	return iut
end


local function track(page)
	require("Module:debug/track")("it-inflections/" .. page)
	return true
end


-- FIXME: Duplicated at least in [[Module:it-headword]]. Move to [[Module:inflection utilities]].
local function expand_footnotes_and_references(footnotes)
	if not footnotes then
		return nil
	end
	local quals, refs
	for _, qualifier in ipairs(footnotes) do
		local this_footnote, this_refs = get_iut().expand_footnote_or_references(qualifier, "return raw")
		if this_refs then
			if not refs then
				refs = this_refs
			else
				for _, ref in ipairs(this_refs) do
					table.insert(refs, ref)
				end
			end
		else
			if not quals then
				quals = {this_footnote}
			else
				table.insert(quals, this_footnote)
			end
		end
	end
	return quals, refs
end


local function generate_inflection_of(tags, lemmas)
	local has_multiple_tag_sets = #tags > 1

	tags = table.concat(tags, "|;|")
	tags = rsplit(tags, "|")

	local terminfos = {}
	for _, lemma in ipairs(lemmas) do
		local quals, refs = expand_footnotes_and_references(lemma.footnotes)
		-- FIXME: Qualifiers and references in the lemma in {{inflection of}} not yet supported, but include them
		-- anyway if/when we end up supporting them.
		table.insert(terminfos, {
			lang = lang,
			term = lemma.form,
			q = quals,
			refs = refs
		})
	end

	if has_multiple_tag_sets then
		tags = require("Module:accel").combine_tag_sets_into_multipart(tags)
	end
	local categories = m_form_of.fetch_lang_categories(lang, tags, terminfos, "verb")
	local cat_text = #categories > 0 and require("Module:utilities").format_categories(categories, lang) or ""
	return m_form_of.tagged_inflections {
		tags = tags, terminfos = terminfos, terminfo_face = "term",
	} .. cat_text
end


function export.verb_form_of(frame)
	local parent_args = frame:getParent().args
	local params = {
		[1] = {required = true, default = def or "mettere<a\\é,mìsi,mésso>"},
		["noheadword"] = {type = "boolean"}, -- FIXME: ignored for now
		["pagename"] = {}, -- for testing
	}

	local args = require("Module:parameters").process(parent_args, params)
	local alternant_multiword_spec = m_it_verb.do_generate_forms(args, "it-inflections")
	local non_lemma_form = alternant_multiword_spec.verb_form_of_form

	local lemmas = {}
	if not alternant_multiword_spec.forms.inf then
		error("Internal error: No infinitive?")
	end
	for _, formobj in ipairs(alternant_multiword_spec.forms.inf) do
		-- If the lemma is multiword or pronominal, it will have multiple parts linked in it, whereas we always want the
		-- entire lemma linked as a unit. In all cases there will also be extra characters like 0xFFF1 (IS_VERB_FORM)
		-- in the raw lemma, which need to be removed.
		local consolidated_accented = m_it_verb.convert_to_accented(formobj.form, nil, "consolidate links")
		m_table.insertIfNot(lemmas, {form = consolidated_accented, footnotes = formobj.footnotes})
	end

	local tags = {}
	local accented_forms = {}
	for _, slot_accel in ipairs(m_it_verb.all_verb_slots) do
		local slot, accel = unpack(slot_accel)
		local forms = alternant_multiword_spec.forms[slot]
		if forms then
			for _, formobj in ipairs(forms) do
				local accented_linked = m_it_verb.convert_to_accented(formobj.form)
				local unaccented = m_it_verb.convert_to_unaccented(formobj.form, "strip links")
				if non_lemma_form == unaccented then
					m_table.insertIfNot(tags, accel)
					local saw_existing = false
					for _, existing_accented in ipairs(accented_forms) do
						if existing_accented.form == accented_linked then
							if existing_accented.footnotes or formobj.footnotes then
								existing_accented.footnotes = get_iut().combine_footnotes(
									existing_accented.footnotes, formobj.footnotes
								)
							end
							saw_existing = true
							break
						end
					end
					if not saw_existing then
						table.insert(accented_forms, formobj)
					end
				end
			end
		end
	end

	if #tags > 0 then
		local prelude
		if args.noheadword then
			prelude = ""
		else
			local heads = {}
			for _, accented_form in ipairs(accented_forms) do
				local quals, refs = expand_footnotes_and_references(accented_form.footnotes)
				table.insert(heads, {term = accented_form.form, q = quals, refs = refs})
			end
			local head_data = {
				lang = lang,
				heads = heads,
				pos_category = "verb forms",
			}
			prelude = require(headword_module).full_headword(head_data) .. "\n\n"
		end

		return prelude .. generate_inflection_of(tags, lemmas)
	end

	-- If we don't find any matches, we try again, looking for non-reflexive forms of reflexive-only verbs.
	if alternant_multiword_spec.props.any_reflexive and not lemma:find(" ") then
		local refl_forms_to_tags = {}
		for _, slot_accel in ipairs(m_it_verb.all_verb_slots) do
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
						frame:preprocess(("{{only used in|it|%s|nocap=1}}, <span class='use-with-mention'>syntactic variant of {{m|it|%s}}</span>"):format(
							refl_form_to_tags.variant, refl_form_to_tags.form))
				else
					only_used_in =
						frame:preprocess(("{{only used in|it|%s|nocap=1}}"):format(refl_form_to_tags.form))
				end
				if refl_form_to_tags.form == lemma then
					table.insert(parts, only_used_in)
				else
					local inflection_of = generate_inflection_of(refl_form_to_tags.tags, lemmas)
					table.insert(parts, ("%s, %s"):format(only_used_in, inflection_of))
				end
			end
			return table.concat(parts, "\n# ")
		end
	end

	error(("'%s' is not any of the forms of the verb '%s'"):format(non_lemma_form, table.concat(lemmas, "/")))
end

return export
