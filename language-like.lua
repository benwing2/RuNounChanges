local export = {}

--[==[
Implementation of {getOtherNames()} for languages, families and scripts. If `onlyOtherNames` is passed in, only return
the names in the `otherNames` field, otherwise combine `otherNames`, `aliases` and `variants`.
]==]
function export.getOtherNames(self, onlyOtherNames)
	local data
	if self._extraData then
		data = self._extraData
	elseif self._rawData then
		data = self._rawData
	else
		-- Called from [[Module:list of languages]]; fields already available directly.
		data = self
	end
	if onlyOtherNames then
		return data.otherNames or {}
	end
	if data.variants and data.varieties then
		error("Internal error: Can't specify both `.variants` and `.varieties`; `.varieties` will be going away")
	end
	local variants = data.variants or data.varieties
	local aliases = data.aliases
	local otherNames = data.otherNames
	-- Combine otherNames, aliases and variants (formerly named `varieties`). First try to optimize and not create any
	-- new memory. This is possible if exactly one of the three exist, and if it's `variants`, there are no nested lists
	-- in `variants`.
	if otherNames and not aliases and not variants then
		return otherNames
	elseif aliases and not otherNames and not variants then
		return aliases
	elseif variants and not otherNames and not aliases then
		local saw_table = false
		for _, name in ipairs(variants) do
			if type(name) == "table" then
				saw_table = true
				break
			end
		end
		if not saw_table then
			return variants
		end
	end

	-- Have to do it the "hard way".
	local ret = {}
	if otherNames then
		for _, name in ipairs(otherNames) do
			table.insert(ret, name)
		end
	end
	if aliases then
		for _, name in ipairs(aliases) do
			table.insert(ret, name)
		end
	end
	if variants then
		for _, name in ipairs(variants) do
			if type(name) == "table" then
				for _, n in ipairs(name) do
					table.insert(ret, n)
				end
			else
				table.insert(ret, name)
			end
		end
	end
	return ret
end


--[==[
Implementation of {getVariants()} for languages, families and scripts. If `flatten` is passed in, flatten down to a
list of strings; otherwise, keep the structure.
]==]
function export.getVariants(self, flatten)
	local data
	if self._extraData then
		data = self._extraData
	elseif self._rawData then
		data = self._rawData
	else
		-- Called from [[Module:list of languages]]; fields already available directly.
		data = self
	end
	if data.variants and data.varieties then
		error("Internal error: Can't specify both `.variants` and `.varieties`; `.varieties` will be going away")
	end
	local variants = data.variants or data.varieties
	if variants then
		-- If flattening not requested, just return them.
		if not flatten then
			return variants
		end
		-- Check if no nested table; if so, just return the result.
		local saw_table = false
		for _, name in ipairs(variants) do
			if type(name) == "table" then
				saw_table = true
				break
			end
		end
		if not saw_table then
			return variants
		end
		-- At this point, we need to flatten the variants.
		local ret = {}
		for _, name in ipairs(variants) do
			if type(name) == "table" then
				for _, n in ipairs(name) do
					table.insert(ret, n)
				end
			else
				table.insert(ret, name)
			end
		end
		return ret
	else
		return {}
	end
end


function export.getVarieties(self, flatten)
	return export.getVariants(self, flatten)
end


--[==[
Implementation of template-callable getByCode() function for languages,
etymology languages, families and scripts. `item` is the language,
family or script in question; `args` is the arguments passed in by the
module invocation; `extra_processing`, if specified, is a function of
one argument (the requested property) and should return the value to
be returned to the caller, or nil if the property isn't recognized.
`extra_processing` is called after special-cased properties are handled
and before general-purpose processing code that works for all string
properties.
]==]
function export.templateGetByCode(args, extra_processing)
	-- The item that the caller wanted to look up.
	local item, itemname, list = args[1], args[2]
	if itemname == "getOtherNames" then
		list = item:getOtherNames()
	elseif itemname == "getOnlyOtherNames" then
		list = item:getOtherNames(true)
	elseif itemname == "getAliases" then
		list = item:getAliases()
	elseif itemname == "getVarieties" then
		list = item:getVarieties(true)
	end
	if list then
		local index = args[3]; if index == "" then index = nil end
		index = tonumber(index or error("Numeric index of the desired item in the list (parameter 3) has not been specified."))
		return list[index] or ""
	end

	if itemname == "getFamily" and item.getFamily then
		return item:getFamily():getCode()
	end

	if extra_processing then
		local retval = extra_processing(itemname)
		if retval then
			return retval
		end
	end

	if item[itemname] then
		local ret = item[itemname](item)
		
		if type(ret) == "string" then
			return ret
		else
			error("The function \"" .. itemname .. "\" did not return a string value.")
		end
	end

	error("Requested invalid item name \"" .. itemname .. "\".")
end

return export
