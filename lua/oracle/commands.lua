local options = require("oracle.options")
local commands = {}

-- Create a command for each prompt
function commands.create_prompt_commands(oracle)
    -- Create root/main Oracle command for users
    -- eg: :Oracle
    vim.api.nvim_create_user_command("Oracle", function(arg)
        local mode
        if arg.range == 0 then
            mode = "n"
        else
            mode = "v"
        end
        if arg.args ~= "" then
            local prompt = oracle.prompts[arg.args]
            if not prompt then
                print("Invalid prompt '" .. arg.args .. "'")
                return
            end
            local p = vim.tbl_deep_extend("force", {mode = mode}, prompt)
            return oracle.exec(p)
        end
        oracle.select_prompt(function(item)
            if not item then return end
            local p = vim.tbl_deep_extend("force", {mode = mode}, oracle.prompts[item])
            oracle.exec(p)
        end)
    end, {
        range = true,
        nargs = "?",
        complete = function(ArgLead)
            local promptKeys = {}
            for key, _ in pairs(oracle.prompts) do
                if key:lower():match("^" .. ArgLead:lower()) then
                    table.insert(promptKeys, key)
                end
            end
            table.sort(promptKeys)
            return promptKeys
        end
    })

    -- Create individual sub commands for users
    -- e.g. :OracleAsk, :OracleReview, :OracleCustomPrompt, etc.
    for prompt_name, prompt_options in pairs(options.prompts) do
        local command_name = "Oracle" .. prompt_name:gsub("_", "")
        vim.api.nvim_create_user_command(command_name, function(arg)
            local mode
            if arg.range == 0 then
                mode = "n"
            else
                mode = "v"
            end

            local exec_opts = vim.tbl_deep_extend("force", {mode = mode}, prompt_options)
            if arg.args ~= "" then
                exec_opts.prompt = exec_opts.prompt:gsub("%$input", arg.args)
            end

            oracle.exec(exec_opts)
        end, {
            range = true,
            nargs = "?",
            complete = function()
                return {}
            end
        })
    end
end

return commands
