Oracle.nvim
===

Use your own computer for running inference on language models. Interact with your machine as
an oracle answering questions, reviewing, discussing, and enhancing your code directly in the editor.

[![Oracle.png](https://i.postimg.cc/rmzN26Jq/Oracle.png)](https://postimg.cc/xJDzL4hZ)

<img src="https://media.giphy.com/media/4xnguootTerTIqN5Pm/giphy.gif" alt="Oracle Preview" width="800"/>

Requirements
---
* [Ollama](https://ollama.com/), and a model (see [here for all available models](https://ollama.ai/library))
* [Curl](https://curl.se/) (why would you not already have curl installed broo?)

Installation
---

Packer example:
```lua
use "antonio-hickey/Oracle.nvim"
```
Lazy example:
```lua
{"antonio-hickey/Oracle.nvim"},
```

Usage
---
Use the `:Oracle` command.

Optional:
* Set custom key maps:
    ```
    -- example key map to run code review
    vim.keymap.set({'v', 'n'}, '<leader>r', ':OracleReview<CR>')
    ```
* See [Suggested Integrations](#suggested-integrations) for more streamlined usage

Configuration
---
```
require('oracle').setup({ 
  -- What model do you want to use?
  model = "llama3"
  -- What ip is hosting your model?
  host = "localhost"
  -- Whats the port is the api running on?
  port = "11434"
  -- Print out debug messages?
  debug = false
  -- Stream responses from the model or wait until it's finished
  body = {stream = true}
  -- Show your prompt in the window
  show_prompt = false
  -- Show what model your using in the window
  show_model = false
  -- The key map for closing the window
  quit_map = "q"
  -- The key map for accepting a response
  accept_map = "<c-cr>"
  -- The key map for retrying a response
  retry_map = "<c-r>"
  -- Hide the responses
  hidden = false
  -- Performs the curl command to your Ai endpoint
  command = function(opts)
      local endpoint = "http://" .. opts.host .. ":" .. opts.port .. "/api/chat"
      return "curl --silent --no-buffer -X POST " .. endpoint .. " -d $body"
  end
  -- Do you want your response in JSON ?
  json_response = true
  -- Window display
  display_mode = "float"
  -- Auto closing window
  no_auto_close = false
  -- Initialize your ollama
  init = function() pcall(io.popen, "ollama serve > /dev/null 2>&1 &") end
  -- Prompts for interacting with your model
  -- NOTE: You can add custom prompts, commands for them will automatically
  -- be created e.g. :OracleCustomPrompt
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
})
```

Suggested Integrations
---
I personally use [which-key](https://github.com/folke/which-key.nvim) with Oracle for mapping
and displaying short cuts for Oracle commands.

Here's a basic which-key config for Oracle:
```
-- This function is for handeling selection ranges
-- for your oracle queries when in visual mode
local function oracle_cmd(cmd)
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" then
    -- Close which-key window
    -- It will affect with selection (diff buffer)
    vim.cmd('normal! :<C-u>')

    -- Run the Oracle command with the selection range
    vim.cmd(string.format("'<,'>%s", cmd))
  else
    vim.cmd(cmd)
  end
end

local mappings = {
    -- ... Your other mappings
    o = {
        icon = "",
        name = "Oracle",
        a = { function() oracle_cmd("OracleAsk") end, "Ask Question" },
        c = { function() oracle_cmd("OracleComment") end, "Generate Comments" },
        d = { function() oracle_cmd("OracleDiscuss") end, "Discuss Something" },
        e = { function() oracle_cmd("OracleRefactor") end, "Enhance Code" },
        g = { function() oracle_cmd("OracleGenerate") end, "Generate Code" },
        r = { function() oracle_cmd("OracleReview") end, "Review Code" },
        s = { function() oracle_cmd("OracleSummarize") end, "Summarize Code" },
        u = { function() oracle_cmd("OracleChange") end, "Update Code" },
    },
}
```

