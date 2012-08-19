#! /bin/sh
#
# csv2lfv.sh
#    CSV(Excel形式(RFC 4180):ダブルクォーテーションのエスケープは"")から
#    行番号列番号インデックス付き値(line field indexed value)ファイルへの変換器
#
# Usage: csv2lfv.sh [CSV_file]
#
# Written by Rich Mikan(richmikan[at]richlab.org) / Date : Aug 4, 2012


ACK=$(printf '\006')             # 1列1行化後に元々の改行を示すための印
NAK=$(printf '\025')             # (未使用)
ESC=$(printf '\033')             # ダブルクォーテーション*2のエスケープ印
LF=$(printf '\\\n_');LF=${LF%_}  # SED内で改行を変数として扱うためのもの

if [ \( $# -eq 1 \) -a \( \( -f "$1" \) -o \( -c "$1" \) \) ]; then
  file=$1
elif [ \( $# -eq 0 \) -o \( \( $# -eq 1 \) -a \( "_$1" = '_-' \) \) ]
then
  file=/dev/stdin
else
  echo "Usage : $0 [CSV_file]" > /dev/stderr
  exit 1
fi

# === データの流し込み ============================================= #
cat "$file"                                                          |
#                                                                    #
# === 値としてのダブルクォーテーションをエスケープ ================= #
#     (但しnull囲みの""も区別が付かず、エスケープされる)             #
sed "s/\"\"/$ESC/g"                                                  |
#                                                                    #
# === 値としての改行を\nに変換 ===================================== #
#     (ダブルクォーテーションが奇数個なら\n付けて次の行と結合する)   #
awk '                                                                \
  {                                                                  \
    s=$0;                                                            \
    gsub(/[^"]/,"",s);                                               \
    if (((length(s)+cy) % 2)==0) {                                   \
      cy=0;                                                          \
      printf("%s\n",$0);                                             \
    } else {                                                         \
      cy=1;                                                          \
      printf("%s\\n",$0);                                            \
    }                                                                \
  }                                                                  \
'                                                                    |
#                                                                    #
# === 各列を1行化するにあたり、元々の改行には予め印をつけておく ==== #
#     (元々の改行の後にACK行を挿入する)                              #
awk '                                                                \
  {                                                                  \
    printf("%s\n'$ACK'\n",$0);                                       \
  }                                                                  \
'                                                                    |
#                                                                    #
# === ダブルクォーテーション囲み列の1列1行化 ======================= #
#     (その前後にスペースもあれば余計なのでここで取り除いておく)     #
# (1/3)先頭からNF-1までのダブルクォーテーション囲み列の1列1行化      #
sed "s/[[:blank:]]*\(\"[^\"]*\"\)[[:blank:]]*,/\1$LF/g"              |
# (2/3)最後列(NF)のダブルクォーテーション囲み列の1列1行化            #
sed "s/,[[:blank:]]*\(\"[^\"]*\"\)[[:blank:]]*$/$LF\1/g"             |
# (3/3)ダブルクォーテーション囲み列が単独行だったらスペース除去だけ  #
sed "s/^[[:blank:]]*\(\"[^\"]*\"\)[[:blank:]]*$/\1/g"                |
#                                                                    #
# === ダブルクォーテーション囲みでない列の1列1行化 ================= #
#     (単純にカンマを改行にすればよい)                               #
#     (ただしダブルクォーテーション囲みの行は反応しないようにする)   #
sed "/[$ACK\"]/!s/,/$LF/g"                                           |
#                                                                    #
# === ダブルクォーテーション囲みを外す ============================= #
#     (単純にダブルクォーテーションを除去すればよい)                 #
#     (値としてのダブルクォーテーションはエスケープ中なので問題無し) #
tr -d '"'                                                            |
#                                                                    #
# === エスケープしてた値としてのダブルクォーテーションを戻す ======= #
#     (ただし、区別できなかったnull囲みの""も戻ってくるので適宜処理) #
# (1/3)まずは""に戻す                                                #
sed "s/$ESC/\"\"/g"                                                  |
# (2/3)null囲みの""だった場合はそれを空行に変換する                  #
sed 's/^[[:blank:]]*""[[:blank:]]*$//'                               |
# (3/3)""を単純な"に戻す                                             #
sed 's/""/"/g'                                                       |
#                                                                    #
# === 先頭に行番号と列番号をつける ================================= #
awk '                                                                \
  BEGIN{                                                             \
    l=1;                                                             \
    f=1;                                                             \
  }                                                                  \
  {                                                                  \
    if ($0=="'$ACK'") {                                              \
      l++;                                                           \
      f=1;                                                           \
    } else {                                                         \
      printf("%d %d %s\n",l,f,$0);                                   \
      f++;                                                           \
    }                                                                \
  }                                                                  \
'