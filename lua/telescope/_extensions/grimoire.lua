
local file_code_actions = function(opts)
    mw = 'asdf'
end

return require('telescope').register_extension{
  exports = {
    file_code_actions = file_code_actions 
  },
}

