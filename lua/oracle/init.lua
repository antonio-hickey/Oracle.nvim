local commands = require("oracle.commands")
local options = require("oracle.options")
local utils = require("oracle.utils")
local oracle = {}

-- Handle default and custom user options from setup
for k, v in pairs(options) do oracle[k] = v end
oracle.setup = function(opts)
    for k, v in pairs(opts) do
        oracle[k] = v
    end
end

-- Global variables
local globals = {}
-- Function for reseting global variables as needed
local function reset(keep_selection)
    if not keep_selection then
        -- current buffer
        globals.curr_buffer = nil
        -- start position of selection
        globals.start_pos = nil
        -- end position of selection
        globals.end_pos = nil
    end
    -- model output buffer
    globals.result_buffer = nil
    -- float window
    globals.float_win = nil
    -- model output
    globals.result_string = ""
    -- model context
    globals.context = nil
    -- model context buffer
    globals.context_buffer = nil
end
reset()

local function close_window(buffer, opts, accept_changes)
    local lines = {}

    -- If extract option is provided and result matches the regex pattern
    if accept_changes and opts.extract then
        -- Extract the matched text from result string
        print(opts.extract)
        print(globals.result_string)
        local extracted = globals.result_string:match(opts.extract)

        -- If no match found, clean up and return
        if not extracted then
            -- Hide float window and delete result buffer
            if opts.auto_closing_window then
                vim.api.nvim_win_hide(globals.float_win)
                vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
                reset()
            end
            return
        end

        -- Split the extracted text into lines, trimming empty strings
        lines = vim.split(extracted, "\n", { trimempty = true })
        lines = utils.trim_table(lines)
        vim.api.nvim_buf_set_text(
            -- Get the current buffer
            globals.curr_buffer,
            -- Calculate the start position (row and column) minus 1
            globals.start_pos[2] - 1,
            -- Calculate the start row and column minus 1
            globals.start_pos[3] - 1,
            -- Calculate the end row and column minus 1
            globals.end_pos[2] - 1,
            -- Calculate the end position (row and column) or row minus 1 if no column is provided
            globals.end_pos[3] > globals.start_pos[3] and
            globals.end_pos[3] or globals.end_pos[3] - 1,
            -- Set the text to be the trimmed lines
            lines
        )

        -- In case another replacement happens
        -- Update end position (row and column) based on the number of lines and length of last line
        globals.end_pos[2] = globals.start_pos[2] + #lines - 1
        globals.end_pos[3] = string.len(lines[#lines])
    end

    if opts.auto_closing_window then
        -- Close any open windows or buffers if auto-close is enabled
        if globals.float_win ~= nil then
            vim.api.nvim_win_close(globals.float_win, true)
        end
        if globals.result_buffer ~= nil then
            -- Delete the result buffer with force (do not prompt to save changes)
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end
        reset()
    end
end

-- Get the options of a window
local function get_window_options(opts)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local new_win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    local middle_row = win_height / 2

    local new_win_height = math.floor(win_height / 2)
    local new_win_row
    if cursor[1] <= middle_row then
        new_win_row = 5
    else
        new_win_row = -5 - new_win_height
    end

    local result = {
        relative = "cursor",
        width = new_win_width,
        height = new_win_height,
        row = new_win_row,
        col = 0,
        style = "minimal",
        border = "rounded"
    }

    local version = vim.version()
    if version.major > 0 or version.minor >= 10 then
        result.hide = opts.hidden
    end

    return result
end

local function create_window(cmd, opts)
    local function setup_split()
        globals.result_buffer = vim.fn.bufnr("%")
        globals.float_win = vim.fn.win_getid()

        vim.api.nvim_set_option_value("filetype", "markdown", { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = globals.result_buffer })
        vim.api.nvim_set_option_value("wrap", true, { win = globals.float_win })
        vim.api.nvim_set_option_value("linebreak", true, { win = globals.float_win })
    end

    if oracle.display_mode == "float" then
        if globals.result_buffer then
            vim.api.nvim_buf_delete(globals.result_buffer, { force = true })
        end

        local win_opts = vim.tbl_deep_extend(
            "force", get_window_options(opts), opts.win_config
        )

        globals.result_buffer = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_option_value("filetype", "markdown", { buf = globals.result_buffer })

        globals.float_win = vim.api.nvim_open_win(globals.result_buffer, true, win_opts)
    elseif oracle.display_mode == "horizontal-split" then
        vim.cmd("split Oracle.nvim")
        setup_split()
    else
        vim.cmd("vnew Oracle.nvim")
        setup_split()
    end

    -- Set keymaps
    vim.keymap.set("n", "<esc>",
        function() vim.fn.jobstop(Job_id) end,
        { buffer = globals.result_buffer }
    )
    vim.keymap.set("n", oracle.quit_map, "<cmd>quit<cr>", { buffer = globals.result_buffer })
    vim.keymap.set("n", oracle.accept_map,
        function()
            --opts.replace = true
            close_window(0, opts, true)
        end,
        { buffer = globals.result_buffer }
    )
    vim.keymap.set("n", oracle.retry_map,
        function()
            vim.api.nvim_win_close(0, true)
            oracle.run_command(cmd, opts)
        end,
        { buffer = globals.result_buffer }
    )
end

-- Write to a windows buffer
local function write_to_buffer(lines)
    if not globals.result_buffer or not vim.api.nvim_buf_is_valid(globals.result_buffer) then
          return
    end

    local all_lines = vim.api.nvim_buf_get_lines(globals.result_buffer, 0, -1, false)
    local last_row = #all_lines
    local last_row_content = all_lines[last_row]
    local last_col = string.len(last_row_content)
    local text = table.concat(lines or {}, "\n")

    vim.api.nvim_set_option_value("modifiable", true, { buf = globals.result_buffer })
    vim.api.nvim_buf_set_text(
        globals.result_buffer, last_row - 1, last_col,
        last_row - 1, last_col, vim.split(text, "\n")
    )

    -- Move the cursor to the end of the new lines
    local new_last_row = last_row + #lines - 1
    vim.api.nvim_win_set_cursor(globals.float_win, { new_last_row, 0 })

    vim.api.nvim_set_option_value("modifiable", false, { buf = globals.result_buffer })
end




-- Handle the execution
oracle.exec = function(exec_opts)
    local opts = vim.tbl_deep_extend("force", oracle, exec_opts)
    if opts.hidden then
        opts.display_mode = 'float'
        opts.replace = true
    end

    if type(opts.init) == 'function' then opts.init(opts) end

    -- Handle buffer update if needed
    if globals.result_buffer ~= vim.fn.winbufnr(0) then
        globals.curr_buffer = vim.fn.winbufnr(0)

        -- Take vim mode into account
        local mode = opts.mode or vim.fn.mode()
        if mode == "v" or mode == "V" then
            -- If in Visual mode then grab the current selection
            -- to pass to the model with the prompt for reference
            globals.start_pos = vim.fn.getpos("'<")
            globals.end_pos = vim.fn.getpos("'>")

            local max_col = vim.api.nvim_win_get_width(0)
            if globals.end_pos[3] > max_col then
                globals.end_pos[3] = vim.fn.col("'>") - 1
            end
        else
            local cursor = vim.fn.getpos(".")
            globals.start_pos = cursor
            globals.end_pos = globals.start_pos
        end
    end

    -- Handle what content to include in the context as reference
    local content
    if globals.start_pos == globals.end_pos then
        -- Grab the entire buffer text
        content = table.concat(
            vim.api.nvim_buf_get_lines(
                globals.curr_buffer, 0, -1, false
            ),
            "\n"
        )
    else
        -- Grab a selection of buffer text
        content = table.concat(
            vim.api.nvim_buf_get_text(
                globals.curr_buffer,
                globals.start_pos[2] - 1, globals.start_pos[3] - 1,
                globals.end_pos[2] - 1, globals.end_pos[3],
                {}
            ),
            "\n"
        )
    end

    -- Replace placeholders with data
    local function substitute_placeholders(input)
        if not input then return input end

        local text = input
        if string.find(text, "%$input") then
            local answer = vim.fn.input("Prompt: ")
            text = string.gsub(text, "%$input", answer)
        end

        text = string.gsub(text, "%$register_([%w*+:/\"])", function(r_name)
            local register = vim.fn.getreg(r_name)
            if not register or register:match("^%s*$") then
                error(
                    "Prompt uses $register_" .. r_name ..
                    " but register " .. r_name .. " is empty."
                )
            end
            return register
        end)

        if string.find(text, "%$register") then
            local register = vim.fn.getreg('"')
            if not register or register:match("^%s*$") then
                error("Prompt uses $register but yank register is empty.")
            end

            text = string.gsub(text, "%$register", register)
        end

        content = string.gsub(content, "%%", "%%%%")
        text = string.gsub(text, "%$text", content)
        text = string.gsub(text, "%$filetype", vim.bo.filetype)
        return text
    end

    -- Process the prompt
    local prompt = opts.prompt
    if type(prompt) == "function" then
        prompt = prompt({content = content, filetype = vim.bo.filetype})
        if type(prompt) ~= 'string' or string.len(prompt) == 0 then
            return
        end
    end
    prompt = substitute_placeholders(prompt)
    opts.extract = substitute_placeholders(opts.extract)
    prompt = string.gsub(prompt, "%%", "%%%%")

    globals.result_string = ""

    local cmd

    opts.json = function(body)
        local json = vim.fn.json_encode(body)
        json = vim.fn.shellescape(json)
        if vim.o.shell == 'cmd.exe' then
            json = string.gsub(json, '\\\"\"', '\\\\\\\"')
        end
        return json
    end

    opts.prompt = prompt

    -- Handle user overrides of command
    if type(opts.command) == 'function' then
        cmd = opts.command(opts)
    else
        cmd = oracle.command
    end

    if string.find(cmd, "%$prompt") then
        local prompt_escaped = vim.fn.shellescape(prompt)
        cmd = string.gsub(cmd, "%$prompt", prompt_escaped)
    end
    cmd = string.gsub(cmd, "%$model", opts.model)
    if string.find(cmd, "%$body") then
        local body = vim.tbl_extend(
          "force", {model = opts.model, stream = true}, opts.body
        )

        local messages = {}
        if globals.context then messages = globals.context end

        -- Add a new prompt to the context
        table.insert(messages, {role = "user", content = prompt})
        body.messages = messages

        -- Handle model options, with ability for custom user model options
        if oracle.model_options ~= nil then
            body = vim.tbl_extend("force", body, oracle.model_options)
        end
        if opts.model_options ~= nil then
            body = vim.tbl_extend("force", body, opts.model_options)
        end

        local json = opts.json(body)
        cmd = string.gsub(cmd, "%$body", json)
    end

    -- add "---" to before a prompt/response within the same context
    if globals.context ~= nil then write_to_buffer({"", "", "---", ""}) end

    oracle.run_command(cmd, opts)
end

oracle.run_command = function(cmd, opts)
    -- Only create a new window if one's not already open
    if globals.result_buffer == nil or globals.float_win == nil or
        not vim.api.nvim_win_is_valid(globals.float_win) then
        create_window(cmd, opts)
    end

    local partial_data = ""

    if opts.debug then print(cmd) end

    -- Handle processes
    Job_id = vim.fn.jobstart(cmd, {
        on_stdout = function(_, data, _)
            -- Handle window close on a process level
            if not globals.float_win or
                not vim.api.nvim_win_is_valid(globals.float_win) then
                if Job_id then vim.fn.jobstop(Job_id) end

                if globals.result_buffer then
                    vim.api.nvim_buf_delete(globals.result_buffer, {force = true})
                end

                reset()
                return
            end

            if opts.debug then vim.print('Response data: ', data) end

            for _, line in ipairs(data) do
                partial_data = partial_data .. line
                if line:sub(-1) == "}" then
                    partial_data = partial_data .. "\n"
                end
            end
            local lines = vim.split(partial_data, "\n", {trimempty = true})

            partial_data = table.remove(lines) or ""

            -- Process response from model, from parsing to writting to window buffer
            for _, line in ipairs(lines) do
                oracle.process_response(line, Job_id, opts.json_response)
            end
            if partial_data:sub(-1) == "}" then
                oracle.process_response(partial_data, Job_id, opts.json_response)
                partial_data = ""
            end
        end,
        on_stderr = function(_, data, _)
            if opts.debug then
                -- Handle window close on a process level
                if not globals.float_win or
                    not vim.api.nvim_win_is_valid(globals.float_win) then
                    if Job_id then vim.fn.jobstop(Job_id) end
                    return
                end

                if data == nil or #data == 0 then return end

                globals.result_string = globals.result_string .. table.concat(data, "\n")
                local lines = vim.split(globals.result_string, "\n")
                write_to_buffer(lines)
            end
        end,
        on_exit = function(_, b)
            --if b == 0 and opts.replace and globals.result_buffer then
            --    close_window(b, opts, true)
            --end
        end
    })

    local group = vim.api.nvim_create_augroup("oracle", {clear = true})
    vim.api.nvim_create_autocmd('WinClosed', {
        buffer = globals.result_buffer,
        group = group,
        callback = function()
            if Job_id then vim.fn.jobstop(Job_id) end
            if globals.result_buffer then
                vim.api.nvim_buf_delete(globals.result_buffer, {force = true})
            end
            reset(true) -- keep selection in case of subsequent retries
        end
    })

    -- Handle showing prompts
    if opts.show_prompt then
        local lines = vim.split(opts.prompt, "\n")
        local short_prompt = {}
        for i = 1, #lines do
            lines[i] = "> " .. lines[i]
            table.insert(short_prompt, lines[i])
            if i >= 3 then
                if #lines > i then
                    table.insert(short_prompt, "...")
                end
                break
            end
        end
        local heading = "#"
        if oracle.show_model then heading = "##" end
        write_to_buffer({
            heading .. " Prompt:", "", table.concat(short_prompt, "\n"), "",
            "---", ""
        })
    end

    vim.api.nvim_buf_attach(globals.result_buffer, false, {
        on_detach = function()
          globals.result_buffer = nil
        end
    })
end

oracle.win_config = {}

-- Select model to run inference on
function oracle.select_model()
    local models = oracle.list_models(oracle)
    vim.ui.select(models, {prompt = "Model:"}, function(item)
        if item ~= nil then
            print("Model set to " .. item)
            oracle.model = item
        end
    end)
end

-- Prompt handeling
oracle.prompts = options.prompts
function oracle.select_prompt(cb)
    local promptKeys = {}
    for key, _ in pairs(oracle.prompts) do table.insert(promptKeys, key) end
    table.sort(promptKeys)
    vim.ui.select(promptKeys, {
        prompt = "Prompt:",
        format_item = function(item)
            return table.concat(vim.split(item, "_"), " ")
        end
    }, function(item) cb(item) end)
end

-- Add commands for users
commands.create_prompt_commands(oracle)

-- Process a response from the model handeling everything from
-- parsing to writting the response to a window buffer.
oracle.process_response = function(str, job_id, json_response)
    if string.len(str) == 0 then return end
    local text

    if json_response then
        local success, result = pcall(function()
            return vim.fn.json_decode(str)
        end)

        if success then
            -- Chat endpoint
            if result.message and result.message.content then
                local content = result.message.content
                text = content

                globals.context = globals.context or {}
                globals.context_buffer = globals.context_buffer or ""
                globals.context_buffer = globals.context_buffer .. content

                -- When the message sequence is complete, add it to the context
                if result.done then
                    table.insert(globals.context, {
                        role = "assistant",
                        content = globals.context_buffer
                    })
                    -- Clear the buffer as we're done with this sequence of messages
                    globals.context_buffer = ""
                end
            -- Generate endpoint
            elseif result.response then
                text = result.response
                if result.context then
                    globals.context = result.context
                end
            end
        else
            write_to_buffer({"", "====== ERROR ====", str, "-------------", ""})
            vim.fn.jobstop(job_id)
        end
    else
        text = str
    end

    if text == nil then return end

    globals.result_string = globals.result_string .. text
    local lines = vim.split(text, "\n")
    write_to_buffer(lines)
end

return oracle
