local rbuf, rwin
local sbuf, swin
local spacer_buf, spacer_win
local selected_file_index = 0
local highlight_namespace
local result_list_length = 7  
local result_count = 0 

local storage_dir = "/Users/alans/grimoire/mdx_files"

-- TODO: Setup so that if you add spaces at the end of a string it does
-- not send a new search query 

local function close_windows()
    vim.api.nvim_win_close(spacer_win, true)
    vim.api.nvim_win_close(rwin, true)
    vim.api.nvim_win_close(swin, true)
end

local function open_search_window()
    sbuf = vim.api.nvim_create_buf(false, true)
    swin = vim.api.nvim_open_win(sbuf, true ,
            {style = "minimal",relative='win', row=0, col=0, width=80, height=1}
        )
    vim.api.nvim_command('au CursorMoved,CursorMovedI <buffer> lua require"grimoire".show_results()')

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
    vim.cmd('startinsert')
end

local function select_previous_index()
    if selected_file_index > 0 then
        selected_file_index = selected_file_index - 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
    end
end

local function select_next_index()
    if selected_file_index < math.min((result_count - 1), (result_list_length - 1)) then
        selected_file_index = selected_file_index + 1
        vim.api.nvim_buf_clear_namespace(rbuf, -1, 0, -1)
        vim.api.nvim_buf_add_highlight(rbuf, -1, 'GrimoireSelection', selected_file_index, 0, -1)
    end
end

local function open_file() 
    local file_name = vim.api.nvim_buf_get_lines(rbuf, selected_file_index, (selected_file_index + 1), true) 
    local file_path = storage_dir..'/'..file_name[1]
    document_buffer = vim.api.nvim_create_buf(false, true)
    document_window = vim.api.nvim_open_win(document_buffer, true ,
            {style = "minimal",relative='win', row=13, col=0, width=80, height=19}
        )
    -- vim.api.nvim_buf_set_lines(document_buffer, 9, 9, false, {file_path})
    vim.api.nvim_command('edit ' .. file_path) 
end

local function open_results_window()
  rbuf = vim.api.nvim_create_buf(false, true)
  rwin = vim.api.nvim_open_win(rbuf, false,
        {style = "minimal",relative='win', row=2, col=0, width=80, height=result_list_length}
    )
end

local function open_spacer_window()
    spacer_buf = vim.api.nvim_create_buf(false, true)
    spacer_win = vim.api.nvim_open_win(spacer_buf, false,
        {style = "minimal",relative='win', row=1, col=0, width=80, height=1}
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
end

local function grimoire()
    open_results_window()
    open_search_window()
    open_spacer_window()
    vim.api.nvim_buf_set_keymap(sbuf, 'i', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
    vim.api.nvim_buf_set_keymap(sbuf, 'n', '<F7>', '<cmd>lua require("grimoire").close_windows()<CR>', {})
end

return {
    grimoire = grimoire,
    close_windows = close_windows,
    open_file = open_file, 
    show_results = show_results,
    select_next_index = select_next_index,
    select_previous_index = select_previous_index, 
}

