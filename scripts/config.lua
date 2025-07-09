local tasks = require "tasks"
tasks.add("test all", "nvim --headless -c 'PlenaryBustedDirectory lua/tests'")
tasks.add("test current file", function(bufnr)
    return "nvim --headless -c 'PlenaryBustedFile " .. vim.fn.expand("#" .. bufnr) .. "'"
end)

require "usr.ai".on("supermaven")
