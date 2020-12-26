if exists('cv#App')
  finish
endif

source autoload/cv/TypeInfo.vim

let s:App = {}
let s:App.currentTarget = v:null
let s:App.breakpoints = []
let s:App.typeInfo = cv#TypeInfo#app()

function s:App.dumpBreakpoints()
  for breakpoint in self.breakpoints
    call breakpoint.dump()
  endfor
endfunction

function s:App.addBreakpoint(breakpoint)
  call assert_true(a:breakpoint.typeInfo == cv#TypeInfo#breakpoint(),
        \  "Invalid object passed to addBreakpoint")
  call add(self.breakpoints, a:breakpoint)
endf

function s:App.setCurrentDirectory(dir)
endf

function cv#App#create()
  let l:copy = deepcopy(s:App)
  return l:copy
endf

