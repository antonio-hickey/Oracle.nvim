-- NOTE: All these options are overridable
local options = {}

-- What model do you want to use?
options.model = "llama3"
-- Whats the ip hosting your model?
options.host = "localhost"
-- Whats the port is the api running on?
options.port = "11434"
-- Print out debug messages?
options.debug = false
-- Stream responses from the model or wait until it's finished
options.body = {stream = true}
-- Show your prompt in the window
options.show_prompt = false
-- Show what model your using in the window
options.show_model = false
-- The key map for closing the window
options.quit_map = "q"
-- The key map for accepting a response
options.accept_map = "<c-cr>"
-- The key map for retrying a response
options.retry_map = "<c-r>"
-- Hide the responses
options.hidden = false
-- Performs the curl command to your Ai endpoint
options.command = function(opts)
    local endpoint = "http://" .. opts.host .. ":" .. opts.port .. "/api/chat"
    return "curl --silent --no-buffer -X POST " .. endpoint .. " -d $body"
end
-- Do you want your response in JSON ?
options.json_response = true
-- Window display
options.display_mode = "float"
-- Auto closing window
options.auto_closing_window = false
-- Initialize your ollama server
options.init = function() pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end
-- Get a list of models available
options.list_models = function(opts)
    local endpoint = "http://" .. opts.host .. ":" .. opts.port .. "/api/tags"

    local response = vim.fn.systemlist("curl --silent --no-buffer " .. endpoint)
    local list = vim.fn.json_decode(response)

    local models = {}
    for key, _ in pairs(list.models) do
        table.insert(models, list.models[key].name)
    end
    table.sort(models)

    return models
end
-- Prompts for interacting with your model
options.prompts = {
    Ask = { prompt = "Regarding the following code, $input:\n$text" },
    Chat = { prompt = "$input" },
    Change = {
        prompt = "Regarding the following code, $input, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Comment = {
        prompt = "Regarding the following code, write comments where needed especially for 'doc comments', do not add or refactor code only comments, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Generate = { prompt = "$input", replace = true },
    Review = {
        prompt = "Review the following code and make concise suggestions, look for bugs, unhandled errors, inconsistencies, bad practices :\n```$filetype\n$text\n```",
    },
    Refactor = {
        prompt = "Refactor and enhance the following code, only output the result in format ```$filetype\n...\n```:\n```$filetype\n$text\n```",
        replace = true,
        extract = "```$filetype\n(.-)```",
    },
    Summarize = { prompt = "Summarize the following code:\n$text" },
}

return options
