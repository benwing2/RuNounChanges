local export = {}

local labels_module = "Module:labels"

-- Find the labels matching category `cat` of type `cat_type` (currently supported values are "topic" for topic
-- categories and "pos" for POS categories) for language `lang` (which may be nil for umbrella categories). The
-- format of `cat` depends on `cat_type`; for topic categories it should be e.g. "water" or "Water" (either form
-- works), and for POS categories it should be e.g. "attenuative verbs".
function export.find_labels_for_category(cat, cat_type, lang)
	local function ucfirst(txt)
		return mw.getContentLanguage():ucfirst(txt)
	end
	if cat_type == "topic" then
		cat = ucfirst(cat)
	end

	local function should_error_on_cat(cat)
		if cat_type == "topic" then
			return cat:find("^[Aa]ll ")
		else
			return cat == "lemmas"
		end
	end

	local function labcat_matches(labcat)
		if cat_type == "topic" then
			return ucfirst(labcat) == cat
		else
			return labcat == cat
		end
	end

	local function fetch_labdata_cats(labdata)
		if cat_type == "topic" then
			return labdata.topical_categories
		else
			return labdata.pos_categories
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

function export.get_labels_categorizing(cat, cat_type, lang)
	local cat_producing_labels = export.find_labels_for_category(cat, cat_type, lang)
	local function make_code(txt)
		return ("<code>%s</code>"):format(txt)
	end
	local formatted_labels = {}
	for label, aliases in pairs(cat_producing_labels) do
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
		end
		return retval
	end
end

return export
