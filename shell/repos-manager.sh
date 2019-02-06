path=$(cd `dirname $0`; pwd)
. $path/base/base.sh

userDir=`cd && pwd`

# main repos alias config
configPath="${userDir}/.repos.sh"

getPath(){
    line=$1
    vars=`expr match "$line" "alias.kg.*"`
    if [ "$vars" = "0" ]; then 
        return 0;
    fi 
    vars=${1%%#*} # 截取#左边
    vars=${vars#*cd } # 截取cd右边
    vars=${vars%\'*} # 截取 右边引号 之左
    echo "$vars"
}

pullRepos(){
    . $configPath
    flag=0
    for repo in "$@" ; do
        # ignore first param
        if [ $flag = 0 ];then
            flag=1
            continue
        fi
        path="`alias kg.$repo`" 
        path=${path##*cd}
        path=${path%\'*}
        log_info $path
        cd $path && git pull
    done
}

pushToAllRemote(){
    path=`pwd`
    result=`git remote -v`
    count=-1
    for temp in $result; do
        count=$(( $count + 1 ))
        if [ $(($count % 6)) = 0 ]; then
            echo $start"$temp"$end
            git push $temp
        fi
    done
}

pullAllRepos(){
    # 并行 最后有序合并输出
    cat $configPath | while read line; do
        # ignore that comment contain + character
        ignore=`echo "$line" | grep "+"`
        if [ "$ignore"x != "x" ];then 
            continue
        fi

        repo_path=$(getPath "$line")
        if [ "$repo_path" = "" ];then
            continue
        fi
        
        showLine "$line" $purple
        cd $repo_path && git pull
    done
}

pushToAllRepos(){
    cat $configPath | while read line;do
        # ignore that comment contain + character
        ignore=`echo "$line" | grep "+"`
        if [ "$ignore"x != "x" ];then 
            continue
        fi

        repo_path=$(getPath "$line")
        if [ "$repo_path" = "" ];then
            continue
        fi
        showLine "$line" $purple
        result=`cd $repo_path && git status`
        haveCommit=`expr match "$result" ".*is ahead of"`
        if [ $haveCommit != 0 ]; then 
            cd $repo_path && git push
        fi
    done
}

checkRepos(){
    cat $configPath | while read line; do
        # ignore that comment contain + character
        ignore=`echo "$line" | grep "+"`
        if [ "$ignore"x != "x" ];then 
            continue
        fi

        repo_path=$(getPath "$line")
        if [ "$repo_path" = "" ];then
            continue
        fi

        result=`cd "$repo_path" && git status -s 2>&1`
        if [ ! "$result" = "" ];then
            showLine "$line" $green
            count=0
            temp=''
            for file in $result; do
                count=$(( $count + 1 ))
                temp="$temp   $file"
                if [ $(($count%2)) = 0 ];then
                    log $cyan "$temp"
                    temp=''
                fi
            done
            echo ''$end
        fi
    done
}

showLine(){
    line=$1
    pathColor=$2

    temp=${line%%#*}
    str_alias=${line%=*}
    str_alias=${str_alias#*alias}
    str_path=${temp#*cd}
    str_path=${str_path%\'*}
    str_comment=${line#*#}
    
    ignore=`echo "$str_comment" | grep "+"`
    if [ "$ignore"x != "x" ];then 
        printf "$yellow%-20s $pathColor%-56s $red%-20s $end\n" $str_alias $str_path "$str_comment"
    else
        printf "$yellow%-20s $pathColor%-56s $green%-20s $end\n" $str_alias $str_path "$str_comment"
    fi
}

listRepos(){
    cat $configPath | while read line ; do 
        vars=`expr match "$line" "alias.kg.*"`
        if [ "$vars" = "0" ]; then 
            continue
        fi
        showLine "$line" $cyan
    done
}

# add repo in current path
addRepo(){
    repo_path=`pwd`
    log_info "Please input comment or description"
    read comment
    log_info "Please input alias name, such as input a, then alias kg.a='/path/to'"
    read aliasName
    echo "alias kg."$aliasName"='cd $repo_path' # $comment" >> $configPath
    log_info "add success, Please run source ~/.zshrc or ~/.bashrc or ..."
}

addPythonPath(){
    lib_path='/usr/local/lib'
    project=$(pwd)
    
    log_info "Please select a python version"
    versions=$(ls $lib_path | grep "python")
    for version in $versions; do
        echo "  " $version 
    done
    read version
    if [ ! -d $lib_path/$version ];then 
        log_error "target dir not exist: $lib_path/$version"
    fi
    
    log_info "Please input filename, result: $lib_path/$version/dist-packages/filename.pth"
    while true; do
        read filename
        if [ -f "$lib_path/$version/dist-packages/$filename.pth" ];then
            log_warn "$filename already exist"
        else 
            break
        fi
    done
    sudo sh -c "echo $project >> $lib_path/$version/dist-packages/$filename.pth"
    log_info "add success: $lib_path/$version/dist-packages/$filename.pth"
}

help(){
    printf "Run：$red sh repos-manager.sh $green<verb> $yellow<args>$end\n"
    format="  $green%-10s $yellow%-10s$end%-20s\n"
    printf "$format" "-h" "" "show help"
    printf "$format" "" "" "show all modify local repo"
    printf "$format" "-l|l|list" "" "list all local repo"
    printf "$format" "-p|p|push" "" "push all modify local repo to remote "
    printf "$format" "-pa|pa" "" "push current local repo to all remote"
    printf "$format" "-pl|pull" "repo ..." "batch pull repo from remote "
    printf "$format" "-pla|pla" "" "pull all repo from remote"
    printf "$format" "-ac|ac" "" "add current local repo to alias config"
    printf "$format" "-app" "" "add current dir to sys.path for python"
    printf "$format" "-c|c" "" "open alias config file "
}

# 入口 读取脚本参数调用对应 函数
case $1 in 
    -h)
        help;;
    -pl | pull)
        pullRepos $@
    ;;
    -p | push | p)
        log_info "ready to push all repos"
        pushToAllRepos
    ;;
    -pa | pa)
        log_info "ready to push repo to all remote"
        pushToAllRemote
    ;;
    -pla | pla)
        log_info "ready to pull all repos"
        pullAllRepos
    ;;
    -ac | ac)
        addRepo
    ;;
    -l | l | list)
        listRepos | sort
    ;;
    -c | c)
        vim $configPath
    ;;
    -app)
        addPythonPath
    ;;
    *)
        checkRepos
    ;;
esac
