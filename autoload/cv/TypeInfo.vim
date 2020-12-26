" if exists("cv#TypeInfo")
"   finish
" endif

function cv#TypeInfo#target()
  return -1
endf

function cv#TypeInfo#breakpoint()
  return -2
endf

function cv#TypeInfo#app()
  return -3
endf

function cv#TypeInfo#cmakeState()
  return -4
endf
