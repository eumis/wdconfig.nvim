---@class Options
---@field config_name? string[] | string
---@field config_path? string[] | string
---@field trusted_cwd_only boolean

---@class LocalConfig
---@field trusted_cwds string[]

local Path = require('plenary.path')

local M = {
    ---@type Options
    opts = {
        config_name = "config.lua",
        trusted_cwd_only = true
    },
    ---@type LocalConfig?
    local_config = nil
}

local config_path = Path:new(vim.fn.stdpath("config"), "wdconfig.json")

---@return LocalConfig
local function load_local_config()
    local ok, local_config = pcall(function() return vim.json.decode(config_path:read()) end)
    return ok and local_config or {}
end

---@param local_config LocalConfig
local function save_local_config(local_config)
    if local_config ~= nil then
        config_path:write(vim.json.encode(local_config), "w")
    end
end

---@param force? boolean default false
function M.load_local_config(force)
    if force == nil then force = false end
    if M.local_config == nil or force then
        M.local_config = load_local_config()
        if M.local_config.trusted_cwds == nil then
            M.local_config.trusted_cwds = {}
        end
    end
end

---@param path string
---@param trust? boolean default true
function M.trust(path, trust)
    M.load_local_config()
    if trust == nil then trust = true end
    local full_path = Path:new(path):absolute()
    if trust then
        if not M.is_trusted(full_path) then
            table.insert(M.local_config.trusted_cwds, full_path)
        end
    else
        table.remove(M.local_config.trusted_cwds, full_path)
    end
    save_local_config(M.local_config)
end

---@param path string
function M.is_trusted(path)
    M.load_local_config()
    local full_path = Path:new(path):absolute()
    return vim.tbl_contains(M.local_config.trusted_cwds, full_path)
end

function M.load_cwd()
    local cwd = vim.fn.getcwd()
    local configs = type(M.opts.config_name) == "string" and { M.opts.config_name } or M.opts.config_name
    local cwd_trusted = not M.opts.trusted_cwd_only or M.is_trusted(cwd)

    ---@cast configs string[]
    for _, config in ipairs(configs) do
        local cwd_lua = Path:new(cwd, config)
        if cwd_lua:exists() then
            if cwd_trusted then
                dofile(cwd_lua:absolute())
                vim.notify(config .. " is run", vim.log.levels.INFO)
            else
                vim.notify("cwd is not trusted", vim.log.levels.WARN)
            end
            return
        end
    end
end

---@param path string | Path
function M.load(path)
    if type(path) == "string" then path = Path:new(path) end

    if path:exists() then
        dofile(path:absolute())
        vim.notify(path.filename .. " is run", vim.log.levels.INFO)
    end
end

---@param name? string
---@param cwd? string
function M.load_package(name, cwd)
    if name == nil then name = "lua" end
    if cwd == nil then cwd = vim.fn.getcwd() end
    local cwd_lua = Path:new(cwd, name, "?.lua")
    package.path = package.path .. ';' .. cwd_lua:absolute()
end

vim.api.nvim_create_user_command("WdcLoad", function(opts)
    if opts.fargs[1] == nil then
        M.load_cwd()
    else
        M.load(opts.fargs[1])
    end
end, { nargs = "?" })

vim.api.nvim_create_user_command("WdcTrust", function(opts)
    local cwd = opts.fargs[1] ~= nil and opts.fargs[1] or vim.fn.getcwd()
    M.trust(cwd)
end, { nargs = "?" })

---@param opts Options
function M.setup(opts)
    for key, value in pairs(opts) do
        if value ~= nil then
            M.opts[key] = value
        end
    end
end

return M
