local export = {}

local require_when_needed = require("Module:utilities/require when needed")

local concat = table.concat
local format_categories = require_when_needed("Module:utilities", "format_categories")
local insert = table.insert
local process_params = require_when_needed("Module:parameters", "process")
local trim = mw.text.trim
local lower = mw.ustring.lower

local etymology_module = "Module:etymology"
local etymology_specialized_module = "Module:etymology/specialized"
local m_internal = require("Module:etymology/templates/internal")

-- For testing
local force_cat = false

function export.etyl(frame)
	local params = {
		[1] = {required = true, type = "language", default = "und"},
		[2] = {type = "language", default = "en"},
		["sort"] = {},
	}
	-- Empty language means English, but "-" means no language. Yes, confusing...
	local args = frame:getParent().args
	if args[2] and trim(args[2]) == "-" then
		params[2] = nil
		args = process_params({
			[1] = args[1],
			["sort"] = args["sort"]
		}, params)
	else
		args = process_params(args, params)
	end
	return require(etymology_module).format_source {
		lang = args[2],
		source = args[1],
		sort_key = args["sort"]
	}
end


-- Supports various specialized types of borrowings, according to `frame.args.bortype`:
--   "learned" = {{lbor}}/{{learned borrowing}}
--   "semi-learned" = {{slbor}}/{{semi-learned borrowing}}
--   "orthographic" = {{obor}}/{{orthographic borrowing}}
--   "unadapted" = {{ubor}}/{{unadapted borrowing}}
--   "calque" = {{cal}}/{{calque}}
--   "partial-calque" = {{pcal}}/{{partial calque}}
--   "semantic-loan" = {{sl}}/{{semantic loan}}
--   "transliteration" = {{translit}}/{{transliteration}}
--   "phono-semantic-matching" = {{psm}}/{{phono-semantic matching}}
function export.specialized_borrowing(frame)
	local bortype = frame.args.bortype
	local args = frame:getParent().args
	if args.gloss then
		require("Module:debug").track("borrowing/" .. bortype .. "/gloss param")
	end

	-- More informative error message for {{calque}}, which used to support other params.
	if bortype == "calque" and (args["etyl lang"] or args["etyl term"] or args["etyl t"] or args["etyl tr"]) then
		error("{{[[Template:calque|calque]]}} no longer supports parameters beginning with etyl. " ..
			"The parameters supported are similar to those used by " ..
			"{{[[Template:der|der]]}}, {{[[Template:inh|inh]]}}, " ..
			"{{[[Template:bor|bor]]}}. See [[Template:calque/documentation]] for more.")
	end
	
	local lang, term, sources
	args, lang, term, sources = m_internal.parse_2_lang_args(frame, "has text")
	local m_etymology_specialized = require(etymology_specialized_module)
	if sources then
		return m_etymology_specialized.specialized_multi_borrowing {
			bortype = bortype,
			lang = lang,
			sc = term.sc,
			sources = sources,
			terminfo = term,
			sort_key = args.sort,
			nocap = args.nocap,
			notext = args.notext,
			nocat = args.nocat,
			conj = args.conj,
			senseid = args.senseid,
		}
	else
		return m_etymology_specialized.specialized_borrowing {
			bortype = bortype,
			lang = lang,
			terminfo = term,
			sort_key = args.sort,
			nocap = args.nocap,
			notext = args.notext,
			nocat = args.nocat,
			senseid = args.senseid,
		}
	end
end


-- Implementation of miscellaneous templates such as {{back-formation}}, {{clipping}},
-- {{ellipsis}}, {{rebracketing}}, and {{reduplication}} that have a single
-- associated term.
do
	local function get_args(frame)
		local alias_of_t = {alias_of = "t"}
		local boolean = {type = "boolean"}
		local plain = {}
		local params = {
			[1] = {required = true, type = "language", default = "und"},
			[2] = plain,
			[3] = {alias_of = "alt"},
			[4] = alias_of_t,
			
			["alt"] = plain,
			["gloss"] = alias_of_t,
			["g"] = {list = true},
			["id"] = plain,
			["lit"] = plain,
			["pos"] = plain,
			["t"] = plain,
			["tr"] = plain,
			["ts"] = plain,
			["sc"] = {type = "script"},
			
			["nocap"] = boolean, -- should be processed in the template itself
			["notext"] = boolean,
			["nocat"] = boolean,
			["sort"] = plain,
		}
		-- |ignore-params= parameter to module invocation specifies
		-- additional parameter names to allow  in template invocation, separated by
		-- commas. They must consist of ASCII letters or numbers or hyphens.
		local ignore_params = frame.args["ignore-params"]
		if ignore_params then
			ignore_params = trim(ignore_params)
			if not ignore_params:match("^[%w%-,]+$") then
				error("Invalid characters in |ignore-params=: " .. ignore_params:gsub("[%w%-,]+", ""))
			end
			for param in ignore_params:gmatch("[%w%-]+") do
				if params[param] then
					error("Duplicate param |" .. param
						.. " in |ignore-params=: already specified in params")
				end
				params[param] = plain
			end
		end
		return process_params(frame:getParent().args, params)
	end
	
	function export.misc_variant(frame)		
		local args = get_args(frame)
		local lang = args[1]
		local sc = args["sc"]

		local parts = {}
		if not args["notext"] then
			insert(parts, frame.args["text"])
		end
		if args[2] or args["alt"] then
			if not args["notext"] then
				insert(parts, " ")
				insert(parts, frame.args["oftext"] or "of")
				insert(parts, " ")
			end
			insert(parts, require("Module:links").full_link(
				{
					lang = lang,
					sc = sc,
					term = args[2],
					alt = args["alt"],
					id = args["id"],
					tr = args["tr"],
					ts = args["ts"],
					genders = args["g"],
					gloss = args["t"],
					pos = args["pos"],
					lit = args["lit"],
				},
				"term"))
		end
		-- Allow |cat=, |cat2=, |cat3=, etc. They must be sequential. If |cat=
		-- is not defined, |cat2= will not be checked. Empty categories are ignored.
		local categories = {}
		if not args["nocat"] and frame.args["cat"] then
			local cat_number
			while true do
				local cat = frame.args["cat" .. (cat_number or "")]
				if not cat then break end
				cat = trim(cat)
				if cat ~= "" then
					insert(categories, lang:getFullName() .. " " .. cat)
				end
				cat_number = (cat_number or 1) + 1
			end
		end
		if #categories > 0 then
			insert(
				parts,
				format_categories(categories, lang, args["sort"], nil, force_cat))
		end

		return concat(parts)
	end
end


-- Implementation of miscellaneous templates such as {{unknown}} that have no
-- associated terms.
do
	local function get_args(frame)
		local boolean = {type = "boolean"}
		local plain = {}
		local params = {
			[1] = {required = true, type = "language", default = "und"},

			["title"] = plain,
			["nocap"] = boolean, -- should be processed in the template itself
			["notext"] = boolean,
			["nocat"] = boolean,
			["sort"] = plain,
		}
		if frame.args["title2_alias"] then
			params[2] = {alias_of = "title"}
		end
		return process_params(frame:getParent().args, params)
	end

	function export.misc_variant_no_term(frame)
		local args = get_args(frame)
		local lang = args[1]
		
		local parts = {}
		if not args["notext"] then
			insert(parts, args["title"] or frame.args["text"])
		end
		if not args["nocat"] and frame.args["cat"] then
			local categories = {}
			insert(categories, lang:getFullName() .. " " .. frame.args["cat"])
			insert(parts, format_categories(categories, lang, args["sort"], nil, force_cat))
		end

		return concat(parts)
	end

	--This function works similarly to misc_variant_no_term(), but with some automatic linking to the glossary in `title`.
	function export.onomatopoeia(frame)
		local args = get_args(frame)

		if args["title"] and (lower(args["title"]) == "imitative" or lower(args["title"]) == "imitation") then
			args["title"] = "[[Appendix:Glossary#imitative|" .. args["title"] .. "]]"
		end

		local lang = args[1]
		
		local parts = {}
		if not args["notext"] then
			insert(parts, args["title"] or frame.args["text"])
		end
		if not args["nocat"] and frame.args["cat"] then
			local categories = {}
			insert(categories, lang:getFullName() .. " " .. frame.args["cat"])
			insert(parts, format_categories(categories, lang, args["sort"], nil, force_cat))
		end

		return concat(parts)
	end
end

return export
