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

let g:cmake_tool = 'cmake'
let g:cmake_window_id = -1
let g:cmake_target_file = v:null
let g:cmake_target_relative = v:null
let g:cmake_target_name = v:null
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


" this needs to be wrapped due to the need to use on_exit to pipeline the config
function! s:_do_parse_codemodel_json()
  let l:build_dir = s:get_build_dir()
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
      call add(g:tars , {l:name : ""})
    endif
  endfor
  return 1
endf

function! g:Parse_codemodel_json()
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    echom 'Must configure and generate first'
    call s:assure_query_reply_with_completion(function('s:_do_parse_codemodel_json'))
  endif
  return s:_do_parse_codemodel_json()
endfunction

function! s:do_all_completions(...)
  for Completion in a:000
    if type(Completion) == v:t_func
      call Completion()
    endif
  endfor
endfunction

function! s:compose_completions(outer, inner)
  call a:outer(a:inner)
endfunction

function! s:parse_codemodel_json_with_completion(completion)
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    call s:assure_query_reply_with_completion(function('s:do_all_completions', [function('s:_do_parse_codemodel_json'), a:completion]))
  else
    call s:_do_parse_codemodel_json()
    call a:completion()
  endif
endfunction

let s:cache_file = s:get_cache_file()
let g:cmake_cache_file = s:cache_file

" this shouldn't be here...
try
  let g:cmake_target_file = s:cache_file[getcwd()].current_target
  let g:cmake_target_relative = s:cache_file[getcwd()].current_target_relative
  let g:cmake_target_name = s:cache_file[getcwd()].current_target_name
catch /.*/
  let g:cmake_target_file = v:null
  let g:cmake_target_relative = v:null
  let g:cmake_target_name = v:null
endtry
try
  let g:current_target_args = s:cache_file[getcwd()]["targets"][g:cmake_target_file].args
catch /.*/
  let g:current_target_args = ''
endtry
try
  let g:cmake_arguments = s:cache_file[getcwd()]["cmake_args"]
catch /.*/
  let g:cmake_arguments = []
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

function! s:assure_query_reply_with_completion(completion)
  let l:build_dir = s:get_build_dir()
  if !isdirectory(l:build_dir . '/.cmake/api/v1/reply')
    call s:cmake_configure_and_generate_with_completion(a:completion)
  else
    call a:completion()
  endif
endfunction

function! s:get_cmake_argument_string()
  call s:make_query_files()
  let l:arguments = []
  let l:arguments += g:cmake_arguments
  let l:arguments += ['-G ' . g:cmake_generator]
  let l:arguments += ['-DCMAKE_EXPORT_COMPILE_COMMANDS=ON']

  let found_source_dir_arg = v:false
  let found_build_dir_arg = v:false
  let found_cmake_build_type = v:false
  for arg in g:cmake_arguments
    if (arg =~ "CMAKE_BUILD_TYPE")
      let found_cmake_build_type = v:true
    elseif (arg =~ "-S")
      let found_source_dir_arg = v:true
    elseif (arg =~ "-B")
      let found_build_dir_arg = v:true
    elseif (isdirectory(arg) && filereadable(arg . "/CMakeLists.txt"))
      let found_source_dir_arg = v:true
    endif
  endfor

  if !found_cmake_build_type
    let l:arguments += ['-DCMAKE_BUILD_TYPE=Debug']
  endif

  if !found_build_dir_arg
    let l:arguments += ['-B', s:get_build_dir()]
  endif

  if !found_source_dir_arg
    let l:arguments += ['-S', s:get_source_dir()]
  endif

  let l:command = join(l:arguments, ' ')
  return l:command
endfunction

function! s:cmdb_configure_and_generate()
  exec 'CMDB ' . s:get_cmake_argument_string()
endfunction

" python3 << endpython
" import os
" import vim

" def get_build_relative_path(build, path):
"     path = os.path.relpath(path, build)
"     vim.command('return "%s"' % path)

" def get_path_to_current_buffer():
"     path = vim.current.buffer.name
"     vim.command('return "%s"' % path)
" endpython

" function! s:get_path_to_current_buffer()
"   python3 get_path_to_current_buffer()
" endfunction

" function! s:get_build_relative_path(current_path)
"   python3 get_build_relative_path(vim.call('s:get_build_dir()'), vim.eval('a:current_path'))
" endfunction


function! s:cmake_compile_current_file()
  echom "This is not currently working"
  " let l:current_path = s:get_path_to_current_buffer()
  " let l:rel_path = s:get_build_relative_path(l:current_path)
  " let &makeprg = 'ninja -C ' .  s:get_build_dir() . ' ' . l:rel_path . '^'
  " Make
  " if !has('gui_running')
  "   redraw!
  " endif
endfunction

function g:CMake_configure_and_generate()
  call s:cmake_configure_and_generate()
endfunction

function! s:check_if_window_is_alive(win)
  if index(nvim_list_wins(), a:win) > -1
    return v:true
  else
    return v:false
  endif
endf

function! s:check_if_buffer_is_alive(buf)
  if index(nvim_list_bufs(), a:buf) > -1
    return v:true
  else
    return v:false
  endif
endf

" close the current window and open a new one
" This is a hack for now because I don't feel like figuring out how to clean a
" dirty buffer and termopen refuses to open in a dirty buffer
function! s:get_only_window()
  call s:close_last_window_if_open()
  call s:close_last_buffer_if_open()
  exe "vs | wincmd L | enew"
  let g:cmake_last_window = nvim_get_current_win()
  let g:cmake_last_buffer = nvim_get_current_buf()
endf

function! s:cmake_configure_and_generate()
  call s:cmake_configure_and_generate_with_completion(s:noop)
endfunction

function! s:cmake_configure_and_generate_with_completion(completion)
  let l:command = g:cmake_tool . " " . s:get_cmake_argument_string()
  call s:get_only_window()
  echo l:command
  call termopen(split(l:command), {'on_exit': a:completion})
  " let l:link_cc_path = getcwd() . '/' . s:get_source_dir() . '/compile_commands.json'
  " let l:build_cc_path = getcwd() . '/' . s:get_build_dir() . '/compile_commands.json'
  " exe 'silent !test -L ' . l:link_cc_path . ' || test -e ' . l:link_cc_path . ' || ln -s ' . l:build_cc_path . .'
endf


function! s:cmake_build_current_target()
  call s:cmake_build_current_target_with_completion(s:noop)
endf

function! s:_do_build_current_target()
  call s:_do_build_current_target_with_completion(s:noop)
endfunction

function! s:noop_function(...)
endfunction

let s:noop = function('s:noop_function')

function! s:_do_build_current_target_with_completion(completion)
  if g:cmake_target_name == v:null
    echo "Please select a target first"
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

  call s:_build_target_with_completion(g:cmake_target_name, a:completion)
endfunction

function! s:cmake_build_current_target_with_completion(completion)
  call s:parse_codemodel_json_with_completion(function('s:compose_completions', [function('s:_do_build_current_target_with_completion'), a:completion]))
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

let g:cmake_last_window = v:null
let g:cmake_last_buffer = v:null

function! s:_build_target_with_completion(target, completion)
  if s:is_absolute_path(s:get_build_dir())
    let l:directory = s:get_build_dir()
  else
    let l:cwd = getcwd()
    let l:directory = cwd . '/' . s:get_build_dir()
  endif

  if g:vim_cmake_build_tool ==? 'vsplit'
    let l:command = 'cmake --build ' . s:get_build_dir() . ' --target ' . a:target
    call s:get_only_window()
    call termopen(l:command, { "on_exit": a:completion })
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
    if g:cmake_target_file
      let l:command += ' --target ' . g:cmake_target_file
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

function! s:save_cache_file()
  call s:update_cache_file()
endfunction

function! s:update_cache_file()
  let cache = s:get_cache_file()
  let serial = s:encode_json(cache)
  let split = split(serial, '\n')
  call writefile(split, $HOME . '/.vim_cmake.json')
endfunction

function! s:cmake_pick_target()
  call s:parse_codemodel_json_with_completion(function('s:_do_cmake_pick_target'))
endf

function! s:cmake_pick_executable_target()
  call s:parse_codemodel_json_with_completion(function('s:_do_cmake_pick_executable_target'))
endf

function! s:_do_cmake_pick_executable_target()
  call s:cmake_get_target_and_run_action(g:execs, 's:update_target')
  call s:dump_current_target()
endfunction

function! s:_do_cmake_pick_target()
  call s:cmake_get_target_and_run_action(g:tars, 's:update_target')
  call s:dump_current_target()
endfunction

function s:cmake_close_windows()
  call s:close_last_window_if_open()
  call s:close_last_buffer_if_open()
endf

function! s:close_last_window_if_open()
  if s:check_if_window_is_alive(g:cmake_last_window)
    call nvim_win_close(g:cmake_last_window, v:true)
  endif
endf

function! s:close_last_buffer_if_open()
  if s:check_if_buffer_is_alive(g:cmake_last_buffer)
    call nvim_buf_delete(g:cmake_last_buffer, {"force": v:true})
  endif
endf

function! s:_run_current_target(job_id, exit_code, event)
  call s:close_last_window_if_open()
  if a:exit_code == 0
    call s:get_only_window()
    exe "terminal \"" . g:cmake_target_file . "\" " . g:current_target_args
  endif
  let g:vim_cmake_build_tool = g:vim_cmake_build_tool_old
endf

function! s:_do_run_current_target()
  if g:cmake_target_file == ''
    call s:cmake_get_target_and_run_action(g:tars, 's:update_target')
  endif
  if g:vim_cmake_build_tool != "vsplit"
    let g:vim_cmake_build_tool_old = g:vim_cmake_build_tool
    let g:vim_cmake_build_tool = "vsplit"
  else
    let g:vim_cmake_build_tool_old = g:vim_cmake_build_tool
  endif
  call s:cmake_build_current_target_with_completion(function("s:_run_current_target"))
endfunction

function! s:cmake_run_current_target()
  call s:parse_codemodel_json_with_completion(function("s:_do_run_current_target"))
endfunction

function! s:update_target(target)
  let g:cmake_target_name = a:target
  if has_key(g:tar_to_file, a:target)
    let g:cmake_target_relative = g:tar_to_file[a:target]
    let g:cmake_target_file = s:get_build_dir() . '/' . g:tar_to_file[a:target]
  else
    let g:cmake_target_relative = ""
    let g:cmake_target_file = ""
  end

  let cache = s:get_cache_file()
  if !has_key(cache, getcwd())
    let cache[getcwd()] = {'current_target': g:cmake_target_file, 'targets':{}}
    let cache[getcwd()] = {'current_target_relative': g:cmake_target_relative, 'targets':{}}
    let cache[getcwd()] = {'current_target_name': g:cmake_target_name, 'targets':{}}
  else
    let dir = cache[getcwd()]
    let dir['current_target'] = g:cmake_target_file
    let dir['current_target_relative'] = g:cmake_target_relative
    let dir['current_target_name'] = g:cmake_target_name
  endif
  call s:update_cache_file()
endfunction

function! s:dump_current_target()
  echo "Current target set to '" . g:cmake_target_file . "' with args '" . g:current_target_args . "'"
endfunction

function! s:cmake_run_target_with_name(target)
  let s:cmake_target = s:get_build_dir() . '/' . g:tar_to_file[a:target]
  try
    exec '!cmake --build ' . s:get_build_dir() . ' --target ' . a:target
  catch /.*/
    echo 'Failed to build ' . a:target
  finally
    call s:get_only_window()
    exe "terminal " . s:cmake_target
  endtry
endfunction

function! s:cmake_pick_and_run_target()
  if !exists('g:execs')
    call g:Parse_codemodel_json()
  endif
  call s:cmake_get_target_and_run_action(g:execs, 's:cmake_run_target_with_name')
endfunction

function! s:cmake_get_target_and_run_action(target_list, action)
  let l:names = []
  for target in a:target_list
    let l:name = keys(target)[0]
    call add(l:names, l:name)
  endfor

  set makeprg=ninja
  call fzf#run({'source': l:names, 'sink': function(a:action), 'down': len(l:names) + 2})
endfunction

function! s:start_gdb(job_id, exit_code, event)
  if a:exit_code != 0
    return
  endif
  let l:commands = ['b main', 'r']
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]['targets']
    if has_key(l:dir, s:get_build_dir() . '/' . g:cmake_target_file)
      let l:target = l:dir[s:get_build_dir() . '/' . g:cmake_target_file]
      if has_key(l:target, 'breakpoints')
        let l:breakpoints = l:target['breakpoints']
        for b in l:breakpoints
          if b['enabled']
            let break = 'b ' . b['text']
            call add(l:commands, break)
          endif
        endfor
        call add(l:commands, 'r')
      endif
    endif
  endif

  let l:init_file = '/tmp/gdbinitvimcmake'
  let l:f = writefile(l:commands, l:init_file)

  call s:close_last_window_if_open()
  call s:close_last_buffer_if_open()

  let l:gdb_init_arg = ' -x /tmp/ginitvimcmake '
  exec 'GdbStart gdb ' . g:cmake_target_file . l:gdb_init_arg . ' -- ' . g:current_target_args
endfunction

function! s:start_lldb(job_id, exit_code, event)
  if a:exit_code != 0
    return
  endif
  let l:commands = ["breakpoint set --func-regex '^main$'", 'r']
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]['targets']
    if has_key(l:dir, s:get_build_dir() . '/' . g:cmake_target_file)
      let l:target = l:dir[s:get_build_dir() . '/' . g:cmake_target_file]
      if has_key(l:target, 'breakpoints')
        let l:breakpoints = l:target['breakpoints']
        for b in l:breakpoints
          if b['enabled']
            let break = 'b ' . b['text']
            call add(l:commands, break)
          endif
        endfor
        call add(l:commands, 'r')
      endif
    endif
  endif

  let l:init_file = '/tmp/lldbinitvimcmake'
  let l:f = writefile(l:commands, l:init_file)

  call s:close_last_window_if_open()
  call s:close_last_buffer_if_open()

  if exists('l:init_file')
    let l:lldb_init_arg = ' -s /tmp/lldbinitvimcmake '
  else
    let l:lldb_init_arg = ''
  endif
  exec 'GdbStartLLDB lldb ' . g:cmake_target_file . l:lldb_init_arg . ' -- ' . g:current_target_args
endfunction

function! s:start_nvim_dap_lldb_vscode(job_id, exit_code, event)
  if a:exit_code != 0
    return
  endif
  let l:commands = ["breakpoint set --func-regex '^main$'", 'r']
  let l:data = s:get_cache_file()
  if has_key(l:data, getcwd())
    let l:dir = l:data[getcwd()]['targets']
    if has_key(l:dir, s:get_build_dir() . '/' . g:cmake_target_file)
      let l:target = l:dir[s:get_build_dir() . '/' . g:cmake_target_file]
      if has_key(l:target, 'breakpoints')
        let l:breakpoints = l:target['breakpoints']
        for b in l:breakpoints
          if b['enabled']
            let break = 'b ' . b['text']
            call add(l:commands, break)
          endif
        endfor
      endif
    endif
  endif

  let l:init_file = '/tmp/lldbinitvimcmake'
  let l:f = writefile(l:commands, l:init_file)

  call s:close_last_window_if_open()
  call s:close_last_buffer_if_open()

  if exists('l:init_file')
    let l:lldb_init_arg = ' /tmp/lldbinitvimcmake '
  else
    let l:lldb_init_arg = ''
  endif
  exec 'DebugLldb ' . g:cmake_target_file . ' --lldbinit ' . l:lldb_init_arg . ' -- ' . g:current_target_args
  " exec 'DebugLldb ' . g:cmake_target . l:lldb_init_arg . ' -- ' . g:current_target_args
endfunction

function! s:cmake_debug_current_target_nvim_dap_lldb_vscode()
  let g:vim_cmake_debugger = 'nvim_dap_lldb_vscode'
  call s:cmake_debug_current_target()
endf

function! s:cmake_debug_current_target_lldb()
  let g:vim_cmake_debugger = 'lldb'
  call s:cmake_debug_current_target()
endf

function! s:cmake_debug_current_target_gdb()
  let g:vim_cmake_debugger = 'gdb'
  call s:cmake_debug_current_target()
endf

function! s:cmake_debug_current_target()
  call s:parse_codemodel_json_with_completion(function("s:_do_debug_current_target"))
endfunction

function! s:_do_debug_current_target()
  if g:cmake_target_file == v:null || get(g:tar_to_file, g:cmake_target_name, v:null) == v:null
    echo "Please select a target first"
    call s:cmake_get_target_and_run_action(g:execs, 's:update_target')
    return
  endif

  if exists('g:vim_cmake_debugger')
    if g:vim_cmake_debugger ==? 'gdb'
      call s:cmake_build_current_target_with_completion(function('s:start_gdb'))
    elseif g:vim_cmake_debugger ==? 'lldb'
      call s:cmake_build_current_target_with_completion(function('s:start_lldb'))
    else
      call s:cmake_build_current_target_with_completion(function('s:start_nvim_dap_lldb_vscode'))
    endif
  endif
endfunction

function! s:cmake_set_cmake_args(...)
  let g:cmake_arguments = a:000
  let c = s:get_cwd_cache()
  let c['cmake_args'] = a:000
  call s:update_cache_file()
endfunction

function! g:GetCMakeArgs()
  return get(s:get_cwd_cache(), "cmake_args", [])
endfunction

function! s:cmake_set_current_target_run_args(args)
  if g:cmake_target_file ==? ''
    call s:cmake_target()
    return
  endif
  let s = a:args
  let c = s:get_target_cache()
  let c['args'] = s
  let g:current_target_args = s
  call s:update_cache_file()
  call s:dump_current_target()
endfunction

function! g:GetCMakeCurrentTargetRunArgs()
  let c = s:get_target_cache()
  return get(c, 'args', "")
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
  if !has_key(c, g:cmake_target_file)
    let c[g:cmake_target] = {}
  endif
  return c[g:cmake_target_file]
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
  let g:cmake_build_dir = dir
  call s:update_cache_file()
endfunction

function! s:cmake_set_source_dir(...)
  let dir = a:1
  let c = s:get_cwd_cache()
  let c['source_dir'] = dir
  let g:cmake_source_dir = dir
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

function g:GetCMakeSourceDir()
  return s:get_source_dir()
endfunction

function g:GetCMakeBuildDir()
  return s:get_build_dir()
endfunction

function! s:get_build_dir()
  let c = s:get_cwd_cache()
  if !has_key(c, 'build_dir')
    if exists("g:cmake_default_build_dir")
      let c['build_dir'] = g:cmake_default_build_dir
    else
      let c['build_dir'] = 'build/Debug'
    endif
  endif
  return c['build_dir']
endfunction

function! s:cmake_open_cache_file()
  exe 'e ' . s:get_build_dir() . '/CMakeCache.txt'
endf

command! -nargs=1 -complete=shellcmd CMakeOpenCacheFile call s:cmake_open_cache_file()

command! -nargs=* -complete=shellcmd CMakeSetCMakeArgs call s:cmake_set_cmake_args(<f-args>)
command! -nargs=1 -complete=shellcmd CMakeSetBuildDir call s:cmake_set_build_dir(<f-args>)
command! -nargs=1 -complete=shellcmd CMakeSetSourceDir call s:cmake_set_source_dir(<f-args>)

command! -nargs=0  CMakeConfigureAndGenerate call s:cmake_configure_and_generate()
command! -nargs=1 -complete=shellcmd CMDBConfigureAndGenerate call s:cmdb_configure_and_generate()

command! -nargs=0 CMakeCompileCurrentFile call s:cmake_compile_current_file()
command! -nargs=0 CMakeDebugWithNvimLLDB call s:cmake_debug_current_target_lldb()
command! -nargs=0 CMakeDebugWithNvimGDB call s:cmake_debug_current_target_gdb()
command! -nargs=0 CMakeDebugWithNvimDapLLDBVSCode call s:cmake_debug_current_target_nvim_dap_lldb_vscode()

command! -nargs=0 CMakePickTarget call s:cmake_pick_target()
command! -nargs=0 CMakePickExecutableTarget call s:cmake_pick_executable_target()
command! -nargs=0 CMakeRunCurrentTarget call s:cmake_run_current_target()
command! -nargs=* -complete=shellcmd CMakeSetCurrentTargetRunArgs call s:cmake_set_current_target_run_args(<q-args>)
command! -nargs=0 CMakeBuildCurrentTarget call s:cmake_build_current_target()

command! -nargs=1 -complete=shellcmd CMakeClean call s:cmake_clean()
command! -nargs=1 -complete=shellcmd CMakeBuildAll call s:cmake_build_all()

command! -nargs=1 -complete=shellcmd CMakeCompileCurrentFile call s:cmake_compile_current_file()

command! -nargs=* -complete=shellcmd CMakeCreateFile call s:cmake_create_file(<f-args>)

command! -nargs=1 -complete=shellcmd CMakeCloseWindow call s:cmake_close_windows()

