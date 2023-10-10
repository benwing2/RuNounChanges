local export = {}

local labels_module = "Module:labels"

function export.find_labels_for_topic(topic, lang)
	local function ucfirst(txt)
		return mw.getContentLanguage():ucfirst(txt)
	end
	topic = ucfirst(topic)

	local topic_labels_found = {}
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
					if topic:find("^[Aa]ll ") then
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
				if topic:find("^[Aa]ll ") then
					-- Only error at top level to avoid a flood of errors.
					error(("Internal error: In submodule '%s', label '%s' is aliased to '%s', which doesn't exist"):format(submodule_to_check, label, canonical))
				end
			else
				-- Deprecated labels directly assign an object to aliases, where `canonical` is the canonical label.
				if labdata.canonical then
					canonical = labdata.canonical
				end
				local topcats = labdata.topical_categories
				local matching_topcat
				if topcats then
					if type(topcats) ~= "table" then
						topcats = {topcats}
					end
					for _, topcat in ipairs(topcats) do
						if topcat == true then
							topcat = canonical
						end
						if ucfirst(topcat) == topic then
							matching_topcat = true
							break
						end
					end
				end
				if matching_topcat and not prev_modules_labels_found[canonical] then
					this_module_labels_found[canonical] = true
					if not topic_labels_found[canonical] then
						topic_labels_found[canonical] = {}
					end
					if canonical ~= label then
						table.insert(topic_labels_found[canonical], label)
					end
				end
			end
		end
	end

	return topic_labels_found
end

return export
