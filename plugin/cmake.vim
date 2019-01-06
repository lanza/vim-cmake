" cmake.vim - Vim plugin to create a CMake project system
" Maintainer: Nathan Lanza <https://github.com/lanza>
" Version:    0.1


if exists("g:loaded_vim_cmake")
  finish
else
  let g:loaded_vim_cmake = 1
  call system("mkdir -p  ~/.local/share/vim-cmake")
endif

let g:cmake_target = ""

if filereadable("~/.local/share/vim-cmake/file")
  let s:cache_file = readfile("~/.local/share/vim-cmake/file")
  if len(s:cache_file)
    let g:cmake_target = s:cache_file[0]
  endif
endif

let g:cmake_export_compile_commands = 1
let g:cmake_build_dir = "build"
let g:cmake_generator = "Ninja"

function! s:cmake_configure_and_generate()
  let l:arguments = []
  let l:arguments += ["-G " . g:cmake_generator]
  let l:arguments += ["-DCMAKE_EXPORT_COMPILE_COMMANDS=ON"]
  let l:arguments += ["-DCMAKE_BUILD_TYPE=Debug"]

  let l:argument_string = join(l:arguments, " ")

  let l:command = 'cmake' . ' -B ' . g:cmake_build_dir . ' -S . ' . l:argument_string
  silent let l:res = system(l:command)
  echo l:res 
endfunction

function! s:cmake_build()
  let l:command = 'cmake --build ' . g:cmake_build_dir
  if g:cmake_target
    let l:command += ' ' . g:cmake_target
  endif
  silent let l:res = system(l:command)
  echo l:res
endfunction

function! s:cmake_target(target)
  let g:cmake_target = a:target
  let l:list = []
  call add(l:list, g:cmake_target)
  call writefile(l:list, "~/.local/share/vim-cmake/file")
endfunction

function! s:cmake_run()
  let l:command = 'build/' . g:cmake_target
  silent let l:res = system(l:command)
  echo l:res
endfunction

function! s:cmake_debug()
  let l:path = "build/" . g:cmake_target
  exec("GdbStartLLDB lldb " . l:path)
endfunction

command! -nargs=0 -complete=shellcmd CMakeDebug call s:cmake_debug()
command! -nargs=0 -complete=shellcmd CMakeRun call s:cmake_run()
command! -nargs=1 -complete=shellcmd CMakeTarget call s:cmake_target(<f-args>)
command! -nargs=0 -complete=shellcmd CMakeBuild call s:cmake_build()
command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()

if 0
  command! -nargs=1 -complete=shellcmd GdbStartLLDB call nvimgdb#Spawn('lldb', 'lldbwrap.sh', <q-args>)

  if !exists('g:nvimgdb_disable_start_keymaps') || !g:nvimgdb_disable_start_keymaps
    nnoremap <leader>dd :GdbStart gdb -q a.out
    nnoremap <leader>dl :GdbStartLLDB lldb a.out
    nnoremap <leader>dp :GdbStartPDB python -m pdb main.py
  endif
endif
