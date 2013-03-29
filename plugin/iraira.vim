" vim:foldmethod=marker:fen:
scriptencoding utf-8

" Saving 'cpoptions' {{{
let s:save_cpo = &cpo
set cpo&vim
" }}}


" TODO:
" * Use <LeftDrag> instead of mouse hovering?
" * Conceal s:CURSOR_NORMAL, s:CURSOR_RED characters.
" * Do not enter Visual-mode. (:behave can prohibit this?)


command! IrairaStart
\   call s:start()

command! IrairaStop
\   call s:stop()


let s:BALLOON_DELAY = 1
let s:UPDATETIME = 50
let s:MAX_SHOOTING_ANIMATE_COUNT = 5
let s:CURSOR_NORMAL = '.'
let s:CURSOR_RED = '_'

function! s:initialize_variables()
    let s:buffer = s:BufferClickToPlay
    let s:mouse_pos = {'col': -1, 'lnum': -1}
    let s:shooting = 0
    let s:shooting_animate_count = 0
    let s:setchar_changed_list = []
endfunction



function! s:start()
    if !has('balloon_eval')
        call s:error('Your Vim must support +balloon_eval feature!')
        return
    endif

    " Initialize scope-local variables.
    call s:initialize_variables()

    " Open a buffer.
    tabedit

    " Set up "Click To Play" buffer.
    call s:buffer.setup()
endfunction

function! s:stop()
    call s:buffer.finalize()
    close!
endfunction

function! s:switch_buffer(buffer_obj_name)
    call s:buffer.finalize()
    let s:buffer = deepcopy(s:[a:buffer_obj_name])
    call s:buffer.setup()
endfunction

function! s:call_buffer_method(name, args)
    return call(s:buffer[a:name], a:args, s:buffer)
endfunction

function! s:call_common_buffer_method(name, args)
    return call(s:BufferCommon[a:name], a:args, s:BufferCommon)
endfunction

function! s:error(msg)
    echohl ErrorMsg
    try
        echomsg a:msg
    finally
        echohl None
    endtry
endfunction

" :sleep without being bothered by 'updatetime'.
function! s:deep_sleep_msec(msec)
    let save_updatetime = &updatetime
    let &updatetime = a:msec + 1000
    try
        execute 'sleep '.a:msec.'m'
    finally
        let &updatetime = save_updatetime
    endtry
endfunction



" s:BufferCommon {{{

let s:BufferCommon = {}

function! s:BufferCommon.setup_common()
    nnoremap <silent><buffer> <C-c> :<C-u>call <SID>call_common_buffer_method('finalize', [])<CR>

    setlocal nobuflisted
    setlocal noswapfile
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal noreadonly
    setlocal nomodeline
    setlocal nonumber
    setlocal nofoldenable
    setlocal foldcolumn=0

    silent file ___IRAIRA___
endfunction

function! s:BufferCommon.finalize()
    if input('Do you sure want to force-stop? (use '':IrairaStop'' for normal stop) [y/n]: ') !~? 'y\%[es]'
        echo "\nCanceled."
        call s:deep_sleep_msec(2)
        return
    endif
    echon "\n"

    try
        call s:buffer.finalize()
    catch
        call s:error('error: ['.v:exception.'] @ ['.v:throwpoint.']')
    endtry

    call s:error('Force-stopped! Please use :IrairaStop for normal stop.')
endfunction

" NOTE: Doesn't care with multi-byte
function! s:BufferCommon.setchar(lnum, col, char)
    let line = getline(a:lnum)
    if a:char !=# ''
    \   && 0 <# a:lnum && a:lnum <# line('$')
    \   && 0 <# a:col  && a:col  <# col('$')
    \   && line[a:col-1] !=# a:char
        let left = a:col-2 <# 0 ? '' : line[: a:col-2]
        let right = line[a:col :]
        call setline(a:lnum, left.a:char.right)
        call add(s:setchar_changed_list, [a:lnum, a:col])
    endif
endfunction

function! s:BufferCommon.restore_chars()
    for pos in s:setchar_changed_list
        call s:BufferCommon.setchar(pos[0], pos[1], s:CURSOR_NORMAL)
    endfor
    let s:setchar_changed_list = []
endfunction

" }}}

" s:BufferClickToPlay {{{

let s:BufferClickToPlay = {}

function! s:BufferClickToPlay.setup()
    call s:BufferCommon.setup_common()

    nnoremap <silent><buffer> <LeftMouse> :<C-u>call <SID>switch_buffer('BufferPlaying')<CR>

    call setline(1, [
    \   '--- Click To Play ---'
    \])
endfunction

function! s:BufferClickToPlay.finalize()
endfunction

" }}}

" s:BufferPlaying {{{

let s:BufferPlaying = {
\   '_registered_cursorhold': 0,
\   '_updatetime': -1,
\   '_registered_ballooneval': 0,
\}

function! s:BufferPlaying.setup()
    call s:BufferCommon.setup_common()

    " Add highlight.
    syn match IrairaRed /x/
    highlight IrairaRed term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red
    " FIXME: Do not change default highlight!
    " highlight def link IrairaCursor Cursor
    " highlight IrairaCursor term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red
    highlight Cursor term=reverse cterm=bold ctermfg=1 ctermbg=1 guifg=Red guibg=Red
    " highlight Normal guifg=White guibg=White

    nnoremap <silent><buffer> <LeftMouse> :<C-u>call <SID>call_buffer_method('__map_shot', [])<CR>
    nmap <silent><buffer> <LeftDrag> <LeftMouse>
    nmap <silent><buffer> <2-LeftMouse> <LeftMouse><LeftMouse>
    nmap <silent><buffer> <3-LeftMouse> <LeftMouse><LeftMouse><LeftMouse>
    nmap <silent><buffer> <4-LeftMouse> <LeftMouse><LeftMouse><LeftMouse><LeftMouse>
    " nnoremap <silent><buffer> <LeftRelease> :<C-u>call <SID>BufferPlaying.__map_shot_release()<CR><LeftRelease>

    " Fill characters in the buffer.
    " :help 'balloonexpr' says:
    "     NOTE: The balloon is displayed only if the cursor is on a text
    "     character.
    setlocal nowrap
    setlocal lazyredraw    " for redrawing buffer
    setlocal cursorcolumn
    setlocal cursorline
    setlocal nohlsearch
    if exists('+colorcolumn')
        setlocal colorcolumn=
    endif
    let MAX_COLUMNS = 480    " TODO
    let MAX_LINES = 640      " TODO
    call setline(1, repeat([repeat(s:CURSOR_NORMAL, MAX_COLUMNS)], MAX_LINES))

    call s:BufferPlaying.__register_cursorhold(s:UPDATETIME)
    call s:BufferPlaying.__register_ballooneval(s:BALLOON_DELAY)
endfunction

function! s:BufferPlaying.__register_cursorhold(local_updatetime)
    " Localize updatetime.
    let self._updatetime = &updatetime
    augroup iraira
        autocmd BufLeave <buffer> call s:BufferPlaying.__unregister_cursorhold()
    augroup END
    let &updatetime = a:local_updatetime

    " Register CursorHold event.
    augroup iraira
        autocmd CursorHold <buffer> call s:BufferPlaying.__polling()
    augroup END

    let self._registered_cursorhold = 1
endfunction

function! s:BufferPlaying.__register_ballooneval(balloondelay)
    augroup iraira
        autocmd BufLeave <buffer> call s:BufferPlaying.__unregister_ballooneval()
    augroup END
    let &l:balloondelay = a:balloondelay
    setlocal balloonexpr=IrairaBalloonExpr()
    setlocal ballooneval

    let self._registered_ballooneval = 1
endfunction

function! IrairaBalloonExpr()
    " 'balloonexpr' must not have side-effect.
    " Just get current mouse cursor position.
    let s:mouse_pos = {'col': v:beval_col, 'lnum': v:beval_lnum}
    " No popup.
    " return ''
    return printf('(%s, %s)', s:mouse_pos.col, s:mouse_pos.lnum)
endfunction

function! s:BufferPlaying.__polling()
    call s:BufferCommon.restore_chars()
    if s:mouse_pos.lnum ># 0 && s:mouse_pos.col ># 0
    \   && s:mouse_pos.lnum isnot line('.')
    \   || s:mouse_pos.col isnot col('.')
        call cursor(s:mouse_pos.lnum, s:mouse_pos.col)
    endif
    try
        call s:BufferPlaying.__main_loop()
    finally
        call feedkeys("g\<Esc>", "n")
        redraw
    endtry
endfunction

function! s:BufferPlaying.__main_loop()
    redraw
    echo printf('(%s, %s) at %s', s:mouse_pos.col, s:mouse_pos.lnum, reltimestr(reltime()))

    if s:mouse_pos.lnum <=# 0 || s:mouse_pos.col <=# 0
        return
    endif

    " Change mouse position character.
    call s:BufferCommon.setchar(s:mouse_pos.lnum, s:mouse_pos.col, s:CURSOR_RED)

    " Shot enemy.
    if s:shooting
        if s:shooting_animate_count <=# s:MAX_SHOOTING_ANIMATE_COUNT
            " left, above
            call s:BufferCommon.setchar(
            \   s:mouse_pos.lnum - s:shooting_animate_count,
            \   s:mouse_pos.col  - s:shooting_animate_count,
            \   s:CURSOR_RED)
            " left, below
            call s:BufferCommon.setchar(
            \   s:mouse_pos.lnum - s:shooting_animate_count,
            \   s:mouse_pos.col  + s:shooting_animate_count,
            \   s:CURSOR_RED)
            " right, above
            call s:BufferCommon.setchar(
            \   s:mouse_pos.lnum + s:shooting_animate_count,
            \   s:mouse_pos.col  - s:shooting_animate_count,
            \   s:CURSOR_RED)
            " right, below
            call s:BufferCommon.setchar(
            \   s:mouse_pos.lnum + s:shooting_animate_count,
            \   s:mouse_pos.col  + s:shooting_animate_count,
            \   s:CURSOR_RED)
            let s:shooting_animate_count += 1
        else
            let s:shooting = 0
            let s:shooting_animate_count = 0
        endif
    endif
endfunction

function! s:BufferPlaying.__map_shot()
    echom 'shot!'
    let s:shooting = 1
    let s:shooting_animate_count = 1
endfunction

function! s:BufferPlaying.__map_shot_release()
    let s:shooting = 0
    let s:shooting_animate_count = 0
endfunction

function! s:BufferPlaying.finalize()
    call s:BufferPlaying.__unregister_cursorhold()
    call s:BufferPlaying.__unregister_ballooneval()
endfunction

function! s:BufferPlaying.__unregister_cursorhold()
    if !self._registered_cursorhold
        return
    endif
    if self._updatetime >=# 0
        let &updatetime = self._updatetime
        let self._updatetime = -1
    endif
    let self._registered_cursorhold = 1
endfunction

function! s:BufferPlaying.__unregister_ballooneval()
    if !self._registered_ballooneval
        return
    endif
    setlocal balloondelay<
    setlocal balloonexpr=
    setlocal noballooneval
endfunction

" }}}




" Restore 'cpoptions' {{{
let &cpo = s:save_cpo
" }}}
