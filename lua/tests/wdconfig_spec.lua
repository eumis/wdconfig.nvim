---@diagnostic disable: need-check-nil

local assert = require "luassert"
local reload = require "plenary.reload"
local Path = require "plenary.path"
local stub = require "luassert.stub"

local M = {
    wdconfig = require "wdconfig",
    package_path = package.path
}

local test_cwd_path = Path:new("some", "cwd", "path")
local test_config_path = Path:new("some", "config.lua")

stub.new(Path, "write")
local path_read_stub = stub.new(Path, "read")
local path_exists_stub = stub.new(Path, "exists")
local dofile_stub = stub.new(_G, "dofile")

local function setup_exists(path)
    path_exists_stub.invokes(function(self) return self.filename == path end)
end

local function setup_not_exists(path)
    path_exists_stub.invokes(function(self) return self.filename ~= path end)
end

local function setup()
    reload.reload_module("wdconfig")
    M.wdconfig = require "wdconfig"
end

local function cleanup()
    path_read_stub:clear()
    path_read_stub:returns("")
    dofile_stub:clear()
    package.path = M.package_path
end

describe("load_local_config", function()
    before_each(setup)
    after_each(cleanup)

    local local_config_path = Path:new(vim.fn.stdpath("data"), "wdconfig.json").filename

    it("should load local config", function()
        local local_config = {
            trusted_cwds = { "/some/path", "/some/other/path" }
        }
        path_read_stub.invokes(function(self)
            return self.filename == local_config_path and vim.json.encode(local_config) or ""
        end)

        M.wdconfig.load_local_config()

        assert.are.same(local_config, M.wdconfig.local_config)
    end)

    it("should not load if already loaded", function()
        M.wdconfig.load_local_config()

        M.wdconfig.load_local_config()

        assert.spy(path_read_stub).was_called(1)
    end)

    it("should reload if already loaded", function()
        M.wdconfig.load_local_config()

        M.wdconfig.load_local_config(true)

        assert.spy(path_read_stub).was_called(2)
    end)
end)

---@param action fun()
---@param cwd string
local function test_trust(action, cwd)
    before_each(setup)
    after_each(cleanup)

    it("should trust cwd", function()
        action()

        assert.are.same({ trusted_cwds = { cwd } }, M.wdconfig.local_config)
        assert.is.True(M.wdconfig.is_trusted(cwd))
    end)

    it("should trust cwd once", function()
        action()

        action()

        assert.are.same({ trusted_cwds = { cwd } }, M.wdconfig.local_config)
        assert.is.True(M.wdconfig.is_trusted(cwd))
    end)
end

describe("trust", function() test_trust(function() M.wdconfig.trust(test_cwd_path.filename) end, test_cwd_path:absolute()) end)
describe("WdcTrust", function() test_trust(function() vim.cmd("WdcTrust") end, vim.fn.getcwd()) end)
describe("WdcTrust with argument", function() test_trust(function() vim.cmd("WdcTrust " .. test_cwd_path.filename) end, test_cwd_path:absolute()) end)

---@param action fun()
local function test_load_cwd(action)
    before_each(setup)
    after_each(cleanup)

    local default_config_name = "config.lua"
    local default_config_path = Path:new(vim.fn.getcwd(), default_config_name):absolute()

    it("should load if exists", function()
        M.wdconfig.setup({ trusted_cwd_only = false })
        setup_exists(default_config_path)

        action()

        assert.stub(dofile_stub).was_called_with(default_config_path)
    end)

    it("should load if trusted", function()
        M.wdconfig.setup({ trusted_cwd_only = true })
        M.wdconfig.trust(vim.fn.getcwd())
        setup_exists(default_config_path)

        action()

        assert.stub(dofile_stub).was_called_with(default_config_path)
    end)

    it("should not load if exists", function()
        M.wdconfig.setup({ trusted_cwd_only = false })
        setup_not_exists(default_config_path)

        action()

        assert.stub(dofile_stub).was_not_called_with(default_config_path)
    end)

    it("should not load if not trusted", function()
        M.wdconfig.setup({ trusted_cwd_only = true })
        setup_exists(default_config_path)

        action()

        assert.stub(dofile_stub).was_not_called_with(default_config_path)
    end)

    local configs = { "config.lua", "local.lua", Path:new("config", "init.lua").filename }
    local use_cases = {}
    for _, config in ipairs(configs) do
        table.insert(use_cases, { config, Path:new(vim.fn.getcwd(), config):absolute() })
    end

    for _, use_case in ipairs(use_cases) do
        it("should load " .. use_case[1] .. " if exists", function()
            M.wdconfig.setup({ config_name = use_case[1], trusted_cwd_only = false })

            setup_exists(use_case[2])

            action()

            assert.stub(dofile_stub).was_called_with(use_case[2])
        end)

        it("should not load " .. use_case[1] .. " if not exists", function()
            M.wdconfig.setup({ config_name = use_case[1], trusted_cwd_only = false })
            setup_not_exists(use_case[2])

            action()

            assert.stub(dofile_stub).was_not_called_with(use_case[2])
        end)
    end

    for _, index in ipairs({ 1, 2, 3 }) do
        it("should load first existing", function()
            M.wdconfig.setup({ config_name = configs, trusted_cwd_only = false })
            local config = use_cases[index]
            setup_exists(config[2])

            action()

            for _, i in ipairs({ 1, 2, 3 }) do
                if i == index then
                    assert.stub(dofile_stub).was_called_with(use_cases[i][2])
                else
                    assert.stub(dofile_stub).was_not_called_with(use_cases[i][2])
                end
            end
        end)
    end
end

describe("load_cwd", function() test_load_cwd(function() M.wdconfig.load_cwd() end) end)
describe("WdcLoad", function() test_load_cwd(function() vim.cmd("WdcLoad") end) end)

---@param action fun(path: string)
---@param path string
local function test_load(action, path)
    before_each(setup)
    after_each(cleanup)

    it("should load path if exists", function()
        setup_exists(path)

        action(path)

        assert.stub(dofile_stub).was_called_with(Path:new(path):absolute())
    end)

    it("should not load if not exists", function()
        setup_not_exists(path)

        action(path)

        assert.stub(dofile_stub).was_not_called_with(Path:new(path):absolute())

    end)
end

describe("load", function() test_load(function(path) M.wdconfig.load(path) end, test_config_path.filename) end)
describe("WdcLoad with argument", function() test_load(function(path) vim.cmd("WdcLoad " .. path) end, test_config_path.filename) end)

describe("load_package", function()
    before_each(setup)
    after_each(cleanup)

    local use_cases = {
        {"scripts", test_cwd_path.filename, Path:new(test_cwd_path.filename, "scripts"):absolute()},
        {nil, test_cwd_path.filename, Path:new(test_cwd_path.filename, "lua"):absolute()},
        {nil, "~/config", Path:new("~/config", "lua"):absolute()},
        {"scripts", nil, Path:new(vim.fn.getcwd(), "scripts"):absolute()},
        {nil, nil, Path:new(vim.fn.getcwd(), "lua"):absolute()},
    }

    for _, use_case in ipairs(use_cases) do
        it("should load package", function()
            local name, cwd, package_path = unpack(use_case)

            M.wdconfig.load_package(name, cwd)

            assert.is.Truthy(package.path:find(package_path, 1, true))
        end)
    end
end)
