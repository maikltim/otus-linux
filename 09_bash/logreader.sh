#!/bin/bash

logfile=/vagrant/access.log
result=/var/log/parser/parser.log
runtimelog=/var/log/parser/runtime.log
templogfile=/var/log/parser/tempaccess.log
lockfile=/tmp/parserlockfile
emailaddress="root@localhost"
ipcount=10
urlcount=10

prepare(){
    if ! [[  -f $runtimelog ]];then
        head -1 $logfile | awk '{print $4}' | sed 's/\[//' > $runtimelog;
    fi
    processingtime=$(cat $runtimelog | sed 's!/!\\/!g')
    starttime=$(cat $runtimelog)
    sed -n "/${processingtime}/,$ p" $logfile > $templogfile
    tail -1 $templogfile | awk '{print $4}' | sed 's/\[//' > $runtimelog
    endtime=$(cat $runtimelog)
}

parser() {
    echo "================================================" > $result
    echo "Data provided from $starttime to $endtime" >> $result
    echo "================================================" >> $result
    #IP adrddesses with the most requests
    echo "------------------------------------------------" >> $result
    echo "$ipcount IP adresses with the most requests:" >> $result
    echo "------------------------------------------------" >> $result
    awk '{print $1}' $templogfile | sort | uniq -cd | sort -nr | head -$ipcount | awk '{print $1 " requests from IP: " $2}' >> $result

    #URL's with the most requests
    echo "------------------------------------------------" >> $result
    echo "$urlcount URL's with the most requests:" >> $result
    echo "------------------------------------------------" >> $result
    awk '{print $7}' $templogfile | sort | uniq -cd | sort -nr | head -$urlcount | awk '{print $1 " requests for: " $2}' >> $result

    #Client side error list
    echo "------------------------------------------------" >> $result
    echo "Client side error list:" >> $result
    echo "------------------------------------------------" >> $result
    awk '($9 ~ /4../){print $9}' $templogfile | sort | uniq -cd | sort -nr |  awk '{print $1 " errors with code: " $2}' >> $result 

    #Server side error list
    echo "------------------------------------------------" >> $result
    echo "Server side error list:" >> $result
    echo "------------------------------------------------" >> $result
    awk '($9 ~ /5../){print $9}' $templogfile | sort | uniq -cd | sort -nr |  awk '{print $1 " errors with code: " $2}' >> $result 

    #List of all return codes
    echo "------------------------------------------------" >> $result
    echo "List of all return codes:" >> $result
    echo "------------------------------------------------" >> $result
    awk '{print $9}' $templogfile | sort | uniq -cd | sort -nr |  awk '{print $1 " responses with HTTP status code: " $2}' >> $result
}
if ( set -o noclobber; echo "$$">"$lockfile" ) 2>/dev/null; then
    trap "rm -f "$lockfile";exit $?" INT TERM EXIT
    while true
        do
            prepare
            parser
            #sleep 10
            mail -s "AccessLog analysis" "$emailaddress" < $result
            rm -f $templogfile
            exit
        done
    rm -f $lockfile
    trap - INT TERM EXIT
else
    echo "Failed to acquire lockfile: $lockfile."
    echo "Held by $(cat $lockfile)"
fi
