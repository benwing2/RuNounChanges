local export = {}

-- Ported from [[w:Module:Demo]] by Benwing2 on Sep 1st 2023 around 6am UTC.

-- creates a frame object that cannot access any of the parent's args
-- unless a table containing a list keys of not to inherit is provided
--
-- FIXME: This appears to do something like argument processing using [[Module:parameters]], and should be replaced
-- with a call to that module.
local function disinherit(frame, onlyTheseKeys)
	local parent = frame:getParent() or frame
	local orphan = parent:newChild{}
	orphan.getParent = parent.getParent --returns nil
	orphan.args = {}
	if onlyTheseKeys then
		local family = {parent, frame}
		for f = 1, 2 do
			for k, v in pairs(family[f] and family[f].args or {}) do
				orphan.args[k] = orphan.args[k] or v
			end
		end
		parent.args = mw.clone(orphan.args)
		setmetatable(orphan.args, nil)
		for _, k in ipairs(onlyTheseKeys) do
			rawset(orphan.args, k, nil)
		end
	end
	return orphan, parent
end

local function getSeparator(args, default)
	local br = tonumber(args.br) and ('<br>'):rep(args.br) or args.br
	local sep = args.sep or br or default
	return #sep > 0 and ' ' .. sep .. ' ' or sep
end

function export.get(frame, source_param)
	local params = {
		[source_param or 1] = {},
		["br"] = {},
		["sep"] = {},
		["reverse"] = {type = "boolean"},
		["nocat"] = {type = "boolean"},
		["result_arg"] = {}, -- FIXME: some sort of weird debugging arg
		["style"] = {},
	}
	local parent_args = frame:getParent().args
	local args = require("Module:parameters").process(parent_args, params, nil, "demo", "get")

	local code = args[source_param or 1]
	if code:match('UNIQ%-%-nowiki') then
		code = mw.text.unstripNoWiki(code)
			:gsub('&lt;', '<')
			:gsub('&gt;', '>')
			:gsub('&quot;', '"')
			-- Replace `&#125;%-` with `}-` because of some server quirk leading to
			-- =mw.text.unstripNoWiki(mw.getCurrentFrame():preprocess('<nowiki>}-</nowiki>'))
			-- outputting `&#125;-` instead of `}-`, while it's ok with `<nowiki>} -</nowiki>`
			:gsub('&#125;%-', '}-')
			-- The same with `-&#123;`
			:gsub('%-&#123;', '-{')
	end
	return {
		source = code,
		output = frame:preprocess(code):gsub(args.nocat and '%[%[Category.-%]%]' or '', ''),
		args = args,
	}
end

function export.main(frame, demoTable)
	local show = demoTable or export.get(frame)
	local args = show.args
	if show[args.result_arg] then
		return show[args.result_arg]
	end
	args.sep = getSeparator(args, '')
	local source = frame:extensionTag{
		name = 'syntaxhighlight',
		args = {
			lang = 'wikitext',
			style = args.style
		},
		content = show.source
	}
	return args.reverse and
		show.output .. args.sep .. source or
		source .. args.sep .. show.output
end

-- Alternate function to return an inline result
function export.inline(frame, demoTable)
	local show = demoTable or export.get(frame)
	local args = show.args
	if show[args.result_arg] then
		return show[args.result_arg]
	end
	local yesno = require('Module:yesno')
	args.sep = getSeparator(args, args.reverse and '←' or '→')
	local source =  frame:extensionTag{
		name = 'syntaxhighlight',
		args = {
			lang = 'wikitext',
			inline = true,
			style = args.style
		},
		content = show.source
	}
	return args.reverse and
		show.output .. args.sep .. source or
		source .. args.sep .. show.output
end

--passing of args into other module without preprocessing
function export.module(frame)
	local orphan, frame = disinherit(frame, {
		'demo_template',
		'demo_module',
		'demo_module_func',
		'demo_main',
		'demo_sep',
		'demo_br',
		'demo_result_arg',
		'nocat'
	})
	local template = frame.args.demo_template and 'Template:'..frame.args.demo_template
	local demoFunc = frame.args.demo_module_func or 'main\n'
	local demoModule = require('Module:' .. frame.args.demo_module)[demoFunc:match('^%s*(.-)%s*$')]
	frame.args.br, frame.args.result_arg = frame.args.demo_sep or frame.args.demo_br, frame.args.demo_result_arg
	local kill_categories = frame.args.nocat
	if demoModule then
		local named = {insert = function(self, ...) table.insert(self, ...) return self end}
		local source = {insert = named.insert, '{{', frame.args.demo_template or frame.args.demo_module, '\n'}
		if not template then
			source:insert(2, '#invoke:'):insert(4, '|'):insert(5, demoFunc)
		end
		local insertNamed = #source + 1
		for k, v in pairs(orphan.args) do
			local nan, insert = type(k) ~= 'number', {v}
			local target = nan and named or source
			target:insert'|'
			if nan then
				target:insert(k):insert'=':insert'\n'
				table.insert(insert, 1, #target)
			end
			target:insert(unpack(insert))
			local nowiki = v:match('nowiki')
			if nowiki or v:match('{{.-}}') then
				orphan.args[k] = frame:preprocess(nowiki and mw.text.unstripNoWiki(v) or v)
			end
		end
		source:insert'}}'
		table.insert(source, insertNamed, table.concat(named))
		return export.main(orphan, {
			source = table.concat(source), "<>'|=~",
			output = tostring(demoModule(orphan)):gsub(kill_categories and '%[%[Category.-%]%]' or '', ''),
			frame = frame
		})
	else
		return "ERROR: Invalid module function: "..demoFunc
	end
end

return export
