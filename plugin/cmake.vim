" cmake.vim - Vim plugin to create a CMake project system
" Maintainer: Nathan Lanza <https://github.com/lanza>
" Version:    0.1

let s:App = {}

function! s:decode_json(string) abort
  if exists('*json_decode')
    return json_decode(a:string)
  endif
  let [null, false, true] = ['', 0, 1]
  let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
  if stripped !~# '[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]'
    try
      return eval(substitute(a:string,'[\r\n]',' ','g'))
    catch
    endtry
  endif
endfunction

function! s:encode_json(object) abort
  if exists('*json_encode')
    return json_encode(a:object)
  endif
  if type(a:object) == v:t_string
    return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
  elseif type(a:object) == v:t_list
    return '['.join(map(copy(a:object), 's:encode_json(v:val)'),', ').']'
  elseif type(a:object) == v:t_dict
    let pairs = []
    for key in keys(a:object)
      call add(pairs, s:encode_json(key) . ': ' . s:encode_json(a:object[key]))
    endfor
    return '{' . join(pairs, ', ') . '}'
  else
    return string(a:object)
  endif
endfunction


if exists('g:loaded_vim_cmake')
  finish
else
  let g:loaded_vim_cmake = 1
endif

let g:cmake_target = ''
let g:current_target_args = ''
let g:cmake_arguments = []

function! s:get_cache_file()
  if exists('g:cmake_cache_file')
    return g:cmake_cache_file
  endif
  let g:vim_cmake_cache_file_path = $HOME . '/.vim_cmake.json'
  if filereadable(g:vim_cmake_cache_file_path)
    let l:contents = readfile(g:vim_cmake_cache_file_path)
    let l:json_string = join(l:contents, "\n")

    let g:cmake_cache_file = s:decode_json(l:json_string)
  else
    let g:cmake_cache_file = s:decode_json('{}')
  endif
  return g:cmake_cache_file
endfunction

function! g:Parse_codemodel_json()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    echom 'Must configure and generate first'
    call s:assure_query_reply()
    return 0
  endif
  let g:cmake_query_response = l:build_dir . '/.cmake/api/v1/reply/'
  let l:codemodel_file = globpath(g:cmake_query_response, 'codemodel*')
  let l:codemodel_contents = readfile(l:codemodel_file)
  let l:json_string = join(l:codemodel_contents, "\n")

  if len(l:json_string) == 0
    return
  endif

  let l:data = s:decode_json(l:json_string)

  let l:configurations = l:data['configurations']
  let l:first_config = l:configurations[0]
  let l:targets_dicts = l:first_config['targets']


  let g:execs = []
  let g:tars = []
  let g:all_tars = []

  let g:tar_to_file = {}
  let g:file_to_tar = {}

  for target in targets_dicts
    let l:jsonFile = target['jsonFile']
    let l:name = target['name']
    let l:file = readfile(g:cmake_query_response . l:jsonFile)
    let l:json_string = join(l:file, "\n")
    let l:target_file_data = s:decode_json(l:json_string)
    if has_key(l:target_file_data, 'artifacts')
      let l:artifacts = l:target_file_data['artifacts']
      let l:artifact = l:artifacts[0]
      let l:path = l:artifact['path']
      let l:type = l:target_file_data['type']
      if l:type ==? 'Executable'
        call add(g:execs, {l:name : l:path})
      endif
      call add(g:tars, {l:name : l:path})
      let g:tar_to_file[l:name] = l:path
      let g:file_to_tar[l:path] = l:name
    else
      let l:type = l:target_file_data['type']
      call add(g:all_tars , {l:name : l:type})
    endif
  endfor
  return 1
endfunction

let s:cache_file = s:get_cache_file()
try
  let g:cmake_target = s:cache_file[getcwd()].current_target
catch /.*/
  let g:cmake_target = ''
endtry

let g:cmake_export_compile_commands = 1
let g:cmake_generator = 'Ninja'

function! s:make_query_files()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/query')
    call mkdir(l:build_dir . '/.cmake/api/v1/query', 'p')
  endif
  if !filereadable(l:build_dir . '/.cmake/api/v1/query/codemodel-v2')
    call writefile([' '], l:build_dir . '/.cmake/api/v1/query/codemodel-v2')
  endif
endfunction

function! s:assure_query_reply()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    call s:cmake_configure_and_generate()
  endif
endfunction

function! s:get_cmake_argument_string()
  call s:make_query_files()
  let l:arguments = []
  let l:arguments += g:cmake_arguments
  let l:arguments += ['-G ' . g:cmake_generator]
  let l:arguments += ['-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']
  let l:arguments += ['-DCMAKE_BUILD_TYPE=Debug']

  let l:argument_string = join(l:arguments, ' ')
  let l:command = l:argument_string . ' -B ' . s:get_build_dir() . ' -S ' . s:get_source_dir()
  return l:command
endfunction

function! s:cmdb_configure_and_generate()
  exec 'CMDB ' . s:get_cmake_argument_string()
endfunction

python3 << endpython
import os
import vim

def get_build_relative_path(build, path):
    path = os.path.relpath(path, build)
    vim.command('return "%s"' % path)

def get_path_to_current_buffer():
    path = vim.current.buffer.name
    vim.command('return "%s"' % path)
endpython

function! s:get_path_to_current_buffer()
  python3 get_path_to_current_buffer()
endfunction

function! s:get_build_relative_path(current_path)
  python3 get_build_relative_path(vim.call('s:get_build_dir()'), vim.eval('a:current_path'))
endfunction


function! s:cmake_compile_current_file()
  let l:current_path = s:get_path_to_current_buffer()
  let l:rel_path = s:get_build_relative_path(l:current_path)
  let &makeprg = 'ninja -C ' .  s:get_build_dir() . ' ' . l:rel_path . '^'
  Make
  if !has('gui_running')
    redraw!
  endif
endfunction

function g:CMake_configure_and_generate()
  call s:cmake_configure_and_generate()
endfunction
function! s:cmake_configure_and_generate()
  let l:command = 'cmake ' . s:get_cmake_argument_string()
  exe "vs | exe \"normal \<c-w>L\" | terminal " . l:command
  exe 'silent !test -L compile_commands.json || test -e compile_commands.json || ln -s ' . s:get_build_dir() . '/compile_commands.json .'
endfunction

function! s:cmake_build_current_target()
  call s:cmake_build_current_target_with_completion(v:null)
endf

function! s:cmake_build_current_target_with_completion(completion)
  call g:Parse_codemodel_json()
  if len(g:cmake_target) == 0
    echo 'Please select a target and try again.'
    call s:cmake_get_target_and_run_action(g:tars, 's:update_target')
    return
  endif

  let l:tar = ''
  " This needs to test if the g:cmake_target is a ninja target or an absolute
  " path. I'm not sure why it can be both, I should fix that...
  if g:cmake_target =~ s:get_build_dir()
    let l:key = substitute(g:cmake_target, s:get_build_dir() . '/', '', 0)
    let l:tar = g:file_to_tar[l:key]
  else
    let l:tar = g:cmake_target
  endif

  call s:_build_target_with_completion(l:tar, a:completion)
endfunction

func s:is_absolute_path(path)
  let l:is_absolute = execute("lua print(vim.startswith('" . a:path . "', '/'))")
  if l:is_absolute =~ "true"
    return 1
  else
    return 0
  endif
endfunction

function! s:_build_target(target)
  call s:_build_target_with_completion(a:target, v:null)
endf

function! s:_build_target_with_completion(target, completion)
  if s:is_absolute_path(s:get_build_dir())
    let l:directory = s:get_build_dir()
  else
    let l:cwd = getcwd()
    let l:directory = cwd . '/' . s:get_build_dir()
  endif

  if g:vim_cmake_build_tool ==? 'vsplit'
    let l:command = 'cmake --build ' . s:get_build_dir() . ' --target ' . a:target
    exe "vs | exe \"normal \<c-w>L\" | terminal " . l:command
  elseif g:vim_cmake_build_tool ==? 'vim-dispatch'
    let &makeprg = 'ninja -C ' . l:directory . ' ' . a:target
    Make
  elseif g:vim_cmake_build_tool ==? 'Makeshift'
    let &makeprg = 'ninja ' . a:target
    let b:makeshift_root = l:directory
    MakeshiftBuild
  elseif g:vim_cmake_build_tool ==? 'make'
    let &makeprg = 'ninja -C ' . l:directory . ' ' . a:target
    make
  elseif g:vim_cmake_build_tool ==? 'job'
    let l:cmd = 'ninja -C ' . l:directory . ' ' . a:target
    call jobstart(cmd, {"on_exit": a:completion })
  else
    echo 'Your g:vim_cmake_build_tool value is invalid. Please set it to either vsplit, Makeshift, vim-dispatch or make.'
  endif
endfunction

function! s:cmake_pick_and_build_target()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:names = []
  for target in g:tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  call fzf#run({'source': l:names, 'sink': function('s:_build_target'), 'down': len(l:names) + 2})
endfunction

function! s:cmake_build_non_artifacts()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:command = '!cmake --build ' . s:get_build_dir() . ' --target'
  let l:names = []
  for target in g:all_tars
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  call fzf#run({'source': l:names, 'sink': l:command , 'down': len(l:names) + 2})
  ". l:command
  " silent let l:res = system(l:command)
  " echo l:res
endfunction

if !exists('g:vim_cmake_build_tool')
  let g:vim_cmake_build_tool = 'vsplit'
endif

function! s:cmake_clean()
  let l:command = 'cmake --build ' . s:get_build_dir() . ' --target clean'
  exe "vs | exe \"normal \<c-w>L\" | terminal " . l:command
endfunction

function! s:cmake_build_all()
  if g:vim_cmake_build_tool ==? 'vsplit'
    " vsplit terminal implementation
    let l:command = 'cmake --build ' . s:get_build_dir()
    if g:cmake_target
      let l:command += ' --target ' . g:cmake_target
    endif
    exe "vs | exe \"normal \<c-w>L\" | terminal " . l:command
  elseif g:vim_cmake_build_tool ==? 'Makeshift'
    " Makeshift implementation
    let &makeprg = 'ninja'
    let cwd = getcwd()
    let b:makeshift_root = cwd . '/' . s:get_build_dir()
    MakeshiftBuild
  elseif g:vim_cmake_build_tool ==? 'vim-dispatch'
    " vim-dispatch implementation
    let cwd = getcwd()
    let &makeprg = 'ninja -C ' . cwd . '/' . s:get_build_dir()
    Make
  elseif g:vim_cmake_build_tool ==? 'make'
    " make implementation
    let cwd = getcwd()
    let &makeprg = 'ninja -C ' . cwd . '/' . s:get_build_dir()
    make
  else
    echo 'Your g:vim_cmake_build_tool value is invalid. Please set it to either vsplit, Makeshift, vim-dispatch or make.'
  endif

endfunction

function! s:update_cache_file()
  let cache = s:get_cache_file()
  let serial = s:encode_json(cache)
  let split = split(serial, '\n')
  call writefile(split, $HOME . '/.vim_cmake.json')
endfunction

function! s:cmake_pick_target()
  call g:Parse_codemodel_json()
  call s:cmake_get_target_and_run_action(g:tars, 's:update_target')
  call s:dump_current_target()
  return
  " if !g:Parse_codemodel_json()
  "   return
  " endif
  " let l:names = []
  " for target in g:tars
  "   let l:name = keys(target)[0]
  "   call add(l:names, l:name)
  " endfor

  " set makeprg=ninja
  " call fzf#run({'source': l:names, 'sink': function('s:update_target'), 'down': len(l:names) + 2})
endfunction

function! s:_run_current_target(job_id, data, event)
  if a:data == 0
    exe "vs | exe \"normal \<c-w>L\" | terminal " . g:cmake_target . " " . g:current_target_args
  endif
  let g:vim_cmake_build_tool = g:vim_cmake_build_tool_old
endf

function! s:cmake_run_current_target()
  if len(g:cmake_target) == 0
    echo 'Please select a target and try again.'
    call g:Parse_codemodel_json()
    call s:cmake_get_target_and_run_action(g:tars, 's:update_target')
  else
    let g:vim_cmake_build_tool_old = g:vim_cmake_build_tool
    let g:vim_cmake_build_tool = "job"
    call s:cmake_build_current_target_with_completion(function("s:_run_current_target"))
  endif
endfunction

function! s:update_target(target)
  let g:cmake_target = s:get_build_dir() . '/' . g:tar_to_file[a:target]

  let cache = s:get_cache_file()
  if !has_key(cache, getcwd())
    let cache[getcwd()] = {'current_target': g:cmake_target, 'targets':{}}
  else
    let dir = cache[getcwd()]
    let dir['current_target'] = g:cmake_target
  endif
  call s:update_cache_file()
endfunction

function! s:dump_current_target()
  echom "Current target set to '" . g:cmake_target . "' with args '" . g:current_target_args . "'"
endfunction

function! s:cmake_run_target_with_name(target)
  let s:cmake_target = s:get_build_dir() . '/' . g:tar_to_file[a:target]
  try
    exec '!cmake --build ' . s:get_build_dir() . ' --target ' . a:target
  catch /.*/
    echo 'Failed to build ' . a:target
  finally
    exe "vs | exe \"normal \<c-w>L\" | terminal " . s:cmake_target
  endtry
endfunction

function! s:cmake_pick_and_run_target()
  if !exists('g:execs')
    call g:Parse_codemodel_json()
  endif
  call s:cmake_get_target_and_run_action(g:execs, 's:cmake_run_target_with_name')
endfunction

function! s:cmake_get_target_and_run_action(target_list, action)
  if !g:Parse_codemodel_json()
    return
  endif
  let l:names = []
  for target in a:target_list
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  "call fzf#run({'source': l:names, 'sink': function('s:update_target'), 'down': len(l:names) + 2})
  call fzf#run({'source': l:names, 'sink': function(a:action), 'down': len(l:names) + 2})
endfunction

function! s:start_gdb(target)
  let l:args = ''
  try
    exec '!cmake --build ' . s:get_build_dir() . ' --target ' . a:target
  catch /.*/
    echo 'Failed to build ' . a:target
  finally
    if exists('l:init_file')
      let l:gdb_init_arg = ' -s /tmp/gdbinitvimcmake '
    else
      let l:gdb_init_arg = ''
    endif
    exec 'GdbStart gdb ' . s:get_build_dir() . '/' . a:target . l:gdb_init_arg . ' -- ' . l:args
  endtry
endfunction

function! s:start_lldb(target)
  let l:args = ''
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]['targets']
    if has_key(l:dir, s:get_build_dir() . '/' . a:target)
      let l:target = l:dir[s:get_build_dir() . '/' . a:target]
      " if has_key(l:target, 'args')
      "   let l:args = l:target['args']
      "   echo l:args
      " endif
      if has_key(l:target, 'breakpoints')
        let l:breakpoints = l:target['breakpoints']
        let l:commands = []
        for b in l:breakpoints
          if b['enabled']
            let break = 'b ' . b['text']
            call add(l:commands, break)
          endif
        endfor
        call add(l:commands, 'r')
        let l:init_file = '/tmp/lldbinitvimcmake'
        let l:f = writefile(l:commands, l:init_file)
      endif
    endif
  endif
  try
    exec '!cmake --build ' . s:get_build_dir() . ' --target ' . a:target
  catch /.*/
    echo 'Failed to build ' . a:target
  finally
    if exists('l:init_file')
      let l:lldb_init_arg = ' -s /tmp/lldbinitvimcmake '
    else
      let l:lldb_init_arg = ''
    endif
    exec 'GdbStartLLDB lldb ' . a:target . l:lldb_init_arg . ' -- ' . g:current_target_args
  endtry
endfunction

function! s:cmake_debug()
  if !g:Parse_codemodel_json()
    return
  endif
  let l:names = []

  for target in g:execs
    let l:name = values(target)[0]
    call add(l:names, l:name)
  endfor

  if g:cmake_target == ''
    if exists('g:vim_cmake_debugger')
      if g:vim_cmake_debugger ==? 'gdb'
        call fzf#run({'source': l:names, 'sink': function('s:start_gdb'), 'down': len(l:names) + 2})
      else
        call fzf#run({'source': l:names, 'sink': function('s:start_lldb'), 'down': len(l:names) + 2})
      endif
    endif
  else
    if exists('g:vim_cmake_debugger')
      if g:vim_cmake_debugger ==? 'gdb'
        call s:start_gdb(g:cmake_target)
      else
        call s:start_lldb(g:cmake_target)
      endif
    endif
  endif
endfunction

function! s:cmake_set_cmake_args(...)
  let g:cmake_arguments = a:000
endfunction

function! s:cmake_set_current_target_run_args(...)
  if g:cmake_target ==? ''
    call s:cmake_target()
    return
  endif
  let s = join(a:000, ' ')
  let c = s:get_target_cache()
  let c['args'] = s
  let g:current_target_args = s
  call s:update_cache_file()
  call s:dump_current_target()
endfunction

function!  s:get_targets_cache()
  let c = s:get_cwd_cache()
  if !has_key(c, 'targets')
    let c['targets'] = {}
  endif
  return c['targets']
endfunction

function! s:get_target_cache()
  let c = s:get_targets_cache()
  if !has_key(c, g:cmake_target)
    let c[g:cmake_target] = {}
  endif
  return c[g:cmake_target]
endfunction

function! s:cmake_create_file(...)
  if len(a:000) > 2 || len(a:000) == 0
    echo 'CMakeCreateFile requires 1 or 2 arguments: e.g. Directory File for `Directory/File.{cpp,h}`'
    return
  endif

  if len(a:000) == 2
    let l:header = "include/" . a:1 . "/" . a:2 . ".h"
    let l:source = "lib/" . a:1 . "/" . a:2 . ".cpp"
    silent exec "!touch " . l:header
    silent exec "!touch " . l:source
  elseif len(a:000) == 1
    let l:header = "include/" . a:1 . ".h"
    let l:source = "lib/" . a:1 . ".cpp"
    silent exec "!touch " . l:header
    silent exec "!touch " . l:source
  end

endfunction

function! s:cmake_set_build_dir(...)
  let dir = a:1
  let c = s:get_cwd_cache()
  let c['build_dir'] = dir
  call s:update_cache_file()
endfunction

function! s:cmake_set_source_dir(...)
  let dir = a:1
  let c = s:get_cwd_cache()
  let c['source_dir'] = dir
  call s:update_cache_file()
endfunction

function! s:get_cwd_cache()
  let c = s:get_cache_file()
  if !has_key(c, getcwd())
    let c[getcwd()] = {'targets' : {}}
  endif
  return c[getcwd()]
endfunction

function! s:get_source_dir()
  let c = s:get_cwd_cache()
  if !has_key(c, 'source_dir')
    let c['source_dir'] = '.'
  endif
  return c['source_dir']
endfunction

function! s:get_build_dir()
  let c = s:get_cwd_cache()
  if !has_key(c, 'build_dir')
    let c['build_dir'] = 'build/Debug'
  endif
  return c['build_dir']
endfunction


command! -nargs=* -complete=shellcmd CMakeSetCMakeArgs call s:cmake_set_cmake_args(<f-args>)
command! -nargs=1 -complete=shellcmd CMakeSetBuildDir call s:cmake_set_build_dir(<f-args>)
command! -nargs=1 -complete=shellcmd CMakeSetSourceDir call s:cmake_set_source_dir(<f-args>)

command! -nargs=0 -complete=shellcmd CMakeConfigureAndGenerate call s:cmake_configure_and_generate()
command! -nargs=0 -complete=shellcmd CMDBConfigureAndGenerate call s:cmdb_configure_and_generate()

command! -nargs=0 -complete=shellcmd CMakeCompileCurrentFile call s:cmake_compile_current_file()
command! -nargs=0 -complete=shellcmd CMakeDebugWithNvimLLDB call s:cmake_debug()

command! -nargs=0 -complete=shellcmd CMakePickTarget call s:cmake_pick_target()
command! -nargs=0 -complete=shellcmd CMakeRunCurrentTarget call s:cmake_run_current_target()
command! -nargs=* -complete=shellcmd CMakeSetCurrentTargetRunArgs call s:cmake_set_current_target_run_args(<f-args>)
command! -nargs=0 -complete=shellcmd CMakeBuildCurrentTarget call s:cmake_build_current_target()

command! -nargs=0 -complete=shellcmd CMakeClean call s:cmake_clean()
command! -nargs=0 -complete=shellcmd CMakeBuildAll call s:cmake_build_all()

command! -nargs=0 -complete=shellcmd CMakeCompileCurrentFile call s:cmake_compile_current_file()

command! -nargs=* -complete=shellcmd CMakeCreateFile call s:cmake_create_file(<f-args>)

