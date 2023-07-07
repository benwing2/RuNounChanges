--[=[
	This module contains functions to implement {{form of/*doc}} templates.
	The module contains the wrappers meant to be called directly from templates.
	The actual implementations are in [[Module:form of doc]].

	Author: Benwing2
]=]

local export = {}

local m_parameters = require("Module:parameters")
local m_form_of_doc = require("Module:form of doc")

local function create_introdoc_params()
	return {
		["lang"] = {},
		["exlang"] = {list = true},
		["pldesc"] = {},
		["primaryentrytext"] = {},
		["cat"] = {list = true},
		["addlintrotext"] = {},
		["etymtemp"] = {},
		["withdot"] = {type = "boolean"},
		["withcap"] = {type = "boolean"},
	}
end

function export.introdoc_t(frame)
	local params = create_introdoc_params()
	local args = m_parameters.process(frame:getParent().args, params)
	return m_form_of_doc.introdoc(args)
end

local function create_paramdoc_params()
	return {
		["lang"] = {},
		["sgdescof"] = {},
		["art"] = {},
		["withfrom"] = {type = "boolean"},
		["withdot"] = {type = "boolean"},
		["withcap"] = {type = "boolean"},
	}
end

function export.paramdoc_t(frame)
	local params = create_paramdoc_params()
	local args = m_parameters.process(frame:getParent().args, params)
	return m_form_of_doc.paramdoc(args)
end

local function create_usagedoc_params()
	local params = create_paramdoc_params()
	params["exlang"] = {list = true}
	return params
end

function export.usagedoc_t(frame)
	local params = create_usagedoc_params()
	local args = m_parameters.process(frame:getParent().args, params)
	return m_form_of_doc.usagedoc(args)
end

local function create_fulldoc_params()
	local params = create_introdoc_params()
	local usageparams = create_usagedoc_params()
	for k, v in pairs(usageparams) do
		params[k] = v
	end
	params["shortcut"] = {list = true}
	return params
end

function export.fulldoc_t(frame)
	local params = create_fulldoc_params()
	local args = m_parameters.process(frame:getParent().args, params)
	return m_form_of_doc.fulldoc(args)
end

local function create_infldoc_params()
	local params = create_fulldoc_params()
	params["pldesc"] = nil
	params["sgdesc"] = {}
	params["form"] = {}
	return params
end

function export.infldoc_t(frame)
	local params = create_infldoc_params()
	local args = m_parameters.process(frame:getParent().args, params)
	return m_form_of_doc.infldoc(args)
end

function export.tagtable_t(frame)
	return m_form_of_doc.tagtable()
end

function export.postable_t(frame)
	return m_form_of_doc.postable()
end

function export.cattable_t(frame)
	return m_form_of_doc.cattable()
end

return export

-- For Vim, so we get 4-space tabs
-- vim: set ts=4 sw=4 noet:
