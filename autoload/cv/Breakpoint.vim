if exists('cv#Breakpoint')
  finish
endif

source autoload/cv/TypeInfo.vim

let s:Breakpoint = {}
let s:Breakpoint.typeInfo = cv#TypeInfo#breakpoint()

function s:Breakpoint.dump()
  echom "Breakpoint: " . self.file . ':' . self.line
endf

function cv#Breakpoint#create(file, line, column)
  let l:copy = deepcopy(s:Breakpoint)
  let l:copy.file = a:file
  let l:copy.line = a:line
  let l:copy.column = a:column
  return l:copy
endf

