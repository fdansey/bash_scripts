#!/bin/bash

trap "echo CAUGHT TRP; exit 3" SIGINT

if [ ! -e $(dirname $0)/machines.txt ]; then
    echo "Could not find 'machines.txt' in script dir"
    exit 1
elif [ -e $(dirname $0)/con_ssh.arf ]; then
    echo "Could not find 'con_ssh.exp' in script dir"
    exit 1
fi

echo -n "Checking machines "

arr=($(cat $(dirname $0)/machines.txt))
#arr=($(seq 2 2))
echo "${arr[*]} TOTAL:${#arr[@]}"
echo -e "\033[2;4;30mIP Address\033[40GPing\033[60GPassword\033[0m"
#echo "arr[1]=${arr[1]}"
prefix=10.44.86
#exit 0
count=0

declare -A pids
declare -A pingresult

do_ping() {
    ping -c2 -w3 $prefix.$1 >/dev/null
}

wait_pings() {
    for pid in "$@"; do
        shift
        wait $pid
        if [ $? -eq 0 ]; then
            pingresult[$pid]=" UP "
        else
            pingresult[$pid]="DOWN"
        fi
    done
#    echo "Results ${pingresult[@]}"
}
for i in ${arr[@]}; do
    do_ping $i &
    pids[$i]=$!
done

for i in ${arr[@]}; do
    echo -e "$prefix.$i"
done

sleep 2.2

wait_pings ${pids[@]}

echo -e "\033[A\033[${#arr[@]}A"

for i in ${arr[@]}; do
    q=${pids[$i]}
    echo -e "\033[40G${pingresult[$q]}"

    let count=count+1

    ssh-keygen -f "$HOME/.ssh/known_hosts" -R $prefix.$i 2>/dev/null
    [ $? -ne 0 ] && echo "error removing SSH key $prefix.$i"
done

count=0
declare -A dot_result
declare -A dot_pids

do_dot() {
    output=$(expect $(dirname $0)/con_ssh.exp "$prefix.$1" nointeract)>/dev/null
}

wait_dots() {
    for pid in "$@"; do
        shift
        wait $pid
        case $? in
        1)
            dot_result[$pid]="\033[31mPROBLEM";;
        2)
            dot_result[$pid]="\033[31mConnection refused";;
        4)
            dot_result[$pid]="\033[2;33mUnknown password";;
        6)
            dot_result[$pid]="\033[2;32m@dm1nS3rv3r";;
        7)
            dot_result[$pid]="\033[2;32mAut01nstall";;
        8)
            dot_result[$pid]="\033[2;36mNewly installed";;
        else)
            dot_result[$pid]="\033[35mOther";;
        esac

    done
}

# pids[1 2..50] = [14529 14530..14578]
# pingresult[14529..14578] = [UP DOWN..DOWN]

for i in ${arr[@]}; do

    q=${pids[$i]}
    [ "${pingresult[$q]}" = " UP " ] && {  # if machine is up
#        output=$(expect $(dirname $0)/con_ssh.exp "$prefix.$i" nointeract)>/dev/null
        do_dot $i &
        dot_pids[$i]=$!
    }
done

sleep 9

wait_dots ${dot_pids[@]}

uplines=0

for i in ${arr[@]}; do
    let count=count+1
    let uplines=${#arr[@]}-$count+1

    status=""
    output=""
    q=${pids[$i]}
    r=${dot_pids[$i]}
    [ "${pingresult[$q]}" = " UP " ] && {  # if machine is up
        status="${dot_result[$r]}"
    }
#    users=$(echo "$output"|grep "^[[:digit:]]"|sed 's/\r//')
#    [ -n "$users" ] && {
        #echo "\$users: \"$users\""
#        let users=users-1
#    }

    echo -en "\033[${uplines}A\033[55G$users\033[60G$status\033[0m\033[${uplines}B\033[0G"
done
#echo ${dot_pids[@]}
#echo ${dot_result[@]}

echo -e "\033[0G"
