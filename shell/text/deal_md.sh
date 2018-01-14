
read_dir(){
    for file in `ls $1`
    do
        if [ -d $1"/"$file ]  #注意此处之间一定要加上空格，否则会报错 
        # 这里是判断是否是文件夹,文件夹就进入
        then
            read_dir $1"/"$file
        else
            # echo ">>"$1"/"$file
            # 判断当前文件是否属于忽略文件 是则文件名否则空
            ignore_file=`cat /home/kcp/Application/Script/shell/text/ignore.conf | grep $file`
            # 判断文件名是否符合正则,负责则文件名否则空
            type=`echo $file | grep .*md$`
            # 不是忽略文件并且文件名符合要求
            if [ "$ignore_file"z = "z" ] && [ "$type"z != "z" ]; then 
                echo ">>>>>>"$file
                result=`python3 ~/Application/Script/python/append_contents.py -a n $1'/'$file`
                echo -e "$result"
            fi 
        fi
    done
}

case $1 in 
    -h | h | help)
        start='\033[0;32m'
        end='\033[0m'
        printf "%-20s$start%-20s$end\n" "运行：bash deal_md.sh " "<params>"
        printf "  $start%-20s$end%-20s\n" "-h|h|help" "输出帮助信息"
        printf "  $start%-20s$end%-20s\n" "-i|i|index" "更新索引目录"
        printf "  $start%-20s$end%-20s\n" "-c|c|current" "更新当前目录所有md文件的索引目录"
        printf "  $start%-20s$end%-20s\n" "-a|a|all" "更新指定目录下所有md文件的索引目录"
        printf "  $start%-20s$end%-20s\n" "-al|al|alter" "更新指定git仓库下修改过的文件目录"
        printf "  $start%-20s$end%-20s\n" "no param" "更新索引目录";;
    -i | i | index)
        echo $2
        result=`python3 ~/Application/Script/python/append_contents.py -a n $2`
        echo -e "$result";;
    -c | c | current)
        files=`ls *.md`
        for file in $files
        do 
            if test -f $file; then
                echo $file
                result=`python3 ~/Application/Script/python/append_contents.py -a n $file`
                echo -e "$result"
            fi
        done;;
    -a | a | all)
        note_path='/home/kcp/Documents/Notes/Notes'
        # note_path='/home/kcp/test/md'
        echo "开始更新全部, 目录: "$note_path
        read_dir $note_path;;
    -al | al | alter)
        # TODO 
        echo "更新修改文件的目录";;
    *)
        echo $1
        # 过滤掉 - 的字符串 
        result=`python3 ~/Application/Script/python/append_contents.py -a n $1`
        echo -e "$result";;
esac