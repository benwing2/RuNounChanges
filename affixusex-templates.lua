local require = require

local m_languages = require("Module:languages")

local concat = table.concat
local find = string.find
local gsub = string.gsub
local insert = table.insert
local match = string.match
local shallowcopy = require("Module:table").shallowcopy
local sort = table.sort
local sub = string.sub

local export = {}

-- Per-param modifiers, which can be specified either as separate parameters (e.g. t2=, pos3=) or as inline modifiers
-- <t:...>, <pos:...>, etc. The key is the name fo the parameter (e.g. "t", "pos") and the value is a table with
-- elements as follows:
-- * `extra_specs`: An optional table of extra key-value pairs to add to the spec used for parsing the parameter
--                  when specified as a separate parameter (e.g. {type = "boolean"} for a Boolean parameter, or
--                  {alias_of = "t"} for the "gloss" parameter, which is aliased to "t"), on top of the default, which
--                  is {list = true, allow_holes = true, require_index = true}.
-- * `convert`: An optional function to convert the raw argument into the form passed to [[Module:affixusex]].
--              This function takes three parameters: (1) `arg` (the raw argument); (2) `inline` (true if we're
--              processing an inline modifier, false otherwise); (3) `i` (the logical index of the term being
--              processed, starting from 1).
-- * `item_dest`: The name of the key used when storing the parameter's value into the processed `parts` list.
--                Normally the same as the parameter's name. Different in the case of "gloss", which is an alias for
--                "t".
local param_mods = {
	t = {},
	gloss = {
		-- "gloss" is an alias of "t". The `extra_specs` handles this automatically for separate parameters, and the
		-- `item_dest` handles this for inline modifiers.
		item_dest = "t",
		extra_specs = {alias_of = "t"},
	},
	tr = {},
	ts = {},
	g = {},
	id = {},
	alt = {},
	q = {},
	qq = {},
	lit = {},
	pos = {},
	lang = {
		extra_specs = {type = "language", etym_lang = true},
		convert = function(arg, inline, i)
			-- i + 1 because we want to reference the actual term param name, which is 2= for the first term, 3= for the second, etc.
			return inline and m_languages.getByCode(arg, (i + 1) .. ":lang", "allow etym") or arg
		end,
	},
	sc = {
		-- sc1=, sc2=, ... are different from sc=; the former apply to individual arguments when lang1=, lang2=, ...
		-- is specified, while the latter applies to all arguments where langN=... isn't specified.
		extra_specs = {type = "script", separate_no_index = true, require_index = false},
		convert = function(arg, inline, i)
			-- i + 1 same as above for "lang".
			return inline and require("Module:scripts").getByCode(arg, (i + 1) .. ":sc") or arg
		end,
	},
	arrow = {
		-- This is a Boolean param. The `extra_specs` below automatically handles this for separate parameters, but
		-- we need to handle it ourselves as an inline modifier.
		extra_specs = {type = "boolean"},
		convert = function(arg, inline, i)
			if inline then
				return require("Module:yesno")(arg, true)
			else
				return arg
			end
		end,
	},
	joiner = {},
	fulljoiner = {},
	accel = {
		convert = function(arg, inline, i)
			return gsub(arg, "_", "|") -- To allow use of | in templates
		end,
	},
}

local default_param_spec = {list = true, allow_holes = true, require_index = true}

local function get_valid_prefixes()
	local valid_prefixes = {}
	for param_mod, _ in pairs(param_mods) do
		insert(valid_prefixes, param_mod)
	end
	sort(valid_prefixes)
	return valid_prefixes
end

function export.affixusex_t(frame)
	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		[2] = {list = true, allow_holes = true},
		
		["altaff"] = {},
		["nointerp"] = {type = "boolean"},
		["pagename"] = {},
	}
	
	for param_mod, param_mod_spec in pairs(param_mods) do
		if not param_mod_spec.extra_specs then
			params[param_mod] = default_param_spec
		else
			local param_spec = shallowcopy(default_param_spec)
			for k, v in pairs(param_mod_spec.extra_specs) do
				param_spec[k] = v
			end
			params[param_mod] = param_spec
		end
	end

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
	local sc = args.sc.default
	
	-- Find the maximum index among any of the list parameters.
	local maxmaxindex = 0
	for k, v in pairs(params) do
		if v.list and v.allow_holes and not v.alias_of and args[k].maxindex > maxmaxindex then
			maxmaxindex = args[k].maxindex
		end
	end

	local put

	-- Build up the per-term objects.
	local parts = {}
	for i=1, maxmaxindex do
		local part = {}
		local term = args[2][i]

		-- Parse all the term-specific modifiers and store in `part`.
		for param_mod, param_mod_spec in pairs(param_mods) do
			local dest = param_mod_spec.item_dest or param_mod
			local arg = args[param_mod] and args[param_mod][i]
			if arg then
				if param_mod_spec.convert then
					arg = param_mod_spec.convert(arg, false, i)
				end
				part[dest] = arg
			end
		end

		-- Remove and remember an initial exclamation point from the term, and parse off an initial language code (e.g.
		-- 'la:minūtia' or 'grc:[[σκῶρ|σκατός]]').
		if term then
			if sub(term, 1, 1) == "!" then
				part.begins_with_exclamation_point = true
				term = gsub(term, "^!", "")
			end
			local termlang, actual_term = match(term, "^([%w._-]+):(.*)$")
			if termlang and termlang ~= "w" then -- special handling for w:... links to Wikipedia
				-- i + 1 because terms begin at 2=.
				termlang = m_languages.getByCode(termlang, i + 1, "allow etym")
				term = actual_term
			else
				termlang = nil
			end
			if part.lang and termlang then
				error(("Both lang%s= and a language in %s= given; specify one or the other"):format(i, i + 1))
			end
			part.lang = part.lang or termlang
			part.term = term
		end

		-- Check for inline modifier, e.g. מרים<tr:Miryem>. But exclude HTML entry with <span ...>, <i ...>, <br/> or
		-- similar in it, caused by wrapping an argument in {{l|...}}, {{af|...}} or similar. Basically, all tags of
		-- the sort we parse here should consist of a less-than sign, plus letters, plus a colon, e.g. <tr:...>, so if
		-- we see a tag on the outer level that isn't in this format, we don't try to parse it. The restriction to the
		-- outer level is to allow generated HTML inside of e.g. qualifier tags, such as foo<q:similar to {{m|fr|bar}}>.
		if term and find(term, "<", 1, true) and not match(term, "^[^<]*<%l*[^%l:]") then
			if not put then
				put = require("Module:parse utilities")
			end
			local run = put.parse_balanced_segment_run(term, "<", ">")
			local function parse_err(msg)
				error(msg .. ": " .. (i + 1) .. "=" .. concat(run))
			end
			part.term = run[1]

			for j = 2, #run - 1, 2 do
				if run[j + 1] ~= "" then
					parse_err("Extraneous text '" .. run[j + 1] .. "' after modifier")
				end
				local modtext = match(run[j], "^<(.*)>$")
				if not modtext then
					parse_err("Internal error: Modifier '" .. modtext .. "' isn't surrounded by angle brackets")
				end
				local prefix, arg = match(modtext, "^(%l+):(.*)$")
				if not prefix then
					parse_err(("Modifier %s lacks a prefix, should begin with one of %s followed by a colon"):format(
						run[j], concat(get_valid_prefixes(), ",")))
				end
				if not param_mods[prefix] then
					parse_err(("Unrecognized prefix '%s' in modifier %s, should be one of %s"):format(
						prefix, run[j], concat(get_valid_prefixes(), ",")))
				end
				local dest = param_mods[prefix].item_dest or prefix
				if part[dest] then
					parse_err("Modifier '" .. prefix .. "' occurs twice, second occurrence " .. run[j])
				end
				if param_mods[prefix].convert then
					arg = param_mods[prefix].convert(arg, true, i)
				end
				part[dest] = arg
			end
		end

		insert(parts, part)
	end

	-- Determine whether the terms in the numbered params contain a prefix or suffix. If not, we may insert one before
	-- the last term (for suffixes) or the first term (for prefixes).
	local affix_in_parts = false
	local SUBPAGE = args.pagename or mw.title.getCurrentTitle().subpageText
	for i=1, maxmaxindex do
		if parts[i].term then
			-- Careful here, a prefix beginning with ! should be treated as a normal term.
			if parts[i].begins_with_exclamation_point or (lang:makeEntryName(parts[i].term)) == SUBPAGE then
				affix_in_parts = true
				if not parts[i].alt then
					parts[i].alt = parts[i].term
					parts[i].term = nil
				end
			end
		end
	end

	-- Determine affix to check for prefixness/suffixness.
	local insertable_aff = args["altaff"] or SUBPAGE

	-- Determine affix to interpolate if needed.
	local affix = args["altaff"]
	if not affix then
		if lang:hasType("reconstructed") then
			affix = "*" .. SUBPAGE
		else
			affix = SUBPAGE
		end
	end

	-- Insert suffix derived from page title or altaff=/altsuf= before the last component if
	-- (a) nointerp= isn't present, and
	-- (b) no suffix is present among the parts (where "suffix" means a part that matches the subpage name after
	--     diacritics have been removed, or a part prefixed by !), and either
	--    (i) {{suffixusex}}/{{sufex}} was used;
	--    (ii) {{affixusex}}/{{afex}} was used and altaff= is given, and its value looks like a suffix (begins with -,
	--         doesn't end in -; an infix is not a suffix)
	--    (iii) {{affixusex}}/{{afex}} was used and altaff= is not given and the subpage title looks like a suffix
	--          (same conditions as for altaff=)
	-- Insert prefix derived from page title or altaff=/altpref= before the first component using similar logic as
	-- preceding.
	if not args["nointerp"] and not affix_in_parts then
		if aftype == "prefix" or (
			aftype == "affix" and
			sub(insertable_aff, -1) == "-" and
			sub(insertable_aff, 1, 1) ~= "-"
		) then
			insert(parts, 1, {alt = affix})
		elseif aftype == "suffix" or (
			aftype == "affix" and
			sub(insertable_aff, 1, 1) == "-" and
			sub(insertable_aff, -1) ~= "-"
		) then
			insert(parts, maxmaxindex, {alt = affix})
		end
	end

	return require("Module:affixusex").format_affixusex(lang, sc, parts, aftype)
end

return export
