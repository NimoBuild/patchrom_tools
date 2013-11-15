#!/bin/bash
#功能函数
funcs=`which functions.sh`
if [ "$funcs" != "" ] ;then
    . $funcs
else
    funcs=`dirname $0`/functions.sh
    echo "$PWD"
    echo "funcs=$funcs"
    if [ "$funcs" != "" ] ;then
	. $funcs
    else
	exit
    fi
fi

function deodex_one_file() 
{
  local ac_file=$1
  local ac_type=$2
  local ac_classpath=$3
  local ac_apilevel=$4
  local ac_file_dir=`dirname $ac_file`
  ac_file=`basename $ac_file`
  tofile=${ac_file/odex/$ac_type}
  if [ -f "$ac_file_dir/$ac_file" ] && [ "$ac_file" != "$tofile" ]; then
    if [ -d out ];then
      rm -rf out
    fi
    echoTextGreen  "java -jar $BAKSMALIJAR -x $ac_file_dir/$ac_file"
    java -jar $BAKSMALIJAR -x $ac_file_dir/$ac_file
    echoTextGreen "java -Xmx512M -jar $SMALIJAR out -o classes.dex "
    java -Xmx512M -jar $SMALIJAR out -o classes.dex  
    echoTextGreen "$AAPT add -v $ac_file_dir/$tofile classes.dex"
    $AAPT add -v $ac_file_dir/$tofile classes.dex
    echoTextRed "$ac_file_dir/$tofile 合并已完成！"    
    rm classes.dex
    rm -rf out
    if [ "$ac_type" = "apk" ];then
      rm $ac_file_dir/$ac_file
    fi
    zipalign 4 $ac_file_dir/$tofile $ac_file_dir/$tofile.aligned
    mv $ac_file_dir/$tofile.aligned $ac_file_dir/$tofile
  fi

}

function deodex_system_files()
{
  local system_dir="$@"
  local saved_dir=`pwd`
  local files_list=
  local ac_files_list=
  local ac_core_jar=
  local ac_classpath=
  #处理apk和其他jar
  cd $saved_dir
  if [ -n "$system_dir" ] && test -d $system_dir;  then
    files_list="`ls $saved_dir/$system_dir/app/ 2> /dev/null |grep odex`"
    cd $system_dir/framework
    for f in $files_list
    do
      deodex_one_file  $saved_dir/$system_dir/app/$f  apk "$ac_classpath"
    done

    ac_frm_odexs="`ls *.odex 2> /dev/null`"
    for f in $ac_frm_odexs
    do
      deodex_one_file  `pwd`/$f  jar "$ac_classpath"
    done
    rm *.odex
    cd $saved_dir
  fi
}

function unzip_one_file()
{
  local zip_file=$1
  local unzip_to=$2
  if [ -n "$zip_file" ] && test -f $zip_file; then
    if [ -d $unzip_to ];then
      rm -rf $unzip_to
    fi
    mkdir -pv $unzip_to
    echo "unzip $zip_file to $unzip_to"
    unzip -q $zip_file -d $unzip_to
  else
    echoTextRed "未指定文件!"
    exit
  fi
}
function zip_one_file()
{
  local zip_file=$1
  local zip_from=$2
  if [ -n "$zip_from" ] && test -d $zip_from; then
    cd $zip_from
    echo "zip $zip_file from $zip_from"
    zip -q -r -y "$zip_file" *
    mv "$zip_file" ../
    cd -
  else
    echoTextRed "未指定目录!"
    exit
  fi
}

function sign_ota_file()
{
  local ota_file=$1
  local signapk_and_key_dir=$2
  local signapk=$signapk_and_key_dir/signapk.jar
  local testkey509=$signapk_and_key_dir/testkey.x509.pem
  local testkeypk8=$signapk_and_key_dir/testkey.pk8
  if [ ! -d $signapk_and_key_dir ];then
    echo "$signapk_and_key_dir"
  fi
  echo "signed $ota_file"
  echoTextGreen "java -Xmx4096m -jar $signapk -w $testkey509 $testkeypk8 $ota_file ${ota_file}.signed"
  java -Xmx4096m -jar $signapk -w $testkey509 $testkeypk8 $ota_file ${ota_file}.signed
  mv ${ota_file}.signed  $ota_file
  
}

function get_dexpreopt_boot_jars()
{
  local unpack_boot_dir=$1
  if [ ! -d $unpack_boot_dir ];then
    echo "目录不存在！"
  fi
  dexpreopt_boot_jars="`grep "INIT: user build setting" $unpack_boot_dir/ramdisk/init.rc -1`"
  if [ "$dexpreopt_boot_jars" != "" ];then
    dexpreopt_boot_jars="`grep "INIT: user build setting" $unpack_boot_dir/ramdisk/init.rc -1 |grep BOOTCLASSPATH |awk '{print $3}' |sed "s/\/system\/framework\///g" |sed "s/.jar//g"`"
  else
    dexpreopt_boot_jars="`grep BOOTCLASSPATH  $unpack_boot_dir/ramdisk/init.rc |awk '{print $3}' |sed "s/\/system\/framework\///g" |sed "s/.jar//g"`"
  fi
  echo "$dexpreopt_boot_jars" 
}
function unpack_tar_gz()
{
  local ac_file=$1
  local unpack_to=$2
  if [ -d $unpack_to ];then
    rm -rf $unpack_to
  fi
  mkdir -p $unpack_to
  cp $ac_file $unpack_to
  cd $unpack_to
  tar -xf *
  cd - 
}
function get_framework.odex_dir()
{
  local ac_file=$1
  local ac_dir=temp/dex_bootjars_dir
  local saved_dir=`pwd`
  if [ -f $ac_file ];then
    unpack_tar_gz $ac_file $ac_dir >&2
  elif [ -d $ac_file ];then
    ac_dir=$ac_file
  fi
  ac_dir="`find $ac_dir -name framework.odex`"
  ac_dir="`dirname $ac_dir`"
  ac_dir=$saved_dir/$ac_dir
  echo $ac_dir
}
function copy_overlay_file()
{
  local ac_file=$1
  local copy_to=$2
  local ac_type=
  if [ ! -d $copy_to ];then
    echoTextRed "指定的目录$copy_to不存在！"
  else
    echoTextRed "copy $ac_file to $copy_to"
    if [ -n "$ac_file" ] && [ -f "$ac_file" ];then
      ac_type=`basename $ac_file |grep jar`
      if [ -n "$ac_type" ];then
        cp $ac_file $copy_to/system/framework/
      else
        cp $ac_file $copy_to/system/app/
      fi
    elif [ -d "$ac_file" ];then
      ac_type=`ls $ac_file |grep jar`
      if [ -n "$ac_type" ];then
        cp $ac_file/* $copy_to/system/framework/
      else
        cp $ac_file/* $copy_to/system/app/
      fi      
    fi
  fi 
}
function odex_one_file()
{
  #echoTextBlue "开始通过apk/jar生成odex文件......"
  local ac_file=$1
  local dex_bootjars_path=$2
  local dexpreopt_boot_jars=$3
  local is_system_jar=$4
  local tool_dex_preopt=`which dex-preopt`
  local tool_dexopt=
  local saved_dir=`pwd`
  local base_name=`basename $dex_bootjars_path`
  dex_bootjars_path=`dirname $dex_bootjars_path`
  tool_dex_preopt="$tool_dex_preopt --dexopt=$base_name/bin/dexopt"
  
  DEX_PREOPT_CMD="$tool_dex_preopt --build-dir=$dex_bootjars_path --product-dir=$base_name --boot-dir=system/framework --boot-jars=$dexpreopt_boot_jars"
  file_name=`basename $ac_file`
  ac_file_dir=`dirname $ac_file`
  ac_type=`echo $file_name |awk -F. '{print $NF}'`
  if [ -n "$ac_type" ];then
    odex_name=`echo $file_name|sed "s/$ac_type/odex/"`
  else
    echo "输入文件有误！"
    exit
  fi
  if [ "$is_system_jar" != "yes" ];then
    cp $ac_file  $dex_bootjars_path/    
    echoTextGreen "$DEX_PREOPT_CMD $file_name  $odex_name"
    $DEX_PREOPT_CMD $file_name  $odex_name
    echoTextGreen "$AAPT remove $dex_bootjars_path/$file_name classes.dex"
    $AAPT remove $dex_bootjars_path/$file_name classes.dex
    mv $dex_bootjars_path/$file_name $ac_file_dir
    mv $dex_bootjars_path/$odex_name $ac_file_dir
  else
    nodex_name=`echo $file_name|sed "s/.$ac_type/nodex.$ac_type/"`
    cp $ac_file  $dex_bootjars_path/$base_name/system/framework/
    cp $ac_file  $dex_bootjars_path/$base_name/system/framework/$nodex_name
    echoTextGreen "$AAPT remove $dex_bootjars_path/$base_name/system/framework/$nodex_name classes.dex"
    $AAPT remove $dex_bootjars_path/$base_name/system/framework/$nodex_name classes.dex
    rm $dex_bootjars_path/$base_name/system/framework/$odex_name
    echoTextGreen "$DEX_PREOPT_CMD $base_name/system/framework/$file_name  $base_name/system/framework/$odex_name"
    $DEX_PREOPT_CMD $base_name/system/framework/$file_name  $base_name/system/framework/$odex_name
    cp $dex_bootjars_path/$base_name/system/framework/$nodex_name $ac_file_dir/$file_name
    cp $dex_bootjars_path/$base_name/system/framework/$odex_name $ac_file_dir  
  fi
}
function get_file_dir() 
{
  local ac_file=$1
  local ac_file_name=
  local ac_file_dir=
  local save_dir=`pwd`
  ac_file_name=`basename $ac_file`
  ac_file_dir=`dirname $ac_file`
  
  cd $ac_file_dir/
  echo "`pwd`/$ac_file_name"
  cd $save_dir
}
function cp_app_and_lib()
{
  local release_system=$1
  local my_system=$2
  echo "拷贝apk和库文件"
  rm -rf ${my_system}/app/*
  echo "cp -rf $release_system/app/* ${my_system}/app/"
  cp -rf $release_system/app/* ${my_system}/app/
  echo "cp -n $release_system/lib/*  ${my_system}/lib/"
  cp -n $release_system/lib/*  ${my_system}/lib/
  return 0
}
function odex_system_file()
{
  local ac_ota_file=$1
  local dex_bootjars_path=$2
  local ac_overlay_file=$3
  local dexpreopt_boot_jars=
  local temp_dir=temp/dex_bootjars_dir
  local unzip_to=temp/unzip_ota
  local unpack_boot_to=temp/unpack_boot
  local ota_file_name=`basename $ac_ota_file`
  local tofile=
  if [ -n "dex_bootjars_path" ] && [ -f $dex_bootjars_path ];then
    unpack_tar_gz $dex_bootjars_path $temp_dir
    dex_bootjars_path=$PWD/$temp_dir
  fi
  unzip_one_file $ac_ota_file  $unzip_to
  uglyfish.sh --unpack-boot   -i $unzip_to/boot.img -o $unpack_boot_to
  dexpreopt_boot_jars=`get_dexpreopt_boot_jars  $unpack_boot_to`
  if [ -f $unzip_to/system/framework/framework.odex ];then
    deodex_system_files $unzip_to/system
    is_odex=yes
  fi
  if [ -n "$ac_apk_file" ];then
    copy_overlay_file $ac_apk_file $unzip_to
  fi
  if [ -n "$ac_overlay_jar_file" ];then
    copy_overlay_file $ac_overlay_jar_file $unzip_to
  fi
  result=`question "将会重新生成新的T卡升级包 ,如需要手动编译文件系统内容(eg:单独增加应用,替换jar包、apk，修改专项版本号), 请在 $PWD/$unzip_to 目录进行,完成后再选择 yes 继续, no 退出!" 1 yes`
  if [ "$result" = "yes" ]; then
    if [ "$is_odex" = "yes" ];then
      framework_jar_list=`echo $dexpreopt_boot_jars.jar |sed "s/:/.jar /g"`
      echoTextRed "必须按顺序拆解的jar包： $framework_jar_list"
      other_framework_jar_list="`echo $dexpreopt_boot_jars.jar |sed "s/:/.jar /g" |tr ' ' '|'`"
      other_framework_jar_list=`ls $unzip_to/system/framework/ |grep jar |grep -v -E "google|tpadsz_engine" |grep -v -E "$other_framework_jar_list"` 
      echoTextRed "其余的jar包： $other_framework_jar_list"  
      for jar in $framework_jar_list
      do
        tofile=${jar/jar/odex}
        odex_one_file  $unzip_to/system/framework/$jar  $dex_bootjars_path $dexpreopt_boot_jars  yes
      done
   
      for apk in `ls $unzip_to/system/app/ |grep apk`
      do
        tofile=${apk/apk/odex}
        odex_one_file  $unzip_to/system/app/$apk  $dex_bootjars_path $dexpreopt_boot_jars
      done  
      for jar in $other_framework_jar_list
      do
        tofile=${jar/jar/odex}
        odex_one_file  $unzip_to/system/framework/$jar  $dex_bootjars_path $dexpreopt_boot_jars
      done
    fi       
    echoTextBlue "zip_one_file new_$ota_file_name $unzip_to"
    zip_one_file new_$ota_file_name $unzip_to
    echoTextGreen "新的T卡包重新签名。。。"
    sign_ota_file  $unzip_to/../new_$ota_file_name $dex_bootjars_path
    echoTextRed "新的T卡升级包已生成到: $unzip_to/../new_$ota_file_name"
  else
    echoTextRed "放弃打包T卡包操作!"
  fi
  rm -rf $unzip_to $unpack_boot_to $temp_dir
  
}

function merge_two_ota_file()
{
  local ac_old_ota_file=$1
  local ac_new_ota_file=$2  
  local dex_bootjars_path=$3
  local dexpreopt_boot_jars=
  local temp_dir=temp/dex_bootjars_dir
  local unzip_to=temp/unzip_ota
  local unpack_boot_to=temp/unpack_boot
  local ota_file_name=`basename $ac_new_ota_file`
  local tofile=
  if [ -f $dex_bootjars_path ];then
    unpack_tar_gz $dex_bootjars_path $temp_dir
    dex_bootjars_path=$PWD/$temp_dir
  fi
  unzip_one_file $ac_old_ota_file  $unzip_to
  uglyfish.sh --unpack-boot   -i $unzip_to/boot.img -o $unpack_boot_to
  dexpreopt_boot_jars=`get_dexpreopt_boot_jars  $unpack_boot_to`
  if [ -f $unzip_to/system/framework/framework.odex ];then
    deodex_system_files $unzip_to/system
  fi
  unzip_one_file $ac_new_ota_file  ${unzip_to}_new
  cp_app_and_lib $unzip_to/system   ${unzip_to}_new/system
  
  result=`question "将会重新生成新的T卡升级包 ,如需要手动编译文件系统内容(eg:单独增加应用,替换apk，修改专项版本号), 请在 $PWD/$unzip_to 目录进行,完成后再选择 yes 继续, no 退出!" 1 yes`
  if [ "$result" = "yes" ]; then
    if [ -f ${unzip_to}_new/system/framework/framework.odex ];then
      dex_bootjars_path_local=`question "请手动指定编译工程中odex的路径" 2 out/target/product/bbk82_wet_jb5/dex_bootjars/`
      cp $dex_bootjars_path_local/* $dex_bootjars_path/ -rf
      all_apk_list=`ls ${unzip_to}_new/system/app/ |grep apk`
      for apk in $all_apk_list
      do
        tofile=${apk/apk/odex}
        odex_one_file  ${unzip_to}_new/system/app/$apk  $dex_bootjars_path $dexpreopt_boot_jars     
      done
    fi
    echoTextBlue "zip_one_file new_$ota_file_name ${unzip_to}_new"
    zip_one_file new_$ota_file_name ${unzip_to}_new
    echoTextGreen "新的T卡包重新签名。。。"
    sign_ota_file  ${unzip_to}_new/../new_$ota_file_name $dex_bootjars_path
    echoTextRed "新的T卡升级包已生成到: ${unzip_to}_new/../new_$ota_file_name"
  fi
  rm -rf $unzip_to ${unzip_to}_new $unpack_boot_to $temp_dir
}
#帮助函数
function usage()
{
  local ac_args="$@"
  echoTextGreen "====>命令参数: $ac_args"
  echoTextGreen "用法:  $1 [-apk path_to_apk] [-d path_to_dex_bootjars] [-jar path_to_jar] [-n path_to_new_ota_zip] [-o path_to_old_ota_zip] [-odex path_to_odex] [-t apk/jar]
  -apk  指定apk文件路径
  -d    指定签名/拆解apk包所需的工具包，配置组提供，放在ftp系统软件目录
  -jar  指定jar包路径
  -n    指定自己编译的T卡升级包
  -o    指定想要修改的OTA包，比如：替换配置组发布的T卡升级包中的apk或者jar（支持user版本）
  -odex 指定odex文件路径
  -t    指定合并odex后要生成的文件类型（apk/jar）
实例：
  1、替换T卡升级包中的apk或者jar：
    $1 -o path/to/PD1224CW_A_1.7.6-update-full.zip  -d path/to/dex_bootjars_1.7.6.tar.gz
  2、将系统版本1.7.6的apk合并到自己编译的T卡升级包：
    $1 -o path/to/PD1224CW_A_1.7.6-update-full.zip -n  path/to/PD1224CW_A_A09.10.11-update-full.zip  -d  path/to/dex_bootjars_1.7.6.tar.gz 
  3、将odex合并成apk或者jar（请先将apk和odex放在同一个目录）：
    $1 -n path/to/PD1224CW_A_1.7.6-update-full.zip -odex path/to/Mms.odex  -t apk
  4、将apk文件拆成odex:
    $1 -n path/to/PD1224CW_A_1.7.6-update-full.zip -apk  path/to/Mms.apk
  "
}
#参数预处理begin
script_name=$0
#script_args=`getopt -o -s -n -t a:l:T:e:k:LD -l url:,help -- "$@"` 
#[ $? -ne 0 ] && usage $script_name $@ && exit $?
if [ $# = 0 ]; then usage $script_name $@;exit $?; fi
#eval set --"${script_args}"
#参数预处理
script_args=
while test $# != 0
do
  case $1 in
    --help)
      usage $script_name $@&&exit
      ;; 
    -a)
      shift
      apilevel=$1    
      ;;
    -apk)
      shift
      ac_apk_file=$1  
      ;;         
    -d | -dex_bootjars)
      shift
      dex_bootjars_tar_gz=$1         
      ;;
    -jar)
      shift
      ac_overlay_jar_file=$1  
      ;;         
    -n | -new)
      shift
      new_ota_zip=$1    
      ;;          
    -odex)
      shift
      ac_odex_file=$1    
      ;;      
    -o | -old)
      shift
      stock_ota_zip=$1    
      ;;
    -t)
      shift
      ac_type=$1    
      ;;   
                     
    *)
      if [ "$1" != "--" ]; then
        script_args="$script_args $1"
      fi
      ;;
      esac
      shift
done
export PATH=$PWD/`dirname $0`:$PATH
#参数预处理end
PORT_ROOT=$PWD
TOOL_PATH=$PORT_ROOT/tools
AAPT=`which aapt`
SMALI=`which smali`
BAKSMALI=`which baksmali`
SMALIJAR=$SMALI.jar
BAKSMALIJAR=$BAKSMALI.jar
if [ -z "$SMALI" ] || [ -z "$BAKSMALI" ]; then
  echoTextRed "Error: Can not find baksmali/smali"
  exit -1
fi
if [ -z "$dex_bootjars_tar_gz" ]; then
  echoTextRed "未指定框架jar工具包dex_bootjars.tar.gz,user版本必须与系统版本对应,eng版本可以直接用最新的系统版本."
  result=`question "是否只想将单个odex合并成apk或者jar？yes 继续, no 退出!" 1 yes`
  if [ "$result" != "yes" ];then
    exit -1
  fi
fi
if [ -n "$stock_ota_zip" ];then
  if [ -n "$new_ota_zip" ]; then
    echoTextRed "合并两个ota包..."
    merge_two_ota_file $stock_ota_zip $new_ota_zip $dex_bootjars_tar_gz
  else
    echoTextRed "替换$stock_ota_zip 中的apk或者jar制作专项软件"
    odex_system_file   $stock_ota_zip   $dex_bootjars_tar_gz
  fi
else
  if [ -n "$new_ota_zip" ]; then
    if [ -n "$ac_apk_file" ];then
      ac_apk_file=`get_file_dir $ac_apk_file`
      echoTextRed "将apk文件拆成odex"
      unzip_one_file $new_ota_zip  unzip_to
      uglyfish.sh --unpack-boot   -i unzip_to/boot.img -o unzip_to/unpack_boot
      dexpreopt_boot_jars=`get_dexpreopt_boot_jars  unzip_to/unpack_boot`
      if [ -f $dex_bootjars_tar_gz ];then
        unpack_tar_gz $dex_bootjars_tar_gz unzip_to/unpack_dex
        dex_bootjars_path=$PWD/unzip_to/unpack_dex
      fi
      apk_name=`basename $ac_apk_file`
      odex_one_file  $ac_apk_file  $dex_bootjars_path $dexpreopt_boot_jars
      rm -rf  unzip_to            
      #odex_one_file 
    elif [ -n "$ac_odex_file" ];then
      if [ "$ac_type" = "" ];then
        ac_type=apk
      fi
      ac_odex_file=`get_file_dir $ac_odex_file`
      echoTextRed "将odex合并成apk或者jar"
      unzip_one_file $new_ota_zip  unzip_to
      cd unzip_to/system/framework/
      deodex_one_file $ac_odex_file  $ac_type
      cd -
      rm -rf unzip_to
    fi
  else
    echoTextRed "未指定OTA包！"
  fi

fi
exit


cp -f "tmp_target_files.zip" $stockzip
echo "remove $tempdir"
rm -rf $tempdir
echo "deodex done. deodex zip: $stockzip"

