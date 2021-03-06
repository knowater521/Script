red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
blue='\033[0;34m'
purple='\033[0;35m'
cyan='\033[0;36m'
white='\033[0;37m'
end='\033[0m'

total_consumer_url='http://kafka-manager.qipeipu.net/clusters/online/consumers'

other_threshold=200
warn_threshold=10
log_threshold=1
pid=$$
userDir=(`cd && pwd`)

cache_dir="$userDir/.config/app-conf/log/ofc_kafka_topic"
log_file="$cache_dir/total.log"
consumers_page="$cache_dir/consumers-page.html"
consumers_log="$cache_dir/consumers.log"

icon_file='/home/kcp/Application/Icon/warning-circle-yellow.svg'

topics='OFC_PURCHASE_FINISH OFC_DATA_TRACK '

info_group='btr-im-admin-online btr-im-service-online btr-operation-publish-online ofc-service-online operation-service operation-web'
ignore_topic='quote_quoteResultPushErp'



log(){
    printf " $1\n"
}
log_error(){
    printf `date +%y-%m-%d_%H:%M:%S`"$red $1 $end\n" 
}
log_info(){
    printf `date +%y-%m-%d_%H:%M:%S`"$green $1 $end\n" 
}
log_warn(){
    printf `date +%y-%m-%d_%H:%M:%S`"$yellow $1 $end\n" 
}

update_cache_for_ofc(){
    topic=$1
    rm -f $cache_dir/$topic
    curl http://kafka-manager.qipeipu.net/clusters/online/consumers/ofc-service-online/topic/$topic/type/ZK -o $cache_dir/$topic > /dev/null 2>&1
    log_info "   update: "$cache_dir/$topic
}

remove_td_tag(){
    str=${1/<td>/}
    str=${str/<\/td>/}
    echo $str
}

check_topic_total_lag(){
    topic=$1
    page=$cache_dir/$topic
    result=$(cat $page | grep Total -A 1)
    count=0
    for line in $result; do
        count=$((count+1))
        if test $count = 3;then
            # echo $count"---------"$line
            num=$(remove_td_tag $line)
            # printf "%s $yellow%-40s  %3s $end\n" `date +%y-%m-%d_%H:%M:%S` "$topic" "$num"
            printf "%s %-40s  %3s \n" `date +%y-%m-%d_%H:%M:%S` "$topic" "$num"  >> $log_file
            mo_num=$(echo $num | sed 's/,//g')
            if test $mo_num -gt $warn_threshold; then
                msg="$topic : $num"
                notify-send -i $icon_file "$msg" -t 3000
            fi
        fi
    done
}

watch_total_topic(){
    curl $total_consumer_url -o $consumers_page > /dev/null 2>&1
    origins=$(cat $consumers_page | grep -v "(0% coverage" | grep -v "unavailable" | grep "lag" -B 2)
    date_str=$(date +%y-%m-%d_%H:%M:%S)

    has_lag=0
    app=''
    topic=''
    count=0

    for line in  $origins; do
        # echo "===="$line
        count=$((count+1))
        if test $count = 2; then
            temp=${line#*consumers\/}
            temp=${temp%//type*}
            app=${temp%%/topic*}
            topic=${temp#*topic/}
            topic=${topic%%/type*}
        fi

        if test $count = 5; then
            # echo $line
            if  [ ! $(echo $temp | grep -v "KF") = "" ]; then
                if test $line -gt $log_threshold; then
                    has_lag=1
                    printf "%s %-30s %-50s " $date_str $app  $topic >> $consumers_log
                    printf "$line\n"  >> $consumers_log
                fi
                if test $line -gt $warn_threshold; then
                    is_info_topic=$(echo $info_group | grep $app)
                    if [ $line -lt $other_threshold ] && [ "$is_info_topic" = "" ]; then
                        continue
                    fi
                    is_ignore=$(echo $ignore_topic | grep $topic)
                    if [ ! "$is_ignore" = "" ]; then
                        continue
                    fi
                    msg="$topic : $line"
                    notify-send -i $icon_file "$app" "$msg" -t 3000
                fi
            fi
        fi

        if test $count = 7; then
            count=0
        fi
    done

    if test $has_lag = 1; then
        printf "\n"  >> $consumers_log
    else
        printf "%s \n" $date_str >> $consumers_log
    fi
}

watch_ofc_topic(){
    for topic in $topics; do
        update_cache_for_ofc $topic
        check_topic_total_lag  $topic 
    done
    printf "\n"  >> $log_file
}

help(){
    printf "Run：$red sh watch-kafka-topic.sh $green<verb> $yellow<args>$end\n"
    format="  $green%-6s $yellow%-8s$end%-20s\n"
    printf "$format" "h" "" "help"
    printf "$format" "l" "" "show log"
    printf "$format" "ln" "" "show log with line num"
    printf "$format" "a" "" "watch all topic exlude KF "
    printf "$format" "d" "" "kill current script"
}

case $1 in 
    -h|h)
        help 
    ;;
    # deprecated
    log)
        less $log_file
    ;;
    l)
        less $consumers_log
    ;;
    ln)
        less -N $consumers_log
    ;;
    a)
        while true; do
            watch_total_topic
            sleep 5;
        done
    ;;
    d)
        last_pid=$(ps aux | grep  "watch-kafka-topic.sh a" | grep -v grep | awk '{print $2}')
        log_error "killed $last_pid"
        kill $last_pid
    ;;
    # deprecated
    w)
        while true; do
            watch_ofc_topic
            sleep 5;
        done
    ;;
    *)
        help
        
    ;;
esac
