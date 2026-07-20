
vim.g.mapleader = " "
vim.g.maplocalleader = " "

if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
  require("config.windows")
elseif vim.fn.has("macunix") == 1 then
  require("config.macos")
else
  require("config.linux")
end

