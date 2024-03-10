#!/usr/bin/env bash

##################################################
# Name: aliases
# Description: Aliases loaded into the shell at startup
##################################################

# NOTE: ls -F uses these:
#   @ symbolic link
#   * executable
#   = socket
#   | named pipe
#   > door
#   / directory

# Use colours when possible
alias ls='ls --color=auto'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
#alias ls='ls -G' # macOS
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias lla='ls -la'
alias llA='ls -lA'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Docker
#alias docker="podman"

# Python
alias python="python3"

# Golang
alias gdoc='godoc -v -index -http=:8080 -goroot ${GOPATH}'

# Dates for international timezones
alias date-utc='date --utc'
alias date-aus='export TZ=Australia/Sydney && date && export TZ=${TIMEZONE}'
alias date-dub='export TZ=Europe/Dublin && date && export TZ=${TIMEZONE}'
alias date-usa='export TZ=America/Lima && date && export TZ=${TIMEZONE}'

# An "alert" alias for long running commands. Use like so:
#   sleep 10 ; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias beep='tput bel'

###################
# Git
###################

alias glog='git log --pretty="format:* %as %h %G? %aN - %s"'
alias glist='git ls-tree --full-tree -r --name-only'
alias git_tree_pull="find . -mindepth 1 -maxdepth 1 -type d -print -exec git -C {} pull \;"

# This has been moved to Nix.
#alias dotfiles='/usr/bin/git --git-dir=${HOME}/.dotfiles/ --work-tree=${HOME}'

##################
# Fonts
##################

alias fonts='fc-list --format="%{family[0]}\n" | sort | uniq'

##################
# k14s
##################

# Moved k14s aliases to Tanzu functions

##################
# Ruby
##################

# GitHub

# Adding to the path does some crazy shit on macOS, but using aliases seems to work ok
#alias bundle='/usr/local/opt/ruby/bin/bundle'
#alias bundler='/usr/local/opt/ruby/bin/bundler'
#alias erb='/usr/local/opt/ruby/bin/erb'
#alias gem='/usr/local/opt/ruby/bin/gem'
#alias irb='/usr/local/opt/ruby/bin/irb'
#alias racc='/usr/local/opt/ruby/bin/racc'
#alias racc2y='/usr/local/opt/ruby/bin/racc2y'
#alias rake='/usr/local/opt/ruby/bin/rake'
#alias rdoc='/usr/local/opt/ruby/bin/rdoc'
#alias ri='/usr/local/opt/ruby/bin/ri'
#alias ruby='/usr/local/opt/ruby/bin/ruby'
#alias r2racc='/usr/local/opt/ruby/bin/r2racc'

# Gems
#alias rubocop='/usr/local/lib/ruby/gems/2.7.0/bin/rubocop'

##################
# GPG
##################

#alias gpg='gpg-wrapper'

##################
# SSH
##################

if [[ "${OS_LAYER^^}" == "WSL" ]];
then

    # Use Windows SSH so we can use 1Password Agent.
    alias ssh='ssh.exe'
    alias ssh-add='ssh-add.exe'
    alias ssh-agent='ssh-agent.exe'
    alias ssh-keyscan='ssh-keyscan.exe'
    alias ssh-keygen='ssh-keygen.exe'

fi

##################
# macOS
##################

alias sleepIn30='caffeinate -t 1800 ; say "Sleeping now" ; pmset sleepnow'
alias sleepIn60='caffeinate -t 3600 ; say "Sleeping now" ; pmset sleepnow'
alias sleepIn90='caffeinate -t 5400 ; say "Sleeping now" ; pmset sleepnow'

##################
# Other
##################

# Logseq
#alias logseq='
#    logseq \
#        --no-sandbox \
#        --enable-features=UseOzonePlatform,WaylandWindowDecorations \
#        --ozone-platform-hint=auto \
#       --ozone-platform=wayland \
#'

# VSCode
#alias code='
#    code \
#        --no-sandbox \
#        --enable-features=UseOzonePlatform,WaylandWindowDecorations \
#        --ozone-platform-hint=auto \
#        --ozone-platform=wayland \
#        --unity-launch \
#'

# EOF
