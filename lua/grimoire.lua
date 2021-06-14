local cjson = require "cjson"

local sbuf, swin
local document_buffer, document_window 
local highlight_namespace
local result_count = 0 
local console_buffer, console_window, console_terminal
local base_width = vim.api.nvim_win_get_width(0)
local base_height = vim.api.nvim_win_get_height(0)
local result_list_length = base_height - 5 
local current_search_query = ''
local current_result_set = {} 
local config = {}

config.results_move_down = '<M-LEFT>'
config.results_move_up = '<M-RIGHT>'
config.edit_document = '¬'
config.jump_to_search = '¬'
config.storage_dir = "/Users/alans/grimoire/mdx_files"
config.debug = true  
config.log_file_path = '/Users/alans/Library/Logs/Grimoire/neovim-grimoire.log'

local state = {
    selection_index = 0
} 

------------------------------------------------
-- VERSION 1 Requirements 
------------------------------------------------
-- [x] Search and show results 
-- [x] Provide nav to move and up and down search results 
-- [x] Show selected result in document window 
-- [x] Be able to edit document in document window 
-- [x] Save the file 
-- [ ] Update the search index on file changes
-- [ ] Make new files (with template)
-- [x] If no search, show nothing in document
-- [x] Clear search on moving back to it. 
-- [ ] Make sure files are saved on exit (e.g. if you exit while still in the document window)
-- [x] Deal with empty query results

------------------------------------------------
-- VERSION 2 Requirements 
------------------------------------------------
-- [ ] Setup config file
-- [ ] Delete files
-- [ ] Rename files 
-- [ ] Setup so `:q` closes all windows (saving the file first)
-- [ ] Setup so `:w` saves a file

------------------------------------------------
-- Other/Misc 
------------------------------------------------
-- [x] Default to wordwrap
-- [x] Maybe just set the window size directly
-- [x] Add a log function
-- [ ] Full screen toggle that also switches off wordwrap. Bascially a way to go from prose to code
-- [ ] Hotkey to turn off wordwrap 
-- [ ] Auto-disable wordwrap in code fences/code blocks
-- [ ] Generate symbolic links based of patterns for posting to the site
-- [ ] Auto-publish to twitter when you make a post 
-- [ ] Start up debug version of the site for preview
-- [ ] Highlight the boreder of the window you're currently in 
-- [ ] High YAML Headers (except for title)
-- [ ] Setup hotkey to toggle word wrap 
-- [ ] Setup multiple window option for horizontal and/or vertical 
-- [ ] Repopulate search with an escape (or something) when you go back to it
-- [ ] Setup so the search results stay when moving back to search even though it clears
-- [ ] Trigger a site build and deploy on file changes
-- [ ] Change `dd` in the search buffer so it returns to insert mode after clearing the line
-- [ ] Make sure you can't add multiple lines in the search buffer
-- [ ] Hotkeys to copy stuff out to pasteboards
-- [ ] Look at `nofile` for search and resutls windows
-- [ ] Setup so whitespace at the end of queries is removed (and doesn't send a new query)
-- [ ] Setup filter lists for modes where things get excluded from search (e.g. streamer mode)
-- [ ] Don't send a new request if nothing has changed (e.g. it's just a space)
-- [ ] Only turn on hot keys when you're in the app (this might already be in place)
-- [ ] Show list of recent files (and their searches) with hotkeys to get back to
-- [ ] Prevent closing one window without closing all
-- [ ] Setup so files are stored in a directory with the first word/token as the name 
-- [ ] Multiple templates for opening files (a default should open with a hot key then another hotkey to open a template selector)
-- [ ] Make sure multiple instances can run at the same time (realizing small chance of editing the same file at the same time)
-- [ ] Deal with windows that get resized
-- [ ] Disable `:w` in the search window
-- [ ] Remember the line number for each file for a specific amount of time
-- [ ] Don't re-render the document windnow if the selected document hasn't changed 
-- [ ] Deal with files that are deleted outside neovim

------------------------------------------------

local function log(message)
    if config.debug then 
        local log_file = io.open(config.log_file_path, "a")
        io.output(log_file)
        io.write('-- '..os.date("%c").."|INFO|"..message.."\n")
        io.close(log_file)
    end
end

local function current_file_path()
    local file_name = current_result_set[state.selection_index + 1]['name']
    local file_path = config.storage_dir..'/'..file_name
    return file_path
end

local function close_windows()
    vim.api.nvim_win_close(rwin, true)
    vim.api.nvim_buf_delete(rbuf, { force=true })
    vim.api.nvim_win_close(swin, true)
    vim.api.nvim_buf_delete(sbuf, { force=true })
    vim.api.nvim_win_close(document_window, true)
    vim.api.nvim_buf_delete(document_buffer, { force=true })
    vim.api.nvim_command('stopinsert')
end

local function edit_document() 
    vim.api.nvim_set_current_win(document_window)
    vim.api.nvim_command('set buftype=""')
    vim.api.nvim_command('file '..current_file_path())
    vim.api.nvim_command('stopinsert')
end

local function jump_to_search() 
    vim.api.nvim_command('write!')
    local data_to_update_with = vim.api.nvim_buf_get_lines(document_buffer, 0, -1, true) 
    local data_as_string = ''
    for i = 1, #data_to_update_with do  
        data_as_string = data_as_string..data_to_update_with[i].." "
    end
    data_as_string = string.gsub(data_as_string, '[^a-zA-Z-]', ' ')
    -- log(data_as_string)

    local update_index_call = [[curl -X POST 'http://127.0.0.1:7700/indexes/grimoire/documents' --data '[{ "id": 1111111111111111112, "name": "aaaaaaaaa-test-insert.md", "overview": "hjkl uiop asdf qwer test" }]']]
    vim.fn.systemlist(update_index_call)
    -- log(update_index_call)

    vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, {})
    vim.api.nvim_set_current_win(swin)
    vim.api.nvim_command('startinsert')
end

local function make_new_file()
    log("Making new file")
end

local function open_document_window()
    document_buffer = vim.api.nvim_create_buf(false, true)
    document_window = vim.api.nvim_open_win(document_buffer, true,
        { 
            style="minimal", 
            relative='editor', 
            row=3, 
            col=math.floor(base_width / 4) + 2, 
            -- width=math.floor(base_width / 4 * 3) - 3,
            width=64,
            height=base_height - 5, border='single'
        }
    )
    vim.api.nvim_win_set_option(document_window, 'linebreak', true)
    vim.api.nvim_win_set_option(document_window, 'wrap', true)
end

local function open_results_window()
    rbuf = vim.api.nvim_create_buf(false, true)
    rwin = vim.api.nvim_open_win(rbuf, false,
        {
            focusable=false,
            style="minimal", relative='editor', row=3, col=0, 
            width=math.floor(base_width / 4), height=base_height - 5,
            border='single'
        }
    )
end

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {
                style="minimal", relative='editor', row=0, col=0, 
                width=base_width - 2, height=1, border='single'
            }
        )
    vim.cmd('startinsert')
end

local function show_file()
    -- log("Calling: show_file()")
    if current_search_query ~= '' then 
        log("Showing file: "..current_file_path())
        local file = io.open(current_file_path(), "r")
        local lines_table = {}
        for line in file:lines() do
            table.insert(lines_table, line)
        end
        vim.api.nvim_win_set_cursor(document_window, {1, 0})
        vim.api.nvim_buf_set_lines(document_buffer, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(document_buffer, 0, -1, false, lines_table)
    end
end

-- This has to be below `show_file()`
local function select_next_index()
    if state.selection_index < math.min((result_count - 1), (result_list_length - 1)) then
        state.selection_index = state.selection_index + 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', state.selection_index, 0, -1)
        show_file()
    end
end

-- This has to be below `show_file()`
local function select_previous_index()
    if state.selection_index > 0 then
        state.selection_index = state.selection_index - 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', state.selection_index, 0, -1)
        show_file()
    end
end

local function current_query_string()
    -- log("Calling: current_query_string()")
    query_string = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    query_string = string.gsub(query_string, '%s*$', '')
    query_string = string.gsub(query_string, '%s', '%%20')
    query_string = string.gsub(query_string, '"', '')
    -- log("New query string:" .. query_string)
    -- TODO: make this just one thing that's global in `state`
    current_search_query = query_string
    return query_string 
end

local function fetch_results()
    local search_query = 'curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..current_query_string()..'&limit='..result_list_length..'"'
    log("Calling: "..search_query)
    local raw_json = vim.fn.systemlist(search_query)
    local json_data = cjson.decode(raw_json[1])
    current_result_set = json_data['hits']
end

local function show_results()
    -- log("Calling: show_results()")
    state.selection_index = 0 
    fetch_results()
    if #current_result_set > 0 then
        local number_of_result_lines = math.min(result_list_length, #current_result_set)
        vim.api.nvim_buf_set_lines(rbuf, 0, result_list_length, false, {})
        for i = 1, number_of_result_lines do
            -- log("id"..current_result_set[i]['id'])
            vim.api.nvim_buf_set_lines(rbuf, i - 1, i, false, { current_result_set[i]['name'] })
        end
        log("number of result lines: "..#current_result_set)
        result_count = #current_result_set 
        highlight_namespace = vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', state.selection_index, 0, -1)
        show_file()
    end
end

local function grimoire()
    log("Grimoire Activated")
    open_document_window()
    open_results_window()
    open_search_window()
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(rbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(rbuf, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(document_buffer, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(document_buffer, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})

    vim.api.nvim_buf_set_keymap(document_buffer, 'i', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(document_buffer, 'n', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.results_move_down, '<cmd>lua require"grimoire".select_next_index()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.results_move_up, '<cmd>lua require"grimoire".select_previous_index()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    
    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.edit_document, '<cmd>lua require"grimoire".edit_document()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(sbuf, 'n', config.results_move_down, '<cmd>lua require"grimoire".select_next_index()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(sbuf, 'n', config.results_move_up, '<cmd>lua require"grimoire".select_previous_index()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_buf_set_keymap(sbuf, 'n', config.edit_document, '<cmd>lua require"grimoire".edit_document()<CR>', {
        nowait = true, noremap = true, silent = true
    })

    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')
    
    show_results()

end

return {
    edit_document = edit_document, 
    grimoire = grimoire,
    jump_to_search = jump_to_search, 
    close_windows = close_windows,
    show_results = show_results,
    select_next_index = select_next_index,
    select_previous_index = select_previous_index, 
}

