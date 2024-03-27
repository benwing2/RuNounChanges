local export = {}

-- This module contains ancillary functions for manipulating labels. Currently the supported functions are for finding
-- the labels that generate a given category.

local m_labels = require("Module:labels")
local languages_module = "Module:languages"

--[==[
Find the labels matching category `cat` of type `cat_type` for language `lang` (a full language object). `lang` can be
{nil}, but in that case no language-specific labels will be fetched. Currently supported values for `cat_type` are
{"topic"} for topic categories, e.g. {en:Water}; {"pos"} for POS categories, e.g. {English attenuative verbs};
{"regional"} for regional categories, e.g. {Ghanaian English}; {"sense"} for sense-dependent categories, e.g.
{English obsolete terms} or {English terms with obsolete senses} (where the particular category chosen depends on
whether {{tl|lb}} or {{tl|tlb}} is used); and {"plain"} for plain categories, e.g. {Issime Walser}. The format of `cat`
depends on `cat_type`, but in general is the portion of the category minus the language prefix or suffix. For topic
categories it should be e.g. {"water"} or {"Water"} (either form works); for POS categories it should be e.g.
{"attenuative verbs"}; for regional categories it should be e.g. {"Ghanaian"}; for sense categories it should be e.g.
{"obsolete"}; and for plain categories it should be e.g. {"Issime Walser"} (the actual category name).

Note that this will only check for categories of the specified type. In particular, since the format of POS and
sense-dependent categories overlaps, you may need to check for labels with both types of categories. (This is done, for
example, in [[Module:category tree/poscatboiler]]; see that module for details.) Likewise with regional and plain
categories. (See the code in [[Module:category tree/poscatboiler/data/language varieties]] that handles both types of
categories.)

If `cat_type` is {"plain"} and `check_all_langs` is specified, the code will check all language-specific modules for
plan categories matching `cat`. In that case, the relevant language is returned in the return value structure (see
below).

The return value is a table whose keys are labels and whose values are objects with keys `module` (the
name of the module from which the label was fetched), `aliases` (a list of any aliases for the label, not including
the label itself) and `lang` (the language needed to generate the category using the label; this will always be the
passed-in `lang` unless `check_all_langs` is specified, in which case it may be a different language).
]==]
function export.find_labels_for_category(cat, cat_type, lang, check_all_langs)
	local function ucfirst(txt)
		return mw.getContentLanguage():ucfirst(txt)
	end
	
	local function transform_cat_for_comparison(cat)
		if cat_type ~= "pos" and cat_type ~= "sense" then
			cat = ucfirst(cat)
		end
		return cat
	end

	local function should_error_on_cat(cat)
		if cat_type == "topic" then
			return cat:find("^[Aa]ll ")
		elseif cat_type == "pos" then
			return cat == "lemmas"
		elseif cat_type == "regional" then
			return cat == "British" -- an arbitrary known regional category
		elseif cat_type == "sense" then
			return cat == "obsolete" -- an arbitrary known sense category
		else
			return cat == "Issime Walser" -- an arbitrary known plain category
		end
	end

	local function labcat_matches(labcat)
		if cat_type ~= "pos" and cat_type ~= "sense" then
			return ucfirst(labcat) == cat
		else
			return labcat == cat
		end
	end

	local function fetch_labdata_cats(labdata)
		if cat_type == "topic" then
			return labdata.topical_categories
		elseif cat_type == "pos" then
			return labdata.pos_categories
		elseif cat_type == "regional" then
			return labdata.regional_categories
		elseif cat_type == "sense" then
			return labdata.sense_categories
		else
			return labdata.plain_categories
		end
	end

	cat = transform_cat_for_comparison(cat)

	local cat_labels_found = {}
	local prev_modules_labels_found = {}
	local this_module_labels_found

	local function check_submodule(submodule_to_check, lang)
		if this_module_labels_found then
			for label, _ in pairs(this_module_labels_found) do
				prev_modules_labels_found[label] = true
			end
		end
		this_module_labels_found = {}
		local submodule = mw.loadData(submodule_to_check)
		for label, labdata in pairs(submodule) do
			local canonical = label
			local num_hops = 0
			local hop_error = false
			while type(labdata) == "string" do
				num_hops = num_hops + 1
				if num_hops >= 10 then
					if should_error_on_cat(cat) then
						error(("Internal error: Likely alias loop processing label '%s' in submodule '%s'"):format(label, submodule_to_check))
					else
						hop_error = true
						break
					end
				end
				-- an alias
				canonical = labdata
				labdata = submodule[labdata]
			end
			if hop_error then
				-- skip this label
			elseif not labdata then
				if should_error_on_cat(cat) then
					-- Only error at top level to avoid a flood of errors.
					error(("Internal error: In submodule '%s', label '%s' is aliased to '%s', which doesn't exist"):format(submodule_to_check, label, canonical))
				end
			else
				-- Deprecated labels directly assign an object to aliases, where `canonical` is the canonical label.
				if labdata.canonical then
					canonical = labdata.canonical
				end
				local labcats = fetch_labdata_cats(labdata)
				local matching_labcat
				if labcats then
					if type(labcats) ~= "table" then
						labcats = {labcats}
					end
					for _, labcat in ipairs(labcats) do
						if labcat == true then
							labcat = canonical
						end
						if labcat_matches(labcat) then
							matching_labcat = true
							break
						end
					end
				end
				local canonical_with_lang = canonical .. ":" .. (lang and lang:getCode() or "nil")
				if matching_labcat and not prev_modules_labels_found[canonical_with_lang] then
					this_module_labels_found[canonical_with_lang] = true
					if not cat_labels_found[canonical_with_lang] then
						cat_labels_found[canonical_with_lang] = {
							module = submodule_to_check, canonical = canonical,
							aliases = {}, lang = lang
						}
					end
					if canonical ~= label then
						table.insert(cat_labels_found[canonical_with_lang].aliases, label)
					end
				end
			end
		end
	end

	local submodules_to_check
	if check_all_langs then
		if cat_type ~= "plain" then
			error("Currently, `check_all_langs` only supported with category type \"plain\"")
		end
		submodules_to_check = {}
		local all_lang_codes = mw.loadData(m_labels.lang_specific_data_list_module)
		for lang_code, _ in pairs(all_lang_codes.langs_with_lang_specific_modules) do
			local lang = require(languages_module).getByCode(lang_code)
			if lang then
				table.insert(submodules_to_check, {
					module = m_labels.lang_specific_data_modules_prefix .. lang_code,
					lang = lang
				})
			end
		end
		for _, submodule_to_check in ipairs(m_labels.get_submodules(nil)) do
			table.insert(submodules_to_check, {module = submodule_to_check, lang = lang})
		end
	else
		submodules_to_check = m_labels.get_submodules(lang)
		for i, submodule_to_check in ipairs(submodules_to_check) do
			submodules_to_check[i] = {module = submodule_to_check, lang = lang}
		end
	end
	for _, submodule_to_check in ipairs(submodules_to_check) do
		check_submodule(submodule_to_check.module, submodule_to_check.lang)
	end

	return cat_labels_found
end

--[==[
Format the labels that categorize into some category for display in the text for that category. `lang` is the
language of the category, or {nil}. `labels` are the labels that categorize when invoked using {{tl|lb}}, while
`tlb_labels` are the labels that categorize when invoked using {{tl|tlb}}. Returns {nil} if there are no labels.
]==]
function export.format_labels_categorizing(labels, tlb_labels, lang)
	local function make_code(txt)
		return ("<code>%s</code>"):format(txt)
	end
	local function generate_label_set_text(labels, use_tlb, include_in_addition)
		local labels_by_lang = {}
		for _, labobj in pairs(labels) do
			local labobj_code = labobj.lang and labobj.lang:getCode() or false
			if not labels_by_lang[labobj_code] then
				labels_by_lang[labobj_code] = {}
			end
			table.insert(labels_by_lang[labobj_code], labobj)
		end

		local function process_lang_labels(labels)
			local formatted_labels = {}
			local has_aliases = false
			if labels then
				for _, labobj in ipairs(labels) do
					local function make_edit_button()
						return ("<sup>[%s edit]</sup>"):format(tostring(mw.uri.fullUrl(labobj.module, "action=edit")))
					end
					local label = labobj.canonical
					local aliases = labobj.aliases
					if #aliases == 0 then
						table.insert(formatted_labels, make_code(label) .. make_edit_button())
					elseif #aliases == 1 then
						table.insert(formatted_labels,
							("%s (alias %s)%s"):format(make_code(label), make_code(aliases[1]), make_edit_button()))
						has_aliases = true
					else
						table.sort(aliases)
						for i, alias in ipairs(aliases) do
							aliases[i] = make_code(alias)
						end
						table.insert(formatted_labels,
							("%s (aliases %s)%s"):format(make_code(label),table.concat(aliases, ", "), make_edit_button()))
						has_aliases = true
					end
				end
			end
			return formatted_labels, has_aliases
		end

		local function get_intro_text(num_labels, include_also)
			local intro_wording = not include_also and include_in_addition and "In addition, the" or "The"
			local sense_dependent = use_tlb and "sense-dependent " or ""
			return ("%s following %slabel%s %sgenerate%s this category:"):format(intro_wording,
				sense_dependent, num_labels == 1 and "" or "s",
				include_also and "also " or "", num_labels == 1 and "s" or "")
		end

		local function get_label_text(label_lang, formatted_labels, has_aliases)
			table.sort(formatted_labels)
			local retval = table.concat(formatted_labels, "; ") .. ". "
			local template = use_tlb and "tlb" or "lb"
			local this_label_text
			if #formatted_labels == 1 and not has_aliases then
				this_label_text = "this label"
			else
				this_label_text = "one of these labels"
			end
			if label_lang then
				retval = retval .. ("To generate this category using %s, use {{tl|%s|%s|<var>label</var>}}."):format(
					this_label_text, template, label_lang:getCode())
			else
				retval = retval .. ("To generate this category using %s, use {{tl|%s|<var>langcode</var>|<var>label</var>}}, " ..
					"where <code><var>langcode</var></code> is the appropriate language code for the language in question " ..
					"(see [[Wiktionary:List of languages]])."):format(this_label_text, template)
			end
			return retval
		end

		if not lang then
			local formatted_labels, has_aliases = process_lang_labels(labels_by_lang[false])
			if #formatted_labels > 0 then
				local intro_text = get_intro_text(#formatted_labels)
				local label_text = get_label_text(false, formatted_labels, has_aliases)
				return intro_text .. " " .. label_text
			end
		else
			local formatted_labels, has_aliases = process_lang_labels(labels_by_lang[lang:getCode()])
			local this_lang_text
			if #formatted_labels > 0 then
				local intro_text = get_intro_text(#formatted_labels)
				local label_text = get_label_text(lang, formatted_labels, has_aliases)
				this_lang_text = intro_text .. " " .. label_text
			end
			local langcode = lang:getCode()
			local other_langs_label_text = {}
			local total_num_other_lang_labels = 0
			for other_lang_code, lang_labels in pairs(labels_by_lang) do
				if other_lang_code ~= langcode then
					local formatted_labels, has_aliases = process_lang_labels(lang_labels)
					if #formatted_labels > 0 then
						total_num_other_lang_labels = total_num_other_lang_labels + #formatted_labels
						local other_lang = require(languages_module).getByCode(other_lang_code, true, "allow etym")
						local label_text = get_label_text(other_lang, formatted_labels, has_aliases)
						table.insert(other_langs_label_text,
							("* For %s: %s"):format(other_lang:getCanonicalName(), label_text))
					end
				end
			end
			local other_lang_text
			if total_num_other_lang_labels > 0 then
				table.sort(other_langs_label_text)
				local intro_text = get_intro_text(total_num_other_lang_labels, this_lang_text and "include also")
				other_lang_text = intro_text .. "\n" .. table.concat(other_langs_label_text, "\n")
			end
			if this_lang_text and other_lang_text then
				return ("%s\n\n%s"):format(this_lang_text, other_lang_text)
			else
				return this_lang_text or other_lang_text
			end
		end
	end

	local labels_text = generate_label_set_text(labels)
	local tlb_labels_text = tlb_labels and
		generate_label_set_text(tlb_labels, "use tlb", labels_text and "include in addition") or nil
	if labels_text and tlb_labels_text then
		return ("%s\n\n%s"):format(labels_text, tlb_labels_text)
	else
		return labels_text or tlb_labels_text
	end
end

return export
