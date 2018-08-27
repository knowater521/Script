#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;34m'
pulper='\033[0;35m'
blue='\033[0;36m'
white='\033[0;37m'
end='\033[0m'

userDir=(`cd && pwd`)
realPath=$(cd `dirname $0`; pwd)
currentPath=`pwd`

mainDir=$userDir'/.config/kuangcp/RecycleBin'
trashDir=$mainDir'/trash'
logDir=$mainDir'/log'
cnfDir=$mainDir'/conf'

logFile=$logDir'/RecycleBin.log'
configFile=$cnfDir'/main.ini'

# 默认配置
# liveTime=86400 # 单位:s 存活时间 3天 86400=1天,  
# checkTime='10m' # 轮询周期 1小时 依赖 sleep实现 单位为: d h m s 

# TODO  就差一个记录文件的原始目录的逻辑, 这样就能达到回收站的全部功能了
# TODO 文件名最大长度是255, 注意测试边界条件
# TODO -l 时 显示链接文件时 格式全混乱了

init(){
    if [ ! -d $trashDir ];then
        mkdir -p $trashDir
    fi
    if [ ! -d $logDir ];then
        mkdir -p $logDir
    fi
    if [ ! -d $cnfDir ];then
        mkdir -p $cnfDir
    fi

    if [ ! -f $logFile ];then
        touch $logFile
    fi
    if [ ! -f $configFile ];then
        echo -e "liveTime=86400\ncheckTime='10m'" > $configFile
    fi

    printf "TrashPath : \033[0;32m"$mainDir"\n\033[0m"
    . $configFile
}
# 延迟删除, 并隐藏屏蔽了信号, 不阻塞当前终端
lazyDelete(){
    result=`ps -ef | grep RecycleBin.sh | wc -l`
    # echo "$result"
    # 限制只开一个进程, 3 是因为第一次运行才是3
    if [ "$result" != "3" ];then
        exit
    else
        fileNum=`ls -A $trashDir | wc -l`
        while [ ! $fileNum = 0 ]; do
            sleep $checkTime
            logInfoWithWhite "→ timing detection  ▌ check trash ..."
            ls -A $trashDir | cat | while read line; do
                currentTime=`date +%s`
                removeTime=${line##*\.}
                ((result=$currentTime-$removeTime))
                # echo "$line | $result"
                if [ $result -ge $liveTime ];then
                    logWarn "▶ real delete       ▌ rm -rf $trashDir/$line"
                    rm -rf "$trashDir/$line"
                fi
            done
            fileNum=`ls -A $trashDir | wc -l`
        done
        logError "▶ trash is empty    ▌ script will exit ..."
    fi
}
# TODO move a dir/file
# move file to trash 
moveFile(){
    fileName="$1";
    deleteTime=`date +%s`
    readable=`date +%Y-%m-%d_%H-%M-%S`
    if [ ! -f "$currentPath/$fileName" ] && [ ! -d "$currentPath/$fileName" ] && [ ! -L "$currentPath/$fileName" ];then 
        printf $red"file not exist \n"
        exit
    fi
    logInfoWithGreen "◆ prepare to delete ▌ $currentPath/$fileName"
    # 全部加上双引号是因为文件名中有可能会有空格
    mv "$currentPath/$fileName" "$trashDir/$fileName.$readable.$deleteTime"
}
# * 通配符删除
moveAll(){
    pattern=$1
    if [ "$pattern"1 = "1" ];then
        printf "delete [all file]/[exclude hidden file]/[no]?  [a/y/n] : " 
        read answer
        flag=0
        if [ "$answer" = "a" ];then
            list=`ls -A`
            flag=1
        fi
        if [ "$answer" = "y" ];then
            list=`ls -A | grep -v "^\."`
            flag=1
        fi
        if [ $flag = 0 ];then
            exit
        fi
    else
        list=`ls -A | egrep $pattern`
    fi
    # list=`ls -A | grep "$pattern"`
    num=${#list}
    if [ $num = 0 ];then
        printf $red"no matches found $pattern \n"
        exit
    fi
    for file in $list; do
        # echo ">> $file"
        moveFile "$file"
    done
}
rollback(){
    if [ "$1"1 = "1" ];then
        printf $red"please select a specific rollback file\n"
        exit 1
    fi
    if [ ! -f $trashDir/$1 ] && [ ! -d $trashDir/$1 ];then
        printf $red"this file not exist \n"
        exit 1
    fi
    file=${1%\.*}
    file=${file%\.*}
    mv $trashDir/$1 $file
    logInfoWithCyan "◀ rollback file     ▌ $file"
    printf $green"rollback [$file] complete \n"
}
logInfoWithWhite(){
    printf "`date +%y-%m-%d_%H:%M:%S` $1\n" >>$logFile
}
logInfoWithGreen(){
    printf `date +%y-%m-%d_%H:%M:%S`"$green $1\n" >>$logFile
}
logInfoWithCyan(){
    printf `date +%y-%m-%d_%H:%M:%S`"$cyan $1\n" >>$logFile
}

logError(){
    printf `date +%y-%m-%d_%H:%M:%S`"$red $1\n" >>$logFile
}

logWarn(){
    printf `date +%y-%m-%d_%H:%M:%S`"$yellow $1\n" >>$logFile
}

help(){
    printf "Run：$red sh RecycleBin.sh$green <verb> $yellow<args>$end\n"
    format="  $green%-5s $yellow%-15s$end%-20s\n"
    printf "$format" "any" "" "move file/dir to trash"
    printf "$format" "-h" "" "show help"
    printf "$format" "-a" "\"pattern\"" "delete file (can't use *, actually command: 'ls | grep \"pattern\"')"
    printf "$format" "-l" "" "list all file in trash(exclude link file)"
    printf "$format" "-roll" "file" "rollback file from trash"
    printf "$format" "-lo" "file" "show log"
    printf "$format" "-cnf" "" "edit main config file "
    printf "$format" "-b" "" "show background running script"
    printf "$format" "-d" "" "shutdown this script"
}

showNameColorful(){
    fileName=$1
    timeStamp=${fileName##*\.}
    fileName=${fileName%\.*}
    time=${fileName##*\.}
    name=${fileName%\.*}
    printf " $green$time$end $yellow$name$end.$time.$red$timeStamp$end\n"
    # printf " %-30s$green%s$end\n" $name "$time" 
}
listTrashFiles(){
    # grep r 是为了将一行结果变成多行, 目前不展示link文件
    file_list=`ls -lAFh $trashDir | egrep -v '^lr' | grep 'r'`
    count=0
    printf "$blue%-9s %-3s %-5s %-5s %-5s%-5s %-5s %-5s %-19s %-5s$end\n" "mode" "num" "user" "group" "size" "month" "day" "time " "datetime" "filename "
    printf "${blue}---------------------------------------------------------------------------------------- $end\n"
    for line in $file_list;do
        count=$(($count + 1))
        if [ $(($count % 9)) = 0 ];then
            showNameColorful $line
        elif [ $(($count % 9)) = 2 ];then
            printf "%-4s" " $line"
        else
            printf "%-6s" "$line"
        fi
    done
}

upgrade(){
    curl https://gitee.com/gin9/script/raw/master/shell/base/RecycleBin.sh -o $realPath/RecycleBin.sh
    printf $green"upgrade script success\n"$end
}

# 初始化脚本的环境
init

case $1 in 
    -h)
        help
    ;;
    -a)
        moveAll "$2"
        (lazyDelete &)  
    ;;
    -lo)
        less $logFile
    ;;
    -l)
        listTrashFiles
    ;;
    -roll)
        rollback $2
    ;;
    -b)
        ps aux | grep RSS | grep -v "grep" && ps aux | egrep -v "grep" | grep RecycleBin.sh | grep -v "RecycleBin.sh -b"
    ;;
    -d)
        id=`ps -ef | grep "RecycleBin.sh" | grep -v "grep" | grep -v "\-d" | awk '{print $2}'`
        if [ "$id"1 = "1" ];then
            printf $red"not exist background running script\n"$end
        else
            printf $red"pid : $id killed\n"$end
            logWarn "♢ killed script     ▌ pid: $id"
            kill -9 $id
        fi
    ;;
    -cnf)
        less $configFile
    ;;
    -upgrade)
        upgrade
    ;;
    *)
        if [ "$1"1 = "1" ];then
            printf $red"pelease select specific file\n"$end 
            help
            exit
        fi
        moveFile "$1"
        (lazyDelete &)
    ;;
esac
