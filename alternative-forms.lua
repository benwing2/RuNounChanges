local export = {}

local labels_module = "Module:labels"
local links_module = "Module:links"
local parameter_utilities_module = "Module:parameter utilities"
local parameters_module = "Module:parameters"
local parse_utilities_module = "Module:parse utilities"
local pron_qualifier_module = "Module:pron qualifier"

local function track(page)
	require("Module:debug/track")("alter/" .. page)
end

local param_mods = {
	alt = {},
	t = {
		-- [[Module:links]] expects the gloss in "gloss".
		item_dest = "gloss",
	},
	gloss = {
		alias_of = "t",
	},
	tr = {},
	ts = {},
	g = {
		-- [[Module:links]] expects the genders in "genders".
		item_dest = "genders",
		sublist = true,
	},
	pos = {},
	lit = {},
	id = {},
	sc = {
		separate_no_index = true,
		type = "script",
	},
}

--[==[
Main function for displaying alternative forms. Extracted out from the template-callable function so this can be
called by other modules (in particular, [[Module:descendants tree]]). `show_labels_after_terms` no longer has any
meaning. `allow_self_link` causes terms the same as the pagename to be shown normally; otherwise they are displayed
unlinked.
]==]
function export.display_alternative_forms(parent_args, pagename, show_labels_after_terms, allow_self_link)
	local params = {
		[1] = {required = true, type = "language", etym_lang = true, default = "en"},
		[2] = {list = true, allow_holes = true},
	}

	local m_param_utils = require(parameter_utilities_module)
	m_param_utils.augment_param_mods_with_pron_qualifiers(param_mods, {
		{param = "q", separate_no_index = false},
		{param = "l", separate_no_index = false, require_index = true},
		"ref",
	})
	m_param_utils.augment_params_with_modifiers(params, param_mods)

	local args = require("Module:parameters").process(parent_args, params)

	local lang = args[1]

	local items = m_param_utils.process_list_arguments {
		args = args,
		param_mods = param_mods,
		termarg = 2,
		parse_lang_prefix = true,
		track_module = "alter",
		lang = lang,
		sc = args.sc.default,
		stop_when = function(data)
			return not data.any_param_at_index
		end,
	}

	if not items[1] then
		error("No items found!")
	end

	local raw_labels = {}

	-- Extract the labels and make sure none are blank or omitted.
	local last_item_index = items[#items].orig_index
	if last_item_index < args[2].maxindex then
		for i = last_item_index + 2, args[2].maxindex do
			if not args[2][i] then
				-- Indices in i start at 1 but parameters start at 2 to add 1 to shown index.
				error("Missing/blank item not allowed in [[Template:alt]] labels, but saw such an item in parameter "
					.. (i + 1))
			end
			table.insert(raw_labels, args[2][i])
		end
	end

	-- Make sure there aren't property parameters after the last item (i.e. corresponding to labels).
	for k, v in pairs(args) do
		-- Look for named list parameters. We check:
		-- (1) key is a string (excludes the term param, which is a number);
		-- (2) value is a table, i.e. a list;
		-- (3) v.maxindex is set (i.e. allow_holes was used);
		-- (4) v.maxindex is past the index of the last term.
		if type(k) == "string" and type(v) == "table" and v.maxindex and v.maxindex > last_item_index then
			local set_values = {}
			for i = last_item_index + 1, v.maxindex do
				if v[i] then
					table.insert(set_values, i)
				end
			end
			error(("Extraneous values for %s= (set at position%s %s)"):format(k, #set_values > 1 and "s" or "",
				table.concat(set_values, ",")))
		end
	end

	if not allow_self_link then
		-- If the to-be-linked term is the same as the pagename, display it unlinked.
		for _, item in ipairs(items) do
			if not item.term and (lang:makeEntryName(item.term)) == pagename then
				track("term is pagename")
				item.alt = item.alt or item.term
				item.term = nil
			end
		end
	end

	local labels
	if #raw_labels > 0 then
		labels = require(labels_module).process_raw_labels { labels = raw_labels, lang = lang, nocat = true }
	end

	local parts = {}
	local function ins(part)
		table.insert(parts, part)
	end

	-- Construct the final output.

	-- First the items, including separators, left and right regular qualifiers and left and right per-item labels.
	for _, item in ipairs(items) do
		ins(item.separator)
		local text = require(links_module).full_link(item, nil, allow_self_link)
		if item.q and item.q[1] or item.qq and item.qq[1] or item.l and item.l[1] or item.ll and item.ll[1]
			or item.refs and item.refs[1] then
			text = require(pron_qualifier_module).format_qualifiers {
				lang = item.lang,
				text = text,
				q = item.q,
				qq = item.qq,
				l = item.l,
				ll = item.ll,
				refs = item.refs,
			}
		end
		ins(text)
	end

	-- If there are labels, construct them now and append to final output.
	if labels then
		if lang:hasTranslit() then
			ins(" &mdash; " .. require(labels_module).format_processed_labels {
				labels = labels, lang = lang
			})
		else
			ins(" " .. require(labels_module).format_processed_labels {
				labels = labels, lang = lang, open = "(", close = ")"
			})
		end
	end

	return table.concat(parts)
end

--[==[
Template-callable function for displaying alternative forms.
]==]
function export.create(frame)
	local parent_args = frame:getParent().args
	local title = mw.title.getCurrentTitle()
	local PAGENAME = title.text
	return export.display_alternative_forms(parent_args, title)
end

return export
