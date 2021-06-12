local rbuf, rwin
local sbuf, swin
local spacer_buf, spacer_win
local document_buffer, document_window 
local selected_file_index = 0
local highlight_namespace
local result_list_length = 7  
local result_count = 0 
local console_buffer, console_window, console_terminal


local storage_dir = "/Users/alans/grimoire/mdx_files"

local function open_terminal_window()
    console_buffer = vim.api.nvim_create_buf(false, true)
    console_window = vim.api.nvim_open_win(console_buffer, true,
        {style = "minimal",relative='editor', row=0, col=84, width=20, height=22}
    )
    console_terminal = vim.api.nvim_open_term(console_buffer, {})
end


local function log(message)
    vim.api.nvim_chan_send(console_terminal, message)
end

-- TODO: Setup so that if you add spaces at the end of a string it does
-- not send a new search query 

local function close_windows()
    -- TODO: Make sure you can close windows if one is already 
    -- closed. 
    vim.api.nvim_win_close(spacer_win, true)
    vim.api.nvim_win_close(rwin, true)
    vim.api.nvim_win_close(swin, true)
    vim.api.nvim_win_close(document_window, true)
end

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {style = "minimal",relative='editor', row=0, col=0, width=80, height=1}
        )
    vim.cmd('startinsert')
end

local function show_file()
    local file_name = vim.api.nvim_buf_get_lines(rbuf, selected_file_index, (selected_file_index + 1), true) 
    local file_path = storage_dir..'/'..file_name[1]
    vim.api.nvim_set_current_win(document_window)
    vim.api.nvim_command('edit ' .. file_path) 
    vim.api.nvim_set_current_win(swin)
    log("hello, log") 
end

local function select_next_index()
    if selected_file_index < math.min((result_count - 1), (result_list_length - 1)) then
        -- selected_file_index = selected_file_index + 1
        -- vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        -- vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
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
        { style = "minimal",relative='editor', row=14, col=0, width=80, height=10 }
    )
    -- vim.api.nvim_put(vim.fn.readfile("/Users/alans/grimoire/mdx_files/99p_kowal.txt"), vim.fn.getregtype(), true, false)
end

local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  rwin = vim.api.nvim_open_win(rbuf, false,
        {style = "minimal",relative='editor', row=2, col=0, width=80, height=result_list_length}
    )
end

local function open_spacer_window()
    spacer_buf = vim.api.nvim_create_buf(false, true)
    spacer_win = vim.api.nvim_open_win(spacer_buf, false,
        {style = "minimal",relative='editor', row=1, col=0, width=80, height=1}
    )
    vim.api.nvim_buf_set_lines(spacer_buf, 0, 0, false, {'======================================================'})
end


local function show_results()
    selected_file_index = 0
    local query = vim.api.nvim_buf_get_lines(0, 0, 1, false)
    local query_string = string.gsub(query[1], '%s*$', '')
    local query_string2 = string.gsub(query_string, '%s', '%%20')
    local lines = vim.fn.systemlist('curl -s "http://127.0.0.1:7700/indexes/grimoire/search?q='..query_string2..'&limit='..result_list_length..'" | jq -r ".hits[] | .name"')
    vim.api.nvim_buf_set_lines(rbuf, 0, result_list_length, false, lines)
    result_count = #lines
    highlight_namespace = vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
    -- open_file()
    show_file()
end

local function grimoire()
    open_terminal_window()
    open_document_window()
    open_results_window()
    open_spacer_window()
    open_search_window()
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '[', '<cmd>lua require"grimoire".select_next_index()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '=', '<cmd>lua require"grimoire".select_previous_index()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'i', ']', '<cmd>lua require"grimoire".open_file()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')

    vim.api.nvim_buf_set_keymap(sbuf, 'n', '[', '<cmd>lua require"grimoire".select_next_index()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '=', '<cmd>lua require"grimoire".select_previous_index()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
    vim.api.nvim_buf_set_keymap(sbuf, 'n', ']', '<cmd>lua require"grimoire".open_file()<CR>', {
        nowait = true, 
        noremap = true, 
        silent = true
    })
end

return {
    grimoire = grimoire,
    close_windows = close_windows,
    open_file = open_file, 
    show_results = show_results,
    select_next_index = select_next_index,
    select_previous_index = select_previous_index, 
}

