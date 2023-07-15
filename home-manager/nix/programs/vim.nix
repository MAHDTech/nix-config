{
  inputs,
  config,
  pkgs,
  ...
}: let
  pkgsUnstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system};

  unstablePlugins = with pkgsUnstable.vimPlugins; [vim-wakatime];
in {
  programs.vim = {
    enable = true;

    packageConfigurable = pkgs.vim-full;

    defaultEditor = true;

    plugins = with pkgs.vimPlugins;
      [
        rust-vim
        statix
        vader-vim
        vim-nix
        vim-one
      ]
      ++ unstablePlugins;

    settings = {
      background = "dark";
      copyindent = false;
      expandtab = true;
      hidden = false;
      history = 100;
      ignorecase = true;
      modeline = false;
      mouse = "a";
      mousefocus = true;
      mousehide = false;
      mousemodel = "extend";
      number = true;
      relativenumber = false;
      shiftwidth = 4;
      smartcase = true;
      tabstop = 4;
    };

    # Custom vimrc goes here.
    extraConfig = ''
      "######################################################
      " Name: .vimrc
      " Description: Custom vim configuration settings
      " NOTES:
      "       :scriptnames is useful for debugging :)
      "######################################################

      "######################################################

      " 1. Load Plugins
      source ~/.vim/rc/plugins.vim

      " 2. Load Functions
      source ~/.vim/rc/functions.vim

      " 3. Load Auto commands
      source ~/.vim/rc/autocmds.vim

      " 4. Load remap
      source ~/.vim/rc/remap.vim

      " 5. Load Color Schemes
      source ~/.vim/rc/colors.vim

      " 6. Load Rust tweaks
      source ~/.vim/rc/rust.vim

      "######################################################

      set encoding=utf-8                              " Encoding
      let mapleader = " "                             " Leader
      set backspace=2                                 " Backspace deletes like most programs in insert mode
      "set history=100                                 " Set the number of commands to store in the history
      set ruler                                       " show the cursor position all the time
      set showcmd                                     " display incomplete commands
      set incsearch                                   " do incremental searching
      set laststatus=2                                " Always display the status line
      set autowrite                                   " Automatically :write before running commands
      "set modelines=0                                 " Disable modelines as a security precaution
      "set nomodeline                                  " Disable reading and processing modelines

      " Secure defaults
      set noswapfile                                  " Disable the swapfile
      set nobackup                                    " Disable creation of vim backup files
      set nowritebackup                               " Don't write to existing backup files
      set viminfo=                                    " Disable vimingo file from copying from current session
      set clipboard=                                  " Disable copying to system clipboard

      if !exists("g:syntax_on")
        syntax enable
        filetype on
      endif

      filetype plugin on
      filetype indent on

      set guifont=Monospace\ 12                       " set the font family and size
      "set number                                      " show line numbers
      "set mouse=a                                     " enable mouse usage
      "set mousehide                                   " hide the mouse cursor when typing
      set spell                                       " Enable spell check
      "set nospell                                     " Disable spell check
      set backspace=indent,eol,start                  " Backspace for dummies
      set linespace=0                                 " No extra spaces between rows
      set showmatch                                   " Show matching brackets/parenthesis
      set incsearch                                   " Find as you type search
      set hlsearch                                    " Highlight search terms
      set winminheight=0                              " Windows can be 0 line high
      "set ignorecase                                  " Case insensitive search
      "set smartcase                                   " Case sensitive when uc present
      set wildmenu                                    " Show list instead of just completing
      set wildmode=list:longest,full                  " Command <Tab> completion, list matches, then longest common part, then all.
      set whichwrap=b,s,h,l,<,>,[,]                   " Backspace and cursor keys wrap too
      set scrolljump=5                                " Lines to scroll when cursor leaves screen
      set scrolloff=3                                 " Minimum lines to keep above and below cursor
      set foldenable                                  " Auto fold code
      set list                                        " Enable list
      "set listchars=eol:$,tab:>>,trail:-,extends:>,precedes:<,nbsp:+ " Show problematic whitespace
      set listchars=tab:>>,trail:-,extends:>,precedes:<,nbsp:+ " Show problematic whitespace
      set nowrap                                      " Don't automatically wrap long lines
      set wrap!                                       " Really, don't automatically wrap long lines
      set autoindent                                  " Indent at the same level of the previous line
      "set shiftwidth=4                                " Use indents of 4 spaces
      "set expandtab                                   " Tabs are spaces, not tabs
      "set tabstop=4                                   " An indentation every four columns
      set softtabstop=4                               " Let backspace delete entire indent
      set nojoinspaces                                " Prevents inserting two spaces after punctuation on a join (J)
      set splitright                                  " Puts new vertical split windows to the right of the current
      set splitbelow                                  " Puts new horizontal split windows below the current
      set pastetoggle=<F12>                           " paste toggle sets sane indentation on paste when using the shortcut
      set timeoutlen=1000                             " Sets the timeout for mapping delays
      set ttimeoutlen=0                               " Set the timeout for key code delays
    '';
  };

  home.file = {
    # File Types

    "conf.vim" = {
      target = "${config.home.homeDirectory}/.vim/ftplugin/conf.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: conf.vim
        " Description: Vim filetype plugin for conf
        "######################################################

        setlocal shiftwidth=2
        setlocal tabstop=2
      '';
    };
    "sls.vim" = {
      target = "${config.home.homeDirectory}/.vim/ftplugin/sls.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: sls.vim
        " Description: Vim filetype plugin for SLS
        "######################################################

        setlocal shiftwidth=2
        setlocal tabstop=2
        setlocal softtabstop=4
      '';
    };
    "yaml.vim" = {
      target = "${config.home.homeDirectory}/.vim/ftplugin/yaml.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: yaml.vim
        " Description: Vim filetype plugin for YAML
        "######################################################

        setlocal shiftwidth=2
        setlocal tabstop=2
      '';
    };
    "yml.vim" = {
      target = "${config.home.homeDirectory}/.vim/ftplugin/yml.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: yml.vim
        " Description: Vim filetype plugin for YAML
        "######################################################

        setlocal shiftwidth=2
        setlocal tabstop=2
      '';
    };

    # RC

    "plugins.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/plugins.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: plugins.vim
        " Description: Loads vim plugins
        "######################################################

        " NOTE: Vim 8 added native plugin support
        "
        " ~/.vim/pack/
        " ~/.vim/pack/plugins/
        " ~/.vim/pack/plugins/start/foo     " Auto load plugins on start
        " ~/.vim/pack/plugins/opt/foo       " Optional load plugins with :packadd foo
        "
        " To install, git submodule add $PLUGIN_REPO ~/.vim/pack/plugins/opt/$PLUGIN_NAME
        " Add :packadd $PLUGIN_NAME below

        " dotfiles submodule add git@github.com:rakr/vim-one.git .vim/pack/colors/opt/vim-one.vim
        ":packadd vim-one.vim

        " dotfiles submodule add git@github.com:junegunn/vader.vim.git .vim/pack/plugins/opt/vader.vim
        ":packadd vader.vim

        " dotfiles submodule add git@github.com:rust-lang/rust.vim.git .vim/pack/plugins/opt/rust.vim
        ":packadd rust.vim

        " dotfiles submodule add git@github.com:racer-rust/vim-racer.git .vim/pack/plugins/opt/vim-racer.vim
        ":packadd vim-racer.vim

        " dotfiles submodule add git@github.com:wakatime/vim-wakatime.git .vim/pack/plugins/opt/vim-wakatime.vim
        ":packadd vim-wakatime.vim
      '';
    };
    "functions.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/functions.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: functions.vim
        " Description: vim functions
        "######################################################

        " Clipboard magic - requires vim with +clipboard feature
        if has('clipboard')
          if has('unnamedplus')                       " when possible, use + register for copy paste
            set clipboard=unnamed,unnamedplus
          else                                        " On MAC and Windows use * register for copy paste
            set clipboard=unnamed
          endif
        endif

        " Tab magic
        " Return indent (all whitespace at start of a line), converted from
        " tabs to spaces if what = 1, or from spaces to tabs otherwise.
        " When converting to tabs, result has no redundant spaces.
        function! Indenting(indent, what, cols)

          let spccol = repeat(' ', a:cols)
          let result = substitute(a:indent, spccol, '\t', 'g')
          let result = substitute(result, ' \+\ze\t', ' ', 'g')

          if a:what == 1
            let result = substitute(result, '\t', spccol, 'g')
          endif

          return result

        endfunction

        " Runs Vader tests
        " Called using :Test from autocmds.vim
        function! VaderTests()

          if expand('%:e') == 'vim'

            let testfile = printf('%s/%s.vader', expand('%:p:h'),
            \ tr(expand('%:p:h:t'), '-', '_'))

            if !filereadable(testfile)
              echoerr 'File does not exist: '. testfile
              return
            endif

            " Source the current file and execute the tests
            source %
            execute 'Vader' testfile

        else

          let sourcefile = printf('%s/%s.vim', expand('%:p:h'),
          \ tr(expand('%:p:h:t'), '-', '_'))

          if !filereadable(sourcefile)
            echoerr 'File does not exist: '. sourcefile
            return
          endif

            " Source the current file and execute the tests
            execute 'source' sourcefile
            Vader

          endif

        endfunction

        " Convert whitespace used for indenting (before first non-whitespace).
        " what = 0 (convert spaces to tabs), or 1 (convert tabs to spaces).
        " cols = string with number of columns per tab, or empty to use 'tabstop'.
        " The cursor position is restored, but the cursor will be in a different
        " column when the number of characters in the indent of the line is changed.
        function! IndentConvert(line1, line2, what, cols)

          let savepos = getpos('.')
          let cols = empty(a:cols) ? &tabstop : a:cols

          execute a:line1 . ',' . a:line2 . 's/^\s\+/\=Indenting(submatch(0), a:what, cols)/e'

          call histdel('search', -1)
          call setpos('.', savepos)

        endfunction
      '';
    };
    "autocmds.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/autocmds.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: autocmds.vim
        " Description: Store autocmds here to keep .vimrc clean
        "######################################################

        " Run Vader on :Test command
        autocmd BufRead *.{vader,vim} command! -buffer Test call VaderTests()

        " Convert spaces to tabs
        command! -nargs=? -range=% Space2Tab call IndentConvert(<line1>,<line2>,0,<q-args>)

        " Convert tabs to spaces
        command! -nargs=? -range=% Tab2Space call IndentConvert(<line1>,<line2>,1,<q-args>)

        " Auto indentation
        command! -nargs=? -range=% RetabIndent call IndentConvert(<line1>,<line2>,&et,<q-args>)

        " Open new split panes to right and bottom
        set splitbelow
        set splitright
      '';
    };
    "remap.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/remap.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: remap.vim
        " Description: remap config
        "######################################################

        " To toggle syntax
        " nnoremap <Leader>s Toggle Syntax
        " Reference: https://vi.stackexchange.com/a/24418/7339
        nnoremap <silent> <expr> <Leader>s exists('g:syntax_on') ? ':syntax off<cr>' : ':syntax enable<cr>'

        " Keyboard Mappings
        vnoremap <C-c> "*y                              " Ctrl+C for Copy
        vnoremap <C-Insert> "+y                         " Ctrl+Insert for Copy
        vnoremap <C-V> "+gP                             " Ctrl+V for Paste
        vnoremap <S-Insert> "+gP                        " Shift+Insert for Paste
        vnoremap Y y$                                   " Y yank to end of line

        " Tab Navigation
        map <C-up> :tabr<cr>                            " Ctrl + Up for Tab Up
        map <C-down> :tabl<cr>                          " Ctrl + Down for Tab Down
        map <C-left> :tabp<cr>                          " Ctrl + Left for Tab left
        map <C-right> :tabn<cr>                         " Ctrl + Right for Tab Right
      '';
    };
    "colors.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/colors.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: colors.vim
        " Description: Color Schemes
        "######################################################

        " Some nice built-in schemes
        "colorscheme default
        "colorscheme elflord
        "colorscheme peachpuff
        "colorscheme koehler

        " Enable True Color support for Vim One scheme
        if (empty($TMUX))

          if (has("nvim"))
            let $NVIM_TUI_ENABLE_TRUE_COLOR=1
          endif

          if (has("termguicolors"))
            set termguicolors
          endif

        endif

        let g:airline_theme='one'
        set background=dark

        colorscheme one

        " Workaround to enable color in Alacritty
        if &term == "alacritty"
          "let &t_8f = "\<Esc>[38;2;%lu;%lu;%lum"
          "let &t_8b = "\<Esc>[48:2;%lu;%lu;%lum"
          let &term = "xterm-256color"
        endif
      '';
    };
    "rust.vim" = {
      target = "${config.home.homeDirectory}/.vim/rc/rust.vim";
      executable = false;
      text = ''
        "######################################################
        " Name: rust.vim
        " Description: Vim tweaks for Rust
        "######################################################

        " Racer
        set hidden
        let g:racer_cmd = "~/.cargo/bin/racer"
        let g:racer_experimental_completer = 1
        let g:racer_insert_paren = 1
      '';
    };
  };
}
