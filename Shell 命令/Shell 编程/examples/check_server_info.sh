#!/bin/bash

# As an example, we will write a script that would gather some useful
# information about our server like:
# - Current Disk usage
# - Current CPU usage
# - Current RAM usage
# - Check the exact Kernel version

server_name=$(hostname)

echo $server_name

function check_memory()
{
    echo ""
    echo "Memory usage on ${server_name} is:"
    free -h
    echo ""
}

function cpu_check() {
    echo ""
    echo "CPU load on ${server_name} is: "
    echo ""
    uptime
    echo ""
}

function tcp_check() {
    echo ""
    echo "TCP connections on ${server_name}: "
    echo ""
    cat /proc/net/tcp | wc -l
    echo ""
}

function kernel_check() {
    echo ""
    echo "Kernel version on ${server_name} is: "
    echo ""
    uname -r
    echo ""
}


function check_all() {
    # check_memory
    cpu_check
    tcp_check
    kernel_check
}

##
# Color Variables
##
green='\e[32m'
blue='\e[34m'
clear='\e[0m'

##
# Color Functions
##
ColorGreen(){
    echo -ne $green$1$clear
}
ColorBlue(){
    echo -ne $blue$1$clear
}

menu(){
echo -ne "
My First Menu
$(ColorGreen '1)') Memory usage
$(ColorGreen '2)') CPU load
$(ColorGreen '3)') Number of TCP connections
$(ColorGreen '4)') Kernel version
$(ColorGreen '5)') Check All
$(ColorGreen '0)') Exit
$(ColorBlue 'Choose an option:') "

    read a

    case $a in
        1) memory_check ; menu ;;
        2) cpu_check ; menu ;;
        3) tcp_check ; menu ;;
        4) kernel_check ; menu ;;
        5) all_checks ; menu ;;
        0) exit 0 ;;
        *) echo -e $red"Wrong option."$clear;
        WrongCommand;;
    esac
}

# Call the menu function
menu