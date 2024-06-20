local export = {}

local labels_module = "Module:labels"
local links_module = "Module:links"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local pron_qualifier_module = "Module:pron qualifier"


local function wrap_span(text, lang, sc)
	return '<span class="' .. sc .. '" lang="' .. lang .. '">' .. text .. '</span>'
end


function export.nyms(frame)
	local parent_args = frame:getParent().args

	-- FIXME: Temporary error message.
	for arg, _ in pairs(parent_args) do
		if type(arg) == "string" and arg:find("^tag[0-9]*$") then
			local larg = arg:gsub("^tag", "l")
			local llarg = arg:gsub("^tag", "ll")
			error(("Use %s= (on the left) or %s= (on the right) instead of %s="):format(larg, llarg, arg))
		end
	end

	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "und"},
		[2] = {list = true, allow_holes = true, required = true},
	}

    local m_param_utils = require(parameter_utilities_module)

	local param_mods = m_param_utils.construct_param_mods {
		{set = {"link", "ref", "l"}},
		-- For compatibility, we don't distinguish q= from q1= and qq= from q1=. FIXME: Maybe we should change this.
		{set = "q", separate_no_index = false},
		{param = "lb", alias_of = "ll"},
	}
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require(parameters_module).process(parent_args, params)

	local nym_type = frame.args[1]
	local nym_type_class = string.gsub(nym_type, "%s", "-")
	local lang = args[1]
	local langcode = lang:getCode()

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "nyms",
		lang = lang,
	}

	local data = {
		lang = lang,
		items = items,
		sc = args.sc.default,
	}
	require(pron_qualifier_module).parse_qualifiers {
		store_obj = data,
		l = args.l.default,
		ll = args.ll.default,
		q = args.q.default,
		qq = args.qq.default,
	}

	local parts = {}
	local overall_sep = data.separator or ", "
	local thesaurus_parts = {}
	for i, item in ipairs(data.items) do
		local explicit_item_lang = item.lang
		item.lang = item.lang or data.lang
		item.sc = item.sc or data.sc
		local text
		local is_thesaurus
		if item.term and item.term:find("^Thesaurus:") then
			is_thesaurus = true
			for k, _ in pairs(item) do
				if m_param_utils.item_key_is_property(k) and k ~= "lang" and k ~= "sc" and k ~= "q" and k ~= "qq" and
					k ~= "l" and k ~= "ll" and k ~= "refs" then
					error(("You cannot use most named parameters and inline modifiers with Thesaurus links, but saw %s%s= or its equivalent inline modifier <%s:...>"):format(
						k, item.itemno, k))
				end
			end
			local term = item.term:match("^Thesaurus:(.*)$")
			-- Chop off fragment
			term = term:match("^(.-)#.*$") or term
			local lang = item.lang
			local sccode = (item.sc or lang:findBestScript(term)):getCode()
			-- FIXME: I assume it's better to include full-language codes in the CSS rather than etym-language codes,
			-- which are generally specific to Wiktionary. However, we should probably instead be using the functions
			-- from [[Module:script utilities]] in preference to rolling our own.
			text = "[[" .. item.term .. "#" .. lang:getFullName() .. "|Thesaurus:" .. wrap_span(term, lang:getFullCode(), sccode) .. "]]"
		else
			if thesaurus_parts[1] then
				error("Links to the Thesaurus must follow all non-Thesaurus links")
			end
			text = require(links_module).full_link(item)
		end
		local qq = item.qq
		-- If a separate language code was given for the term, display the language name as a right qualifier.
		-- Otherwise it may not be obvious that the term is in a separate language (e.g. if the main language is 'zh'
		-- and the term language is a Chinese lect such as Min Nan). But don't do this for Translingual terms, which
		-- are often added to the list of English and other-language terms.
		if explicit_item_lang then
			local explicit_code = explicit_item_lang:getCode()
			if explicit_code ~= langcode and explicit_code ~= "mul" then
				qq = mw.clone(qq) or {}
				table.insert(qq, 1, explicit_item_lang:getCanonicalName())
			end
		end
		if item.q and item.q[1] or qq and qq[1] or item.l and item.l[1] or item.ll and item.ll[1] or
			item.refs and item.refs[1] then
			text = require(pron_qualifier_module).format_qualifiers {
				lang = item.lang,
				text = text,
				q = item.q,
				qq = qq,
				l = item.l,
				ll = item.ll,
				refs = item.refs,
			}
		end
		local insert_place = is_thesaurus and thesaurus_parts or parts
		-- Don't include the separator if this is the first item we're inserting.
		table.insert(insert_place, insert_place[1] and overall_sep or "")
		table.insert(insert_place, text)
	end

	local text = table.concat(parts)
	local thesaurus_text = table.concat(thesaurus_parts)

	local caption = "<span class=\"defdate\">" .. mw.getContentLanguage():ucfirst(nym_type) ..
		((#items > 1 or thesaurus_text ~= "") and "s" or "") .. ":</span> "
	text = caption .. text
	local function qualifier_error_if_no_terms()
		if not parts[1] then
			error("Cannot specify overall qualifiers if no non-Thesaurus terms given")
		end
	end
	if data.q and data.q[1] or data.qq and data.qq[1] or data.l and data.l[1] then
		qualifier_error_if_no_terms()
		text = require(pron_qualifier_module).format_qualifiers {
			lang = data.lang,
			text = text,
			q = data.q,
			qq = data.qq,
			l = data.l,
			-- ll handled specially for compatibility's sake
		}
	end
	if data.ll and data.ll[1] then
		qualifier_error_if_no_terms()
		text = text .. " &mdash; " .. require(labels_module).show_labels {
			lang = data.lang,
			labels = data.ll,
			nocat = true,
			open = false,
			close = false,
			no_track_already_seen = true,
		}
	end
	if thesaurus_text ~= "" then
		local thesaurus_intro = parts[1] and "; ''see also'' " or "''see'' "
		text = text .. thesaurus_intro .. thesaurus_text
	end
	return "<span class=\"nyms " .. nym_type_class .. "\">" .. text .. "</span>"
end


return export
