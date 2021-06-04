
local commands = function(opts)
  pickers.new(opts, {
    prompt_title = 'ConfigPicker',
    finder = finders.new_table {
      results = {
         "path/to/file"
      },
      entry_maker = opts.entry_maker,
    },
  }):find()
end

return require('telescope').register_extension{
  exports = {
    commands = commands 
  },
}

