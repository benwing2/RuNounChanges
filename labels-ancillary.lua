local export = {}

-- This module contains ancillary functions for manipulating labels. Currently the supported functions are for finding
-- the labels that generate a given category.

local labels_module = "Module:labels"

-- Find the labels matching category `cat` of type `cat_type` (currently supported values are "topic" for topic
-- categories, e.g. 'en:Water'; "pos" for POS categories, e.g. 'English attenuative verbs'; "regional" for regional
-- categories, e.g. 'Ghanaian English; and "plain" for plain categories, e.g. 'Issime Walser') for language `lang`
-- (which may be nil for umbrella or plain categories). The format of `cat` depends on `cat_type`, but in general is
-- the portion of the category minus the language prefix or suffix. For topic categories it should be e.g. "water" or
-- "Water" (either form works); for POS categories it should be e.g. "attenuative verbs"; for regional categories it
-- should be e.g. "Ghanaian"; and for plain categories it should be e.g. "Issime Walser" (the actual category name).
function export.find_labels_for_category(cat, cat_type, lang)
	local function ucfirst(txt)
		return mw.getContentLanguage():ucfirst(txt)
	end
	if cat_type ~= "pos" then
		cat = ucfirst(cat)
	end

	local function should_error_on_cat(cat)
		if cat_type == "topic" then
			return cat:find("^[Aa]ll ")
		elseif cat_type == "pos" then
			return cat == "lemmas"
		elseif cat_type == "regional" then
			return "British English" -- an arbitrary known regional category
		else
			return "Issime Walser" -- an arbitrary known plain category
		end
	end

	local function labcat_matches(labcat)
		if cat_type ~= "pos" then
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
		else
			return labdata.plain_categories
		end
	end

	local cat_labels_found = {}
	local prev_modules_labels_found = {}
	local this_module_labels_found

	local submodules_to_check = require(labels_module).get_submodules(lang)
	for _, submodule_to_check in ipairs(submodules_to_check) do
		if this_module_labels_found then
			for label, _ in pairs(this_module_labels_found) do
				prev_modules_labels_found[label] = true
			end
		end
		this_module_labels_found = {}
		submodule = mw.loadData(submodule_to_check)
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
				if matching_labcat and not prev_modules_labels_found[canonical] then
					this_module_labels_found[canonical] = true
					if not cat_labels_found[canonical] then
						cat_labels_found[canonical] = {}
					end
					if canonical ~= label then
						table.insert(cat_labels_found[canonical], label)
					end
				end
			end
		end
	end

	return cat_labels_found
end

-- Format the labels that categorize into some category for display in the text for that category. `lang` is the
-- language of the category, or nil. Returns nil if there are no labels.
function export.format_labels_categorizing(labels, lang)
	local function make_code(txt)
		return ("<code>%s</code>"):format(txt)
	end
	local formatted_labels = {}
	for label, aliases in pairs(labels) do
		if #aliases == 0 then
			table.insert(formatted_labels, make_code(label))
		elseif #aliases == 1 then
			table.insert(formatted_labels, ("%s (alias %s)"):format(make_code(label), make_code(aliases[1])))
		else
			table.sort(aliases)
			for i, alias in ipairs(aliases) do
				aliases[i] = make_code(alias)
			end
			table.insert(formatted_labels, ("%s (aliases %s)"):format(make_code(label), table.concat(aliases, ", ")))
		end
	end
	if #formatted_labels > 0 then
		table.sort(formatted_labels)
		local retval = ("The following label%s generate%s this category: %s."):format(
			#formatted_labels == 1 and "" or "s", #formatted_labels == 1 and "s" or "",
			table.concat(formatted_labels, "; "))
		if lang then
			retval = retval .. (" To generate this category using a label, use {{tl|lb|%s|<var>label</var>}}."):format(
				lang:getCode())
		else
			retval = retval .. " To generate this category using a label, use {{tl|lb|<var>langcode</var>|<var>label</var>}}, " ..
				"where <code><var>langcode</var></code> is the appropriate language code for the language in question " ..
				"(see [[Wiktionary:List of languages]])."
		end
		return retval
	end
end

-- Generate a message indicating what labels categorize into the specified category `cat` of type `cat_type`, for
-- language `lang` (a language object, may be nil). Parameters are the same as for find_labels_for_category() above.
function export.get_labels_categorizing(cat, cat_type, lang)
	return export.format_labels_categorizing(export.find_labels_for_category(cat, cat_type, lang), lang)
end

return export
