" if exists('g:cv#vim_cmake')
"   finish
" endif
let g:cv#vim_cmake = {}

source autoload/cv/TypeInfo.vim
source autoload/cv/CMakeState.vim
source autoload/cv/Target.vim
source autoload/cv/App.vim
source autoload/cv/Breakpoint.vim

let g:cvapp = cv#App#create()

let g:cvtarget = cv#Target#create("Muffin", ".")


function g:CMakeToggleBreakpoint()
  let l:currentPosition = getcurpos()
  let l:bufferNumber = l:currentPosition[0]
  let l:lineNumber = l:currentPosition[1]
  let l:column = l:currentPosition[2]
  let l:offset = l:currentPosition[3]
  let l:curswant = l:currentPosition[4]

  let l:breakpoint = cv#Breakpoint#create(expand("%"), l:lineNumber, l:column)
  call g:cvapp.addBreakpoint(l:breakpoint)
endf




call g:cvtarget.setArgs("-cc1 /tmp/test.c")
call g:cvtarget.dump()

call g:CMakeToggleBreakpoint()

call g:cvapp.dumpBreakpoints()
