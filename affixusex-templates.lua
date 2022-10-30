local export = {}

local m_languages = require("Module:languages")

local rfind = mw.ustring.find
local rsubn = mw.ustring.gsub

-- helper functions

-- version of rsubn() that discards all but the first return value
local function rsub(term, foo, bar)
	local retval = rsubn(term, foo, bar)
	return retval
end

function export.affixusex_t(frame)
	local params = {
		[1] = {required = true, default="und"},
		[2] = {list = true, allow_holes = true},
		
		["t"] = {list = true, allow_holes = true, require_index = true},
		["gloss"] = {list = true, allow_holes = true, require_index = true, alias_of = "t"},
		["tr"] = {list = true, allow_holes = true, require_index = true},
		["ts"] = {list = true, allow_holes = true, require_index = true},
		["g"] = {list = true, allow_holes = true, require_index = true},
		["id"] = {list = true, allow_holes = true, require_index = true},
		["altaff"] = {},
		["alt"] = {list = true, allow_holes = true, require_index = true},
		["q"] = {list = true, allow_holes = true, require_index = true},
		["lit"] = {list = true, allow_holes = true, require_index = true},
		["pos"] = {list = true, allow_holes = true, require_index = true},
		["sc"] = {},
		["nointerp"] = {type = "boolean"},
		["lang"] = {list = true, allow_holes = true, require_index = true},
		-- Note, sc1=, sc2=, ... are different from sc=; the former apply to
		-- individual arguments when lang1=, lang2=, ... is specified, while
		-- the latter applies to all arguments where langN=... isn't specified
		["langsc"] = {list = "sc", allow_holes = true, require_index = true},
		["arrow"] = {list = true, allow_holes = true, require_index = true, type = "boolean"},
		["joiner"] = {list = true, allow_holes = true, require_index = true},
		["fulljoiner"] = {list = true, allow_holes = true, require_index = true},
		["accel"] = {list = true, allow_holes = true, require_index = true},
	}

	local aftype = frame.args["type"]
	if aftype == "" or not aftype then
		aftype = "affix"
	end

	if aftype == "prefix" then
		params["altpref"] = {alias_of = "altaff"}
	elseif aftype == "suffix" then
		params["altsuf"] = {alias_of = "altaff"}
	end

	local args = require("Module:parameters").process(frame:getParent().args, params)
	
	local lang = args[1]
	lang = m_languages.getByCode(lang) or m_languages.err(lang, 1)
	local sc = args["sc"]
	sc = (sc and (require("Module:scripts").getByCode(sc) or error("The script code \"" .. sc .. "\" is not valid.")) or nil)

	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(params) do
		if v.list and v.allow_holes and not v.alias_of and args[k].maxindex > maxmaxindex then
			maxmaxindex = args[k].maxindex
		end
	end

	-- Determine whether the terms in the numbered params contain a prefix or suffix.
	-- If not, we may insert one before the last term (for suffixes) or the first
	-- term (for prefixes).
	local affix_in_parts = false
	local SUBPAGE = mw.title.getCurrentTitle().subpageText
	local is_affix = {}
	for i=1,maxmaxindex do
		if args[2][i] then
			-- Careful here, a prefix beginning with ! should be treated as a
			-- normal term.
			if rfind(args[2][i], "^!") or lang:makeEntryName(args[2][i]) == SUBPAGE then
				affix_in_parts = true
				is_affix[i] = true
			end
		end
	end

	local insertable_aff = args["altaff"] or SUBPAGE
	-- Insert suffix derived from page title or altaff=/altsuf= before the last
	-- component if
	-- (a) nointerp= isn't present, and
	-- (b) no suffix is present among the parts (where "suffix" means a part that
	--     matches the subpage name after diacritics have been removed, or a part
	--     prefixed by !), and either
	--    (i) {{suffixusex}}/{{sufex}} was used;
	--    (ii) {{affixusex}}/{{afex}} was used and altaff= is given, and its value
	--         looks like a suffix (begins with -, doesn't end in -; an infix is
	--         not a suffix)
	--    (iii) {{affixusex}}/{{afex}} was used and altaff= is not given and the
	--          subpage title looks like a suffix (same conditions as for altaff=)
	local insert_suffix = not args["nointerp"] and not affix_in_parts and (aftype == "suffix" or (
		aftype == "affix" and rfind(insertable_aff, "^%-") and not rfind(insertable_aff, "%-$")))
	-- Insert prefix derived from page title or altaff=/altpref= before the first
	-- component using similar logic as preceding.
	local insert_prefix = not args["nointerp"] and not affix_in_parts and (aftype == "prefix" or (
		aftype == "affix" and rfind(insertable_aff, "%-$") and not rfind(insertable_aff, "^%-")))

	-- Build up the per-term objects.
	local parts = {}
	for i=1,maxmaxindex do
		-- If we're {{suffixusex}} and about to append the last term, or {{prefixusex}}
		-- and about to append the first term, and no affix appeared among the terms, and
		-- nointerp= isn't set, insert the affix (which comes either from altaff=/altpref=/altsuf=
		-- or from the subpage name).
		if i == maxmaxindex and insert_suffix or i == 1 and insert_prefix then
			local affix = args["altaff"]
			if not affix then
				if lang:getType() == "reconstructed" then
					affix = "*" .. SUBPAGE
				else
					affix = SUBPAGE
				end
			end
			table.insert(parts, {alt = affix})
		end

		local part = {}
		if is_affix[i] and not args["alt"][i] then
			part.alt = rsub(args[2][i], "^!", "")
		else
			part.term = args[2][i]
			part.alt = args["alt"][i]
		end

		local langn = args["lang"][i]
		if langn then
			langn =
				m_languages.getByCode(langn) or
				require("Module:etymology languages").getByCode(langn) or
				m_languages.err(langn, "lang" .. i)
		end

		local langsc = args["langsc"][i]
		if langsc then
			langsc = require("Module:scripts").getByCode(langsc) or error("The script code \"" .. langsc .. "\" is not valid.")
		end

		part.t = args["t"][i]
		part.tr = args["tr"][i]
		part.ts = args["ts"][i]
		part.g = args["g"][i]
		part.id = args["id"][i]
		part.q = args["q"][i]
		part.lit = args["lit"][i]
		part.pos = args["pos"][i]
		part.lang = langn
		part.sc = langsc
		part.arrow = args["arrow"][i]
		part.joiner = args["joiner"][i]
		part.fulljoiner = args["fulljoiner"][i]
		part.accel = args["accel"][i] and string.gsub(args["accel"], "_", "|"),  -- To allow use of | in templates
		table.insert(parts, part)
	end

	return require("Module:affixusex").format_affixusex(lang, sc, parts, aftype)
end

return export
