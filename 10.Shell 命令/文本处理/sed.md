# sed

sed 是一种非交互式的流编辑器，可动态编辑文件。所谓的非交互式是说，sed 和传统的文本编辑器不同，并非和使用者直接互动，sed 处理的对象是文件的数据流。sed 的工作模式是，比对每一行数据，若符合样式，就执行指定的操作。

```sh
# 选项与参数
-n：使用安静(silent)模式。在一般 sed 的用法中，所有来自 STDIN 的数据一般都会被列出到终端上。但如果加上 -n 参数后，则只有经过sed 特殊处理的那一行(或者动作)才会被列出来。
-e：直接在命令列模式上进行 sed 的动作编辑；
-f：直接将 sed 的动作写在一个文件内，-f filename 则可以运行 filename 内的 sed 动作；
-r：sed 的动作支持的是延伸型正规表示法的语法。(默认是基础正规表示法语法)
-i：直接修改读取的文件内容，而不是输出到终端。

# 函数
a：新增，a 的后面可以接字串，而这些字串会在新的一行出现(目前的下一行)～
c：取代，c 的后面可以接字串，这些字串可以取代 n1,n2 之间的行！
d：删除，因为是删除啊，所以 d 后面通常不接任何咚咚；
i：插入，i 的后面可以接字串，而这些字串会在新的一行出现(目前的上一行)；
p：列印，亦即将某个选择的数据印出。通常 p 会与参数 sed -n 一起运行～
s：取代，可以直接进行取代的工作哩！通常这个 s 的动作可以搭配正规表示法！例如 1,20s/old/new/g 就是啦！
```

常用示例：

```sh
# 在第一行和第二行间插入一行123Abc
sed -i '2i 123Abc' 1.log
# 在第二行和第三行间插入一行 123Abc
sed -i '2a 123Abc' 1.log

sed '1,4d' 1.log  #删除1到4行数据，剩下的显示出来。d是sed的删除命令。这里的删除并不是修改了源文件

# 删除最后一行
sed '$d' 1.log
# 删除匹配到包含'LA'字符行的数据，剩下的显示。#代表搜索
sed '/LA/d' 1.log

sed '/[0-9]\{3\}/d' 1.log   #删除包含三位数字的行，注意{3}个数指定的大括号转义

sed '/LA/!d' 1.log  # 反选，把不含LA行的数据删除

sed '/^$/d' 1.log #删除空白行

# 如果想显示匹配到的呢？
sed '/a/p' 1.log   #由于默认sed也会显示不符合的数据行，所以要用-n，抑制这个操作
sed -n '/a/p' 1.log


# 替换字符，把a替换成A
sed -n 's/a/A/p' 1.log  #s是替换的命令，第一个#中的字符是搜索目标（a），第二个#是要替换的字符A

# 上面的只会替换匹配到的第一个，如果我想所有替换呢
sed -n 's/a/A/gp' 1.log   # g 全局替换
sed -n 's/a#gp' 1.log #删除所有的a
sed -n 's/^...#gp' 1.log  #删除每行的前三个字符
sed -n 's/...$#gp' 1.log  #删除每行结尾的三个字符
sed -n 's/\(A\)/\1BC/gp' 1.log  # 在A后面追加BC，\1表示搜索里面括号里的字符


sed -n '/AAA/s/234/567/p' 1.log  # 找到包含字符AAA这一行，并把其中的234替换成567
sed -n '/AAA/,/BBB/s/234/567/p' 1.log # 找到包含字符AAA或者BBB的行，并把其中的234替换成567
sed -n '1,4s/234/567/p' 1.log  # 将1到4行中的234.替换成567
cat 1.log | sed -e '3,$d' -e 's/A/a/g'   # 删除3行以后的数据，并把剩余的数据替换A为a
sed -i '1d' 1.log   # 直接修改文件，删除第一行
```

统计文件中的词频：

```sh
sed 's/ /\n/g' "$@" |      # convert to one word per line
tr A-Z a-z |               # map uppercase to lower case
sed "s/[^a-z']//g" |       # remove all characters except a-z and '
egrep -v '^$' |             # remove empty lines
sort |                     # place words in alphabetical order
uniq -c |                  # use uniq to count how many times each word occurs
sort -n                   # order words in frequency of occurrance
```
