



function s:do_thing(completion)
  return a:completion(4)
endfunction


function s:add_four(value)
  return a:value + 4
endf

echom s:do_thing({arg -> s:add_four(arg)})



let things = [1,2,3]
echom index(things, 4)

