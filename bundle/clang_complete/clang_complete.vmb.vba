" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
autoload/getopts/cache.vim	[[[1
92
" clang_complete include paths caching helper
" Author: xaizek, leszekswirski

let s:scr = expand('<sfile>')
let s:cache_path = fnamemodify(s:scr, ':p:h')

function! getopts#cache#getcachedopts(ext, optfunc)
  let s:cache = s:cache_path . '/' . &filetype . '.' . a:ext . '.cache'
  if !s:CacheExists()
    call s:CreateCache(a:optfunc)
  endif
  call s:ReadCache()
  call s:AppendOptions()
endfunction

function! ClearIncludeCaches()
  let l:cache_files = split(globpath(s:cache_path, '*.cache', 1), "\n")
  for l:cache_file in l:cache_files
    call delete(l:cache_file)
  endfor
  unlet! s:opts
endfunction

function! getopts#cache#getlangname()
  if &filetype == 'c'
    let l:lang_name = 'c'
  elseif &filetype == 'cpp'
    let l:lang_name = 'c++'
  elseif &filetype == 'objc'
    let l:lang_name = 'objective-c'
  elseif &filetype == 'objcpp'
    let l:lang_name = 'objective-c++'
  elseif
    let l:lang_name = 'none'
  endif
  return l:lang_name
endfunction

function! s:CacheExists()
  if !filereadable(s:cache)
    return 0
  endif

  let l:lines = readfile(s:cache)

  for l:line in l:lines
    let l:line = substitute(l:line, '^\s\+', '', '')
    if l:line =~ '^-I' && !isdirectory(l:line[2:])
      return 0
    endif
  endfor

  return len(l:lines) > 0
endfunction

function! s:CreateCache(optfunc)
  let s:opts = s:GetOptions(a:optfunc)
  call writefile(s:opts, s:cache)
endfunction

function! s:GetOptions(optfunc)
  let l:out = split(system(a:optfunc), "\n")

  while !empty(l:out) && l:out[0] !~ '^#include <...>'
    let l:out = l:out[1:]
  endwhile
  if !empty(l:out)
    let l:out = l:out[1:]
  endif

  let l:result = []
  while !empty(l:out) && l:out[0] !~ '^End of search list.$'
    let l:inc_path = substitute(l:out[0], '^\s*', '', '')
    let l:inc_path = fnamemodify(l:inc_path, ':p')
    let l:inc_path = substitute(l:inc_path, '\', '/', 'g')

    if isdirectory(l:inc_path)
      call add(l:result, '-I' . l:inc_path)
    endif

    let l:out = l:out[1:]
  endwhile
  return l:result
endfunction

function! s:ReadCache()
  let s:opts = readfile(s:cache)
endfunction

function! s:AppendOptions()
  let b:clang_user_options .= ' ' . join(s:opts, ' ')
endfunction
autoload/getopts/clang.vim	[[[1
9
" clang_complete clang's include paths finder
" Author: leszekswirski

function! getopts#clang#getopts()
  let l:optfunc = 'echo | clang -v -E -x ' . getopts#cache#getlangname() . ' -'
  call getopts#cache#getcachedopts('clang', l:optfunc)
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
autoload/getopts/gcc.vim	[[[1
9
" clang_complete gcc's include paths finder
" Author: leszekswirski

function! getopts#gcc#getopts()
  let l:optfunc = 'echo | gcc -v -E -x ' . getopts#cache#getlangname() . ' -'
  call getopts#cache#getcachedopts('gcc', l:optfunc)
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
autoload/snippets/clang_complete.vim	[[[1
113
" clang_complete clang_complete's snippet generator
" Author: Xavier Deguillard, Philippe Vaucher

function! snippets#clang_complete#init()
  noremap <expr> <silent> <buffer> <tab> UpdateSnips()
  snoremap <expr> <silent> <buffer> <tab> UpdateSnips()
  if g:clang_conceal_snippets == 1
    augroup ClangCompleteSnippets
      " the check for b:clang_user_options is to do not define anything on
      " buffers that are not supported by clang_complete
      autocmd! Syntax *
             \ if exists('b:clang_user_options') |
             \   call <SID>UpdateConcealSyntax() |
             \ endif
    augroup END
    call s:UpdateConcealSyntax()
  endif
endfunction

function! s:UpdateConcealSyntax()
  syntax match Conceal /<#/ conceal
  syntax match Conceal /#>/ conceal
endfunction

" fullname = strcat(char *dest, const char *src)
" args_pos = [ [8, 17], [20, 34] ]
function! snippets#clang_complete#add_snippet(fullname, args_pos)
  let l:res = ''
  let l:prev_idx = 0
  for elt in a:args_pos
    let l:res .= a:fullname[l:prev_idx : elt[0] - 1] . '<#' . a:fullname[elt[0] : elt[1] - 1] . '#>'
    let l:prev_idx = elt[1]
  endfor

  let l:res .= a:fullname[l:prev_idx : ]
  if g:clang_trailing_placeholder == 1 && len(a:args_pos) > 0
    let l:res .= '<##>'
  endif

  return l:res
endfunction

function! snippets#clang_complete#trigger()
  call s:BeginSnips()
endfunction

function! snippets#clang_complete#reset()
endfunction


" ---------------- Helpers ----------------

function! UpdateSnips()
  let l:line = getline('.')
  let l:pattern = '<#[^#]*#>'
  if match(l:line, l:pattern) == -1
    return "\<c-i>"
  endif

  let l:commands = ""
  if mode() != 'n'
      let l:commands .= "\<esc>"
  endif

  let l:commands .= ":call MoveToCCSnippetBegin()\<CR>"
  let l:commands .= "m'"
  let l:commands .= ":call MoveToCCSnippetEnd()\<CR>"

  if &selection == "exclusive"
    let l:commands .= "ll"
  else
    let l:commands .= "l"
  endif

  let l:commands .= "v`'o\<C-G>"

  return l:commands
endfunction

function! MoveToCCSnippetBegin()
  let l:pattern = '<#'
  let l:line = getline('.')
  let l:startpos = col('.') + 1
  let l:ind = match(l:line, l:pattern, l:startpos)
  if l:ind == -1
    let l:ind = match(l:line, l:pattern, 0)
  endif
  call cursor(line('.'), l:ind + 1)
endfunction

function! MoveToCCSnippetEnd()
  let l:line = getline('.')
  let l:pattern = '#>'
  let l:startpos = col('.') + 1

  call cursor(line('.'), match(l:line, l:pattern, l:startpos) + 1)
endfunction

function! s:BeginSnips()
  if pumvisible() != 0
    return
  endif

  " Do we need to launch UpdateSnippets()?
  let l:line = getline('.')
  let l:pattern = '<#[^#]*#>'
  if match(l:line, l:pattern) == -1
    return
  endif
  call feedkeys("\<esc>^\<tab>")
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
autoload/snippets/dummy.vim	[[[1
24
" Prepare the snippet engine
function! snippets#dummy#init()
  echo 'Initializing stuffs'
endfunction

" Add a snippet to be triggered
" fullname: contain an unmangled name. ex: strcat(char *dest, const char *src)
" args_pos: contain the position of the argument in fullname. ex [ [8, 17], [20, 34] ]
" Returns: text to be inserted for when trigger() is called
function! snippets#dummy#add_snippet(fullname, args_pos)
  echo 'Creating snippet for "' . a:fullname
  return a:fullname
endfunction

" Trigger the snippet
" Note: usually as simple as triggering the tab key
function! snippets#dummy#trigger()
  echo 'Triggering snippet'
endfunction

" Remove all snippets
function! snippets#dummy#reset()
  echo 'Resetting all snippets'
endfunction
autoload/snippets/snipmate.vim	[[[1
50
" clang_complete snipmate's snippet generator
" Author: Philippe Vaucher

function! snippets#snipmate#init()
  call snippets#snipmate#reset()
endfunction

" fullname = strcat(char *dest, const char *src)
" args_pos = [ [8, 17], [20, 34] ]
function! snippets#snipmate#add_snippet(fullname, args_pos)
  " If we are already in a snipmate snippet, well not much we can do until snipmate supports nested snippets
  if exists('g:snipPos')
    return a:fullname
  endif

  let l:snip = ''
  let l:prev_idx = 0
  let l:snip_idx = 1
  for elt in a:args_pos
    let l:snip .= a:fullname[l:prev_idx : elt[0] - 1] . '${' . l:snip_idx . ':' . a:fullname[elt[0] : elt[1] - 1] . '}'
    let l:snip_idx += 1
    let l:prev_idx = elt[1]
  endfor

  let l:snip .= a:fullname[l:prev_idx : ] . '${' . l:snip_idx . '}'

  let l:snippet_id = substitute(a:fullname, ' ', '_', 'g')

  call MakeSnip(&filetype, l:snippet_id, l:snip)

  return l:snippet_id
endfunction

function! snippets#snipmate#trigger()
  " If we are already in a snipmate snippet, well not much we can do until snipmate supports nested snippets
  if exists('g:snipPos')
    return
  endif

  " Trigger snipmate
  call feedkeys("\<Tab>", 't')
endfunction

function! snippets#snipmate#reset()
  " Quick & Easy way to prevent snippets to be added twice
  " Ideally we should modify snipmate to be smarter about this
  call ReloadSnippets(&filetype)
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
autoload/snippets/ultisnips.vim	[[[1
38
" clang_complete ultisnips's snippet generator
" Author: Philippe Vaucher

function! snippets#ultisnips#init()
  exe "UltiSnipsAddFiletypes ".&filetype.".clang_complete"
  call snippets#ultisnips#reset()
endfunction

" fullname = strcat(char *dest, const char *src)
" args_pos = [ [8, 17], [20, 34] ]
function! snippets#ultisnips#add_snippet(fullname, args_pos)
  let l:snip = ''
  let l:prev_idx = 0
  let l:snip_idx = 1
  for elt in a:args_pos
    let l:snip .= a:fullname[l:prev_idx : elt[0] - 1] . '${' . l:snip_idx . ':' . a:fullname[elt[0] : elt[1] - 1] . '}'
    let l:snip_idx += 1
    let l:prev_idx = elt[1]
  endfor

  let l:snip .= a:fullname[l:prev_idx : ] . '${' . l:snip_idx . '}'

  let l:snippet_id = substitute(a:fullname, ' ', '_', 'g')

  call UltiSnips_AddSnippet(l:snippet_id, l:snip, a:fullname, 'i', "clang_complete")

  return l:snippet_id
endfunction

function! snippets#ultisnips#trigger()
  call UltiSnips_ExpandSnippet()
endfunction

function! snippets#ultisnips#reset()
  python UltiSnips_Manager.clear_snippets(ft="clang_complete")
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
bin/cc_args.py	[[[1
87
#!/usr/bin/env python
#-*- coding: utf-8 -*-

import os
import sys

CONFIG_NAME = ".clang_complete"

def readConfiguration():
  try:
    f = open(CONFIG_NAME, "r")
  except IOError:
    return []

  result = []
  for line in f.readlines():
    strippedLine = line.strip()
    if len(strippedLine) > 0:
      result += [strippedLine]
  f.close()
  return result

def writeConfiguration(lines):
  f = open(CONFIG_NAME, "w")
  f.writelines(lines)
  f.close()

def parseArguments(arguments):
  nextIsInclude = False
  nextIsDefine = False
  nextIsIncludeFile = False

  includes = []
  defines = []
  include_file = []

  for arg in arguments:
    if nextIsInclude:
      includes += [arg]
      nextIsInclude = False
    elif nextIsDefine:
      defines += [arg]
      nextIsDefine = False
    elif nextIsIncludeFile:
      include_file += [arg]
      nextIsIncludeFile = False
    elif arg == "-I":
      nextIsInclude = True
    elif arg == "-D":
      nextIsDefine = True
    elif arg[:2] == "-I":
      includes += [arg[2:]]
    elif arg[:2] == "-D":
      defines += [arg[2:]]
    elif arg == "-include":
      nextIsIncludeFile = True

  result = list(map(lambda x: "-I" + x, includes))
  result.extend(map(lambda x: "-D" + x, defines))
  result.extend(map(lambda x: "-include " + x, include_file))

  return result

def mergeLists(base, new):
  result = list(base)
  for newLine in new:
    try:
      result.index(newLine)
    except ValueError:
      result += [newLine]
  return result

configuration = readConfiguration()
args = parseArguments(sys.argv)
result = mergeLists(configuration, args)
writeConfiguration(map(lambda x: x + "\n", result))


import subprocess
proc = subprocess.Popen(sys.argv[1:])
ret = proc.wait()

if ret is None:
  sys.exit(1)
sys.exit(ret)

# vim: set ts=2 sts=2 sw=2 expandtab :
doc/clang_complete.txt	[[[1
363
*clang_complete.txt*	For Vim version 7.3.  Last change: 2012 Jul 29


		  clang_complete plugin documentation


clang_complete plugin		      		*clang_complete*

1. Description		|clang_complete-description|
2. Completion kinds    	|clang_complete-compl_kinds|
3. Configuration	|clang_complete-configuration|
4. Options		|clang_complete-options|
5. Known issues		|clang_complete-issues|
6. PCH      		|clang_complete-pch|
7. cc_args.py script	|clang_complete-cc_args|
8. To do		|clang_complete-todo|
9. FAQ			|clang_complete-faq|
10. License		|clang_complete-license|

Author: Xavier Deguillard <deguilx@gmail.com>	*clang_complete-author*

==============================================================================
1. Description 					*clang_complete-description*

This plugin use clang for accurately completing C and C++ code.

Note: This plugin is incompatible with omnicppcomplete due to the
unconditionnaly set mapping done by omnicppcomplete. So don't forget to
suppress it before using this plugin.

==============================================================================
2. Completion kinds    				*clang_complete-compl_kinds*

Because libclang provides a lot of information about completion, there are
some additional kinds of completion along with standard ones (see
|complete-items| for details):
 '+' - constructor
 '~' - destructor
 'e' - enumerator constant
 'a' - parameter ('a' from "argument") of a function, method or template
 'u' - unknown or buildin type (int, float, ...)
 'n' - namespace or its alias
 'p' - template ('p' from "pattern")

==============================================================================
3. Configuration				*clang_complete-configuration*

Each project can have a .clang_complete at his root, containing the compiler
options. This is useful if you're using some non-standard include paths or
need to specify particular architecture type, frameworks to use, path to
precompiled headers, precompiler definitions etc.

Note that as with other option sources, .clang_complete file is loaded and
parsed by the plugin only on buffer loading (or reloading, for example with
:edit! command). Thus no changes made to .clang_complete file after loading
source file into Vim's buffer will take effect until buffer will be closed and
opened again, reloaded or Vim is restarted.

Compiler options should go on individual lines (multiple options on one line
can work sometimes too, but since there are some not obvious conditions for
that, it's better to have one option per line).

Linking isn't performed during completion, so one doesn't need to specify any
of linker arguments in .clang_complete file. They will lead to completion
failure when using clang executable and will be completely ignored by
libclang.

Example .clang_complete file: >
 -DDEBUG
 -include ../config.h
 -I../common
 -I/usr/include/c++/4.5.3/
 -I/usr/include/c++/4.5.3/x86_64-slackware-linux/
<
==============================================================================
4. Options					*clang_complete-options*

       				       	*clang_complete-auto_select*
				       	*g:clang_auto_select*
If equal to 0, nothing is selected.
If equal to 1, automatically select the first entry in the popup menu, but
without inserting it into the code.
If equal to 2, automatically select the first entry in the popup menu, and
insert it into the code.
Default: 0

       				       	*clang_complete-complete_auto*
       				       	*g:clang_complete_auto*
If equal to 1, automatically complete after ->, ., ::
Default: 1

       				       	*clang_complete-copen*
       				       	*g:clang_complete_copen*
If equal to 1, open quickfix window on error.
Default: 0

       				       	*clang_complete-hl_errors*
       				       	*g:clang_hl_errors*
If equal to 1, it will highlight the warnings and errors the same way clang
does it.
Default: 1

       				       	*clang_complete-periodic_quickfix*
       				       	*g:clang_periodic_quickfix*
If equal to 1, it will periodically update the quickfix window.
Default: 0
Note: You could use the g:ClangUpdateQuickFix() to do the same with a mapping.

       				       	*clang_complete-snippets*
       				       	*g:clang_snippets*
If equal to 1, it will do some snippets magic after a ( or a , inside function
call. Not currently fully working.
Default: 0

				       	*clang_complete-snippets_engine*
				       	*g:clang_snippets_engine*
The snippets engine (clang_complete, snipmate, ultisnips... see the snippets
subdirectory).
Default: "clang_complete"

       				       	*clang_complete-conceal_snippets*
       				       	*g:clang_conceal_snippets*
Note: This option is specific to clang_complete snippets engine.
If equal to 1, clang_complete will use vim 7.3 conceal feature to hide <#
and #> which delimit snippet placeholders.

Example of conceal configuration (see |'concealcursor'| and |'conceallevel'|
for details): >
 " conceal in insert (i), normal (n) and visual (v) modes
 set concealcursor=inv
 " hide concealed text completely unless replacement character is defined
 set conceallevel=2

Default: 1 (0 if conceal not available)

       				       	*clang_complete-clang_trailing_placeholder*
       				       	*g:clang_trailing_placeholder*
Note: This option is specific to clang_complete snippets engine.
If equal to 1, clang_complete will add a trailing placeholder after functions
to let you add you continue writing code faster.
Default: 0

       				       	*clang_close-preview*
       				       	*g:clang_close_preview*
If equal to 1, the preview window will be close automatically after a
completion.
Default: 0

       				       	*clang_complete-exec*
       				       	*g:clang_exec*
Name or path of clang executable.
Note: Use this if clang has a non-standard name, or isn't in the path.
Default: "clang"

       				      	*clang_complete-user_options*
       				       	*g:clang_user_options*
When using clang executable the value of this option is added at the end of
clang command. Useful if you want to filter the result, or do other stuffs.
To ignore the error code returned by clang, set |g:clang_exec| to `"clang` and
|g:clang_user_options| to `2>/dev/null || exit 0"` if you're on *nix, or to
`2>NUL || exit 0"` if you are on windows.

When using libclang the value of this option is passed to libclang as
compilation arguments.

Example: >
 " compile all sources as c++11 (just for example, use .clang_complete for
 " setting version of the language per project)
 let g:clang_user_options = '-std=c++11'
<
Default: ""

       				       	*clang_complete-auto_user_options*
       				       	*g:clang_auto_user_options*
Set sources for user options passed to clang. Available sources are:
- path - use &path content as list of include directories (relative paths are
  ignored);
- .clang_complete - use information from .clang_complete file Multiple options
  are separated by comma;
- {anything} else will be treaded as a custom option source in the following
  manner: clang_complete will try to load the autoload-function named
  getopts#{anything}#getopts, which then will be able to modify
  b:clang_user_options variable. See help on |autoload| if you don't know
  what it is.

This option is processed and all sources are used on buffer loading, not each
time before doing completion.

Two examples of custom option sources is bundled with clang_complete and are
called "clang" and "gcc". These sources run clang and gcc, respectively, to
get a list of include paths. The list of include paths for each of supported
filetypes (c, cpp, objc and objcpp) is cached on a disk and can be removed by
calling the ClearIncludeCaches() function (for changes to take affect one
needs to reread buffers using the :edit command or something equivalent).
Default: "path, .clang_complete, clang"

       				       	*clang_complete-use_library*
       				       	*g:clang_use_library*
Instead of calling the clang/clang++ tool use libclang directly. This gives
access to many more clang features. Furthermore it automatically caches all
includes in memory. Updates after changes in the same file will therefore be a
lot faster.
Default: 0

       				       	*clang_complete-library_path*
       				       	*g:clang_library_path*
If libclang.[dll/so/dylib] is not in your library search path, set this to the
absolute path where libclang is available.
Default: ""

					*clang_complete-sort_algo*
					*g:clang_sort_algo*
How results are sorted (alpha, priority, none). Currently only works with
libclang.
Default: "priority"

					*clang_complete-complete_macros*
					*g:clang_complete_macros*
If clang should complete preprocessor macros and constants.
Default: 0

					*clang_complete-complete_patterns*
					*g:clang_complete_patterns*
If clang should complete code patterns, i.e loop constructs etc.
Defaut: 0

==============================================================================
5. Known issues					*clang_complete-issues*

If you find that completion is slow, please read the |clang_complete-pch|
section below.

If you get following error message while trying to complete anything: >
 E121: Undefined variable: b:should_overload
it means that your version of Vim is too old (this is an old bug and it has
been fixed with one of patches for Vim 7.2) and you need to update it.

If clang is not able to compile your file, it cannot complete anything. Since
clang is not supporting every C++0x features, this is normal if it can do any
completion on C++0x file.

There is no difference in clang's output between private methods/members and
public ones. Which means that I cannot filter private methods on the
completion list.

==============================================================================
6. PCH      					*clang_complete-pch*

In case you can not or you do not want to install libclang, a precompiled
header file is another way to accelerate compilation, and so, to accelerate
the completion. It is however more complicated to install and is still slower
than the use of libclang.

Here is how to create the <vector> pch, on linux (OSX users may use
-fnext-runtime instead of -fgnu-runtime): >
 clang -x c++-header /path/to/c++/vector -fno-exceptions -fgnu-runtime \
    -o vector.pch
You just have to insert it into your .clang_complete: >
 echo '-include-pch /path/to/vector.pch -fgnu-runtime' >> .clang_complete
<
One of the major problem is that you cannot include more that one pch, the
solution is to put the system headers or non changing headers into another
header and then compile it to pch: >
 echo '#include <iostream>\n#include <vector>' > pchheader.h
 clang -x c++-header ./pchheader.h -fno-exceptions -fnu-runtime \
    -o ./pchheader.pch
And then add it to the .clang_complete file.

==============================================================================
7. cc_args.py script				*clang_complete-cc_args*

This script, installed at ~/.vim/bin/cc_args.py, could be used to generate or
update the .clang_complete file. It works similar to gccsence's gccrec and
simply stores -I and -D arguments passed to the compiler in the
.clang_complete file.  Just add the cc_args.py script as the first argument of
the compile command. You should do that every time compile options have
changed.

Example (we need -B flag to force compiling even if project is up to date): >
 make CC='~/.vim/bin/cc_args.py gcc' CXX='~/.vim/bin/cc_args.py g++' -B
After running this command, .clang_complete will be created or updated with
new options. If you don't want to update an existing configuration file,
delete it before running make.

==============================================================================
8. To do						*clang_complete-todo*

- Write some unit tests
  - clang vs libclang accuracy for complex completions
  - clang vs libclang timing
- Explore "jump to declaration/definition" with libclang FGJ
- Think about supertab (<C-X><C-U> with supertab and clang_auto_select)
- Parse fix-its and do something useful with it

==============================================================================
9. FAQ						*clang_complete-faq*

*) clang_complete doesn't work! I always get the message "pattern not found".

This can have multiple reasons. You can try to open the quickfix window
(:copen) that displays the error messages from clang to get a better idea what
goes on. It might be that you need to update your .clang_complete file. If
this does not help, keep in mind that clang_complete can cause clang to search
for header files first in the system-wide paths and then in the ones specified
locally in .clang_complete. Therefore you might have to add "-nostdinc" and
the system include paths in the right order to .clang_complete.

*) Only function names get completed but not the parentheses/parameters.

Enable the snippets-support by adding the following lines to your .vimrc,
for example:

let g:clang_snippets = 1
let g:clang_snippets_engine = 'clang_complete'

If you have snipmate installed, you can use

let g:clang_snippets = 1
let g:clang_snippets_engine = 'snipmate'

instead. After a completetion you can use <Tab> in normal mode to jump to the
next parameter.

*) Can I configure clang_complete to insert the text automatically when there
   is only one possibility?

You can configure vim to complete automatically the longest common match by
adding the following line to your vimrc:

set completeopt=menu,longest

==============================================================================
10. License					*clang_complete-license*

Copyright (c) 2010, 2011, Xavier Deguillard
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of Xavier Deguillard nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL XAVIER DEGUILLARD BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Note: This license does not cover the files that come from the LLVM project,
namely, cindex.py and __init__.py, which are covered by the LLVM license.

 vim:tw=78:ts=8:ft=help:norl:
plugin/clang/__init__.py	[[[1
24
#===- __init__.py - Clang Python Bindings --------------------*- python -*--===#
#
#                     The LLVM Compiler Infrastructure
#
# This file is distributed under the University of Illinois Open Source
# License. See LICENSE.TXT for details.
#
#===------------------------------------------------------------------------===#

r"""
Clang Library Bindings
======================

This package provides access to the Clang compiler and libraries.

The available modules are:

  cindex

    Bindings for the Clang indexing library.
"""

__all__ = ['cindex']

plugin/clang/cindex.py	[[[1
2893
#===- cindex.py - Python Indexing Library Bindings -----------*- python -*--===#
#
#                     The LLVM Compiler Infrastructure
#
# This file is distributed under the University of Illinois Open Source
# License. See LICENSE.TXT for details.
#
#===------------------------------------------------------------------------===#

r"""
Clang Indexing Library Bindings
===============================

This module provides an interface to the Clang indexing library. It is a
low-level interface to the indexing library which attempts to match the Clang
API directly while also being "pythonic". Notable differences from the C API
are:

 * string results are returned as Python strings, not CXString objects.

 * null cursors are translated to None.

 * access to child cursors is done via iteration, not visitation.

The major indexing objects are:

  Index

    The top-level object which manages some global library state.

  TranslationUnit

    High-level object encapsulating the AST for a single translation unit. These
    can be loaded from .ast files or parsed on the fly.

  Cursor

    Generic object for representing a node in the AST.

  SourceRange, SourceLocation, and File

    Objects representing information about the input source.

Most object information is exposed using properties, when the underlying API
call is efficient.
"""

# TODO
# ====
#
# o API support for invalid translation units. Currently we can't even get the
#   diagnostics on failure because they refer to locations in an object that
#   will have been invalidated.
#
# o fix memory management issues (currently client must hold on to index and
#   translation unit, or risk crashes).
#
# o expose code completion APIs.
#
# o cleanup ctypes wrapping, would be nice to separate the ctypes details more
#   clearly, and hide from the external interface (i.e., help(cindex)).
#
# o implement additional SourceLocation, SourceRange, and File methods.

from ctypes import *
import collections

import clang.enumerations

def get_cindex_library():
    # FIXME: It's probably not the case that the library is actually found in
    # this location. We need a better system of identifying and loading the
    # CIndex library. It could be on path or elsewhere, or versioned, etc.
    import platform, sys
    name = platform.system()
    path = sys.argv[0]
    path = path + '/' if path else ''
    if name == 'Darwin':
        return cdll.LoadLibrary(path + 'libclang.dylib')
    elif name == 'Windows':
        return cdll.LoadLibrary(path + 'libclang.dll')
    else:
        return cdll.LoadLibrary(path + 'libclang.so')

# ctypes doesn't implicitly convert c_void_p to the appropriate wrapper
# object. This is a problem, because it means that from_parameter will see an
# integer and pass the wrong value on platforms where int != void*. Work around
# this by marshalling object arguments as void**.
c_object_p = POINTER(c_void_p)

lib = get_cindex_library()
callbacks = {}

### Exception Classes ###

class TranslationUnitLoadError(Exception):
    """Represents an error that occurred when loading a TranslationUnit.

    This is raised in the case where a TranslationUnit could not be
    instantiated due to failure in the libclang library.

    FIXME: Make libclang expose additional error information in this scenario.
    """
    pass

class TranslationUnitSaveError(Exception):
    """Represents an error that occurred when saving a TranslationUnit.

    Each error has associated with it an enumerated value, accessible under
    e.save_error. Consumers can compare the value with one of the ERROR_
    constants in this class.
    """

    # Indicates that an unknown error occurred. This typically indicates that
    # I/O failed during save.
    ERROR_UNKNOWN = 1

    # Indicates that errors during translation prevented saving. The errors
    # should be available via the TranslationUnit's diagnostics.
    ERROR_TRANSLATION_ERRORS = 2

    # Indicates that the translation unit was somehow invalid.
    ERROR_INVALID_TU = 3

    def __init__(self, enumeration, message):
        assert isinstance(enumeration, int)

        if enumeration < 1 or enumeration > 3:
            raise Exception("Encountered undefined TranslationUnit save error "
                            "constant: %d. Please file a bug to have this "
                            "value supported." % enumeration)

        self.save_error = enumeration
        Exception.__init__(self, 'Error %d: %s' % (enumeration, message))

### Structures and Utility Classes ###

class CachedProperty(object):
    """Decorator that lazy-loads the value of a property.

    The first time the property is accessed, the original property function is
    executed. The value it returns is set as the new value of that instance's
    property, replacing the original method.
    """

    def __init__(self, wrapped):
        self.wrapped = wrapped
        try:
            self.__doc__ = wrapped.__doc__
        except:
            pass

    def __get__(self, instance, instance_type=None):
        if instance is None:
            return self

        value = self.wrapped(instance)
        setattr(instance, self.wrapped.__name__, value)

        return value


class _CXString(Structure):
    """Helper for transforming CXString results."""

    _fields_ = [("spelling", c_char_p), ("free", c_int)]

    def __del__(self):
        lib.clang_disposeString(self)

    @staticmethod
    def from_result(res, fn, args):
        assert isinstance(res, _CXString)
        return lib.clang_getCString(res)

class SourceLocation(Structure):
    """
    A SourceLocation represents a particular location within a source file.
    """
    _fields_ = [("ptr_data", c_void_p * 2), ("int_data", c_uint)]
    _data = None

    def _get_instantiation(self):
        if self._data is None:
            f, l, c, o = c_object_p(), c_uint(), c_uint(), c_uint()
            lib.clang_getInstantiationLocation(self, byref(f), byref(l),
                    byref(c), byref(o))
            if f:
                f = File(f)
            else:
                f = None
            self._data = (f, int(l.value), int(c.value), int(o.value))
        return self._data

    @staticmethod
    def from_position(tu, file, line, column):
        """
        Retrieve the source location associated with a given file/line/column in
        a particular translation unit.
        """
        return lib.clang_getLocation(tu, file, line, column)

    @staticmethod
    def from_offset(tu, file, offset):
        """Retrieve a SourceLocation from a given character offset.

        tu -- TranslationUnit file belongs to
        file -- File instance to obtain offset from
        offset -- Integer character offset within file
        """
        return lib.clang_getLocationForOffset(tu, file, offset)

    @property
    def file(self):
        """Get the file represented by this source location."""
        return self._get_instantiation()[0]

    @property
    def line(self):
        """Get the line represented by this source location."""
        return self._get_instantiation()[1]

    @property
    def column(self):
        """Get the column represented by this source location."""
        return self._get_instantiation()[2]

    @property
    def offset(self):
        """Get the file offset represented by this source location."""
        return self._get_instantiation()[3]

    def __eq__(self, other):
        return lib.clang_equalLocations(self, other)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __repr__(self):
        if self.file:
            filename = self.file.name
        else:
            filename = None
        return "<SourceLocation file %r, line %r, column %r>" % (
            filename, self.line, self.column)

class SourceRange(Structure):
    """
    A SourceRange describes a range of source locations within the source
    code.
    """
    _fields_ = [
        ("ptr_data", c_void_p * 2),
        ("begin_int_data", c_uint),
        ("end_int_data", c_uint)]

    # FIXME: Eliminate this and make normal constructor? Requires hiding ctypes
    # object.
    @staticmethod
    def from_locations(start, end):
        return lib.clang_getRange(start, end)

    @property
    def start(self):
        """
        Return a SourceLocation representing the first character within a
        source range.
        """
        return lib.clang_getRangeStart(self)

    @property
    def end(self):
        """
        Return a SourceLocation representing the last character within a
        source range.
        """
        return lib.clang_getRangeEnd(self)

    def __eq__(self, other):
        return lib.clang_equalRanges(self, other)

    def __ne__(self, other):
        return not self.__eq__(other)

    def __repr__(self):
        return "<SourceRange start %r, end %r>" % (self.start, self.end)

class Diagnostic(object):
    """
    A Diagnostic is a single instance of a Clang diagnostic. It includes the
    diagnostic severity, the message, the location the diagnostic occurred, as
    well as additional source ranges and associated fix-it hints.
    """

    Ignored = 0
    Note    = 1
    Warning = 2
    Error   = 3
    Fatal   = 4

    def __init__(self, ptr):
        self.ptr = ptr

    def __del__(self):
        lib.clang_disposeDiagnostic(self)

    @property
    def severity(self):
        return lib.clang_getDiagnosticSeverity(self)

    @property
    def location(self):
        return lib.clang_getDiagnosticLocation(self)

    @property
    def spelling(self):
        return lib.clang_getDiagnosticSpelling(self)

    @property
    def ranges(self):
        class RangeIterator:
            def __init__(self, diag):
                self.diag = diag

            def __len__(self):
                return int(lib.clang_getDiagnosticNumRanges(self.diag))

            def __getitem__(self, key):
                if (key >= len(self)):
                    raise IndexError
                return lib.clang_getDiagnosticRange(self.diag, key)

        return RangeIterator(self)

    @property
    def fixits(self):
        class FixItIterator:
            def __init__(self, diag):
                self.diag = diag

            def __len__(self):
                return int(lib.clang_getDiagnosticNumFixIts(self.diag))

            def __getitem__(self, key):
                range = SourceRange()
                value = lib.clang_getDiagnosticFixIt(self.diag, key,
                        byref(range))
                if len(value) == 0:
                    raise IndexError

                return FixIt(range, value)

        return FixItIterator(self)

    @property
    def category_number(self):
        """The category number for this diagnostic."""
        return lib.clang_getDiagnosticCategory(self)

    @property
    def category_name(self):
        """The string name of the category for this diagnostic."""
        return lib.clang_getDiagnosticCategoryName(self.category_number)

    @property
    def option(self):
        """The command-line option that enables this diagnostic."""
        return lib.clang_getDiagnosticOption(self, None)

    @property
    def disable_option(self):
        """The command-line option that disables this diagnostic."""
        disable = _CXString()
        lib.clang_getDiagnosticOption(self, byref(disable))

        return lib.clang_getCString(disable)

    def __repr__(self):
        return "<Diagnostic severity %r, location %r, spelling %r>" % (
            self.severity, self.location, self.spelling)

    def from_param(self):
      return self.ptr

class FixIt(object):
    """
    A FixIt represents a transformation to be applied to the source to
    "fix-it". The fix-it shouldbe applied by replacing the given source range
    with the given value.
    """

    def __init__(self, range, value):
        self.range = range
        self.value = value

    def __repr__(self):
        return "<FixIt range %r, value %r>" % (self.range, self.value)

class TokenGroup(object):
    """Helper class to facilitate token management.

    Tokens are allocated from libclang in chunks. They must be disposed of as a
    collective group.

    One purpose of this class is for instances to represent groups of allocated
    tokens. Each token in a group contains a reference back to an instance of
    this class. When all tokens from a group are garbage collected, it allows
    this class to be garbage collected. When this class is garbage collected,
    it calls the libclang destructor which invalidates all tokens in the group.

    You should not instantiate this class outside of this module.
    """
    def __init__(self, tu, memory, count):
        self._tu = tu
        self._memory = memory
        self._count = count

    def __del__(self):
        lib.clang_disposeTokens(self._tu, self._memory, self._count)

    @staticmethod
    def get_tokens(tu, extent):
        """Helper method to return all tokens in an extent.

        This functionality is needed multiple places in this module. We define
        it here because it seems like a logical place.
        """
        tokens_memory = POINTER(Token)()
        tokens_count = c_uint()

        lib.clang_tokenize(tu, extent, byref(tokens_memory),
                byref(tokens_count))

        count = int(tokens_count.value)

        # If we get no tokens, no memory was allocated. Be sure not to return
        # anything and potentially call a destructor on nothing.
        if count < 1:
            return

        tokens_array = cast(tokens_memory, POINTER(Token * count)).contents

        token_group = TokenGroup(tu, tokens_memory, tokens_count)

        for i in xrange(0, count):
            token = Token()
            token.int_data = tokens_array[i].int_data
            token.ptr_data = tokens_array[i].ptr_data
            token._tu = tu
            token._group = token_group

            yield token

class TokenKind(object):
    """Describes a specific type of a Token."""

    _value_map = {} # int -> TokenKind

    def __init__(self, value, name):
        """Create a new TokenKind instance from a numeric value and a name."""
        self.value = value
        self.name = name

    def __repr__(self):
        return 'TokenKind.%s' % (self.name,)

    @staticmethod
    def from_value(value):
        """Obtain a registered TokenKind instance from its value."""
        result = TokenKind._value_map.get(value, None)

        if result is None:
            raise ValueError('Unknown TokenKind: %d' % value)

        return result

    @staticmethod
    def register(value, name):
        """Register a new TokenKind enumeration.

        This should only be called at module load time by code within this
        package.
        """
        if value in TokenKind._value_map:
            raise ValueError('TokenKind already registered: %d' % value)

        kind = TokenKind(value, name)
        TokenKind._value_map[value] = kind
        setattr(TokenKind, name, kind)

### Cursor Kinds ###

class CursorKind(object):
    """
    A CursorKind describes the kind of entity that a cursor points to.
    """

    # The unique kind objects, indexed by id.
    _kinds = []
    _name_map = None

    def __init__(self, value):
        if value >= len(CursorKind._kinds):
            CursorKind._kinds += [None] * (value - len(CursorKind._kinds) + 1)
        if CursorKind._kinds[value] is not None:
            raise ValueError,'CursorKind already loaded'
        self.value = value
        CursorKind._kinds[value] = self
        CursorKind._name_map = None

    def from_param(self):
        return self.value

    @property
    def name(self):
        """Get the enumeration name of this cursor kind."""
        if self._name_map is None:
            self._name_map = {}
            for key,value in CursorKind.__dict__.items():
                if isinstance(value,CursorKind):
                    self._name_map[value] = key
        return self._name_map[self]

    @staticmethod
    def from_id(id):
        if id >= len(CursorKind._kinds) or CursorKind._kinds[id] is None:
            raise ValueError,'Unknown cursor kind'
        return CursorKind._kinds[id]

    @staticmethod
    def get_all_kinds():
        """Return all CursorKind enumeration instances."""
        return filter(None, CursorKind._kinds)

    def is_declaration(self):
        """Test if this is a declaration kind."""
        return lib.clang_isDeclaration(self)

    def is_reference(self):
        """Test if this is a reference kind."""
        return lib.clang_isReference(self)

    def is_expression(self):
        """Test if this is an expression kind."""
        return lib.clang_isExpression(self)

    def is_statement(self):
        """Test if this is a statement kind."""
        return lib.clang_isStatement(self)

    def is_attribute(self):
        """Test if this is an attribute kind."""
        return lib.clang_isAttribute(self)

    def is_invalid(self):
        """Test if this is an invalid kind."""
        return lib.clang_isInvalid(self)

    def is_translation_unit(self):
        """Test if this is a translation unit kind."""
        return lib.clang_isTranslationUnit(self)

    def is_preprocessing(self):
        """Test if this is a preprocessing kind."""
        return lib.clang_isPreprocessing(self)

    def is_unexposed(self):
        """Test if this is an unexposed kind."""
        return lib.clang_isUnexposed(self)

    def __repr__(self):
        return 'CursorKind.%s' % (self.name,)

# FIXME: Is there a nicer way to expose this enumeration? We could potentially
# represent the nested structure, or even build a class hierarchy. The main
# things we want for sure are (a) simple external access to kinds, (b) a place
# to hang a description and name, (c) easy to keep in sync with Index.h.

###
# Declaration Kinds

# A declaration whose specific kind is not exposed via this interface.
#
# Unexposed declarations have the same operations as any other kind of
# declaration; one can extract their location information, spelling, find their
# definitions, etc. However, the specific kind of the declaration is not
# reported.
CursorKind.UNEXPOSED_DECL = CursorKind(1)

# A C or C++ struct.
CursorKind.STRUCT_DECL = CursorKind(2)

# A C or C++ union.
CursorKind.UNION_DECL = CursorKind(3)

# A C++ class.
CursorKind.CLASS_DECL = CursorKind(4)

# An enumeration.
CursorKind.ENUM_DECL = CursorKind(5)

# A field (in C) or non-static data member (in C++) in a struct, union, or C++
# class.
CursorKind.FIELD_DECL = CursorKind(6)

# An enumerator constant.
CursorKind.ENUM_CONSTANT_DECL = CursorKind(7)

# A function.
CursorKind.FUNCTION_DECL = CursorKind(8)

# A variable.
CursorKind.VAR_DECL = CursorKind(9)

# A function or method parameter.
CursorKind.PARM_DECL = CursorKind(10)

# An Objective-C @interface.
CursorKind.OBJC_INTERFACE_DECL = CursorKind(11)

# An Objective-C @interface for a category.
CursorKind.OBJC_CATEGORY_DECL = CursorKind(12)

# An Objective-C @protocol declaration.
CursorKind.OBJC_PROTOCOL_DECL = CursorKind(13)

# An Objective-C @property declaration.
CursorKind.OBJC_PROPERTY_DECL = CursorKind(14)

# An Objective-C instance variable.
CursorKind.OBJC_IVAR_DECL = CursorKind(15)

# An Objective-C instance method.
CursorKind.OBJC_INSTANCE_METHOD_DECL = CursorKind(16)

# An Objective-C class method.
CursorKind.OBJC_CLASS_METHOD_DECL = CursorKind(17)

# An Objective-C @implementation.
CursorKind.OBJC_IMPLEMENTATION_DECL = CursorKind(18)

# An Objective-C @implementation for a category.
CursorKind.OBJC_CATEGORY_IMPL_DECL = CursorKind(19)

# A typedef.
CursorKind.TYPEDEF_DECL = CursorKind(20)

# A C++ class method.
CursorKind.CXX_METHOD = CursorKind(21)

# A C++ namespace.
CursorKind.NAMESPACE = CursorKind(22)

# A linkage specification, e.g. 'extern "C"'.
CursorKind.LINKAGE_SPEC = CursorKind(23)

# A C++ constructor.
CursorKind.CONSTRUCTOR = CursorKind(24)

# A C++ destructor.
CursorKind.DESTRUCTOR = CursorKind(25)

# A C++ conversion function.
CursorKind.CONVERSION_FUNCTION = CursorKind(26)

# A C++ template type parameter
CursorKind.TEMPLATE_TYPE_PARAMETER = CursorKind(27)

# A C++ non-type template paramater.
CursorKind.TEMPLATE_NON_TYPE_PARAMETER = CursorKind(28)

# A C++ template template parameter.
CursorKind.TEMPLATE_TEMPLATE_PARAMTER = CursorKind(29)

# A C++ function template.
CursorKind.FUNCTION_TEMPLATE = CursorKind(30)

# A C++ class template.
CursorKind.CLASS_TEMPLATE = CursorKind(31)

# A C++ class template partial specialization.
CursorKind.CLASS_TEMPLATE_PARTIAL_SPECIALIZATION = CursorKind(32)

# A C++ namespace alias declaration.
CursorKind.NAMESPACE_ALIAS = CursorKind(33)

# A C++ using directive
CursorKind.USING_DIRECTIVE = CursorKind(34)

# A C++ using declaration
CursorKind.USING_DECLARATION = CursorKind(35)

# A Type alias decl.
CursorKind.TYPE_ALIAS_DECL = CursorKind(36)

# A Objective-C synthesize decl
CursorKind.OBJC_SYNTHESIZE_DECL = CursorKind(37)

# A Objective-C dynamic decl
CursorKind.OBJC_DYNAMIC_DECL = CursorKind(38)

# A C++ access specifier decl.
CursorKind.CXX_ACCESS_SPEC_DECL = CursorKind(39)


###
# Reference Kinds

CursorKind.OBJC_SUPER_CLASS_REF = CursorKind(40)
CursorKind.OBJC_PROTOCOL_REF = CursorKind(41)
CursorKind.OBJC_CLASS_REF = CursorKind(42)

# A reference to a type declaration.
#
# A type reference occurs anywhere where a type is named but not
# declared. For example, given:
#   typedef unsigned size_type;
#   size_type size;
#
# The typedef is a declaration of size_type (CXCursor_TypedefDecl),
# while the type of the variable "size" is referenced. The cursor
# referenced by the type of size is the typedef for size_type.
CursorKind.TYPE_REF = CursorKind(43)
CursorKind.CXX_BASE_SPECIFIER = CursorKind(44)

# A reference to a class template, function template, template
# template parameter, or class template partial specialization.
CursorKind.TEMPLATE_REF = CursorKind(45)

# A reference to a namespace or namepsace alias.
CursorKind.NAMESPACE_REF = CursorKind(46)

# A reference to a member of a struct, union, or class that occurs in
# some non-expression context, e.g., a designated initializer.
CursorKind.MEMBER_REF = CursorKind(47)

# A reference to a labeled statement.
CursorKind.LABEL_REF = CursorKind(48)

# A reference toa a set of overloaded functions or function templates
# that has not yet been resolved to a specific function or function template.
CursorKind.OVERLOADED_DECL_REF = CursorKind(49)

###
# Invalid/Error Kinds

CursorKind.INVALID_FILE = CursorKind(70)
CursorKind.NO_DECL_FOUND = CursorKind(71)
CursorKind.NOT_IMPLEMENTED = CursorKind(72)
CursorKind.INVALID_CODE = CursorKind(73)

###
# Expression Kinds

# An expression whose specific kind is not exposed via this interface.
#
# Unexposed expressions have the same operations as any other kind of
# expression; one can extract their location information, spelling, children,
# etc. However, the specific kind of the expression is not reported.
CursorKind.UNEXPOSED_EXPR = CursorKind(100)

# An expression that refers to some value declaration, such as a function,
# varible, or enumerator.
CursorKind.DECL_REF_EXPR = CursorKind(101)

# An expression that refers to a member of a struct, union, class, Objective-C
# class, etc.
CursorKind.MEMBER_REF_EXPR = CursorKind(102)

# An expression that calls a function.
CursorKind.CALL_EXPR = CursorKind(103)

# An expression that sends a message to an Objective-C object or class.
CursorKind.OBJC_MESSAGE_EXPR = CursorKind(104)

# An expression that represents a block literal.
CursorKind.BLOCK_EXPR = CursorKind(105)

# An integer literal.
CursorKind.INTEGER_LITERAL = CursorKind(106)

# A floating point number literal.
CursorKind.FLOATING_LITERAL = CursorKind(107)

# An imaginary number literal.
CursorKind.IMAGINARY_LITERAL = CursorKind(108)

# A string literal.
CursorKind.STRING_LITERAL = CursorKind(109)

# A character literal.
CursorKind.CHARACTER_LITERAL = CursorKind(110)

# A parenthesized expression, e.g. "(1)".
#
# This AST node is only formed if full location information is requested.
CursorKind.PAREN_EXPR = CursorKind(111)

# This represents the unary-expression's (except sizeof and
# alignof).
CursorKind.UNARY_OPERATOR = CursorKind(112)

# [C99 6.5.2.1] Array Subscripting.
CursorKind.ARRAY_SUBSCRIPT_EXPR = CursorKind(113)

# A builtin binary operation expression such as "x + y" or
# "x <= y".
CursorKind.BINARY_OPERATOR = CursorKind(114)

# Compound assignment such as "+=".
CursorKind.COMPOUND_ASSIGNMENT_OPERATOR = CursorKind(115)

# The ?: ternary operator.
CursorKind.CONDITIONAL_OPERATOR = CursorKind(116)

# An explicit cast in C (C99 6.5.4) or a C-style cast in C++
# (C++ [expr.cast]), which uses the syntax (Type)expr.
#
# For example: (int)f.
CursorKind.CSTYLE_CAST_EXPR = CursorKind(117)

# [C99 6.5.2.5]
CursorKind.COMPOUND_LITERAL_EXPR = CursorKind(118)

# Describes an C or C++ initializer list.
CursorKind.INIT_LIST_EXPR = CursorKind(119)

# The GNU address of label extension, representing &&label.
CursorKind.ADDR_LABEL_EXPR = CursorKind(120)

# This is the GNU Statement Expression extension: ({int X=4; X;})
CursorKind.StmtExpr = CursorKind(121)

# Represents a C11 generic selection.
CursorKind.GENERIC_SELECTION_EXPR = CursorKind(122)

# Implements the GNU __null extension, which is a name for a null
# pointer constant that has integral type (e.g., int or long) and is the same
# size and alignment as a pointer.
#
# The __null extension is typically only used by system headers, which define
# NULL as __null in C++ rather than using 0 (which is an integer that may not
# match the size of a pointer).
CursorKind.GNU_NULL_EXPR = CursorKind(123)

# C++'s static_cast<> expression.
CursorKind.CXX_STATIC_CAST_EXPR = CursorKind(124)

# C++'s dynamic_cast<> expression.
CursorKind.CXX_DYNAMIC_CAST_EXPR = CursorKind(125)

# C++'s reinterpret_cast<> expression.
CursorKind.CXX_REINTERPRET_CAST_EXPR = CursorKind(126)

# C++'s const_cast<> expression.
CursorKind.CXX_CONST_CAST_EXPR = CursorKind(127)

# Represents an explicit C++ type conversion that uses "functional"
# notion (C++ [expr.type.conv]).
#
# Example:
# \code
#   x = int(0.5);
# \endcode
CursorKind.CXX_FUNCTIONAL_CAST_EXPR = CursorKind(128)

# A C++ typeid expression (C++ [expr.typeid]).
CursorKind.CXX_TYPEID_EXPR = CursorKind(129)

# [C++ 2.13.5] C++ Boolean Literal.
CursorKind.CXX_BOOL_LITERAL_EXPR = CursorKind(130)

# [C++0x 2.14.7] C++ Pointer Literal.
CursorKind.CXX_NULL_PTR_LITERAL_EXPR = CursorKind(131)

# Represents the "this" expression in C++
CursorKind.CXX_THIS_EXPR = CursorKind(132)

# [C++ 15] C++ Throw Expression.
#
# This handles 'throw' and 'throw' assignment-expression. When
# assignment-expression isn't present, Op will be null.
CursorKind.CXX_THROW_EXPR = CursorKind(133)

# A new expression for memory allocation and constructor calls, e.g:
# "new CXXNewExpr(foo)".
CursorKind.CXX_NEW_EXPR = CursorKind(134)

# A delete expression for memory deallocation and destructor calls,
# e.g. "delete[] pArray".
CursorKind.CXX_DELETE_EXPR = CursorKind(135)

# Represents a unary expression.
CursorKind.CXX_UNARY_EXPR = CursorKind(136)

# ObjCStringLiteral, used for Objective-C string literals i.e. "foo".
CursorKind.OBJC_STRING_LITERAL = CursorKind(137)

# ObjCEncodeExpr, used for in Objective-C.
CursorKind.OBJC_ENCODE_EXPR = CursorKind(138)

# ObjCSelectorExpr used for in Objective-C.
CursorKind.OBJC_SELECTOR_EXPR = CursorKind(139)

# Objective-C's protocol expression.
CursorKind.OBJC_PROTOCOL_EXPR = CursorKind(140)

# An Objective-C "bridged" cast expression, which casts between
# Objective-C pointers and C pointers, transferring ownership in the process.
#
# \code
#   NSString *str = (__bridge_transfer NSString *)CFCreateString();
# \endcode
CursorKind.OBJC_BRIDGE_CAST_EXPR = CursorKind(141)

# Represents a C++0x pack expansion that produces a sequence of
# expressions.
#
# A pack expansion expression contains a pattern (which itself is an
# expression) followed by an ellipsis. For example:
CursorKind.PACK_EXPANSION_EXPR = CursorKind(142)

# Represents an expression that computes the length of a parameter
# pack.
CursorKind.SIZE_OF_PACK_EXPR = CursorKind(143)

# A statement whose specific kind is not exposed via this interface.
#
# Unexposed statements have the same operations as any other kind of statement;
# one can extract their location information, spelling, children, etc. However,
# the specific kind of the statement is not reported.
CursorKind.UNEXPOSED_STMT = CursorKind(200)

# A labelled statement in a function.
CursorKind.LABEL_STMT = CursorKind(201)

# A compound statement
CursorKind.COMPOUND_STMT = CursorKind(202)

# A case statement.
CursorKind.CASE_STMT = CursorKind(203)

# A default statement.
CursorKind.DEFAULT_STMT = CursorKind(204)

# An if statement.
CursorKind.IF_STMT = CursorKind(205)

# A switch statement.
CursorKind.SWITCH_STMT = CursorKind(206)

# A while statement.
CursorKind.WHILE_STMT = CursorKind(207)

# A do statement.
CursorKind.DO_STMT = CursorKind(208)

# A for statement.
CursorKind.FOR_STMT = CursorKind(209)

# A goto statement.
CursorKind.GOTO_STMT = CursorKind(210)

# An indirect goto statement.
CursorKind.INDIRECT_GOTO_STMT = CursorKind(211)

# A continue statement.
CursorKind.CONTINUE_STMT = CursorKind(212)

# A break statement.
CursorKind.BREAK_STMT = CursorKind(213)

# A return statement.
CursorKind.RETURN_STMT = CursorKind(214)

# A GNU-style inline assembler statement.
CursorKind.ASM_STMT = CursorKind(215)

# Objective-C's overall @try-@catch-@finally statement.
CursorKind.OBJC_AT_TRY_STMT = CursorKind(216)

# Objective-C's @catch statement.
CursorKind.OBJC_AT_CATCH_STMT = CursorKind(217)

# Objective-C's @finally statement.
CursorKind.OBJC_AT_FINALLY_STMT = CursorKind(218)

# Objective-C's @throw statement.
CursorKind.OBJC_AT_THROW_STMT = CursorKind(219)

# Objective-C's @synchronized statement.
CursorKind.OBJC_AT_SYNCHRONIZED_STMT = CursorKind(220)

# Objective-C's autorealease pool statement.
CursorKind.OBJC_AUTORELEASE_POOL_STMT = CursorKind(221)

# Objective-C's for collection statement.
CursorKind.OBJC_FOR_COLLECTION_STMT = CursorKind(222)

# C++'s catch statement.
CursorKind.CXX_CATCH_STMT = CursorKind(223)

# C++'s try statement.
CursorKind.CXX_TRY_STMT = CursorKind(224)

# C++'s for (* : *) statement.
CursorKind.CXX_FOR_RANGE_STMT = CursorKind(225)

# Windows Structured Exception Handling's try statement.
CursorKind.SEH_TRY_STMT = CursorKind(226)

# Windows Structured Exception Handling's except statement.
CursorKind.SEH_EXCEPT_STMT = CursorKind(227)

# Windows Structured Exception Handling's finally statement.
CursorKind.SEH_FINALLY_STMT = CursorKind(228)

# The null statement.
CursorKind.NULL_STMT = CursorKind(230)

# Adaptor class for mixing declarations with statements and expressions.
CursorKind.DECL_STMT = CursorKind(231)

###
# Other Kinds

# Cursor that represents the translation unit itself.
#
# The translation unit cursor exists primarily to act as the root cursor for
# traversing the contents of a translation unit.
CursorKind.TRANSLATION_UNIT = CursorKind(300)

###
# Attributes

# An attribute whoe specific kind is note exposed via this interface
CursorKind.UNEXPOSED_ATTR = CursorKind(400)

CursorKind.IB_ACTION_ATTR = CursorKind(401)
CursorKind.IB_OUTLET_ATTR = CursorKind(402)
CursorKind.IB_OUTLET_COLLECTION_ATTR = CursorKind(403)

CursorKind.CXX_FINAL_ATTR = CursorKind(404)
CursorKind.CXX_OVERRIDE_ATTR = CursorKind(405)
CursorKind.ANNOTATE_ATTR = CursorKind(406)
CursorKind.ASM_LABEL_ATTR = CursorKind(407)

###
# Preprocessing
CursorKind.PREPROCESSING_DIRECTIVE = CursorKind(500)
CursorKind.MACRO_DEFINITION = CursorKind(501)
CursorKind.MACRO_INSTANTIATION = CursorKind(502)
CursorKind.INCLUSION_DIRECTIVE = CursorKind(503)

### Cursors ###

class Cursor(Structure):
    """
    The Cursor class represents a reference to an element within the AST. It
    acts as a kind of iterator.
    """
    _fields_ = [("_kind_id", c_int), ("xdata", c_int), ("data", c_void_p * 3)]

    @staticmethod
    def from_location(tu, location):
        # We store a reference to the TU in the instance so the TU won't get
        # collected before the cursor.
        cursor = lib.clang_getCursor(tu, location)
        cursor._tu = tu

        return cursor

    def __eq__(self, other):
        return lib.clang_equalCursors(self, other)

    def __ne__(self, other):
        return not self.__eq__(other)

    def is_definition(self):
        """
        Returns true if the declaration pointed at by the cursor is also a
        definition of that entity.
        """
        return lib.clang_isCursorDefinition(self)

    def is_static_method(self):
        """Returns True if the cursor refers to a C++ member function or member
        function template that is declared 'static'.
        """
        return lib.clang_CXXMethod_isStatic(self)

    def get_definition(self):
        """
        If the cursor is a reference to a declaration or a declaration of
        some entity, return a cursor that points to the definition of that
        entity.
        """
        # TODO: Should probably check that this is either a reference or
        # declaration prior to issuing the lookup.
        return lib.clang_getCursorDefinition(self)

    def get_usr(self):
        """Return the Unified Symbol Resultion (USR) for the entity referenced
        by the given cursor (or None).

        A Unified Symbol Resolution (USR) is a string that identifies a
        particular entity (function, class, variable, etc.) within a
        program. USRs can be compared across translation units to determine,
        e.g., when references in one translation refer to an entity defined in
        another translation unit."""
        return lib.clang_getCursorUSR(self)

    @property
    def kind(self):
        """Return the kind of this cursor."""
        return CursorKind.from_id(self._kind_id)

    @property
    def spelling(self):
        """Return the spelling of the entity pointed at by the cursor."""
        if not self.kind.is_declaration():
            # FIXME: clang_getCursorSpelling should be fixed to not assert on
            # this, for consistency with clang_getCursorUSR.
            return None
        if not hasattr(self, '_spelling'):
            self._spelling = lib.clang_getCursorSpelling(self)

        return self._spelling

    @property
    def displayname(self):
        """
        Return the display name for the entity referenced by this cursor.

        The display name contains extra information that helps identify the cursor,
        such as the parameters of a function or template or the arguments of a
        class template specialization.
        """
        if not hasattr(self, '_displayname'):
            self._displayname = lib.clang_getCursorDisplayName(self)

        return self._displayname

    @property
    def location(self):
        """
        Return the source location (the starting character) of the entity
        pointed at by the cursor.
        """
        if not hasattr(self, '_loc'):
            self._loc = lib.clang_getCursorLocation(self)

        return self._loc

    @property
    def extent(self):
        """
        Return the source range (the range of text) occupied by the entity
        pointed at by the cursor.
        """
        if not hasattr(self, '_extent'):
            self._extent = lib.clang_getCursorExtent(self)

        return self._extent

    @property
    def type(self):
        """
        Retrieve the Type (if any) of the entity pointed at by the cursor.
        """
        if not hasattr(self, '_type'):
            self._type = lib.clang_getCursorType(self)

        return self._type

    @property
    def canonical(self):
        """Return the canonical Cursor corresponding to this Cursor.

        The canonical cursor is the cursor which is representative for the
        underlying entity. For example, if you have multiple forward
        declarations for the same class, the canonical cursor for the forward
        declarations will be identical.
        """
        if not hasattr(self, '_canonical'):
            self._canonical = lib.clang_getCanonicalCursor(self)

        return self._canonical

    @property
    def result_type(self):
        """Retrieve the Type of the result for this Cursor."""
        if not hasattr(self, '_result_type'):
            self._result_type = lib.clang_getResultType(self.type)

        return self._result_type

    @property
    def underlying_typedef_type(self):
        """Return the underlying type of a typedef declaration.

        Returns a Type for the typedef this cursor is a declaration for. If
        the current cursor is not a typedef, this raises.
        """
        if not hasattr(self, '_underlying_type'):
            assert self.kind.is_declaration()
            self._underlying_type = lib.clang_getTypedefDeclUnderlyingType(self)

        return self._underlying_type

    @property
    def enum_type(self):
        """Return the integer type of an enum declaration.

        Returns a Type corresponding to an integer. If the cursor is not for an
        enum, this raises.
        """
        if not hasattr(self, '_enum_type'):
            assert self.kind == CursorKind.ENUM_DECL
            self._enum_type = lib.clang_getEnumDeclIntegerType(self)

        return self._enum_type

    @property
    def enum_value(self):
        """Return the value of an enum constant."""
        if not hasattr(self, '_enum_value'):
            assert self.kind == CursorKind.ENUM_CONSTANT_DECL
            # Figure out the underlying type of the enum to know if it
            # is a signed or unsigned quantity.
            underlying_type = self.type
            if underlying_type.kind == TypeKind.ENUM:
                underlying_type = underlying_type.get_declaration().enum_type
            if underlying_type.kind in (TypeKind.CHAR_U,
                                        TypeKind.UCHAR,
                                        TypeKind.CHAR16,
                                        TypeKind.CHAR32,
                                        TypeKind.USHORT,
                                        TypeKind.UINT,
                                        TypeKind.ULONG,
                                        TypeKind.ULONGLONG,
                                        TypeKind.UINT128):
                self._enum_value = lib.clang_getEnumConstantDeclUnsignedValue(self)
            else:
                self._enum_value = lib.clang_getEnumConstantDeclValue(self)
        return self._enum_value

    @property
    def objc_type_encoding(self):
        """Return the Objective-C type encoding as a str."""
        if not hasattr(self, '_objc_type_encoding'):
            self._objc_type_encoding = lib.clang_getDeclObjCTypeEncoding(self)

        return self._objc_type_encoding

    @property
    def hash(self):
        """Returns a hash of the cursor as an int."""
        if not hasattr(self, '_hash'):
            self._hash = lib.clang_hashCursor(self)

        return self._hash

    @property
    def semantic_parent(self):
        """Return the semantic parent for this cursor."""
        if not hasattr(self, '_semantic_parent'):
            self._semantic_parent = lib.clang_getCursorSemanticParent(self)

        return self._semantic_parent

    @property
    def lexical_parent(self):
        """Return the lexical parent for this cursor."""
        if not hasattr(self, '_lexical_parent'):
            self._lexical_parent = lib.clang_getCursorLexicalParent(self)

        return self._lexical_parent

    @property
    def translation_unit(self):
        """Returns the TranslationUnit to which this Cursor belongs."""
        # If this triggers an AttributeError, the instance was not properly
        # created.
        return self._tu

    def get_children(self):
        """Return an iterator for accessing the children of this cursor."""

        # FIXME: Expose iteration from CIndex, PR6125.
        def visitor(child, parent, children):
            # FIXME: Document this assertion in API.
            # FIXME: There should just be an isNull method.
            assert child != lib.clang_getNullCursor()

            # Create reference to TU so it isn't GC'd before Cursor.
            child._tu = self._tu
            children.append(child)
            return 1 # continue
        children = []
        lib.clang_visitChildren(self, callbacks['cursor_visit'](visitor),
            children)
        return iter(children)

    def get_tokens(self):
        """Obtain Token instances formulating that compose this Cursor.

        This is a generator for Token instances. It returns all tokens which
        occupy the extent this cursor occupies.
        """
        return TokenGroup.get_tokens(self._tu, self.extent)

    @staticmethod
    def from_result(res, fn, args):
        assert isinstance(res, Cursor)
        # FIXME: There should just be an isNull method.
        if res == lib.clang_getNullCursor():
            return None

        # Store a reference to the TU in the Python object so it won't get GC'd
        # before the Cursor.
        tu = None
        for arg in args:
            if isinstance(arg, TranslationUnit):
                tu = arg
                break

            if hasattr(arg, 'translation_unit'):
                tu = arg.translation_unit
                break

        assert tu is not None

        res._tu = tu
        return res

    @staticmethod
    def from_cursor_result(res, fn, args):
        assert isinstance(res, Cursor)
        if res == lib.clang_getNullCursor():
            return None

        res._tu = args[0]._tu
        return res

### Type Kinds ###

class TypeKind(object):
    """
    Describes the kind of type.
    """

    # The unique kind objects, indexed by id.
    _kinds = []
    _name_map = None

    def __init__(self, value):
        if value >= len(TypeKind._kinds):
            TypeKind._kinds += [None] * (value - len(TypeKind._kinds) + 1)
        if TypeKind._kinds[value] is not None:
            raise ValueError,'TypeKind already loaded'
        self.value = value
        TypeKind._kinds[value] = self
        TypeKind._name_map = None

    def from_param(self):
        return self.value

    @property
    def name(self):
        """Get the enumeration name of this cursor kind."""
        if self._name_map is None:
            self._name_map = {}
            for key,value in TypeKind.__dict__.items():
                if isinstance(value,TypeKind):
                    self._name_map[value] = key
        return self._name_map[self]

    @property
    def spelling(self):
        """Retrieve the spelling of this TypeKind."""
        return lib.clang_getTypeKindSpelling(self.value)

    @staticmethod
    def from_id(id):
        if id >= len(TypeKind._kinds) or TypeKind._kinds[id] is None:
            raise ValueError,'Unknown type kind %d' % id
        return TypeKind._kinds[id]

    def __repr__(self):
        return 'TypeKind.%s' % (self.name,)

TypeKind.INVALID = TypeKind(0)
TypeKind.UNEXPOSED = TypeKind(1)
TypeKind.VOID = TypeKind(2)
TypeKind.BOOL = TypeKind(3)
TypeKind.CHAR_U = TypeKind(4)
TypeKind.UCHAR = TypeKind(5)
TypeKind.CHAR16 = TypeKind(6)
TypeKind.CHAR32 = TypeKind(7)
TypeKind.USHORT = TypeKind(8)
TypeKind.UINT = TypeKind(9)
TypeKind.ULONG = TypeKind(10)
TypeKind.ULONGLONG = TypeKind(11)
TypeKind.UINT128 = TypeKind(12)
TypeKind.CHAR_S = TypeKind(13)
TypeKind.SCHAR = TypeKind(14)
TypeKind.WCHAR = TypeKind(15)
TypeKind.SHORT = TypeKind(16)
TypeKind.INT = TypeKind(17)
TypeKind.LONG = TypeKind(18)
TypeKind.LONGLONG = TypeKind(19)
TypeKind.INT128 = TypeKind(20)
TypeKind.FLOAT = TypeKind(21)
TypeKind.DOUBLE = TypeKind(22)
TypeKind.LONGDOUBLE = TypeKind(23)
TypeKind.NULLPTR = TypeKind(24)
TypeKind.OVERLOAD = TypeKind(25)
TypeKind.DEPENDENT = TypeKind(26)
TypeKind.OBJCID = TypeKind(27)
TypeKind.OBJCCLASS = TypeKind(28)
TypeKind.OBJCSEL = TypeKind(29)
TypeKind.COMPLEX = TypeKind(100)
TypeKind.POINTER = TypeKind(101)
TypeKind.BLOCKPOINTER = TypeKind(102)
TypeKind.LVALUEREFERENCE = TypeKind(103)
TypeKind.RVALUEREFERENCE = TypeKind(104)
TypeKind.RECORD = TypeKind(105)
TypeKind.ENUM = TypeKind(106)
TypeKind.TYPEDEF = TypeKind(107)
TypeKind.OBJCINTERFACE = TypeKind(108)
TypeKind.OBJCOBJECTPOINTER = TypeKind(109)
TypeKind.FUNCTIONNOPROTO = TypeKind(110)
TypeKind.FUNCTIONPROTO = TypeKind(111)
TypeKind.CONSTANTARRAY = TypeKind(112)
TypeKind.VECTOR = TypeKind(113)

class Type(Structure):
    """
    The type of an element in the abstract syntax tree.
    """
    _fields_ = [("_kind_id", c_int), ("data", c_void_p * 2)]

    @property
    def kind(self):
        """Return the kind of this type."""
        return TypeKind.from_id(self._kind_id)

    def argument_types(self):
        """Retrieve a container for the non-variadic arguments for this type.

        The returned object is iterable and indexable. Each item in the
        container is a Type instance.
        """
        class ArgumentsIterator(collections.Sequence):
            def __init__(self, parent):
                self.parent = parent
                self.length = None

            def __len__(self):
                if self.length is None:
                    self.length = lib.clang_getNumArgTypes(self.parent)

                return self.length

            def __getitem__(self, key):
                # FIXME Support slice objects.
                if not isinstance(key, int):
                    raise TypeError("Must supply a non-negative int.")

                if key < 0:
                    raise IndexError("Only non-negative indexes are accepted.")

                if key >= len(self):
                    raise IndexError("Index greater than container length: "
                                     "%d > %d" % ( key, len(self) ))

                result = lib.clang_getArgType(self.parent, key)
                if result.kind == TypeKind.INVALID:
                    raise IndexError("Argument could not be retrieved.")

                return result

        assert self.kind == TypeKind.FUNCTIONPROTO
        return ArgumentsIterator(self)

    @property
    def element_type(self):
        """Retrieve the Type of elements within this Type.

        If accessed on a type that is not an array, complex, or vector type, an
        exception will be raised.
        """
        result = lib.clang_getElementType(self)
        if result.kind == TypeKind.INVALID:
            raise Exception('Element type not available on this type.')

        return result

    @property
    def element_count(self):
        """Retrieve the number of elements in this type.

        Returns an int.

        If the Type is not an array or vector, this raises.
        """
        result = lib.clang_getNumElements(self)
        if result < 0:
            raise Exception('Type does not have elements.')

        return result

    @property
    def translation_unit(self):
        """The TranslationUnit to which this Type is associated."""
        # If this triggers an AttributeError, the instance was not properly
        # instantiated.
        return self._tu

    @staticmethod
    def from_result(res, fn, args):
        assert isinstance(res, Type)

        tu = None
        for arg in args:
            if hasattr(arg, 'translation_unit'):
                tu = arg.translation_unit
                break

        assert tu is not None
        res._tu = tu

        return res

    def get_canonical(self):
        """
        Return the canonical type for a Type.

        Clang's type system explicitly models typedefs and all the
        ways a specific type can be represented.  The canonical type
        is the underlying type with all the "sugar" removed.  For
        example, if 'T' is a typedef for 'int', the canonical type for
        'T' would be 'int'.
        """
        return lib.clang_getCanonicalType(self)

    def is_const_qualified(self):
        """Determine whether a Type has the "const" qualifier set.

        This does not look through typedefs that may have added "const"
        at a different level.
        """
        return lib.clang_isConstQualifiedType(self)

    def is_volatile_qualified(self):
        """Determine whether a Type has the "volatile" qualifier set.

        This does not look through typedefs that may have added "volatile"
        at a different level.
        """
        return lib.clang_isVolatileQualifiedType(self)

    def is_restrict_qualified(self):
        """Determine whether a Type has the "restrict" qualifier set.

        This does not look through typedefs that may have added "restrict" at
        a different level.
        """
        return lib.clang_isRestrictQualifiedType(self)

    def is_function_variadic(self):
        """Determine whether this function Type is a variadic function type."""
        assert self.kind == TypeKind.FUNCTIONPROTO

        return lib.clang_isFunctionTypeVariadic(self)

    def is_pod(self):
        """Determine whether this Type represents plain old data (POD)."""
        return lib.clang_isPODType(self)

    def get_pointee(self):
        """
        For pointer types, returns the type of the pointee.
        """
        return lib.clang_getPointeeType(self)

    def get_declaration(self):
        """
        Return the cursor for the declaration of the given type.
        """
        return lib.clang_getTypeDeclaration(self)

    def get_result(self):
        """
        Retrieve the result type associated with a function type.
        """
        return lib.clang_getResultType(self)

    def get_array_element_type(self):
        """
        Retrieve the type of the elements of the array type.
        """
        return lib.clang_getArrayElementType(self)

    def get_array_size(self):
        """
        Retrieve the size of the constant array.
        """
        return lib.clang_getArraySize(self)

    def __eq__(self, other):
        if type(other) != type(self):
            return False

        return lib.clang_equalTypes(self, other)

    def __ne__(self, other):
        return not self.__eq__(other)

## CIndex Objects ##

# CIndex objects (derived from ClangObject) are essentially lightweight
# wrappers attached to some underlying object, which is exposed via CIndex as
# a void*.

class ClangObject(object):
    """
    A helper for Clang objects. This class helps act as an intermediary for
    the ctypes library and the Clang CIndex library.
    """
    def __init__(self, obj):
        assert isinstance(obj, c_object_p) and obj
        self.obj = self._as_parameter_ = obj

    def from_param(self):
        return self._as_parameter_


class _CXUnsavedFile(Structure):
    """Helper for passing unsaved file arguments."""
    _fields_ = [("name", c_char_p), ("contents", c_char_p), ('length', c_ulong)]

class CompletionChunk:
    class Kind:
        def __init__(self, name):
            self.name = name

        def __str__(self):
            return self.name

        def __repr__(self):
            return "<ChunkKind: %s>" % self

    def __init__(self, completionString, key):
        self.cs = completionString
        self.key = key

    def __repr__(self):
        return "{'" + self.spelling + "', " + str(self.kind) + "}"

    @CachedProperty
    def spelling(self):
        return lib.clang_getCompletionChunkText(self.cs, self.key).spelling

    @CachedProperty
    def kind(self):
        return completionChunkKindMap[self.raw_kind]

    @CachedProperty
    def raw_kind(self):
        return lib.clang_getCompletionChunkKind(self.cs, self.key)

    @CachedProperty
    def string(self):
        res = lib.clang_getCompletionChunkCompletionString(self.cs, self.key)

        if (res):
          return CompletionString(res)
        else:
          None

    def isKindOptional(self):
      return self.raw_kind == 0

    def isKindTypedText(self):
      return self.raw_kind == 1

    def isKindPlaceHolder(self):
      return self.raw_kind == 3

    def isKindInformative(self):
      return self.raw_kind == 4

    def isKindResultType(self):
      return self.raw_kind == 15

completionChunkKindMap = {
            0: CompletionChunk.Kind("Optional"),
            1: CompletionChunk.Kind("TypedText"),
            2: CompletionChunk.Kind("Text"),
            3: CompletionChunk.Kind("Placeholder"),
            4: CompletionChunk.Kind("Informative"),
            5: CompletionChunk.Kind("CurrentParameter"),
            6: CompletionChunk.Kind("LeftParen"),
            7: CompletionChunk.Kind("RightParen"),
            8: CompletionChunk.Kind("LeftBracket"),
            9: CompletionChunk.Kind("RightBracket"),
            10: CompletionChunk.Kind("LeftBrace"),
            11: CompletionChunk.Kind("RightBrace"),
            12: CompletionChunk.Kind("LeftAngle"),
            13: CompletionChunk.Kind("RightAngle"),
            14: CompletionChunk.Kind("Comma"),
            15: CompletionChunk.Kind("ResultType"),
            16: CompletionChunk.Kind("Colon"),
            17: CompletionChunk.Kind("SemiColon"),
            18: CompletionChunk.Kind("Equal"),
            19: CompletionChunk.Kind("HorizontalSpace"),
            20: CompletionChunk.Kind("VerticalSpace")}

class CompletionString(ClangObject):
    class Availability:
        def __init__(self, name):
            self.name = name

        def __str__(self):
            return self.name

        def __repr__(self):
            return "<Availability: %s>" % self

    def __len__(self):
        self.num_chunks

    def __getitem__(self, key):
        if self.num_chunks <= key:
            raise IndexError
        return CompletionChunk(self.obj, key)

    def __repr__(self):
        return " | ".join([str(a) for a in self]) \
               + " || Priority: " + str(self.priority) \
               + " || Availability: " + str(self.availability)

    @CachedProperty
    def num_chunks(self):
        return lib.clang_getNumCompletionChunks(self.obj)

    @CachedProperty
    def priority(self):
        return lib.clang_getCompletionPriority(self.obj)

    @CachedProperty
    def availability(self):
        return availabilityKinds[self.raw_availability]

    @CachedProperty
    def raw_availability(self):
        return lib.clang_getCompletionAvailability(self.obj)

    def isAvailable(self):
        return self.raw_availability == 0

    def isDeprecated(self):
        return self.raw_availability == 1

    def isNotAvailable(self):
        return self.raw_availability == 2

    def isNotAccessible(self):
        return self.raw_availability == 3

availabilityKinds = {
            0: CompletionChunk.Kind("Available"),
            1: CompletionChunk.Kind("Deprecated"),
            2: CompletionChunk.Kind("NotAvailable"),
            3: CompletionChunk.Kind("NotAccessible")}

class CodeCompletionResult(Structure):
    _fields_ = [('cursorKind', c_int), ('completionString', c_object_p)]

    def __repr__(self):
        return str(CompletionString(self.completionString))

    @property
    def kind(self):
        return CursorKind.from_id(self.cursorKind)

    @property
    def string(self):
        return CompletionString(self.completionString)

class CCRStructure(Structure):
    _fields_ = [('results', POINTER(CodeCompletionResult)),
                ('numResults', c_int)]

    def __len__(self):
        return self.numResults

    def __getitem__(self, key):
        if len(self) <= key:
            raise IndexError

        return self.results[key]

class CodeCompletionResults(ClangObject):
    def __init__(self, ptr):
        assert isinstance(ptr, POINTER(CCRStructure)) and ptr
        self.ptr = self._as_parameter_ = ptr

    def from_param(self):
        return self._as_parameter_

    def __del__(self):
        lib.clang_disposeCodeCompleteResults(self)

    @property
    def results(self):
        return self.ptr.contents

    @property
    def diagnostics(self):
        class DiagnosticsItr:
            def __init__(self, ccr):
                self.ccr= ccr

            def __len__(self):
                return int(lib.clang_codeCompleteGetNumDiagnostics(self.ccr))

            def __getitem__(self, key):
                return lib.clang_codeCompleteGetDiagnostic(self.ccr, key)

        return DiagnosticsItr(self)


class Index(ClangObject):
    """
    The Index type provides the primary interface to the Clang CIndex library,
    primarily by providing an interface for reading and parsing translation
    units.
    """

    @staticmethod
    def create(excludeDecls=False):
        """
        Create a new Index.
        Parameters:
        excludeDecls -- Exclude local declarations from translation units.
        """
        return Index(lib.clang_createIndex(excludeDecls, 0))

    def __del__(self):
        lib.clang_disposeIndex(self)

    def read(self, path):
        """Load a TranslationUnit from the given AST file."""
        return TranslationUnit.from_ast(path, self)

    def parse(self, path, args=None, unsaved_files=None, options = 0):
        """Load the translation unit from the given source code file by running
        clang and generating the AST before loading. Additional command line
        parameters can be passed to clang via the args parameter.

        In-memory contents for files can be provided by passing a list of pairs
        to as unsaved_files, the first item should be the filenames to be mapped
        and the second should be the contents to be substituted for the
        file. The contents may be passed as strings or file objects.

        If an error was encountered during parsing, a TranslationUnitLoadError
        will be raised.
        """
        return TranslationUnit.from_source(path, args, unsaved_files, options,
                                           self)

class TranslationUnit(ClangObject):
    """Represents a source code translation unit.

    This is one of the main types in the API. Any time you wish to interact
    with Clang's representation of a source file, you typically start with a
    translation unit.
    """

    # Default parsing mode.
    PARSE_NONE = 0

    # Instruct the parser to create a detailed processing record containing
    # metadata not normally retained.
    PARSE_DETAILED_PROCESSING_RECORD = 1

    # Indicates that the translation unit is incomplete. This is typically used
    # when parsing headers.
    PARSE_INCOMPLETE = 2

    # Instruct the parser to create a pre-compiled preamble for the translation
    # unit. This caches the preamble (included files at top of source file).
    # This is useful if the translation unit will be reparsed and you don't
    # want to incur the overhead of reparsing the preamble.
    PARSE_PRECOMPILED_PREAMBLE = 4

    # Cache code completion information on parse. This adds time to parsing but
    # speeds up code completion.
    PARSE_CACHE_COMPLETION_RESULTS = 8

    # Flags with values 16 and 32 are deprecated and intentionally omitted.

    # Do not parse function bodies. This is useful if you only care about
    # searching for declarations/definitions.
    PARSE_SKIP_FUNCTION_BODIES = 64

    @classmethod
    def from_source(cls, filename, args=None, unsaved_files=None, options=0,
                    index=None):
        """Create a TranslationUnit by parsing source.

        This is capable of processing source code both from files on the
        filesystem as well as in-memory contents.

        Command-line arguments that would be passed to clang are specified as
        a list via args. These can be used to specify include paths, warnings,
        etc. e.g. ["-Wall", "-I/path/to/include"].

        In-memory file content can be provided via unsaved_files. This is an
        iterable of 2-tuples. The first element is the str filename. The
        second element defines the content. Content can be provided as str
        source code or as file objects (anything with a read() method). If
        a file object is being used, content will be read until EOF and the
        read cursor will not be reset to its original position.

        options is a bitwise or of TranslationUnit.PARSE_XXX flags which will
        control parsing behavior.

        index is an Index instance to utilize. If not provided, a new Index
        will be created for this TranslationUnit.

        To parse source from the filesystem, the filename of the file to parse
        is specified by the filename argument. Or, filename could be None and
        the args list would contain the filename(s) to parse.

        To parse source from an in-memory buffer, set filename to the virtual
        filename you wish to associate with this source (e.g. "test.c"). The
        contents of that file are then provided in unsaved_files.

        If an error occurs, a TranslationUnitLoadError is raised.

        Please note that a TranslationUnit with parser errors may be returned.
        It is the caller's responsibility to check tu.diagnostics for errors.

        Also note that Clang infers the source language from the extension of
        the input filename. If you pass in source code containing a C++ class
        declaration with the filename "test.c" parsing will fail.
        """
        if args is None:
            args = []

        if unsaved_files is None:
            unsaved_files = []

        if index is None:
            index = Index.create()

        args_array = None
        if len(args) > 0:
            args_array = (c_char_p * len(args))(* args)

        unsaved_array = None
        if len(unsaved_files) > 0:
            unsaved_array = (_CXUnsavedFile * len(unsaved_files))()
            for i, (name, contents) in enumerate(unsaved_files):
                if hasattr(contents, "read"):
                    contents = contents.read()

                unsaved_array[i].name = name
                unsaved_array[i].contents = contents
                unsaved_array[i].length = len(contents)

        ptr = lib.clang_parseTranslationUnit(index, filename, args_array,
                                    len(args), unsaved_array,
                                    len(unsaved_files), options)

        if ptr is None:
            raise TranslationUnitLoadError("Error parsing translation unit.")

        return cls(ptr, index=index)

    @classmethod
    def from_ast_file(cls, filename, index=None):
        """Create a TranslationUnit instance from a saved AST file.

        A previously-saved AST file (provided with -emit-ast or
        TranslationUnit.save()) is loaded from the filename specified.

        If the file cannot be loaded, a TranslationUnitLoadError will be
        raised.

        index is optional and is the Index instance to use. If not provided,
        a default Index will be created.
        """
        if index is None:
            index = Index.create()

        ptr = lib.clang_createTranslationUnit(index, filename)
        if ptr is None:
            raise TranslationUnitLoadError(filename)

        return cls(ptr=ptr, index=index)

    def __init__(self, ptr, index):
        """Create a TranslationUnit instance.

        TranslationUnits should be created using one of the from_* @classmethod
        functions above. __init__ is only called internally.
        """
        assert isinstance(index, Index)

        ClangObject.__init__(self, ptr)

    def __del__(self):
        lib.clang_disposeTranslationUnit(self)

    @property
    def cursor(self):
        """Retrieve the cursor that represents the given translation unit."""
        return lib.clang_getTranslationUnitCursor(self)

    @property
    def spelling(self):
        """Get the original translation unit source file name."""
        return lib.clang_getTranslationUnitSpelling(self)

    def get_includes(self):
        """
        Return an iterable sequence of FileInclusion objects that describe the
        sequence of inclusions in a translation unit. The first object in
        this sequence is always the input file. Note that this method will not
        recursively iterate over header files included through precompiled
        headers.
        """
        def visitor(fobj, lptr, depth, includes):
            if depth > 0:
                loc = lptr.contents
                includes.append(FileInclusion(loc.file, File(fobj), loc, depth))

        # Automatically adapt CIndex/ctype pointers to python objects
        includes = []
        lib.clang_getInclusions(self,
                callbacks['translation_unit_includes'](visitor), includes)

        return iter(includes)

    def get_file(self, filename):
        """Obtain a File from this translation unit."""

        return File.from_name(self, filename)

    def get_location(self, filename, position):
        """Obtain a SourceLocation for a file in this translation unit.

        The position can be specified by passing:

          - Integer file offset. Initial file offset is 0.
          - 2-tuple of (line number, column number). Initial file position is
            (0, 0)
        """
        f = self.get_file(filename)

        if isinstance(position, int):
            return SourceLocation.from_offset(self, f, position)

        return SourceLocation.from_position(self, f, position[0], position[1])

    def get_extent(self, filename, locations):
        """Obtain a SourceRange from this translation unit.

        The bounds of the SourceRange must ultimately be defined by a start and
        end SourceLocation. For the locations argument, you can pass:

          - 2 SourceLocation instances in a 2-tuple or list.
          - 2 int file offsets via a 2-tuple or list.
          - 2 2-tuple or lists of (line, column) pairs in a 2-tuple or list.

        e.g.

        get_extent('foo.c', (5, 10))
        get_extent('foo.c', ((1, 1), (1, 15)))
        """
        f = self.get_file(filename)

        if len(locations) < 2:
            raise Exception('Must pass object with at least 2 elements')

        start_location, end_location = locations

        if hasattr(start_location, '__len__'):
            start_location = SourceLocation.from_position(self, f,
                start_location[0], start_location[1])
        elif isinstance(start_location, int):
            start_location = SourceLocation.from_offset(self, f,
                start_location)

        if hasattr(end_location, '__len__'):
            end_location = SourceLocation.from_position(self, f,
                end_location[0], end_location[1])
        elif isinstance(end_location, int):
            end_location = SourceLocation.from_offset(self, f, end_location)

        assert isinstance(start_location, SourceLocation)
        assert isinstance(end_location, SourceLocation)

        return SourceRange.from_locations(start_location, end_location)

    @property
    def diagnostics(self):
        """
        Return an iterable (and indexable) object containing the diagnostics.
        """
        class DiagIterator:
            def __init__(self, tu):
                self.tu = tu

            def __len__(self):
                return int(lib.clang_getNumDiagnostics(self.tu))

            def __getitem__(self, key):
                diag = lib.clang_getDiagnostic(self.tu, key)
                if not diag:
                    raise IndexError
                return Diagnostic(diag)

        return DiagIterator(self)

    def reparse(self, unsaved_files=None, options=0):
        """
        Reparse an already parsed translation unit.

        In-memory contents for files can be provided by passing a list of pairs
        as unsaved_files, the first items should be the filenames to be mapped
        and the second should be the contents to be substituted for the
        file. The contents may be passed as strings or file objects.
        """
        if unsaved_files is None:
            unsaved_files = []

        unsaved_files_array = 0
        if len(unsaved_files):
            unsaved_files_array = (_CXUnsavedFile * len(unsaved_files))()
            for i,(name,value) in enumerate(unsaved_files):
                if not isinstance(value, str):
                    # FIXME: It would be great to support an efficient version
                    # of this, one day.
                    value = value.read()
                    print value
                if not isinstance(value, str):
                    raise TypeError,'Unexpected unsaved file contents.'
                unsaved_files_array[i].name = name
                unsaved_files_array[i].contents = value
                unsaved_files_array[i].length = len(value)
        ptr = lib.clang_reparseTranslationUnit(self, len(unsaved_files),
                unsaved_files_array, options)

    def save(self, filename):
        """Saves the TranslationUnit to a file.

        This is equivalent to passing -emit-ast to the clang frontend. The
        saved file can be loaded back into a TranslationUnit. Or, if it
        corresponds to a header, it can be used as a pre-compiled header file.

        If an error occurs while saving, a TranslationUnitSaveError is raised.
        If the error was TranslationUnitSaveError.ERROR_INVALID_TU, this means
        the constructed TranslationUnit was not valid at time of save. In this
        case, the reason(s) why should be available via
        TranslationUnit.diagnostics().

        filename -- The path to save the translation unit to.
        """
        options = lib.clang_defaultSaveOptions(self)
        result = int(lib.clang_saveTranslationUnit(self, filename, options))
        if result != 0:
            raise TranslationUnitSaveError(result,
                'Error saving TranslationUnit.')

    def codeComplete(self, path, line, column, unsaved_files=None, options=0):
        """
        Code complete in this translation unit.

        In-memory contents for files can be provided by passing a list of pairs
        as unsaved_files, the first items should be the filenames to be mapped
        and the second should be the contents to be substituted for the
        file. The contents may be passed as strings or file objects.
        """
        if unsaved_files is None:
            unsaved_files = []

        unsaved_files_array = 0
        if len(unsaved_files):
            unsaved_files_array = (_CXUnsavedFile * len(unsaved_files))()
            for i,(name,value) in enumerate(unsaved_files):
                if not isinstance(value, str):
                    # FIXME: It would be great to support an efficient version
                    # of this, one day.
                    value = value.read()
                    print value
                if not isinstance(value, str):
                    raise TypeError,'Unexpected unsaved file contents.'
                unsaved_files_array[i].name = name
                unsaved_files_array[i].contents = value
                unsaved_files_array[i].length = len(value)
        ptr = lib.clang_codeCompleteAt(self, path, line, column,
                unsaved_files_array, len(unsaved_files), options)
        if ptr:
            return CodeCompletionResults(ptr)
        return None

    def get_tokens(self, locations=None, extent=None):
        """Obtain tokens in this translation unit.

        This is a generator for Token instances. The caller specifies a range
        of source code to obtain tokens for. The range can be specified as a
        2-tuple of SourceLocation or as a SourceRange. If both are defined,
        behavior is undefined.
        """
        if locations is not None:
            extent = SourceRange(start=locations[0], end=locations[1])

        return TokenGroup.get_tokens(self, extent)

class File(ClangObject):
    """
    The File class represents a particular source file that is part of a
    translation unit.
    """

    @staticmethod
    def from_name(translation_unit, file_name):
        """Retrieve a file handle within the given translation unit."""
        return File(lib.clang_getFile(translation_unit, file_name))

    @property
    def name(self):
        """Return the complete file and path name of the file."""
        return lib.clang_getCString(lib.clang_getFileName(self))

    @property
    def time(self):
        """Return the last modification time of the file."""
        return lib.clang_getFileTime(self)

    def __str__(self):
        return self.name

    def __repr__(self):
        return "<File: %s>" % (self.name)

    @staticmethod
    def from_cursor_result(res, fn, args):
        assert isinstance(res, File)

        # Copy a reference to the TranslationUnit to prevent premature GC.
        res._tu = args[0]._tu
        return res

class FileInclusion(object):
    """
    The FileInclusion class represents the inclusion of one source file by
    another via a '#include' directive or as the input file for the translation
    unit. This class provides information about the included file, the including
    file, the location of the '#include' directive and the depth of the included
    file in the stack. Note that the input file has depth 0.
    """

    def __init__(self, src, tgt, loc, depth):
        self.source = src
        self.include = tgt
        self.location = loc
        self.depth = depth

    @property
    def is_input_file(self):
        """True if the included file is the input file."""
        return self.depth == 0

class CompilationDatabaseError(Exception):
    """Represents an error that occurred when working with a CompilationDatabase

    Each error is associated to an enumerated value, accessible under
    e.cdb_error. Consumers can compare the value with one of the ERROR_
    constants in this class.
    """

    # An unknown error occured
    ERROR_UNKNOWN = 0

    # The database could not be loaded
    ERROR_CANNOTLOADDATABASE = 1

    def __init__(self, enumeration, message):
        assert isinstance(enumeration, int)

        if enumeration > 1:
            raise Exception("Encountered undefined CompilationDatabase error "
                            "constant: %d. Please file a bug to have this "
                            "value supported." % enumeration)

        self.cdb_error = enumeration
        Exception.__init__(self, 'Error %d: %s' % (enumeration, message))

class CompileCommand(object):
    """Represents the compile command used to build a file"""
    def __init__(self, cmd, ccmds):
        self.cmd = cmd
        # Keep a reference to the originating CompileCommands
        # to prevent garbage collection
        self.ccmds = ccmds

    @property
    def directory(self):
        """Get the working directory for this CompileCommand"""
        return lib.clang_CompileCommand_getDirectory(self.cmd)

    @property
    def arguments(self):
        """
        Get an iterable object providing each argument in the
        command line for the compiler invocation as a _CXString.

        Invariant : the first argument is the compiler executable
        """
        length = lib.clang_CompileCommand_getNumArgs(self.cmd)
        for i in xrange(length):
            yield lib.clang_CompileCommand_getArg(self.cmd, i)

class CompileCommands(object):
    """
    CompileCommands is an iterable object containing all CompileCommand
    that can be used for building a specific file.
    """
    def __init__(self, ccmds):
        self.ccmds = ccmds

    def __del__(self):
        lib.clang_CompileCommands_dispose(self.ccmds)

    def __len__(self):
        return int(lib.clang_CompileCommands_getSize(self.ccmds))

    def __getitem__(self, i):
        cc = lib.clang_CompileCommands_getCommand(self.ccmds, i)
        if not cc:
            raise IndexError
        return CompileCommand(cc, self)

    @staticmethod
    def from_result(res, fn, args):
        if not res:
            return None
        return CompileCommands(res)

class CompilationDatabase(ClangObject):
    """
    The CompilationDatabase is a wrapper class around
    clang::tooling::CompilationDatabase

    It enables querying how a specific source file can be built.
    """

    def __del__(self):
        lib.clang_CompilationDatabase_dispose(self)

    @staticmethod
    def from_result(res, fn, args):
        if not res:
            raise CompilationDatabaseError(0,
                                           "CompilationDatabase loading failed")
        return CompilationDatabase(res)

    @staticmethod
    def fromDirectory(buildDir):
        """Builds a CompilationDatabase from the database found in buildDir"""
        errorCode = c_uint()
        try:
            cdb = lib.clang_CompilationDatabase_fromDirectory(buildDir,
                byref(errorCode))
        except CompilationDatabaseError as e:
            raise CompilationDatabaseError(int(errorCode.value),
                                           "CompilationDatabase loading failed")
        return cdb

    def getCompileCommands(self, filename):
        """
        Get an iterable object providing all the CompileCommands available to
        build filename. Returns None if filename is not found in the database.
        """
        return lib.clang_CompilationDatabase_getCompileCommands(self, filename)

class Token(Structure):
    """Represents a single token from the preprocessor.

    Tokens are effectively segments of source code. Source code is first parsed
    into tokens before being converted into the AST and Cursors.

    Tokens are obtained from parsed TranslationUnit instances. You currently
    can't create tokens manually.
    """
    _fields_ = [
        ('int_data', c_uint * 4),
        ('ptr_data', c_void_p)
    ]

    @property
    def spelling(self):
        """The spelling of this token.

        This is the textual representation of the token in source.
        """
        return lib.clang_getTokenSpelling(self._tu, self)

    @property
    def kind(self):
        """Obtain the TokenKind of the current token."""
        return TokenKind.from_value(lib.clang_getTokenKind(self))

    @property
    def location(self):
        """The SourceLocation this Token occurs at."""
        return lib.clang_getTokenLocation(self._tu, self)

    @property
    def extent(self):
        """The SourceRange this Token occupies."""
        return lib.clang_getTokenExtent(self._tu, self)

    @property
    def cursor(self):
        """The Cursor this Token corresponds to."""
        cursor = Cursor()

        lib.clang_annotateTokens(self._tu, byref(self), 1, byref(cursor))

        return cursor

# Now comes the plumbing to hook up the C library.

# Register callback types in common container.
callbacks['translation_unit_includes'] = CFUNCTYPE(None, c_object_p,
        POINTER(SourceLocation), c_uint, py_object)
callbacks['cursor_visit'] = CFUNCTYPE(c_int, Cursor, Cursor, py_object)

def register_functions(lib):
    """Register function prototypes with a libclang library instance.

    This must be called as part of library instantiation so Python knows how
    to call out to the shared library.
    """
    # Functions are registered in strictly alphabetical order.
    lib.clang_annotateTokens.argtype = [TranslationUnit, POINTER(Token),
                                        c_uint, POINTER(Cursor)]

    lib.clang_CompilationDatabase_dispose.argtypes = [c_object_p]

    lib.clang_CompilationDatabase_fromDirectory.argtypes = [c_char_p,
        POINTER(c_uint)]
    lib.clang_CompilationDatabase_fromDirectory.restype = c_object_p
    lib.clang_CompilationDatabase_fromDirectory.errcheck = CompilationDatabase.from_result

    lib.clang_CompilationDatabase_getCompileCommands.argtypes = [c_object_p, c_char_p]
    lib.clang_CompilationDatabase_getCompileCommands.restype = c_object_p
    lib.clang_CompilationDatabase_getCompileCommands.errcheck = CompileCommands.from_result

    lib.clang_CompileCommands_dispose.argtypes = [c_object_p]

    lib.clang_CompileCommands_getCommand.argtypes = [c_object_p, c_uint]
    lib.clang_CompileCommands_getCommand.restype = c_object_p

    lib.clang_CompileCommands_getSize.argtypes = [c_object_p]
    lib.clang_CompileCommands_getSize.restype = c_uint

    lib.clang_CompileCommand_getArg.argtypes = [c_object_p, c_uint]
    lib.clang_CompileCommand_getArg.restype = _CXString
    lib.clang_CompileCommand_getArg.errcheck = _CXString.from_result

    lib.clang_CompileCommand_getDirectory.argtypes = [c_object_p]
    lib.clang_CompileCommand_getDirectory.restype = _CXString
    lib.clang_CompileCommand_getDirectory.errcheck = _CXString.from_result

    lib.clang_CompileCommand_getNumArgs.argtypes = [c_object_p]
    lib.clang_CompileCommand_getNumArgs.restype = c_uint

    lib.clang_codeCompleteAt.argtypes = [TranslationUnit, c_char_p, c_int,
        c_int, c_void_p, c_int, c_int]
    lib.clang_codeCompleteAt.restype = POINTER(CCRStructure)

    lib.clang_codeCompleteGetDiagnostic.argtypes = [CodeCompletionResults,
        c_int]
    lib.clang_codeCompleteGetDiagnostic.restype = Diagnostic

    lib.clang_codeCompleteGetNumDiagnostics.argtypes = [CodeCompletionResults]
    lib.clang_codeCompleteGetNumDiagnostics.restype = c_int

    lib.clang_createIndex.argtypes = [c_int, c_int]
    lib.clang_createIndex.restype = c_object_p

    lib.clang_createTranslationUnit.argtypes = [Index, c_char_p]
    lib.clang_createTranslationUnit.restype = c_object_p

    lib.clang_CXXMethod_isStatic.argtypes = [Cursor]
    lib.clang_CXXMethod_isStatic.restype = bool

    lib.clang_CXXMethod_isVirtual.argtypes = [Cursor]
    lib.clang_CXXMethod_isVirtual.restype = bool

    lib.clang_defaultSaveOptions.argtypes = [TranslationUnit]
    lib.clang_defaultSaveOptions.restype = c_uint

    lib.clang_disposeCodeCompleteResults.argtypes = [CodeCompletionResults]

    #lib.clang_disposeCXTUResourceUsage.argtypes = [CXTUResourceUsage]

    lib.clang_disposeDiagnostic.argtypes = [Diagnostic]

    lib.clang_disposeIndex.argtypes = [Index]

    lib.clang_disposeString.argtypes = [_CXString]

    lib.clang_disposeTokens.argtype = [TranslationUnit, POINTER(Token), c_uint]

    lib.clang_disposeTranslationUnit.argtypes = [TranslationUnit]

    lib.clang_equalCursors.argtypes = [Cursor, Cursor]
    lib.clang_equalCursors.restype = bool

    lib.clang_equalLocations.argtypes = [SourceLocation, SourceLocation]
    lib.clang_equalLocations.restype = bool

    lib.clang_equalRanges.argtypes = [SourceRange, SourceRange]
    lib.clang_equalRanges.restype = bool

    lib.clang_equalTypes.argtypes = [Type, Type]
    lib.clang_equalTypes.restype = bool

    lib.clang_getArgType.argtypes = [Type, c_uint]
    lib.clang_getArgType.restype = Type
    lib.clang_getArgType.errcheck = Type.from_result

    lib.clang_getArrayElementType.argtypes = [Type]
    lib.clang_getArrayElementType.restype = Type
    lib.clang_getArrayElementType.errcheck = Type.from_result

    lib.clang_getArraySize.argtypes = [Type]
    lib.clang_getArraySize.restype = c_longlong

    lib.clang_getCanonicalCursor.argtypes = [Cursor]
    lib.clang_getCanonicalCursor.restype = Cursor
    lib.clang_getCanonicalCursor.errcheck = Cursor.from_cursor_result

    lib.clang_getCanonicalType.argtypes = [Type]
    lib.clang_getCanonicalType.restype = Type
    lib.clang_getCanonicalType.errcheck = Type.from_result

    lib.clang_getCompletionAvailability.argtypes = [c_void_p]
    lib.clang_getCompletionAvailability.restype = c_int

    lib.clang_getCompletionChunkCompletionString.argtypes = [c_void_p, c_int]
    lib.clang_getCompletionChunkCompletionString.restype = c_object_p

    lib.clang_getCompletionChunkKind.argtypes = [c_void_p, c_int]
    lib.clang_getCompletionChunkKind.restype = c_int

    lib.clang_getCompletionChunkText.argtypes = [c_void_p, c_int]
    lib.clang_getCompletionChunkText.restype = _CXString

    lib.clang_getCompletionPriority.argtypes = [c_void_p]
    lib.clang_getCompletionPriority.restype = c_int

    lib.clang_getCString.argtypes = [_CXString]
    lib.clang_getCString.restype = c_char_p

    lib.clang_getCursor.argtypes = [TranslationUnit, SourceLocation]
    lib.clang_getCursor.restype = Cursor

    lib.clang_getCursorDefinition.argtypes = [Cursor]
    lib.clang_getCursorDefinition.restype = Cursor
    lib.clang_getCursorDefinition.errcheck = Cursor.from_result

    lib.clang_getCursorDisplayName.argtypes = [Cursor]
    lib.clang_getCursorDisplayName.restype = _CXString
    lib.clang_getCursorDisplayName.errcheck = _CXString.from_result

    lib.clang_getCursorExtent.argtypes = [Cursor]
    lib.clang_getCursorExtent.restype = SourceRange

    lib.clang_getCursorLexicalParent.argtypes = [Cursor]
    lib.clang_getCursorLexicalParent.restype = Cursor
    lib.clang_getCursorLexicalParent.errcheck = Cursor.from_cursor_result

    lib.clang_getCursorLocation.argtypes = [Cursor]
    lib.clang_getCursorLocation.restype = SourceLocation

    lib.clang_getCursorReferenced.argtypes = [Cursor]
    lib.clang_getCursorReferenced.restype = Cursor
    lib.clang_getCursorReferenced.errcheck = Cursor.from_result

    lib.clang_getCursorReferenceNameRange.argtypes = [Cursor, c_uint, c_uint]
    lib.clang_getCursorReferenceNameRange.restype = SourceRange

    lib.clang_getCursorSemanticParent.argtypes = [Cursor]
    lib.clang_getCursorSemanticParent.restype = Cursor
    lib.clang_getCursorSemanticParent.errcheck = Cursor.from_cursor_result

    lib.clang_getCursorSpelling.argtypes = [Cursor]
    lib.clang_getCursorSpelling.restype = _CXString
    lib.clang_getCursorSpelling.errcheck = _CXString.from_result

    lib.clang_getCursorType.argtypes = [Cursor]
    lib.clang_getCursorType.restype = Type
    lib.clang_getCursorType.errcheck = Type.from_result

    lib.clang_getCursorUSR.argtypes = [Cursor]
    lib.clang_getCursorUSR.restype = _CXString
    lib.clang_getCursorUSR.errcheck = _CXString.from_result

    #lib.clang_getCXTUResourceUsage.argtypes = [TranslationUnit]
    #lib.clang_getCXTUResourceUsage.restype = CXTUResourceUsage

    lib.clang_getCXXAccessSpecifier.argtypes = [Cursor]
    lib.clang_getCXXAccessSpecifier.restype = c_uint

    lib.clang_getDeclObjCTypeEncoding.argtypes = [Cursor]
    lib.clang_getDeclObjCTypeEncoding.restype = _CXString
    lib.clang_getDeclObjCTypeEncoding.errcheck = _CXString.from_result

    lib.clang_getDiagnostic.argtypes = [c_object_p, c_uint]
    lib.clang_getDiagnostic.restype = c_object_p

    lib.clang_getDiagnosticCategory.argtypes = [Diagnostic]
    lib.clang_getDiagnosticCategory.restype = c_uint

    lib.clang_getDiagnosticCategoryName.argtypes = [c_uint]
    lib.clang_getDiagnosticCategoryName.restype = _CXString
    lib.clang_getDiagnosticCategoryName.errcheck = _CXString.from_result

    lib.clang_getDiagnosticFixIt.argtypes = [Diagnostic, c_uint,
        POINTER(SourceRange)]
    lib.clang_getDiagnosticFixIt.restype = _CXString
    lib.clang_getDiagnosticFixIt.errcheck = _CXString.from_result

    lib.clang_getDiagnosticLocation.argtypes = [Diagnostic]
    lib.clang_getDiagnosticLocation.restype = SourceLocation

    lib.clang_getDiagnosticNumFixIts.argtypes = [Diagnostic]
    lib.clang_getDiagnosticNumFixIts.restype = c_uint

    lib.clang_getDiagnosticNumRanges.argtypes = [Diagnostic]
    lib.clang_getDiagnosticNumRanges.restype = c_uint

    lib.clang_getDiagnosticOption.argtypes = [Diagnostic, POINTER(_CXString)]
    lib.clang_getDiagnosticOption.restype = _CXString
    lib.clang_getDiagnosticOption.errcheck = _CXString.from_result

    lib.clang_getDiagnosticRange.argtypes = [Diagnostic, c_uint]
    lib.clang_getDiagnosticRange.restype = SourceRange

    lib.clang_getDiagnosticSeverity.argtypes = [Diagnostic]
    lib.clang_getDiagnosticSeverity.restype = c_int

    lib.clang_getDiagnosticSpelling.argtypes = [Diagnostic]
    lib.clang_getDiagnosticSpelling.restype = _CXString
    lib.clang_getDiagnosticSpelling.errcheck = _CXString.from_result

    lib.clang_getElementType.argtypes = [Type]
    lib.clang_getElementType.restype = Type
    lib.clang_getElementType.errcheck = Type.from_result

    lib.clang_getEnumConstantDeclUnsignedValue.argtypes = [Cursor]
    lib.clang_getEnumConstantDeclUnsignedValue.restype = c_ulonglong

    lib.clang_getEnumConstantDeclValue.argtypes = [Cursor]
    lib.clang_getEnumConstantDeclValue.restype = c_longlong

    lib.clang_getEnumDeclIntegerType.argtypes = [Cursor]
    lib.clang_getEnumDeclIntegerType.restype = Type
    lib.clang_getEnumDeclIntegerType.errcheck = Type.from_result

    lib.clang_getFile.argtypes = [TranslationUnit, c_char_p]
    lib.clang_getFile.restype = c_object_p

    lib.clang_getFileName.argtypes = [File]
    lib.clang_getFileName.restype = _CXString
    # TODO go through _CXString.from_result?

    lib.clang_getFileTime.argtypes = [File]
    lib.clang_getFileTime.restype = c_uint

    lib.clang_getIBOutletCollectionType.argtypes = [Cursor]
    lib.clang_getIBOutletCollectionType.restype = Type
    lib.clang_getIBOutletCollectionType.errcheck = Type.from_result

    lib.clang_getIncludedFile.argtypes = [Cursor]
    lib.clang_getIncludedFile.restype = File
    lib.clang_getIncludedFile.errcheck = File.from_cursor_result

    lib.clang_getInclusions.argtypes = [TranslationUnit,
        callbacks['translation_unit_includes'], py_object]

    lib.clang_getInstantiationLocation.argtypes = [SourceLocation,
        POINTER(c_object_p), POINTER(c_uint), POINTER(c_uint), POINTER(c_uint)]

    lib.clang_getLocation.argtypes = [TranslationUnit, File, c_uint, c_uint]
    lib.clang_getLocation.restype = SourceLocation

    lib.clang_getLocationForOffset.argtypes = [TranslationUnit, File, c_uint]
    lib.clang_getLocationForOffset.restype = SourceLocation

    lib.clang_getNullCursor.restype = Cursor

    lib.clang_getNumArgTypes.argtypes = [Type]
    lib.clang_getNumArgTypes.restype = c_uint

    lib.clang_getNumCompletionChunks.argtypes = [c_void_p]
    lib.clang_getNumCompletionChunks.restype = c_int

    lib.clang_getNumDiagnostics.argtypes = [c_object_p]
    lib.clang_getNumDiagnostics.restype = c_uint

    lib.clang_getNumElements.argtypes = [Type]
    lib.clang_getNumElements.restype = c_longlong

    lib.clang_getNumOverloadedDecls.argtypes = [Cursor]
    lib.clang_getNumOverloadedDecls.restyp = c_uint

    lib.clang_getOverloadedDecl.argtypes = [Cursor, c_uint]
    lib.clang_getOverloadedDecl.restype = Cursor
    lib.clang_getOverloadedDecl.errcheck = Cursor.from_cursor_result

    lib.clang_getPointeeType.argtypes = [Type]
    lib.clang_getPointeeType.restype = Type
    lib.clang_getPointeeType.errcheck = Type.from_result

    lib.clang_getRange.argtypes = [SourceLocation, SourceLocation]
    lib.clang_getRange.restype = SourceRange

    lib.clang_getRangeEnd.argtypes = [SourceRange]
    lib.clang_getRangeEnd.restype = SourceLocation

    lib.clang_getRangeStart.argtypes = [SourceRange]
    lib.clang_getRangeStart.restype = SourceLocation

    lib.clang_getResultType.argtypes = [Type]
    lib.clang_getResultType.restype = Type
    lib.clang_getResultType.errcheck = Type.from_result

    lib.clang_getSpecializedCursorTemplate.argtypes = [Cursor]
    lib.clang_getSpecializedCursorTemplate.restype = Cursor
    lib.clang_getSpecializedCursorTemplate.errcheck = Cursor.from_cursor_result

    lib.clang_getTemplateCursorKind.argtypes = [Cursor]
    lib.clang_getTemplateCursorKind.restype = c_uint

    lib.clang_getTokenExtent.argtypes = [TranslationUnit, Token]
    lib.clang_getTokenExtent.restype = SourceRange

    lib.clang_getTokenKind.argtypes = [Token]
    lib.clang_getTokenKind.restype = c_uint

    lib.clang_getTokenLocation.argtype = [TranslationUnit, Token]
    lib.clang_getTokenLocation.restype = SourceLocation

    lib.clang_getTokenSpelling.argtype = [TranslationUnit, Token]
    lib.clang_getTokenSpelling.restype = _CXString
    lib.clang_getTokenSpelling.errcheck = _CXString.from_result

    lib.clang_getTranslationUnitCursor.argtypes = [TranslationUnit]
    lib.clang_getTranslationUnitCursor.restype = Cursor
    lib.clang_getTranslationUnitCursor.errcheck = Cursor.from_result

    lib.clang_getTranslationUnitSpelling.argtypes = [TranslationUnit]
    lib.clang_getTranslationUnitSpelling.restype = _CXString
    lib.clang_getTranslationUnitSpelling.errcheck = _CXString.from_result

    lib.clang_getTUResourceUsageName.argtypes = [c_uint]
    lib.clang_getTUResourceUsageName.restype = c_char_p

    lib.clang_getTypeDeclaration.argtypes = [Type]
    lib.clang_getTypeDeclaration.restype = Cursor
    lib.clang_getTypeDeclaration.errcheck = Cursor.from_result

    lib.clang_getTypedefDeclUnderlyingType.argtypes = [Cursor]
    lib.clang_getTypedefDeclUnderlyingType.restype = Type
    lib.clang_getTypedefDeclUnderlyingType.errcheck = Type.from_result

    lib.clang_getTypeKindSpelling.argtypes = [c_uint]
    lib.clang_getTypeKindSpelling.restype = _CXString
    lib.clang_getTypeKindSpelling.errcheck = _CXString.from_result

    lib.clang_hashCursor.argtypes = [Cursor]
    lib.clang_hashCursor.restype = c_uint

    lib.clang_isAttribute.argtypes = [CursorKind]
    lib.clang_isAttribute.restype = bool

    lib.clang_isConstQualifiedType.argtypes = [Type]
    lib.clang_isConstQualifiedType.restype = bool

    lib.clang_isCursorDefinition.argtypes = [Cursor]
    lib.clang_isCursorDefinition.restype = bool

    lib.clang_isDeclaration.argtypes = [CursorKind]
    lib.clang_isDeclaration.restype = bool

    lib.clang_isExpression.argtypes = [CursorKind]
    lib.clang_isExpression.restype = bool

    lib.clang_isFileMultipleIncludeGuarded.argtypes = [TranslationUnit, File]
    lib.clang_isFileMultipleIncludeGuarded.restype = bool

    lib.clang_isFunctionTypeVariadic.argtypes = [Type]
    lib.clang_isFunctionTypeVariadic.restype = bool

    lib.clang_isInvalid.argtypes = [CursorKind]
    lib.clang_isInvalid.restype = bool

    lib.clang_isPODType.argtypes = [Type]
    lib.clang_isPODType.restype = bool

    lib.clang_isPreprocessing.argtypes = [CursorKind]
    lib.clang_isPreprocessing.restype = bool

    lib.clang_isReference.argtypes = [CursorKind]
    lib.clang_isReference.restype = bool

    lib.clang_isRestrictQualifiedType.argtypes = [Type]
    lib.clang_isRestrictQualifiedType.restype = bool

    lib.clang_isStatement.argtypes = [CursorKind]
    lib.clang_isStatement.restype = bool

    lib.clang_isTranslationUnit.argtypes = [CursorKind]
    lib.clang_isTranslationUnit.restype = bool

    lib.clang_isUnexposed.argtypes = [CursorKind]
    lib.clang_isUnexposed.restype = bool

    lib.clang_isVirtualBase.argtypes = [Cursor]
    lib.clang_isVirtualBase.restype = bool

    lib.clang_isVolatileQualifiedType.argtypes = [Type]
    lib.clang_isVolatileQualifiedType.restype = bool

    lib.clang_parseTranslationUnit.argypes = [Index, c_char_p, c_void_p, c_int,
        c_void_p, c_int, c_int]
    lib.clang_parseTranslationUnit.restype = c_object_p

    lib.clang_reparseTranslationUnit.argtypes = [TranslationUnit, c_int,
        c_void_p, c_int]
    lib.clang_reparseTranslationUnit.restype = c_int

    lib.clang_saveTranslationUnit.argtypes = [TranslationUnit, c_char_p,
        c_uint]
    lib.clang_saveTranslationUnit.restype = c_int

    lib.clang_tokenize.argtypes = [TranslationUnit, SourceRange,
        POINTER(POINTER(Token)), POINTER(c_uint)]

    lib.clang_visitChildren.argtypes = [Cursor, callbacks['cursor_visit'],
        py_object]
    lib.clang_visitChildren.restype = c_uint

register_functions(lib)

def register_enumerations():
    for name, value in clang.enumerations.TokenKinds:
        TokenKind.register(value, name)

register_enumerations()

__all__ = [
    'CodeCompletionResults',
    'CompilationDatabase',
    'CompileCommands',
    'CompileCommand',
    'CursorKind',
    'Cursor',
    'Diagnostic',
    'File',
    'FixIt',
    'Index',
    'SourceLocation',
    'SourceRange',
    'TokenKind',
    'Token',
    'TranslationUnitLoadError',
    'TranslationUnit',
    'TypeKind',
    'Type',
]
plugin/clang/enumerations.py	[[[1
34
#===- enumerations.py - Python Enumerations ------------------*- python -*--===#
#
#                     The LLVM Compiler Infrastructure
#
# This file is distributed under the University of Illinois Open Source
# License. See LICENSE.TXT for details.
#
#===------------------------------------------------------------------------===#

"""
Clang Enumerations
==================

This module provides static definitions of enumerations that exist in libclang.

Enumerations are typically defined as a list of tuples. The exported values are
typically munged into other types or classes at module load time.

All enumerations are centrally defined in this file so they are all grouped
together and easier to audit. And, maybe even one day this file will be
automatically generated by scanning the libclang headers!
"""

# Maps to CXTokenKind. Note that libclang maintains a separate set of token
# enumerations from the C++ API.
TokenKinds = [
    ('PUNCTUATION', 0),
    ('KEYWORD', 1),
    ('IDENTIFIER', 2),
    ('LITERAL', 3),
    ('COMMENT', 4),
]

__all__ = ['TokenKinds']
plugin/clang_complete.vim	[[[1
751
"
" File: clang_complete.vim
" Author: Xavier Deguillard <deguilx@gmail.com>
"
" Description: Use of clang to complete in C/C++.
"
" Help: Use :help clang_complete
"

au FileType c,cpp,objc,objcpp call <SID>ClangCompleteInit()

let b:clang_parameters = ''
let b:clang_user_options = ''
let b:my_changedtick = 0

" Store plugin path, as this is available only when sourcing the file,
" not during a function call.
let s:plugin_path = escape(expand('<sfile>:p:h'), '\')

function! s:ClangCompleteInit()
  let l:bufname = bufname("%")
  if l:bufname == ''
    return
  endif
  
  if !exists('g:clang_auto_select')
    let g:clang_auto_select = 0
  endif

  if !exists('g:clang_complete_auto')
    let g:clang_complete_auto = 1
  endif

  if !exists('g:clang_close_preview')
    let g:clang_close_preview = 0
  endif

  if !exists('g:clang_complete_copen')
    let g:clang_complete_copen = 0
  endif

  if !exists('g:clang_hl_errors')
    let g:clang_hl_errors = 1
  endif

  if !exists('g:clang_periodic_quickfix')
    let g:clang_periodic_quickfix = 0
  endif

  if !exists('g:clang_snippets')
    let g:clang_snippets = 0
  endif

  if !exists('g:clang_snippets_engine')
    let g:clang_snippets_engine = 'clang_complete'
  endif

  if !exists('g:clang_exec')
    let g:clang_exec = 'clang'
  endif

  if !exists('g:clang_user_options')
    let g:clang_user_options = ''
  endif

  if !exists('g:clang_conceal_snippets')
    let g:clang_conceal_snippets = has('conceal')
  endif

  if !exists('g:clang_trailing_placeholder')
    let g:clang_trailing_placeholder = 0
  endif

  " Only use libclang if the user clearly show intent to do so for now
  if !exists('g:clang_use_library')
    let g:clang_use_library = (has('python') && exists('g:clang_library_path'))
  endif

  if !exists('g:clang_complete_macros')
    let g:clang_complete_macros = 0
  endif

  if !exists('g:clang_complete_patterns')
    let g:clang_complete_patterns = 0
  endif

  if !exists('g:clang_debug')
    let g:clang_debug = 0
  endif

  if !exists('g:clang_sort_algo')
    let g:clang_sort_algo = 'priority'
  endif

  if !exists('g:clang_auto_user_options')
    let g:clang_auto_user_options = 'path, .clang_complete, clang'
  endif

  if !exists('g:clang_memory_percent')
    let g:clang_memory_percent = 50
  endif

  call LoadUserOptions()

  inoremap <expr> <buffer> <C-X><C-U> <SID>LaunchCompletion()
  inoremap <expr> <buffer> . <SID>CompleteDot()
  inoremap <expr> <buffer> > <SID>CompleteArrow()
  inoremap <expr> <buffer> : <SID>CompleteColon()
  inoremap <expr> <buffer> <CR> <SID>HandlePossibleSelectionEnter()

  if g:clang_snippets == 1
    call g:ClangSetSnippetEngine(g:clang_snippets_engine)
  endif

  " Force menuone. Without it, when there's only one completion result,
  " it can be confusing (not completing and no popup)
  if g:clang_auto_select != 2
    set completeopt-=menu
    set completeopt+=menuone
  endif

  " Disable every autocmd that could have been set.
  augroup ClangComplete
    autocmd!
  augroup end

  let b:should_overload = 0
  let b:my_changedtick = b:changedtick
  let b:clang_parameters = '-x c'

  if &filetype == 'objc'
    let b:clang_parameters = '-x objective-c'
  endif

  if &filetype == 'cpp' || &filetype == 'objcpp'
    let b:clang_parameters .= '++'
  endif

  if expand('%:e') =~ 'h*'
    let b:clang_parameters .= '-header'
  endif

  let g:clang_complete_lib_flags = 0

  if g:clang_complete_macros == 1
    let b:clang_parameters .= ' -code-completion-macros'
    let g:clang_complete_lib_flags = 1
  endif

  if g:clang_complete_patterns == 1
    let b:clang_parameters .= ' -code-completion-patterns'
    let g:clang_complete_lib_flags += 2
  endif

  setlocal completefunc=ClangComplete
  setlocal omnifunc=ClangComplete

  if g:clang_periodic_quickfix == 1
    augroup ClangComplete
      au CursorHold,CursorHoldI <buffer> call <SID>DoPeriodicQuickFix()
    augroup end
  endif

  " Load the python bindings of libclang
  if g:clang_use_library == 1
    if has('python')
      call s:initClangCompletePython()
    else
      echoe 'clang_complete: No python support available.'
      echoe 'Cannot use clang library, using executable'
      echoe 'Compile vim with python support to use libclang'
      let g:clang_use_library = 0
    endif
  endif
endfunction

function! LoadUserOptions()
  let b:clang_user_options = ''

  let l:option_sources = split(g:clang_auto_user_options, ',')
  let l:remove_spaces_cmd = 'substitute(v:val, "\\s*\\(.*\\)\\s*", "\\1", "")'
  let l:option_sources = map(l:option_sources, l:remove_spaces_cmd)

  for l:source in l:option_sources
    if l:source == 'path'
      call s:parsePathOption()
    elseif l:source == '.clang_complete'
      call s:parseConfig()
    else
      let l:getopts = 'getopts#' . l:source . '#getopts'
      silent call eval(l:getopts . '()')
    endif
  endfor
endfunction

function! s:parseConfig()
  let l:local_conf = findfile('.clang_complete', getcwd() . ',.;')
  if l:local_conf == '' || !filereadable(l:local_conf)
    return
  endif

  let l:root = substitute(fnamemodify(l:local_conf, ':p:h'), '\', '/', 'g')

  let l:opts = readfile(l:local_conf)
  for l:opt in l:opts
    " Use forward slashes only
    let l:opt = substitute(l:opt, '\', '/', 'g')
    " Handling of absolute path
    if matchstr(l:opt, '\C-I\s*/') != ''
      let l:opt = substitute(l:opt, '\C-I\s*\(/\%(\w\|\\\s\)*\)',
            \ '-I' . '\1', 'g')
    elseif s:isWindows() && matchstr(l:opt, '\C-I\s*[a-zA-Z]:/') != ''
      let l:opt = substitute(l:opt, '\C-I\s*\([a-zA-Z:]/\%(\w\|\\\s\)*\)',
            \ '-I' . '\1', 'g')
    else
      let l:opt = substitute(l:opt, '\C-I\s*\(\%(\w\|\.\|/\|\\\s\)*\)',
            \ '-I' . l:root . '/\1', 'g')
    endif
    let b:clang_user_options .= ' ' . l:opt
  endfor
endfunction

function! s:parsePathOption()
  let l:dirs = split(&path, ',')
  for l:dir in l:dirs
    if len(l:dir) == 0 || !isdirectory(l:dir)
      continue
    endif

    " Add only absolute paths
    if matchstr(l:dir, '\s*/') != ''
      let l:opt = '-I' . l:dir
      let b:clang_user_options .= ' ' . l:opt
    endif
  endfor
endfunction

function! s:initClangCompletePython()
  " Only parse the python library once
  if !exists('s:libclang_loaded')
    python import sys
    if exists('g:clang_library_path')
      " Load the library from the given library path.
      exe 'python sys.argv = ["' . escape(g:clang_library_path, '\') . '"]'
    else
      " By setting argv[0] to '' force the python bindings to load the library
      " from the normal system search path.
      python sys.argv[0] = ''
    endif

    exe 'python sys.path = ["' . s:plugin_path . '"] + sys.path'
    exe 'pyfile ' . s:plugin_path . '/libclang.py'
    python initClangComplete(vim.eval('g:clang_complete_lib_flags'))
    let s:libclang_loaded = 1
  endif
endfunction

function! s:GetKind(proto)
  if a:proto == ''
    return 't'
  endif
  let l:ret = match(a:proto, '^\[#')
  let l:params = match(a:proto, '(')
  if l:ret == -1 && l:params == -1
    return 't'
  endif
  if l:ret != -1 && l:params == -1
    return 'v'
  endif
  if l:params != -1
    return 'f'
  endif
  return 'm'
endfunction

function! s:CallClangBinaryForDiagnostics(tempfile)
  let l:escaped_tempfile = shellescape(a:tempfile)
  let l:buf = getline(1, '$')
  try
    call writefile(l:buf, a:tempfile)
  catch /^Vim\%((\a\+)\)\=:E482/
    return
  endtry

  let l:command = g:clang_exec . ' -cc1 -fsyntax-only'
        \ . ' -fno-caret-diagnostics -fdiagnostics-print-source-range-info'
        \ . ' ' . l:escaped_tempfile
        \ . ' ' . b:clang_parameters . ' ' . b:clang_user_options . ' ' . g:clang_user_options

  let l:clang_output = split(system(s:escapeCommand(l:command)), "\n")
  call delete(a:tempfile)
  return l:clang_output
endfunction

function! s:CallClangForDiagnostics(tempfile)
  if g:clang_use_library == 1
    python updateCurrentDiagnostics()
  else
    return s:CallClangBinaryForDiagnostics(a:tempfile)
  endif
endfunction

function! s:DoPeriodicQuickFix()
  " Don't do any superfluous reparsing.
  if b:my_changedtick == b:changedtick
    return
  endif
  let b:my_changedtick = b:changedtick

  " Create tempfile name for clang/clang++ executable mode
  let l:tempfile = expand('%:p:h') . '/' . localtime() . expand('%:t')

  let l:clang_output = s:CallClangForDiagnostics(l:tempfile)

  call s:ClangQuickFix(l:clang_output, l:tempfile)
endfunction

function! s:ClangQuickFix(clang_output, tempfname)
  " Clear the bad spell, the user may have corrected them.
  syntax clear SpellBad
  syntax clear SpellLocal

  if g:clang_use_library == 0
    let l:list = s:ClangUpdateQuickFix(a:clang_output, a:tempfname)
  else
    python vim.command('let l:list = ' + str(getCurrentQuickFixList()))
    python highlightCurrentDiagnostics()
  endif

  if g:clang_complete_copen == 1
    " We should get back to the original buffer
    let l:bufnr = bufnr('%')

    " Workaround:
    " http://vim.1045645.n5.nabble.com/setqflist-inconsistency-td1211423.html
    if l:list == []
      cclose
    else
      copen
    endif

    let l:winbufnr = bufwinnr(l:bufnr)
    exe l:winbufnr . 'wincmd w'
  endif
  call setqflist(l:list)
  silent doautocmd QuickFixCmdPost make
endfunction

function! s:ClangUpdateQuickFix(clang_output, tempfname)
  let l:list = []
  for l:line in a:clang_output
    let l:erridx = match(l:line, '\%(error\|warning\|note\): ')
    if l:erridx == -1
      " Error are always at the beginning.
      if l:line[:11] == 'COMPLETION: ' || l:line[:9] == 'OVERLOAD: '
        break
      endif
      continue
    endif
    let l:pattern = '^\(.*\):\(\d*\):\(\d*\):\(\%({\d\+:\d\+-\d\+:\d\+}\)*\)'
    let l:tmp = matchstr(l:line, l:pattern)
    let l:fname = substitute(l:tmp, l:pattern, '\1', '')
    if l:fname == a:tempfname
      let l:fname = '%'
    endif
    let l:bufnr = bufnr(l:fname, 1)
    let l:lnum = substitute(l:tmp, l:pattern, '\2', '')
    let l:col = substitute(l:tmp, l:pattern, '\3', '')
    let l:errors = substitute(l:tmp, l:pattern, '\4', '')
    if l:line[l:erridx] == 'e'
      let l:text = l:line[l:erridx + 7:]
      let l:type = 'E'
      let l:hlgroup = ' SpellBad '
    elseif l:line[l:erridx] == 'w'
      let l:text = l:line[l:erridx + 9:]
      let l:type = 'W'
      let l:hlgroup = ' SpellLocal '
    else
      let l:text = l:line[l:erridx + 6:]
      let l:type = 'I'
      let l:hlgroup = ' '
    endif
    let l:item = {
          \ 'bufnr': l:bufnr,
          \ 'lnum': l:lnum,
          \ 'col': l:col,
          \ 'text': l:text,
          \ 'type': l:type }
    let l:list = add(l:list, l:item)

    if g:clang_hl_errors == 0 || l:fname != '%' || l:type == 'I'
      continue
    endif

    " Highlighting the ^
    let l:pat = '/\%' . l:lnum . 'l' . '\%' . l:col . 'c./'
    exe 'syntax match' . l:hlgroup . l:pat

    if l:errors == ''
      continue
    endif
    let l:ranges = split(l:errors, '}')
    for l:range in l:ranges
      " Doing precise error and warning handling.
      " The highlight will be the same as clang's carets.
      let l:pattern = '{\%(\d\+\):\(\d\+\)-\%(\d\+\):\(\d\+\)'
      let l:tmp = matchstr(l:range, l:pattern)
      let l:startcol = substitute(l:tmp, l:pattern, '\1', '')
      let l:endcol = substitute(l:tmp, l:pattern, '\2', '')
      " Highlighting the ~~~~
      let l:pat = '/\%' . l:lnum . 'l'
            \ . '\%' . l:startcol . 'c'
            \ . '.*'
            \ . '\%' . l:endcol . 'c/'
      exe 'syntax match' . l:hlgroup . l:pat
    endfor
  endfor
  return l:list
endfunction

function! s:DemangleProto(prototype)
  let l:proto = substitute(a:prototype, '\[#[^#]*#\]', '', 'g')
  let l:proto = substitute(l:proto, '{#.*#}', '', 'g')
  return l:proto
endfunction

let b:col = 0

function! s:ClangCompleteBinary(base)
  let l:buf = getline(1, '$')
  let l:tempfile = expand('%:p:h') . '/' . localtime() . expand('%:t')
  try
    call writefile(l:buf, l:tempfile)
  catch /^Vim\%((\a\+)\)\=:E482/
    return {}
  endtry
  let l:escaped_tempfile = shellescape(l:tempfile)

  let l:command = g:clang_exec . ' -cc1 -fsyntax-only'
        \ . ' -fno-caret-diagnostics -fdiagnostics-print-source-range-info'
        \ . ' -code-completion-at=' . l:escaped_tempfile . ':'
        \ . line('.') . ':' . b:col . ' ' . l:escaped_tempfile
        \ . ' ' . b:clang_parameters . ' ' . b:clang_user_options . ' ' . g:clang_user_options

  let l:clang_output = split(system(s:escapeCommand(l:command)), "\n")
  call delete(l:tempfile)

  call s:ClangQuickFix(l:clang_output, l:tempfile)
  if v:shell_error
    return []
  endif
  if l:clang_output == []
    return []
  endif

  let l:filter_str = "v:val =~ '^COMPLETION: " . a:base . "\\|^OVERLOAD: '"
  call filter(l:clang_output, l:filter_str)

  let l:res = []
  for l:line in l:clang_output

    if l:line[:11] == 'COMPLETION: ' && b:should_overload != 1

      let l:value = l:line[12:]

      let l:colonidx = stridx(l:value, ' : ')
      if l:colonidx == -1
        let l:wabbr = s:DemangleProto(l:value)
        let l:word = l:value
        let l:proto = l:value
      else
        let l:word = l:value[:l:colonidx - 1]
        " WTF is that?
        if l:word =~ '(Hidden)'
          let l:word = l:word[:-10]
        endif
        let l:wabbr = l:word
        let l:proto = l:value[l:colonidx + 3:]
      endif

      let l:kind = s:GetKind(l:proto)
      if l:kind == 't' && b:clang_complete_type == 0
        continue
      endif

      let l:word = l:wabbr
      let l:menu = substitute(l:proto, '\[#\([^#]*\)#\]', '\1 ', 'g')
      let l:menu = substitute(l:menu, '<#\([^#]*\)#>', '\1', 'g')
      let l:menu = substitute(l:menu, '{#[^#]*#}', '', 'g')

      let l:proto = s:DemangleProto(l:proto)

    elseif l:line[:9] == 'OVERLOAD: ' && b:should_overload == 1

      let l:value = l:line[10:]
      if match(l:value, '<#') == -1
        continue
      endif
      let l:word = substitute(l:value, '.*<#', '<#', 'g')
      let l:word = substitute(l:word, '#>.*', '#>', 'g')
      let l:wabbr = substitute(l:word, '<#\([^#]*\)#>', '\1', 'g')
      let l:menu = l:wabbr
      let l:proto = s:DemangleProto(l:value)
      let l:kind = ''
    else
      continue
    endif

    let l:args_pos = []
    if g:clang_snippets == 1
      let l:startidx = match(l:proto, '<#')
      while l:startidx != -1
        let l:proto = substitute(l:proto, '<#', '', '')
        let l:endidx = match(l:proto, '#>')
        let l:proto = substitute(l:proto, '#>', '', '')
        let l:args_pos += [[ l:startidx, l:endidx ]]
        let l:startidx = match(l:proto, '<#')
      endwhile
    endif

    let l:item = {
          \ 'word': l:word,
          \ 'abbr': l:wabbr,
          \ 'menu': l:menu,
          \ 'info': l:proto,
          \ 'dup': 0,
          \ 'kind': l:kind,
          \ 'args_pos': l:args_pos }

    call add(l:res, l:item)
  endfor
  return l:res
endfunction

function! s:escapeCommand(command)
    return s:isWindows() ? a:command : escape(a:command, '()')
endfunction

function! s:isWindows()
  " Check for win32 is enough since it's true on win64
  return has('win32')
endfunction

function! ClangComplete(findstart, base)
  if a:findstart
    let l:line = getline('.')
    let l:start = col('.') - 1
    let b:clang_complete_type = 1
    let l:wsstart = l:start
    if l:line[l:wsstart - 1] =~ '\s'
      while l:wsstart > 0 && l:line[l:wsstart - 1] =~ '\s'
        let l:wsstart -= 1
      endwhile
    endif
    if l:line[l:wsstart - 1] =~ '[(,]'
      let b:should_overload = 1
      let b:col = l:wsstart + 1
      return l:wsstart
    endif
    let b:should_overload = 0
    while l:start > 0 && l:line[l:start - 1] =~ '\i'
      let l:start -= 1
    endwhile
    if l:line[l:start - 2:] =~ '->' || l:line[l:start - 1] == '.'
      let b:clang_complete_type = 0
    endif
    let b:col = l:start + 1
    return l:start
  else
    if g:clang_debug == 1
      let l:time_start = reltime()
    endif

    if g:clang_snippets == 1
      call b:ResetSnip()
    endif

    inoremap <expr> <buffer> <C-Y> <SID>HandlePossibleSelectionCtrlY()
    augroup ClangComplete
      au CursorMovedI <buffer> call <SID>TriggerSnippet()
    augroup end
    let b:snippet_chosen = 0

    if g:clang_use_library == 1
      python startCompletion(vim.eval('a:base'))

      let l:ready = 0
      while !l:ready && !complete_check()
        python vim.command('let l:ready = ' + isCompletionReady(0.25))
      endwhile

      if l:ready
        if &pumheight
          python pumheight = int(vim.eval('&pumheight'))
        else
          python pumheight = 50
        endif

        while !complete_check()
          python vim.command('let l:handful = ' + fetchCompletions(pumheight))

          if l:handful == []
            break
          endif

          for item in l:handful
            if g:clang_snippets == 1
              let item['word'] = b:AddSnip(item['info'], item['args_pos'])
            else
              let item['word'] = item['abbr']
            endif
            call complete_add(item)
          endfor
        endwhile
      endif

      python endCompletion()

      let l:res = []
    else
      let l:res = s:ClangCompleteBinary(a:base)
      for item in l:res
        if g:clang_snippets == 1
          let item['word'] = b:AddSnip(item['info'], item['args_pos'])
        else
          let item['word'] = item['abbr']
        endif
      endfor
    endif

    if g:clang_debug == 1
      echom 'clang_complete: completion time (' . (g:clang_use_library == 1 ? 'library' : 'binary') . ') '. split(reltimestr(reltime(l:time_start)))[0]
    endif
    return l:res
  endif
endfunction

function! s:HandlePossibleSelectionEnter()
  if pumvisible()
    let b:snippet_chosen = 1
    return "\<C-Y>"
  end
  return "\<CR>"
endfunction

function! s:HandlePossibleSelectionCtrlY()
  if pumvisible()
    let b:snippet_chosen = 1
  end
  return "\<C-Y>"
endfunction

function! s:TriggerSnippet()
  " Dont bother doing anything until we're sure the user exited the menu
  if !b:snippet_chosen
    return
  endif

  if g:clang_snippets == 1
    " Stop monitoring as we'll trigger a snippet
    silent! iunmap <buffer> <C-Y>
    augroup ClangComplete
      au! CursorMovedI <buffer>
    augroup end

    " Trigger the snippet
    call b:TriggerSnip()
  endif

  if g:clang_close_preview
    pclose
  endif
endfunction

function! s:ShouldComplete()
  if (getline('.') =~ '#\s*\(include\|import\)')
    return 0
  else
    if col('.') == 1
      return 1
    endif
    for l:id in synstack(line('.'), col('.') - 1)
      if match(synIDattr(l:id, 'name'), '\CComment\|String\|Number')
            \ != -1
        return 0
      endif
    endfor
    return 1
  endif
endfunction

function! s:LaunchCompletion()
  let l:result = ""
  if s:ShouldComplete()
    let l:result = "\<C-X>\<C-U>"
    if g:clang_auto_select != 2
      let l:result .= "\<C-P>"
    endif
    if g:clang_auto_select == 1
      let l:result .= "\<C-R>=(pumvisible() ? \"\\<Down>\" : '')\<CR>"
    endif
  endif
  return l:result
endfunction

function! s:CompleteDot()
  if g:clang_complete_auto == 1
    return '.' . s:LaunchCompletion()
  endif
  return '.'
endfunction

function! s:CompleteArrow()
  if g:clang_complete_auto != 1 || getline('.')[col('.') - 2] != '-'
    return '>'
  endif
  return '>' . s:LaunchCompletion()
endfunction

function! s:CompleteColon()
  if g:clang_complete_auto != 1 || getline('.')[col('.') - 2] != ':'
    return ':'
  endif
  return ':' . s:LaunchCompletion()
endfunction

" May be used in a mapping to update the quickfix window.
function! g:ClangUpdateQuickFix()
  call s:DoPeriodicQuickFix()
  return ''
endfunction

" May be used in a mapping to update precompiled preamble.
function! g:ClangBackgroundParse()
  python backgroundParse()
  return ''
endfunction

function! g:ClangSetSnippetEngine(engine_name)
  try
    call eval('snippets#' . a:engine_name . '#init()')
    let b:AddSnip = function('snippets#' . a:engine_name . '#add_snippet')
    let b:ResetSnip = function('snippets#' . a:engine_name . '#reset')
    let b:TriggerSnip = function('snippets#' . a:engine_name . '#trigger')
  catch /^Vim\%((\a\+)\)\=:E117/
    echoe 'Snippets engine ' . a:engine_name . ' not found.'
    let g:clang_snippets = 0
  endtry
endfunction

" vim: set ts=2 sts=2 sw=2 expandtab :
plugin/libclang.py	[[[1
425
from clang.cindex import Index, TranslationUnit
import vim
import time
import threading
import psutil, os

def initClangComplete(clang_complete_flags):
  global index
  index = Index.create()
  global translationUnits
  translationUnits = []
  global complete_flags
  complete_flags = int(clang_complete_flags)
  global libclangLock
  libclangLock = threading.Lock()
  global process
  process = psutil.Process(os.getpid())
  global memory_percent
  memory_percent = vim.eval("g:clang_memory_percent")
  if memory_percent.isdigit() and 0 <= int(memory_percent) <= 100:
    memory_percent = int(memory_percent)
  else:
    memory_percent = 50

# Get a tuple (fileName, fileContent) for the file opened in the current
# vim buffer. The fileContent contains the unsafed buffer content.
def getCurrentFile():
  file = "\n".join(vim.eval("getline(1, '$')"))
  return (vim.current.buffer.name, file)

def getCurrentTranslationUnit(args, currentFile, fileName, update = False):
  fileNames = [name for name, tu in translationUnits]
  if fileName in fileNames:
    tu = translationUnits[fileNames.index(fileName)][1]
    if update:
      if debug:
        start = time.time()
      tu.reparse([currentFile])
      if debug:
        elapsed = (time.time() - start)
        print "LibClang - Reparsing: %.3f" % elapsed
    return tu

  if process.get_memory_percent() > memory_percent:
    translationUnits.pop()

  if debug:
    start = time.time()
  flags = TranslationUnit.PARSE_PRECOMPILED_PREAMBLE
  tu = index.parse(fileName, args, [currentFile], flags)
  if debug:
    elapsed = (time.time() - start)
    print "LibClang - First parse: %.3f" % elapsed

  if tu == None:
    print "Cannot parse this source file. The following arguments " \
        + "are used for clang: " + " ".join(args)
    return None

  translationUnits.append((fileName, tu))

  # Reparse to initialize the PCH cache even for auto completion
  # This should be done by index.parse(), however it is not.
  # So we need to reparse ourselves.
  if debug:
    start = time.time()
  tu.reparse([currentFile])
  if debug:
    elapsed = (time.time() - start)
    print "LibClang - First reparse (generate PCH cache): %.3f" % elapsed
  return tu

def splitOptions(options):
  optsList = []
  opt = ""
  quoted = False

  for char in options:
    if char == ' ' and not quoted:
      if opt != "":
        optsList += [opt]
        opt = ""
      continue
    elif char == '"':
      quoted = not quoted
    opt += char

  if opt != "":
    optsList += [opt]
  return optsList

def getQuickFix(diagnostic):
  # Some diagnostics have no file, e.g. "too many errors emitted, stopping now"
  if diagnostic.location.file:
    filename = diagnostic.location.file.name
  else:
    filename = ""

  if diagnostic.severity == diagnostic.Ignored:
    type = 'I'
  elif diagnostic.severity == diagnostic.Note:
    type = 'I'
  elif diagnostic.severity == diagnostic.Warning:
    if "argument unused during compilation" in diagnostic.spelling:
      return None
    type = 'W'
  elif diagnostic.severity == diagnostic.Error:
    type = 'E'
  elif diagnostic.severity == diagnostic.Fatal:
    type = 'E'
  else:
    return None

  return dict({ 'bufnr' : int(vim.eval("bufnr('" + filename + "', 1)")),
    'lnum' : diagnostic.location.line,
    'col' : diagnostic.location.column,
    'text' : diagnostic.spelling,
    'type' : type})

def getQuickFixList(tu):
  return filter (None, map (getQuickFix, tu.diagnostics))

def highlightRange(range, hlGroup):
  pattern = '/\%' + str(range.start.line) + 'l' + '\%' \
      + str(range.start.column) + 'c' + '.*' \
      + '\%' + str(range.end.column) + 'c/'
  command = "exe 'syntax match' . ' " + hlGroup + ' ' + pattern + "'"
  vim.command(command)

def highlightDiagnostic(diagnostic):
  if diagnostic.severity == diagnostic.Warning:
    hlGroup = 'SpellLocal'
  elif diagnostic.severity == diagnostic.Error:
    hlGroup = 'SpellBad'
  else:
    return

  pattern = '/\%' + str(diagnostic.location.line) + 'l\%' \
      + str(diagnostic.location.column) + 'c./'
  command = "exe 'syntax match' . ' " + hlGroup + ' ' + pattern + "'"
  vim.command(command)

  # Use this wired kind of iterator as the python clang libraries
        # have a bug in the range iterator that stops us to use:
        #
        # | for range in diagnostic.ranges
        #
  for i in range(len(diagnostic.ranges)):
    highlightRange(diagnostic.ranges[i], hlGroup)

def highlightDiagnostics(tu):
  map (highlightDiagnostic, tu.diagnostics)

def highlightCurrentDiagnostics():
  fileNames = [name for name, tu in translationUnits]
  if vim.current.buffer.name in fileNames:
    tu = translationUnits[fileNames.index(vim.current.buffer.name)][1]
    highlightDiagnostics(tu)

def getCurrentQuickFixList():
  fileNames = [name for name, tu in translationUnits]
  if vim.current.buffer.name in fileNames:
    tu = translationUnits[fileNames.index(vim.current.buffer.name)][1]
    return getQuickFixList(tu)
  return []

def evalArgs():
  global debug
  debug = int(vim.eval("g:clang_debug")) == 1
  userOptionsGlobal = splitOptions(vim.eval("g:clang_user_options"))
  userOptionsLocal = splitOptions(vim.eval("b:clang_user_options"))
  parametersLocal = splitOptions(vim.eval("b:clang_parameters"))
  return userOptionsGlobal + userOptionsLocal + parametersLocal

def updateCurrentDiagnostics():
  parse(evalArgs(), getCurrentFile(), vim.current.buffer.name)

def getCurrentCompletionResults(line, column, args, currentFile, fileName):
  tu = getCurrentTranslationUnit(args, currentFile, fileName)
  if debug:
    start = time.time()
  cr = tu.codeComplete(fileName, line, column, [currentFile],
      complete_flags)
  if debug:
    elapsed = (time.time() - start)
    print "LibClang - Code completion time (library): %.3f" % elapsed
  return cr

def formatResult(result):
  completion = dict()

  returnValue = None
  abbr = ""
  chunks = filter(lambda x: not x.isKindInformative(), result.string)

  args_pos = []
  cur_pos = 0
  word = ""

  for chunk in chunks:

    if chunk.isKindResultType():
      returnValue = chunk
      continue

    chunk_spelling = chunk.spelling

    if chunk.isKindTypedText():
      abbr = chunk_spelling

    chunk_len = len(chunk_spelling)
    if chunk.isKindPlaceHolder():
      args_pos += [[ cur_pos, cur_pos + chunk_len ]]
    cur_pos += chunk_len
    word += chunk_spelling

  menu = word

  if returnValue:
    menu = returnValue.spelling + " " + menu

  completion['word'] = word
  completion['abbr'] = abbr
  completion['menu'] = menu
  completion['info'] = word
  completion['args_pos'] = args_pos
  completion['dup'] = 0

  # Replace the number that represents a specific kind with a better
  # textual representation.
  completion['kind'] = kinds[result.cursorKind]

  return completion

class CompleteThread(threading.Thread):
  def __init__(self, line, column, currentFile, fileName):
    threading.Thread.__init__(self)
    self.line = line
    self.column = column
    self.currentFile = currentFile
    self.fileName = fileName
    self.args = evalArgs()
    self.result = None

  def run(self):
    with libclangLock:
      self.result = getCurrentCompletionResults(self.line, self.column,
                                                self.args, self.currentFile, self.fileName)

class Completion:
  def __init__(self):
    self.base    = None
    self.basket  = None
    self.thread  = None
    self.sorting = None

  def start(self, base):
    self.base = base
    self.sorting = vim.eval("g:clang_sort_algo")
    line = int(vim.eval("line('.')"))
    column = int(vim.eval("b:col"))
    self.thread = CompleteThread(line, column, getCurrentFile(), vim.current.buffer.name)
    self.thread.start()

  def isReady(self, timeout):
    self.thread.join(timeout)
    if not self.thread.isAlive():
      self.basket = self.thread.result
      self.basket = self.basket.results if self.basket else []
      if self.base:
        self.basket = filter(lambda x: getAbbr(x.string).startswith(self.base), self.basket)
      if self.sorting == 'priority':
        getPriority = lambda x: x.string.priority
        self.basket = sorted(self.basket, None, getPriority)
      if self.sorting == 'alpha':
        getAbbrevation = lambda x: getAbbr(x.string).lower()
        self.basket = sorted(self.basket, None, getAbbrevation)
      return True
    return False

  def fetch(self, amount):
    handful = self.basket[0:amount]
    del self.basket[0:amount]
    return map(formatResult, handful)

def startCompletion(base):
  global debug
  global completion

  debug = int(vim.eval("g:clang_debug")) == 1
  completion = Completion()
  completion.start(base)

def isCompletionReady(timeout):
  return '1' if completion.isReady(timeout) else '0'

def fetchCompletions(amount):
  return str(completion.fetch(amount))

def endCompletion():
  global completion
  completion = None

def getAbbr(strings):
  for s in strings:
    if s.isKindTypedText():
      return s.spelling
  return ""

def parse(args, currentFile, fileName):
  with libclangLock:
    getCurrentTranslationUnit(args, currentFile, fileName, update = True)

def backgroundParse():
  threading.Thread(target=parse, args=(evalArgs(), getCurrentFile(), vim.current.buffer.name)).start()

kinds = dict({                                                                 \
# Declarations                                                                 \
 1 : 't',  # CXCursor_UnexposedDecl (A declaration whose specific kind is not  \
           # exposed via this interface)                                       \
 2 : 't',  # CXCursor_StructDecl (A C or C++ struct)                           \
 3 : 't',  # CXCursor_UnionDecl (A C or C++ union)                             \
 4 : 't',  # CXCursor_ClassDecl (A C++ class)                                  \
 5 : 't',  # CXCursor_EnumDecl (An enumeration)                                \
 6 : 'm',  # CXCursor_FieldDecl (A field (in C) or non-static data member      \
           # (in C++) in a struct, union, or C++ class)                        \
 7 : 'e',  # CXCursor_EnumConstantDecl (An enumerator constant)                \
 8 : 'f',  # CXCursor_FunctionDecl (A function)                                \
 9 : 'v',  # CXCursor_VarDecl (A variable)                                     \
10 : 'a',  # CXCursor_ParmDecl (A function or method parameter)                \
11 : '11', # CXCursor_ObjCInterfaceDecl (An Objective-C @interface)            \
12 : '12', # CXCursor_ObjCCategoryDecl (An Objective-C @interface for a        \
           # category)                                                         \
13 : '13', # CXCursor_ObjCProtocolDecl (An Objective-C @protocol declaration)  \
14 : '14', # CXCursor_ObjCPropertyDecl (An Objective-C @property declaration)  \
15 : '15', # CXCursor_ObjCIvarDecl (An Objective-C instance variable)          \
16 : '16', # CXCursor_ObjCInstanceMethodDecl (An Objective-C instance method)  \
17 : '17', # CXCursor_ObjCClassMethodDecl (An Objective-C class method)        \
18 : '18', # CXCursor_ObjCImplementationDec (An Objective-C @implementation)   \
19 : '19', # CXCursor_ObjCCategoryImplDecll (An Objective-C @implementation    \
           # for a category)                                                   \
20 : 't',  # CXCursor_TypedefDecl (A typedef)                                  \
21 : 'f',  # CXCursor_CXXMethod (A C++ class method)                           \
22 : 'n',  # CXCursor_Namespace (A C++ namespace)                              \
23 : '23', # CXCursor_LinkageSpec (A linkage specification, e.g. 'extern "C"') \
24 : '+',  # CXCursor_Constructor (A C++ constructor)                          \
25 : '~',  # CXCursor_Destructor (A C++ destructor)                            \
26 : '26', # CXCursor_ConversionFunction (A C++ conversion function)           \
27 : 'a',  # CXCursor_TemplateTypeParameter (A C++ template type parameter)    \
28 : 'a',  # CXCursor_NonTypeTemplateParameter (A C++ non-type template        \
           # parameter)                                                        \
29 : 'a',  # CXCursor_TemplateTemplateParameter (A C++ template template       \
           # parameter)                                                        \
30 : 'f',  # CXCursor_FunctionTemplate (A C++ function template)               \
31 : 'p',  # CXCursor_ClassTemplate (A C++ class template)                     \
32 : '32', # CXCursor_ClassTemplatePartialSpecialization (A C++ class template \
           # partial specialization)                                           \
33 : 'n',  # CXCursor_NamespaceAlias (A C++ namespace alias declaration)       \
34 : '34', # CXCursor_UsingDirective (A C++ using directive)                   \
35 : '35', # CXCursor_UsingDeclaration (A using declaration)                   \
36 : '36', # CXCursor_TypeAliasDecl (A C++ alias declaration)                  \
                                                                               \
# References                                                                   \
40 : '40', # CXCursor_ObjCSuperClassRef                                        \
41 : '41', # CXCursor_ObjCProtocolRef                                          \
42 : '42', # CXCursor_ObjCClassRef                                             \
43 : '43', # CXCursor_TypeRef                                                  \
44 : '44', # CXCursor_CXXBaseSpecifier                                         \
45 : '45', # CXCursor_TemplateRef (A reference to a class template, function   \
           # template, template template parameter, or class template partial  \
           # specialization)                                                   \
46 : '46', # CXCursor_NamespaceRef (A reference to a namespace or namespace    \
           # alias)                                                            \
47 : '47', # CXCursor_MemberRef (A reference to a member of a struct, union,   \
           # or class that occurs in some non-expression context, e.g., a      \
           # designated initializer)                                           \
48 : '48', # CXCursor_LabelRef (A reference to a labeled statement)            \
49 : '49', # CXCursor_OverloadedDeclRef (A reference to a set of overloaded    \
           # functions or function templates that has not yet been resolved to \
           # a specific function or function template)                         \
                                                                               \
# Error conditions                                                             \
#70 : '70', # CXCursor_FirstInvalid                                            \
70 : '70',  # CXCursor_InvalidFile                                             \
71 : '71',  # CXCursor_NoDeclFound                                             \
72 : 'u',   # CXCursor_NotImplemented                                          \
73 : '73',  # CXCursor_InvalidCode                                             \
                                                                               \
# Expressions                                                                  \
100 : '100',  # CXCursor_UnexposedExpr (An expression whose specific kind is   \
              # not exposed via this interface)                                \
101 : '101',  # CXCursor_DeclRefExpr (An expression that refers to some value  \
              # declaration, such as a function, varible, or enumerator)       \
102 : '102',  # CXCursor_MemberRefExpr (An expression that refers to a member  \
              # of a struct, union, class, Objective-C class, etc)             \
103 : '103',  # CXCursor_CallExpr (An expression that calls a function)        \
104 : '104',  # CXCursor_ObjCMessageExpr (An expression that sends a message   \
              # to an Objective-C object or class)                             \
105 : '105',  # CXCursor_BlockExpr (An expression that represents a block      \
              # literal)                                                       \
                                                                               \
# Statements                                                                   \
200 : '200',  # CXCursor_UnexposedStmt (A statement whose specific kind is not \
              # exposed via this interface)                                    \
201 : '201',  # CXCursor_LabelStmt (A labelled statement in a function)        \
                                                                               \
# Translation unit                                                             \
300 : '300',  # CXCursor_TranslationUnit (Cursor that represents the           \
              # translation unit itself)                                       \
                                                                               \
# Attributes                                                                   \
400 : '400',  # CXCursor_UnexposedAttr (An attribute whose specific kind is    \
              # not exposed via this interface)                                \
401 : '401',  # CXCursor_IBActionAttr                                          \
402 : '402',  # CXCursor_IBOutletAttr                                          \
403 : '403',  # CXCursor_IBOutletCollectionAttr                                \
                                                                               \
# Preprocessing                                                                \
500 : '500', # CXCursor_PreprocessingDirective                                 \
501 : 'd',   # CXCursor_MacroDefinition                                        \
502 : '502', # CXCursor_MacroInstantiation                                     \
503 : '503'  # CXCursor_InclusionDirective                                     \
})

# vim: set ts=2 sts=2 sw=2 expandtab :
