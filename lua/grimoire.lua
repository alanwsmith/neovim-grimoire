local sbuf, swin
local document_buffer, document_window 
local selected_file_index = 0
local highlight_namespace
local result_count = 0 
local console_buffer, console_window, console_terminal

local base_width = vim.api.nvim_win_get_width(0)
local base_height = vim.api.nvim_win_get_height(0)
local result_list_length = base_height - 5 

local current_file_name
local current_file_path

local current_search_query = ''

local config = {}

config.results_move_down = '<C-j>'
config.results_move_up = '<C-k>'
config.edit_document = '<C-l>'
config.jump_to_search = '<C-l>'

local storage_dir = "/Users/alans/grimoire/mdx_files"

------------------------------------------------
-- VERSION 1 Requirements 
------------------------------------------------
-- [x] Search and show results 
-- [x] Provide nav to move and up and down search results 
-- [x] Show selected result in document window 
-- [x] Be able to edit document in document window 
-- [x] Save the file 
-- [ ] Update the search index 
-- [ ] Make new files 
-- [ ] Make sure it doesn't try to save empty
-- [ ] If no search, show nothing in document
-- [ ] Clear search on moving back to it. 


------------------------------------------------
-- VERSION 2 Requirements 
------------------------------------------------
-- [ ] Delete files
-- [ ] Rename files 


------------------------------------------------
-- Misc 
------------------------------------------------
-- [ ] Look at `nofile` for search and resutls windows
-- [ ] Setup so `:q` closes all windows 
-- [ ] Setup so whitespace at the end of queries is removed
-- [ ] Don't send a new request if nothing has changed (e.g. it's just a space)
-- [ ] Setup config file
-- [ ] Only turn on hot keys when you're in the app 
-- [ ] Save the last search and return to it when you reopen
-- [ ] Show list of recent files (and their searches) with hotkeys to get back to
-- [ ] Setup filter lists for modes where things get excluded from search (e.g. streamer mode)
-- [ ] Deal with windows that get resized
-- [ ] Prevent closing one window without closing all
-- [ ] Setup so files are stored in a directory with the first word/token as the name 


------------------------------------------------



local function edit_document() 
    vim.api.nvim_set_current_win(document_window)
    vim.api.nvim_command('set buftype=""')
    vim.api.nvim_command('file '..current_file_path)
    vim.api.nvim_command('stopinsert')
end

local function jump_to_search() 
    vim.api.nvim_command('write!')
    vim.api.nvim_buf_set_lines(sbuf, 0, -1, false, {})
    vim.api.nvim_set_current_win(swin)
    vim.api.nvim_command('startinsert')
end


local function close_windows()
    vim.api.nvim_win_close(rwin, true)
    vim.api.nvim_buf_delete(rbuf, { force=true })
    vim.api.nvim_win_close(swin, true)
    vim.api.nvim_buf_delete(sbuf, { force=true })
    vim.api.nvim_win_close(document_window, true)
    vim.api.nvim_buf_delete(document_buffer, { force=true })
    vim.api.nvim_command('stopinsert')
    -- vim.api.nvim_win_close(console_window, true)
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
    -- TODO: Deal with no matches / no file

    if current_search_query ~= '' then 
        current_file_name = vim.api.nvim_buf_get_lines(rbuf, selected_file_index, (selected_file_index + 1), true)
        current_file_path = storage_dir..'/'..current_file_name[1]
        local file = io.open(current_file_path, "r")
        local lines_table = {}
        for line in file:lines() do
            table.insert(lines_table, line)
        end
        vim.api.nvim_buf_set_lines(document_buffer, 0, -1, false, {})
        vim.api.nvim_buf_set_lines(document_buffer, 0, -1, false, lines_table)
    end
end

local function select_next_index()
    if selected_file_index < math.min((result_count - 1), (result_list_length - 1)) then
        selected_file_index = selected_file_index + 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
        show_file()
    end
end

local function select_previous_index()
    if selected_file_index > 0 then
        selected_file_index = selected_file_index - 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
        show_file()
    end
end

-- TODO: Remove this when show_file() is done
local function open_document_window()
    document_buffer = vim.api.nvim_create_buf(false, true)
    document_window = vim.api.nvim_open_win(document_buffer, true ,
        { 
            style="minimal", relative='editor', row=3, 
            col=math.floor(base_width / 4) + 2, 
            width=math.floor(base_width / 4 * 3) - 3,
            height=base_height - 5, border='single'
        }
    )
end

local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  rwin = vim.api.nvim_open_win(rbuf, false,
        {
            style="minimal", relative='editor', row=3, col=0, 
            width=math.floor(base_width / 4), height=base_height - 5,
            border='single'
        }
    )
end

local function show_results()
    selected_file_index = 0
    local query = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    local query_string = string.gsub(query[1], '%s*$', '')
    local query_string2 = string.gsub(query_string, '%s', '%%20')
    current_search_query = query_string2 
    local lines = vim.fn.systemlist('curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..query_string2..'&limit='..result_list_length..'" | jq -r ".hits[] | .name"')
    vim.api.nvim_buf_set_lines(rbuf, 0, result_list_length, false, lines)
    result_count = #lines
    highlight_namespace = vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
    show_file()
end

local function grimoire()
    open_document_window()
    open_results_window()
    open_search_window()
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(rbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(rbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(document_buffer, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
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
    open_file = open_file, 
    show_results = show_results,
    select_next_index = select_next_index,
    select_previous_index = select_previous_index, 
}

