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

    remotes=""
    for temp in $result; do
        count=$(( $count + 1 ))
        if [ $(($count % 6)) = 0 ]; then
            log_info "push to "$temp
            git push $temp
        fi
    done
}

pullAllRepos(){
    # 并行 最后有序合并输出
    cat $configPath | while read line; do
    {
        # ignore that comment contain + character
        ignore=`echo "$line" | grep "+"`
        if [ "$ignore"x != "x" ];then 
            continue
        fi

        repo_path=$(getPath "$line")
        if [ "$repo_path" = "" ];then
            continue
        fi
        
        result=""
        result=$result""$(showLine "$line" $purple)"\n"
        result=$result""$(cd $repo_path && git pull)"\n"
        echo "$result"
    }&
    done
    wait
}

pushToAllRepos(){
    cat $configPath | while read line; do
    {
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
    }&
    done
    wait
}

checkRepos(){
    cat $configPath | while read line; do
    {
        repoOutput=''
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
            repoOutput=$repoOutput" "$(showLine "$line" $green)"\n"
            count=0
            temp=''
            for file in $result; do
                count=$(( $count + 1 ))
                temp="$temp   $file"
                if [ $(($count%2)) = 0 ];then
                    repoOutput=$repoOutput" "$(log $cyan "$temp")"\n"
                    temp=''
                fi
            done
            repoOutput=$repoOutput" "$(echo ''$end)
        fi
        if [ ! "$repoOutput" = "" ]; then
            echo "$repoOutput"
        fi
    }&
    done
    wait
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
        printf "$yellow%-20s $pathColor%-56s $blue%-20s $end\n" $str_alias $str_path "$str_comment"
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
    log_info "Please input description"
    read comment
    log_info "Please input alias name, such as input a, result: $end alias kg.a='/current/path/to'"
    read aliasName
    echo "alias kg."$aliasName"='cd $repo_path' # $comment" >> $configPath
    log_info "add success, Please run $end source ~/.zshrc"
}



help(){
    printf "Run：$red sh repos-manager.sh $green<verb> $yellow<args>$end\n"
    format="  $green%-10s $yellow%-10s$end%-20s\n"
    printf "$format" "-h|h" "" "show help"
    printf "$format" "" "" "show all modify local repo"
    printf "$format" "-l|l|list" "" "list all local repo"
    printf "$format" "-p|p|push" "" "push all modify local repo to remote "
    printf "$format" "-pa|pa" "" "push current local repo to all remote"
    printf "$format" "-pl|pull" "repo ..." "batch pull repo from remote "
    printf "$format" "-pla|pla" "" "pull all repo from remote"
    printf "$format" "-ds|ds" "" "download subdir by svn for github"
    printf "$format" "-ac|ac" "" "add current local repo to alias config"
    printf "$format" "-cnf|cnf" "" "open alias config file "
    printf "$format" "-f|f" "filename" "show file content url in github"
}

get_user_repo(){
    domain=$1

    remote=$(git remote -v | grep $domain".*push" | awk '{print $2}')
    remote=${remote#*//}
    remote=${remote#*/}
    remote=${remote%.git*}
    echo $remote
}

get_remote_file_url(){
    file_path=$(pwd)'/'$1
    while true; do
        current=$(pwd)
        if [ $current = '/' ];then
            log_error "has find with root dir /, but not find git repo"
            exit 1
        fi
        if [ -d $current/.git ];then
            # echo "repo root path: "$current
            root_path=$current
            break
        fi
        cd ..
    done

    file_path=${file_path#*$root_path}

    remote=$(get_user_repo github)
    echo $remote
    if [ ! $remote'z' = 'z' ];then
        log "\nGithub"
        log_info " raw: https://raw.githubusercontent.com/"$remote"/master"$file_path""
        log_info " url: https://github.com/"$remote"/blob/master"$file_path"\n"
    fi

    remote=$(get_user_repo gitee)
    if [ ! $remote'z' = 'z' ];then
        log "Gitee"
        log_info " raw: https://gitee.com/"$remote"/raw/master"$file_path"\n"
    fi

    remote=$(get_user_repo gitlab)
    if [ ! $remote'z' = 'z' ];then
        log "Gitlab"
        log_info " raw: https:"$remote"/raw/master"$file_path"\n"
        log_info " url: https:"$remote"/blob/master"$file_path"\n"
    fi
}

# 入口 读取脚本参数调用对应 函数
case $1 in 
    -h | h)
        help;;
    -pl | pull)
        pullRepos $@
    ;;
    -p | push | p)
        pushToAllRepos
    ;;
    -pa | pa)
        pushToAllRemote
    ;;
    -pla | pla)
        pullAllRepos
    ;;
    -ds | ds)
        # url=${2/tree\/master/trunk} bash
        url=$(echo $2 | awk '{gsub(/tree\/master/,"trunk");print}')
        svn co $url
    ;;
    -ac | ac)
        addRepo
    ;;
    -l | l | list)
        listRepos | sort
    ;;
    -traash | trash)
        current_branch=$(git branch --show-current)
        git add -A
        git checkout -b trash/`date "+%Y%m%d-%H%M%S"`-$current_branch
        git commit -am "cache"
        git checkout -
    ;;
    -cnf | cnf)
        vim $configPath
    ;;
    -f | f)
        get_remote_file_url $2
    ;;
    *)
        checkRepos
    ;;
esac