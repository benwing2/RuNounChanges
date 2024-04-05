local export = {}

function export.makeObject(code, data, useRequire)
	local Family = {}

	--[==[
	Return the family code of the family, e.g. {"ine"} for the Indo-European languages.
	]==]
	function Family:getCode()
		return self._code
	end

	--[==[
	Return the canonical name of the family. This is the name used to represent that language family on Wiktionary,
	and is guaranteed to be unique to that family alone. Example: {"Indo-European"} for the Indo-European languages.
	]==]
	function Family:getCanonicalName()
		return self._rawData[1]
	end

	--[==[
	Return the display form of the family. For families, this is the same as the value returned by
	{getCategoryName("nocap")}, i.e. it reads <code>"<var>name</var> languages"</code> (e.g.
	{"Indo-Iranian languages"}). For full and etymology-only languages, this is the same as the canonical name, and
	for scripts, it reads <code>"<var>name</var> script"</code> (e.g. {"Arabic script"}). The displayed text used in
	{makeCategoryLink()} is always the same as the display form.
	]==]
	function Family:getDisplayForm()
		return self:getCategoryName("nocap")
	end

	function Family:getOtherNames(onlyOtherNames)
		return require("Module:language-like").getOtherNames(self, onlyOtherNames)
	end

	function Family:getAliases()
		return self._rawData.aliases or {}
	end

	function Family:getVarieties(flatten)
		return require("Module:language-like").getVarieties(self, flatten)
	end


	--Returns a table of all names that the family is known by, including the canonical name.
	--The names are not guaranteed to be unique, sometimes more than one family is known by the same name.
	--Example: <code>{"Slavic", "Slavonic"}</code> for the Slavic languages.
	--function Family:getAllNames()
	--	return self._rawData.names
	--end

	--[==[Given a list of types as strings, returns true if the family has all of them. 

	The following types are recognized:
	* {family}: This object is a family.
	* {full}: This object is a "full" family. This includes all families but a couple of etymology-only
			  families for Old and Middle Iranian languages.
	* {etymology-only}: This object is an etymology-only family, similar to etymology-only languages. There
						are currently only two such families, for Old Iranian languages and Middle Iranian
						languages (which do not represent proper clades and have no proto-languages, hence
						cannot be full families).
	]==]
	function Family:hasType(...)
		if not self._type then
			self._type = {family = true}
			if self:getFullCode() == self:getCode() then
				self._type.full = true
			else
				self._type["etymology-only"] = true
			end
			if self._rawData.type then
				for _, type in ipairs(mw.text.split(self._rawData.type, "%s*,%s*")) do
					self._type[type] = true
				end
			end
		end
		for _, type in ipairs{...} do
			if not self._type[type] then
				return false
			end
		end
		return true
	end

	--[==[Returns a {Family} object for the superfamily that the family belongs to.]==]
	function Family:getFamily()
		if self._familyObject == nil then
			local familyCode = self:getFamilyCode()
			if familyCode then
				self._familyObject = export.getByCode(familyCode, useRequire)
			else
				self._familyObject = false
			end
		end
		return self._familyObject or nil
	end

	--[==[Returns the code of the family's superfamily.]==]
	function Family:getFamilyCode()
		if not self._familyCode then
			self._familyCode = self._rawData[3]
		end
		return self._familyCode
	end

	--[==[Returns the canonical name of the family's superfamily.]==]
	function Family:getFamilyName()
		if self._familyName == nil then
			local family = self:getFamily()
			if family then
				self._familyName = family:getCanonicalName()
			else
				self._familyName = false
			end
		end
		return self._familyName or nil
	end

	--[==[Check whether the family belongs to {superfamily} (which can be a family code or object), and returns a boolean. If more than one is given, returns {true} if the family belongs to any of them. A family is '''not''' considered to belong to itself.]==]
	function Family:inFamily(...)
		for _, superfamily in ipairs{...} do
			if type(superfamily) == "table" then
				superfamily = superfamily:getCode()
			end
			local family, code = self:getFamily()
			while true do
				if not family then
					return false
				end
				code = family:getCode()
				family = family:getFamily()
				-- If family is parent to itself, return false.
				if family and family:getCode() == code then
					return false
				elseif code == superfamily then
					return true
				end
			end
		end
	end

	function Family:getParent()
		if self._parentObject == nil then
			local parentCode = self:getParentCode()
			if parentCode then
				self._parentObject = require("Module:languages").getByCode(parentCode, nil, true, true, useRequire)
			else
				self._parentObject = false
			end
		end
		return self._parentObject or nil
	end

	function Family:getParentCode()
		if not self._parentCode then
			self._parentCode = self._rawData[5]
		end
		return self._parentCode
	end

	function Family:getParentName()
		if self._parentName == nil then
			local parent = self:getParent()
			if parent then
				self._parentName = parent:getCanonicalName()
			else
				self._parentName = false
			end
		end
		return self._parentName or nil
	end

	function Family:getParentChain()
		if not self._parentChain then
			self._parentChain = {}
			local parent = self:getParent()
			while parent do
				table.insert(self._parentChain, parent)
				parent = parent:getParent()
			end
		end
		return self._parentChain
	end

	function Family:hasParent(...)
		--checkObject("family", nil, ...)
		for _, other_family in ipairs{...} do
			for _, parent in ipairs(self:getParentChain()) do
				if type(other_family) == "string" then
					if other_family == parent:getCode() then return true end
				else
					if other_family:getCode() == parent:getCode() then return true end
				end
			end
		end
		return false
	end

	--[==[
	If the family is etymology-only, this iterates through its parents until a full family is found, and the
	corresponding object is returned. If the family is a full family, then it simply returns itself.
	]==]
	function Family:getFull()
		if not self._fullObject then
			local fullCode = self:getFullCode()
			if fullCode ~= self:getCode() then
				self._fullObject = require("Module:languages").getByCode(fullCode, nil, nil, true, useRequire)
			else
				self._fullObject = self
			end
		end
		return self._fullObject
	end

	--[==[
	If the family is etymology-only, this iterates through its parents until a full family is found, and the
	corresponding code is returned. If the family is a full family, then it simply returns the family code.
	]==]
	function Family:getFullCode()
		return self._fullCode or self:getCode()
	end

	--[==[
	If the family is etymology-only, this iterates through its parents until a full family is found, and the
	corresponding canonical name is returned. If the family is a full family, then it simply returns the canonical name
	of the family.
	]==]
	function Family:getFullName()
		if self._fullName == nil then
			local full = self:getFull()
			if full then
				self._fullName = full:getCanonicalName()
			else
				self._fullName = false
			end
		end
		return self._fullName or nil
	end

	--[==[
	Return a {Language} object (see [[Module:languages]]) for the proto-language of this family, if one exists.
	Otherwise, return {nil}.
	]==]
	function Family:getProtoLanguage()
		if self._protoLanguageObject == nil then
			self._protoLanguageObject = require("Module:languages").getByCode(self._rawData.protoLanguage or self:getCode() .. "-pro", nil, true, nil, useRequire) or false
		end
		return self._protoLanguageObject or nil
	end

	function Family:getProtoLanguageCode()
		if self._protoLanguageCode == nil then
			local protoLanguage = self:getProtoLanguage()
			self._protoLanguageCode = protoLanguage and protoLanguage:getCode() or false
		end
		return self._protoLanguageCode or nil
	end

	function Family:getProtoLanguageName()
		if not self._protoLanguageName then
			self._protoLanguageName = self:getProtoLanguage():getCanonicalName()
		end
		return self._protoLanguageName
	end

	function Family:hasAncestor(...)
		-- Go up the family tree until a protolanguage is found.
		local family = self
		local protolang = family:getProtoLanguage()
		while not protolang do
			family = family:getFamily()
			protolang = family:getProtoLanguage()
			-- Return false if the family is its own family, to avoid an infinite loop.
			if family:getFamilyCode() == family:getCode() then
				return false
			end
		end
		-- If the protolanguage is not in the family, it must therefore be ancestral to it. Check if it is a match.
		for _, otherlang in ipairs{...} do
			if (
				type(otherlang) == "string" and protolang:getCode() == otherlang or
				type(otherlang) == "table" and protolang:getCode() == otherlang:getCode()
			) and not protolang:inFamily(self) then
				return true
			end
		end
		-- If not, check the protolanguage's ancestry.
		return protolang:hasAncestor(...)
	end

	local function fetch_descendants(self, format)
		local languages = require("Module:languages/code to canonical name")
		local etymology_languages = require("Module:etymology languages/code to canonical name")
		local families = require("Module:families/code to canonical name")
		local descendants = {}
		local family = self:getFamily()
		-- Iterate over all three datasets.
		for _, data in ipairs{languages, etymology_languages, families} do
			for code in pairs(data) do
				local lang = require("Module:languages").getByCode(code, nil, true, true, useRequire)
				if lang:inFamily(self) then
					if format == "object" then
						table.insert(descendants, lang)
					elseif format == "code" then
						table.insert(descendants, code)
					elseif format == "name" then
						table.insert(descendants, lang:getCanonicalName())
					end
				end
			end
		end
		return descendants
	end

	function Family:getDescendants()
		if not self._descendantObjects then
			self._descendantObjects = fetch_descendants(self, "object")
		end
		return self._descendantObjects
	end

	function Family:getDescendantCodes()
		if not self._descendantCodes then
			self._descendantCodes = fetch_descendants(self, "code")
		end
		return self._descendantCodes
	end

	function Family:getDescendantNames()
		if not self._descendantNames then
			self._descendantNames = fetch_descendants(self, "name")
		end
		return self._descendantNames
	end

	function Family:hasDescendant(...)
		for _, lang in ipairs{...} do
			if type(lang) == "string" then
				lang = require("Module:languages").getByCode(lang, nil, true, nil, useRequire)
			end
			if lang:inFamily(self) then
				return true
			end
		end
		return false
	end

	--[==[
	Return the name of the main category of that family. Example: {"Germanic languages"} for the Germanic languages,
	whose category is at [[:Category:Germanic languages]].
	
	Unless optional argument `nocap` is given, the family name at the beginning of the returned value will be
	capitalized. This capitalization is correct for category names, but not if the family name is lowercase and
	the returned value of this function is used in the middle of a sentence. (For example, the pseudo-family with
	the code {qfa-mix} has the name {"mixed"}, which should remain lowercase when used as part of the category name
	[[:Category:Terms derived from mixed languages]] but should be capitalized in [[:Category:Mixed languages]].)
	If you are considering using {getCategoryName("nocap")}, use {getDisplayForm()} instead.
	]==]
	function Family:getCategoryName(nocap)
		local name = self._rawData[1]

		-- If the name already has "languages" in it, don't add it.
		if not name:find("[Ll]anguages$") then
			name = name .. " languages"
		end
		if not nocap then
			name = mw.getContentLanguage():ucfirst(name)
		end
		return name
	end

	function Family:makeCategoryLink()
		return "[[:Category:" .. self:getCategoryName() .. "|" .. self:getDisplayForm() .. "]]"
	end

	--[==[
	Return the Wikidata item of that family.
	]==]
	function Family:getWikidataItem()
		local item = self._rawData[2] or self._rawData.wikidata_item

		if not item then
			return nil
		end

		if type(item) ~= "number" then
			error("The method getWikidataItem expects the item to be stored as a number, but it is currently a " .. type(code) .. ".")
		end

		return "Q" .. item
	end

	--[==[
	Returns the Wikipedia article of that family, usually derived from {getWikidataItem()}.
	]==]
	function Family:getWikipediaArticle()
		return (self:getWikidataItem() and mw.wikibase and mw.wikibase.sitelink(self:getWikidataItem(), 'enwiki')) or
			self:getCategoryName()
	end

	function Family:makeWikipediaLink()
		return "[[w:" .. self:getWikipediaArticle() .. "|" .. self:getCanonicalName() .. "]]"
	end

	function Family:toJSON()
		if not self._type then
			self:hasType()
		end
		local types = {}
		for type in pairs(self._type) do
			table.insert(types, type)
		end

		local ret = {
			canonicalName = self:getCanonicalName(),
			categoryName = self:getCategoryName("nocap"),
			code = self:getCode(),
			family = self._rawData[3],
			protoLanguage = self._rawData.protoLanguage,
			otherNames = self:getOtherNames(true),
			aliases = self:getAliases(),
			varieties = self:getVarieties(),
			type = types,
			wikidataItem = self:getWikidataItem(),
		}

		return require("Module:JSON").toJSON(ret)
	end

	function Family:getRawData()
		return self._rawData
	end

	Family.__index = Family

	return data and setmetatable({ _rawData = data, _code = code }, Family) or nil
end

--[==[
Finds the family whose code matches the one provided. If it exists, it returns a {Family} object representing the
family. Otherwise, it returns {nil}.
]==]
function export.getByCode(code, useRequire)
	local function conditionalRequire(modulename)
		if useRequire then
			return require(modulename)
		else
			return mw.loadData(modulename)
		end
	end

	local data = conditionalRequire("Module:families/data")[code]
	if data then
		return export.makeObject(code, data, useRequire)
	end

	data = require("Module:families/track-bad-etym-code")(code) and conditionalRequire("Module:families/data/etymology")[code]
	if data then
		return require("Module:languages").makeObject(code, data, useRequire)
	end

	return nil
end

--[==[
Look for the family whose canonical name (the name used to represent that language on Wiktionary) matches the one
provided. If it exists, it returns a {Family} object representing the family. Otherwise, it returns {nil}. The
canonical name of families should always be unique (it is an error for two families on Wiktionary to share the same
canonical name), so this is guaranteed to give at most one result.
]==]
function export.getByCanonicalName(name, useRequire)
	local function conditionalRequire(modulename)
		if useRequire then
			return require(modulename)
		else
			return mw.loadData(modulename)
		end
	end

	local byName = conditionalRequire("Module:families/canonical names")
	local code = byName and byName[name] or
		byName[name:match("^(.*) languages$")]

	return export.getByCode(code, useRequire)
end

return export
