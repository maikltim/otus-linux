#!/bin/bash

pstty(){
	ttynr=$(awk '{print $7}' /proc/$pid/stat)
        if [ $ttynr -gt 0 ];then
        	majorhex=$(printf '%x\n' $ttynr | rev | cut -b 3,4 | rev)
                minorhex=$(printf '%x\n' $ttynr | rev | cut -b 1,2 | rev)
                major=$(printf '%d\n' "0x$majorhex")
                minor=$(printf '%d\n' "0x$minorhex")
                if [ $major -eq 4 ];then
                	ttynum="tty$minor"
                elif [ $major -eq 136 ];then
                        ttynum=$(ls -l /proc/$pid/fd | grep -o "pts\/[0-9]" | head -1)
                else
                        ttynum="?"
                fi
        else
                ttynum="?"
        fi
	echo $ttynum
}

psstatus(){
	procstatus=$(grep "State:" /proc/$pid/status | awk -F:  '{print substr($2,2)}')
	echo $procstatus
}

psnice(){
	procnice=$(awk '{print $19}' /proc/$pid/stat)
	echo $procnice
}

pstime(){
	utime=$(awk '{print $14}' /proc/$pid/stat)
        stime=$(awk '{print $15}' /proc/$pid/stat)
	sumtime=$(($utime+$stime))
	cputime=$(date -u -d @$(($sumtime/$hertz)) +"%T")
	echo $cputime
}

pscmd(){
	proccmd=$(sed -e 's/\x00/ /g' -e 's!$!\n!' /proc/$pid/cmdline)
	echo $proccmd
}

hertz=$(getconf CLK_TCK)
allpids=$(ls /proc | grep -E '^[0-9]+$' | sort -n)
echo -e "PID\tTTY\tSTAT\t\tNICE\tTIME\t\tCOMMAND"
for pid in $allpids; do
        if [ -e /proc/$pid ];then
		echo -e "$pid\t$(pstty)\t$(psstatus)\t$(psnice)\t$(pstime)\t$(pscmd)"
	fi
done
