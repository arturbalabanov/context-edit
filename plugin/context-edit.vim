function! ContextEdit() " {{{
	" Check if the context filetype is the same as the vim's `filetype` option
	" If they are, return

	let s:orig_buff = bufnr('%')
	let s:context = context_filetype#get()

	if s:context['filetype'] == &filetype
		return
	endif

	let s:orig_curpos_line = getcurpos()[1]
	let s:orig_curpos_col = getcurpos()[2]

	silent exec s:context['range'][0][0] . '+1,' . s:context['range'][1][0] . 'yank a'
	let context_lines = split(@a, "\n")

	let s:min_indentation = 0
	for line in context_lines
		if line !~# '^\s*$'
			let indentation = matchlist(line, '^\(\s*\)')[0]
			if type(s:min_indentation) == type(0) || len(indentation) < len(s:min_indentation)
				let s:min_indentation = indentation
			endif
		endif
	endfor

	let s:rel_curpos_line = s:orig_curpos_line - s:context['range'][0][0]
	let s:rel_curpos_col = s:orig_curpos_col - len(s:min_indentation)

	if type(s:min_indentation) == type(0)
		let new_lines = context_lines
	else
		let new_lines = []

		for line in context_lines
			call add(new_lines, substitute(line, '^' . s:min_indentation, '', ''))
		endfor
	endif

	let @a = join(new_lines, "\n")

	let context_win_height = max([winheight('%') / 3, s:context['range'][1][0] - s:context['range'][0][0] + 3])

	let context_filename = tempname()
	silent exec context_win_height . 'new ' . context_filename
	silent exec 'setlocal filetype=' . s:context['filetype']
	put! a

	" Remove folds
	normal! zR

	" Delete the last line
	normal! G
	normal! dd

	" Go back to the same place the cursor was in the original buffer
	call cursor(s:rel_curpos_line, s:rel_curpos_col)

	silent write

	function! ReplaceContext() " {{{
		silent 0,$yank a

		if type(s:min_indentation) != type(0)
			let context_lines = split(@a, "\n")
			let new_lines = []

			for line in context_lines
				if line !~# '^\s*$'
					call add(new_lines, s:min_indentation . line)
				else
					call add(new_lines, line)
				endif
			endfor

			let @a = join(new_lines, "\n")
		endif

		wincmd k

		silent exec s:context['range'][0][0] . '+1,' . s:context['range'][1][0] . 'delete b'
		let @b = ''

		silent exec s:context['range'][0][0] . 'put a'
		let @a = ''

		let s:context = context_filetype#get()
		write
	endfunction " }}}

	augroup contextedit
		autocmd!
		silent exec 'autocmd BufWritePost ' . context_filename . ' call ReplaceContext()'
	augroup END
endfunction " }}}
