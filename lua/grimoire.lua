local cjson = require "cjson"

local highlight_namespace
local result_count = 0 
local console_buffer, console_window, console_terminal
local base_width = vim.api.nvim_win_get_width(0)
local base_height = vim.api.nvim_win_get_height(0)
local result_list_length = base_height - 5 
result_list_length = 10
local current_search_query = ''
local current_result_set = {} 

local config = {}

config.streamer_mode_filters = {
    'work-',
    'apple'
}

config.keys = {}
config.keys.create_new_file = '∂' -- Option + d (document creation)
config.results_move_down = '<M-LEFT>' -- AWS: Enter + j
config.results_move_up = '<M-RIGHT>' -- AWS: Enter + k
config.edit_document = '<CR>'
config.jump_to_search = 'ƒ' -- Option + f (find)
config.keys.save_and_quit = '∫' -- Option + b (bail)

config.storage_dir = "/Users/alans/grimoire/mdx_files"
config.log_file_path = '/Users/alans/Library/Logs/Grimoire/neovim-grimoire.log'
config.debug = true  

local state = {
    selection_index = 0,
} 

------------------------------------------------
-- VERSION 1 Goals 
------------------------------------------------
-- [x] Search and show results 
-- [x] Provide nav to move and up and down search results 
-- [x] Show selected result in document window 
-- [x] Be able to edit document in document window 
-- [x] Save the file 
-- [x] Update the search index on file changes
-- [x] If no search, show nothing in document
-- [x] Clear search on moving back to it. 
-- [x] Make sure files are saved on exit (e.g. if you exit while still in the document window)
-- [x] Deal with empty query results
-- [ ] Filter to remove certain results based on straing matches (streamer mode)

------------------------------------------------
-- VERSION 2 Goals 
------------------------------------------------
-- [ ] Make new files (with template)
-- [ ] Setup config file
-- [ ] Delete files
-- [ ] Rename files 
-- [ ] Make sure that if you undo after jumping to the file it doesn't blank the content

------------------------------------------------
-- Other/Misc 
------------------------------------------------
-- [ ] When you go back to the search window, clear it, but not the results or document. And, have a hotkey to get back to the document and maybe restore the serach.
-- [ ] Store files in directories based off the first two words
-- [ ] Look into debouncing keystrokes after the first key
-- [ ] If there is nothing in the search window don't allow switcing to the document window
-- [ ] If there are no results, don't let enter move you to the document window
-- [x] Have Enter/Return switch to document window when pressed in search window 
-- [ ] On save, run greps through the file looking for patterns and if they match fire off to external scripts
-- [x] Setup so if there are no results it shows a window saying that in both results and the document
-- [ ] See if there's a way to insert a few millisecond delay so that while you're typing it doesn't slow down opening files (may not be worth doing)
-- [x] Setup so `:q` closes all windows (saving the file first, or blocking if it's not ready) 
-- [x] Setup so `:w` saves a file 
-- [ ] Periodically rebuild the search index
-- [ ] See if passing results as a table instead of line by line makes it faster
-- [x] Limit search query to the number of results that can be displayed
-- [ ] Prevent search from going to second line
-- [ ] Don't send a new request if nothing has changed (e.g. it's just a space or normal mode updates)
-- [ ] Figure out how to get syntax highlighting in code fences 
-- [ ] Switch to using native Lua http call instead of shelling out to curl to see if it's faster
-- [x] Default to wordwrap
-- [x] Maybe just set the window size directly
-- [x] Add a log function
-- [x] Setup debug flag for logs 
-- [ ] Show list of recent files (and their searches) with hotkeys to get back to
-- [ ] Full screen toggle that also switches off wordwrap. Bascially a way to go from prose to code
-- [ ] Auto-disable wordwrap in code fences/code blocks (if that's possible? with softwarp)
-- [ ] Generate symbolic links based of patterns for posting to the site
-- [ ] Start up debug version of the site for preview
-- [ ] Highlight the border of the window you're currently in 
-- [ ] Hide YAML Headers (except for title)
-- [ ] Setup hotkey to toggle word wrap 
-- [ ] Setup multiple window option for horizontal and/or vertical 
-- [ ] Repopulate search with an escape (or something) when you go back to it
-- [ ] Setup so the search results stay when moving back to search even though it clears
-- [ ] Trigger a site build and deploy on file changes
-- [ ] Change `dd` in the search buffer so it returns to insert mode after clearing the line
-- [ ] Setup hotkey to jump to code blocks and auto highlight them 
-- [ ] Setup hotkey to execute code blocks and put resutls into a results code block if one exists
-- [ ] Make sure you can't add multiple lines in the search buffer
-- [ ] Hotkeys to copy stuff out to OS pasteboards
-- [ ] Look at `nofile` for search and resutls windows
-- [ ] Setup so whitespace at the end of queries is removed (and doesn't send a new query)
-- [ ] Auto-publish to twitter when you make a post 
-- [ ] Setup filter lists for modes where things get excluded from search (e.g. streamer mode)
-- [ ] Only turn on hot keys when you're in the app (this might already be in place)
-- [ ] Prevent closing one window without closing all
-- [ ] Setup so files are stored in a directory with the first word/token as the name 
-- [ ] Multiple templates for opening files (a default should open with a hot key then another hotkey to open a template selector)
-- [ ] Make sure multiple instances can run at the same time (realizing small chance of editing the same file at the same time)
-- [ ] Deal with windows that get resized
-- [ ] Disable `:w` in the search window
-- [ ] Remember the line number for each file for a specific amount of time
-- [ ] Don't re-render the document windnow if the selected document hasn't changed 
-- [ ] Deal with files that are deleted outside neovim
-- [ ] Automatically update `Updated:` metadata in the header 
-- [ ] Add Markdown Table Formatter type functionlity 
-- [ ] If you're insert mode in the search bar and hit option f (i.e. `ƒ`) it throws an error 
-- [ ] Setup a hotkey to jump down to code snippets and highlight them so you can just copy
-- [ ] Add example files 

------------------------------------------------

local function log(message)
    if config.debug then 
        local log_file = io.open(config.log_file_path, "a")
        io.output(log_file)
        io.write(os.date("%c").."|INFO|"..message.."\n")
        io.close(log_file)
    end
end

local function current_file_path()
    state.active_file_name = current_result_set[state.selection_index + 1]['name']
    state.active_file_id = current_result_set[state.selection_index + 1]['id'] 
    local file_name = current_result_set[state.selection_index + 1]['name']
    local file_path = config.storage_dir..'/'..file_name
    return file_path
end

local function close_windows()
    vim.api.nvim_command('au! WinClosed <buffer='..sbuf..'>')
    vim.api.nvim_command('au! CursorMoved,CursorMovedI <buffer='..sbuf..'>')
    if (preview_buffer ~= vim.api.nvim_win_get_buf(document_window)) then 
        -- Prevent closing the window from calling close again 
        vim.api.nvim_command('au! WinClosed <buffer='..vim.api.nvim_win_get_buf(document_window)..'>')
        vim.api.nvim_set_current_win(document_window)
        vim.api.nvim_command('write')
        vim.api.nvim_buf_delete(vim.api.nvim_win_get_buf(document_window), {})
        vim.api.nvim_buf_delete(preview_buffer, { force=true })
    else 
        vim.api.nvim_buf_delete(preview_buffer, { force=true })
    end
    log("Trying to clsose buffer: "..rbuf)
    vim.api.nvim_buf_delete(rbuf, { force=true })
    vim.api.nvim_buf_delete(sbuf, { force=true })
    vim.api.nvim_command('stopinsert')
end

local function create_new_file()
    state.active_file_name = vim.api.nvim_buf_get_lines(sbuf, 0, 1, true)[1] .. ".mdx"
    state.active_file_id = os.time() 
    if new_file_base_name ~= '' then 
        local new_file_path = config.storage_dir .. '/' .. state.active_file_name 
        log("Creating file: "..new_file_path)
        vim.api.nvim_set_current_win(document_window)
        vim.api.nvim_command('e '.. new_file_path)
        vim.api.nvim_buf_set_keymap(0, 'i', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
            nowait = true, noremap = true, silent = true
        })
        vim.api.nvim_buf_set_keymap(0, 'n', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
            nowait = true, noremap = true, silent = true
        })
    else
        log("Won't create file with no name")
    end
end

local function edit_document() 
    vim.api.nvim_set_current_win(document_window)
    vim.api.nvim_command('edit '..current_file_path())
    vim.api.nvim_buf_set_keymap(0, 'i', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(0, 'n', config.jump_to_search, '<cmd>lua require"grimoire".jump_to_search()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(0, 'i', '∫', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(0, 'n', '∫', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_command('stopinsert')
    vim.api.nvim_win_set_cursor(0, {1, 0})
    log("----- edit_document ------")
    edit_buffer = vim.api.nvim_win_get_buf(document_window)
    vim.api.nvim_command('au WinClosed <buffer> lua require"grimoire".close_windows()')
end

local function jump_to_search() 
    -- Write the file
    vim.api.nvim_command('write!')

    -- Get the updated data
    local data_to_update_with = vim.api.nvim_buf_get_lines(0, 0, -1, true) 

    -- Push the updated data to the preview buffer 
    vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, data_to_update_with)
    vim.api.nvim_win_set_buf(document_window, preview_buffer)
    vim.api.nvim_buf_delete(edit_buffer, {})

    -- Make a string to hold the data for the search engine update 
    local data_as_string = ''

    -- Push the data onto the search string
    for i = 1, #data_to_update_with do  
        data_as_string = data_as_string..data_to_update_with[i].." "
    end

    -- Remove anything that's not a s letter or dash so you can send without further encoding
    data_as_string = string.gsub(data_as_string, '[^a-zA-Z-]', ' ')

    -- Setup the curl call
    local update_index_call = string.format(
        [[curl -X POST 'http://127.0.0.1:7700/indexes/grimoire/documents' --data '[{ "id": %d, "name": "%s", "overview": "%s" }]']], 
        state.active_file_id,
        state.active_file_name,
        data_as_string
    )

    log("Updating Search Engine With: "..update_index_call)
    vim.fn.systemlist(update_index_call)
    vim.api.nvim_set_current_win(swin)
    vim.api.nvim_command('startinsert')
end

local function make_new_file()
    log("TKTKTKTKT: Making new file")
end

local function open_document_window()
    preview_buffer = vim.api.nvim_create_buf(false, true)
    log("Preview Buffer ID: "..preview_buffer)
    document_window = vim.api.nvim_open_win(preview_buffer, true,
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
    vim.api.nvim_win_set_option(rwin, 'wrap', false)
end

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {
                style="minimal", relative='editor', row=0, col=0, 
                width=base_width - 2, height=1, border='single'
            }
        )
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '∫', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '∫', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.results_move_down, '<cmd>lua require"grimoire".select_next_index()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.results_move_up, '<cmd>lua require"grimoire".select_previous_index()<CR>', {
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
    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.edit_document, '<cmd>lua require"grimoire".edit_document()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'i', config.keys.create_new_file, '<cmd>lua require"grimoire".create_new_file()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'n', config.keys.create_new_file, '<cmd>lua require"grimoire".create_new_file()<CR>', {
        nowait = true, noremap = true, silent = true
    })
    vim.cmd('startinsert')
    -- vim.api.nvim_command('au WinClosed <buffer> lua require"grimoire".process_quit()')
    -- vim.api.nvim_command('au! WinClosed <buffer>')
    -- vim.api.nvim_command('au WinClosed <buffer> echo "asdfasdfasdf"')
end

local function show_file()
    -- log("Calling: show_file()")
    if current_search_query ~= '' then 
        if #current_result_set > 0 then  
            log("Showing file: "..current_file_path())
                -- THIS DOESN'T WORK FOR SOME REASON 
                -- vim.api.nvim_set_current_win(document_window)
                -- vim.api.nvim_command('edit ' .. current_file_path())
                -- vim.api.nvim_set_current_win(swin)

             local file = io.open(current_file_path(), "r")
             local lines_table = {}
             for line in file:lines() do
                 table.insert(lines_table, line)
             end
             vim.api.nvim_win_set_cursor(document_window, {1, 0})
             vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, {})
             vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, lines_table)
        else 
            vim.api.nvim_win_set_cursor(document_window, {1, 0})
            vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, {})
            vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, { "---  Nothing to see here  ---"} )
        end
    else
        vim.api.nvim_win_set_cursor(document_window, {1, 0})
        local header_text = {
            "", "", "", "",
"                     ---  Grimoire  ---"
        }
        vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(preview_buffer, 0, -1, false, header_text)
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
    query_string = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    query_string = string.gsub(query_string, '%s*$', '')
    query_string = string.gsub(query_string, '%s', '%%20')
    query_string = string.gsub(query_string, '"', '')
    current_search_query = query_string
    return query_string 
end

local function fetch_results()
    local search_query = 'curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..current_query_string()..'&limit='..result_list_length..'"'
    log("Calling: "..search_query)
    local raw_json = vim.fn.systemlist(search_query)
    local json_data = cjson.decode(raw_json[1])

    local block_patterns = config.streamer_mode_filters
    -- block_patterns = { 'work-' } 
    
    current_result_set = {} 
    for i=1, #json_data['hits'] do
        local document_is_safe = true 
        for block_id = 1, #block_patterns do 
            local item_name = string.lower(json_data['hits'][i]['name'])
            local item_overview = string.lower(json_data['hits'][i]['overview'])
            local block_item = string.lower(block_patterns[block_id])
            log("Block item: " .. block_item)
            if string.find(item_name, block_item) then 
                document_is_safe = false
            end 
            if string.find(item_overview, block_item) then 
                document_is_safe = false
            end 
        end
        if document_is_safe == true then 
            current_result_set[#current_result_set+1] = json_data['hits'][i]
        end
    end 

    -- current_result_set = json_data['hits']
end

local function process_quit() 
    log("Processing quit")
end

local function show_results()
    window_list = vim.api.nvim_list_wins()
    for i = 1, #window_list do
        log(window_list[i])
    end
    buffer_list = vim.api.nvim_list_bufs()
    for i = 1, #buffer_list do
        log(buffer_list[i])
    end
    state.selection_index = 0 
    fetch_results()
    if current_search_query ~= '' then 
        if #current_result_set > 0 then
            local number_of_result_lines = math.min(result_list_length, #current_result_set)
            vim.api.nvim_buf_set_lines(rbuf, 0, result_list_length, false, {})
            for i = 1, number_of_result_lines do
                vim.api.nvim_buf_set_lines(rbuf, i - 1, i, false, { current_result_set[i]['name'] })
            end
            log("number of result lines: "..#current_result_set)
            result_count = #current_result_set 
            highlight_namespace = vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', state.selection_index, 0, -1)
            show_file()
        else
            vim.api.nvim_buf_set_lines(rbuf, 0, result_list_length, false, {})
            vim.api.nvim_buf_set_lines(rbuf, 0, -1, false, { "No results"})
            show_file()
        end
    else
        local symbol_start = {
"",
"",
"        <--.",
"   <-.   <  )  ;`a__",
"      \\___|  )/ /--\" ~~",
"       \\__|___)/",
"        \\~   \\~",
"",
"  ~~ Begin Your Search ~~",  
}
        vim.api.nvim_buf_set_lines(rbuf, 0, -1, true, {})
        vim.api.nvim_buf_set_lines(rbuf, 0, 8, false, symbol_start )
        show_file()
    end

end

local function grimoire()
    log("Grimoire Activated")
    open_document_window()
    open_results_window()
    open_search_window()
    vim.api.nvim_buf_set_keymap(preview_buffer, 'i', '<F8>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(preview_buffer, 'n', '<F8>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')
    vim.api.nvim_command([[au WinClosed <buffer> lua require"grimoire".close_windows()]])
    show_results()
end

return {
    close_windows = close_windows,
    create_new_file = create_new_file, 
    edit_document = edit_document, 
    grimoire = grimoire,
    jump_to_search = jump_to_search, 
    log = log, 
    process_quit = process_quit,
    select_next_index = select_next_index,
    select_previous_index = select_previous_index, 
    show_results = show_results,
}

