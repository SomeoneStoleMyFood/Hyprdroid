function fish_greeting
    set_color -o cba6f7
    echo -n "  welcome to kitty, "
    set_color -o f5c2e7
    echo -n $USER
    set_color -o cba6f7
    echo "! "
    set_color normal

    set_color 6c7086
    echo "  "(date "+%A, %d %B  %H:%M")"  ·  up "(uptime -p | string replace "up " "")
    set_color normal
    echo
end
