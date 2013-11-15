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


#============================
mtk_hdr_len=512
mtk_boot_tag=ROOTFS
mtk_recovery_tag=RECOVERY
mtk_img_tag=
is_mtk_img=false
g_result=false
HOST_OUT_EXECUTABLES=out/host/linux-x86/bin
def_MKBOOTFS=$HOST_OUT_EXECUTABLES/mkbootfs
def_MINIGZIP=$HOST_OUT_EXECUTABLES/minigzip 
def_MKBOOTIMG=$HOST_OUT_EXECUTABLES/mkbootimg
def_MKIMAGE=mediatek/build/tools/mkimage
def_CHECK_TARGET_FILES_SIGNATURES=build/tools/releasetools/check_target_files_signatures
def_IMG_FROM_TARGET_FILES=build/tools/releasetools/img_from_target_files
def_OTA_FROM_TARGET_FILES=build/tools/releasetools/ota_from_target_files
def_SIGN_TARGET_FILES_APKS=build/tools/releasetools/sign_target_files_apks

tools_com="
adb
java
mkbootfs
minigzip
mkbootimg
"
tools_mtk="	
mkimage									
"
tools_qcom="
mkbootimg"
tools_rom="
apktool
apktool.jar
baksmali
baksmali.jar
build_libra.sh
signapk.jar
smali
smali.jar
dex2jar.sh
jd-gui
unpackbootimg
"

#out/host/linux-x86/framework/signapk.jar
#imgdiff zipalign mkbootfs minigzip mkbootimg unzip openssl 
tools_ota="
check_target_files_signatures
img_from_target_files
ota_from_target_files
sign_target_files_apks
imgdiff
"
files_not_exist=
function repack_boot()
{
  echoTextBlue "boot repacking ......"
}

function repack_ramdisk()
{
  echoTextBlue "ramdisk repacking ......"
}

function echoTextRedEx()
{
  local ac_id="$1"
  local ac_str=
  ac_str="`sh_get_display_str_by_id $ac_id`"
  echoTextRed "$ac_str"
}


function unpack_ramdisk()
{
  echoTextBlue "ramdisk unpacking ......"
  local input=$1
  local tmp_input=`mktemp -p $PWD tempfile.XXX`
  local tmp_ramdisk=`mktemp -p $PWD tempfile.XXX`
  local output=$2
  local tag=
  local ac_cmds="hexmodify.shc gzip"
  #检测需要的工具
  result=`sh_cmds_not_exist $ac_cmds`
  if [ -n "$result" ]; then
    echoTextRedEx "请确保存在以下工具: $result" "Please ensure  the following tools: $result"
    return 2
  fi
  echoTextGreen "input=$input output=$output"
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定要处理的文件和输出目录!!"
    usage
    return;
  fi
  if test ! -d $output; then
    mkdir -pv $output
  fi
  cp $input $tmp_input
  tag="`hexmodify.shc -s 8 -n 8 -i $tmp_input`"
  tag="`sh_HexToCh "$tag"`"
  cd $output
  if [ "$tag" = "ROOTFS" ] || [ "$tag" = "RECOVERY" ]; then
    mtk_tag=true
    mtk_img_tag=$tag
    dd if=$tmp_input  bs=$mtk_hdr_len skip=1 of=$tmp_ramdisk
    cp $tmp_ramdisk $tmp_input -rf
  fi 
  tag=1f8b08
  echo "hexmodify.shc -s 0 -n 4 -i $tmp_input | tr -d ' ' | grep $tag"
  tag=`hexmodify.shc -s 0 -n 4 -i $tmp_input | tr -d ' ' | grep $tag`
  if [ -z "$tag" ]; then
    echoTextRed "$input 格式有误，不具备 ramdisk 文件特性!!"
    rm -rvf $tmp_input $tmp_ramdisk
    return 2
  else
    gzip -dc $tmp_input | cpio -i
  fi
  rm -rvf $tmp_input $tmp_ramdisk
  cd -
}

function unpack_boot()
{
  echoTextBlue "boot unpacking ......"
  local input=$1
  local output=$2
  local ac_cmds="unpackbootimg"
  local tag=
  local tmp_name=
  local result=
  #检测需要的工具
  result=`sh_cmds_not_exist $ac_cmds`
  if [ -n "$result" ]; then
    echoTextRedEx "请确保存在以下工具: $result" "Please ensure  the following tools: $result"
    return 2
  fi
  echo "input=$input output=$output"
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRedEx "指定要处理的文件和输出目录!!" "Please give input file and output dir!!"
    usage
    return 2
  fi
  tmp_name=`basename $input`
  if [ -n "$input" ] && test -f $input; then
    rm -rf $output
    if test ! -d $output; then
      mkdir $output -pv
    else
    result=`question "目录 $output 已经存在,是否覆盖？" 1 yes` 
      if [  "$result" = "no" ] ; then
        return 2
      fi
    fi
    #解压缩boot.img
    unpackbootimg -i $input -o $output/
    [ $? -ne 0 ] && rm -rvf $output && return $?
    #解压缩ramdisk.gz
    unpack_ramdisk $output/${tmp_name}-ramdisk.gz  $output/ramdisk 
    [ $? -ne 0 ] && rm -rvf $output && exit $?
  else
     echo "$img not exist!!"
     return 2
  fi
  return 0
}


function modify_boot()
{
  local input=$1
  local output=$2
  local ARGS=
  local tmp_name=`basename $input`
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  local ac_cmds="mkbootimg mkimage mkbootfs minigzip"
  #检测需要的工具
  result=`sh_cmds_not_exist $ac_cmds`
  if [ -n "$result" ]; then
    echoTextRedEx "请确保存在以下工具: $result" "Please ensure  the following tools: $result"
    return 2
  fi
  MKBOOTIMG=`which mkbootimg`
  MKIMAGE=`which mkimage`
  MKBOOTFS=`which mkbootfs`
  MINIGZIP=`which minigzip`

  #解压缩boot.img
  unpack_boot $input ${input}_tmp
  [ $? -ne 0 ] && rm -rvf ${input}_tmp  && return $?
  result=`question "解压缩处理完成，到 ${input}_tmp/ramdisk/ 目录对文件系统进行修改，修改完成 yes ，否则 no" 1 yes`
  if [ "$result" = "no" ]; then return; fi
  if [ "$is_mtk_img" = "false" ]; then
    result=`question "是否为mtk镜像？" 1 yes` 
    if [ "$result" = "yes" ]; then
      is_mtk_img=true
    fi
  fi
  ROOT_OUT=${input}_tmp/ramdisk
  RAMDISK_TMP=${input}_tmp/ramdisk_tmp.img
  RAMDISK=${input}_tmp/ramdisk.img
  KERNEL=${input}_tmp/${tmp_name}-zImage
  pwd
  BASE=`cat ${input}_tmp/${tmp_name}-base`
  CMDLINE=`cat ${input}_tmp/${tmp_name}-cmdline`
  PAGESIZE=`cat ${input}_tmp/${tmp_name}-pagesize`
  BOARD=1346662297
  if [ -n "$BASE" ]; then BASE="--base $BASE"; fi
  if [ -n "$PAGESIZE" ]; then PAGESIZE="--pagesize $PAGESIZE"; fi
  if [ -n "$BOARD" ]; then BOARD="--board $BOARD"; fi
  ARGS="$BASE $PAGESIZE  $BOARD"
  echo PATH=$PATH
  echo "MKBOOTIMG=$MKBOOTIMG MKBOOTFS=$MKBOOTFS"
  if [  "$is_mtk_img" = "true" ] ; then
    echoTextBlue "
    $MKBOOTFS $ROOT_OUT | $MINIGZIP > ${RAMDISK}
    $MKIMAGE  $RAMDISK $mtk_img_tag >$RAMDISK_TMP
    mv $RAMDISK_TMP $RAMDISK"
    $MKBOOTFS $ROOT_OUT | $MINIGZIP > ${RAMDISK}
    $MKIMAGE  $RAMDISK $mtk_img_tag >$RAMDISK_TMP
    mv $RAMDISK_TMP $RAMDISK
  else
    echoTextBlue "
    $MKBOOTFS $ROOT_OUT | $MINIGZIP > ${RAMDISK}"
    $MKBOOTFS $ROOT_OUT | $MINIGZIP > ${RAMDISK}
  fi
  echoText ">>-----重新生成 boot.img-----<<" GREEN
  echo "$MKBOOTIMG  --kernel $KERNEL --ramdisk $RAMDISK  $ARGS --cmdline \"$CMDLINE\" --output $output"
  $MKBOOTIMG  --kernel $KERNEL --ramdisk $RAMDISK  $ARGS --cmdline "$CMDLINE" --output $output
}

function create_update_zip()
{
  local  system_pull=$1
  local  files_list=
  local  file_size=
  local  box_size=
  if [ -z "$system_pull" ]; then
    system_pull=/tmp/system-pull
    rm -rvf $system_pull
    mkdir -pv $system_pull
    sudo adb pull /system $system_pull
    sudo chown -R $USER.$USER $system_pull
  fi
  #cd $system_pull
  #system_pull=`pwd`
  #cd
  echo system_pull=$system_pull
  cd $system_pull
  for box in `find.sh -d $system_pull |grep -E "busybox|toolbox"`
  do
    files_list="`find.sh -d $system_pull`"
    box_size=`du -b $box|awk '{print $1}'`
    box_basename=`basename $box`
    result=`sh_menu_select "$menu_list"`
    eval "result=\$$result"

    for file in $files_list
    do
      file_size=`du -b $file|awk '{print $1}'`
      file_name=`basename $file`
      if [ "$file_size" = "$box_size" ] && [ "$box_basename" != "$file_name" ]; then
        aaa="$aaa $file"
      fi
    done
    if [ -n "$aaa" ]; then
      rm $aaa -rvf
    fi
  done
  cd -
}

function apktool_d()
{
  local input=$1
  local output=$2
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  $APKTOOL d -f $input $output
}
function apktool_b()
{
  local input=$1
  local output=$2
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  $APKTOOL b -f $input $output 
}

function  baksmali()
{
#java -jar baksmali.jar -o classout/ classes.dex
#java -jar smali/baksmali-1.2.6.jar -o $1/smali $1/classes.dex
  local input=$1
  local output=$2
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  $BAKSMALI $input -o $output
}

function  smali()
{
#java -jar smali.jar classout/ -o classes.dex 
  local input=$1
  local output=$2
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  $SMALI $input -o $output
}

function unzip_apk()
{
  local input=$1
  local output=$2 
  local apkzip=
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  rm $output -rf
  mkdir -pv $output
  apkzip=`basename $input`.zip
  if test -f $input; then   
    cp -rvf $input $output/$apkzip
  fi
  cd $output
  unzip $apkzip
  rm $apkzip
  cd -
}

function dex2jar()
{
  local input=$1
  local output=$2
  echo "DEX2JARSH=${DEX2JARSH}"
  unzip_apk $input $output
#  cp $DEX2JARSH $output -rf
#  cp `dirname $DEX2JARSH`/lib $output -rf
#  cd $output
  $DEX2JARSH $output/classes.dex 
#  cd -
}

function jdgui()
{
  #dex2jar.sh $dir/classes.dex
  #jd-gui $dir/classes.dex.dex2jar.jar &
  echo "JDGUI=$JDGUI"
  local input=$1
  local output=$2
  if [ -z "$input" ] || [ -z "$output" ]; then
    echoTextRed "指定输入输出文件!!"
    usage
    return 
  fi
  dex2jar $input $output
  $JDGUI $output/classes.dex.dex2jar.jar
}

function ota_icrs()
{
  local input="$1"
  local output=$2
  local target_old=
  local target_new=
  local key_dir=
  local host_bin=
  result=`sh_cmds_not_exist $tools_ota`
  if [ -n "$result" ]; then
    echoTextRed "确保 $result 存在!!......"
    return 
  fi
  target_old=`echo "$input"|awk '{print $1}'`
  target_new=`echo "$input"|awk '{print $2}'`
  echo "ota_from_target_files=$OTA_FROM_TARGET_FILES"
  echo "tools_dir=$tools_dir"
  if test -d build/target/product/security/; then
    key_dir=build/target/product/security
    host_bin=out/host/linux-x86/
  else
    key_dir=`dirname $OTA_FROM_TARGET_FILES`/../security
    host_bin=$tools_dir/linux-x86
  fi
  echo "key_dir=$key_dir"
  echo "$OTA_FROM_TARGET_FILES -k $key_dir/testkey -p $host_bin  -i $target_old $target_new $output"
  $OTA_FROM_TARGET_FILES -k $key_dir/testkey -p $host_bin  -i $target_old $target_new $output
  #$ota_tool -i $zipfrom -p $host_linux_dir -k $signature $zipto $target
  #cat build/core/version_defaults.mk |grep PLATFORM_VERSION -w |grep :=
}


function ota_full()
{
  local input="$1"
  local output=$2
  local target=
  local key_dir=
  local host_bin=
  result=`sh_cmds_not_exist $tools_ota`
  if [ -n "$result" ]; then
    echoTextRed "确保 $result 存在!!......"
    return 
  fi
  target=`echo "$input"|awk '{print $1}'`
  echo "ota_from_target_files=$OTA_FROM_TARGET_FILES"
  echo "tools_dir=$tools_dir"
  if test -d build/target/product/security/; then
    key_dir=build/target/product/security
    host_bin=out/host/linux-x86/
  else
    key_dir=`dirname $OTA_FROM_TARGET_FILES`/../security
    host_bin=$tools_dir/linux-x86
  fi
  echo "key_dir=$key_dir"
  echo "$OTA_FROM_TARGET_FILES -k $key_dir/testkey -p $host_bin $target $output"
  $OTA_FROM_TARGET_FILES -k $key_dir/testkey -p $host_bin $target $output
  #$ota_tool -i $zipfrom -p $host_linux_dir -k $signature $zipto $target
  #cat build/core/version_defaults.mk |grep PLATFORM_VERSION -w |grep :=
}

function init_update()
{
  local top_dir=$1
  mkdir -pv $top_dir/META-INF/com/google/android
  mkdir -pv $top_dir/META-INF/com/android
}
function ota_system()
{
  local input="$1"
  local output=$2
}
function ota_rom()
{
  local input="$1"
  local output=$2
}

function ota_phone()
{
  local input=/tmp/update-from-phone/system
  local output=$2
  local update_dir=$input/..
  sudo $ADB "wait-for-device"
  sudo $ADB shell id
  read -p "如果上面显示的id为0或者root，按任意键继续；否则按Ctrl-C取消，获取root权限后再尝试!"
  if test -d $input; then
    result=`question "目录 $input 已经存在,是否覆盖？" 1 yes` 
    if [  "$result" = "yes" ] ; then
       sudo $ADB pull /system $input
    fi
  else
    mkdir -pv $input
    sudo $ADB pull /system $input
  fi
  sudo chown -R $USER.$USER $input
  init_update $update_dir 
  echo "zip all in $update_dir ....."

  read -p "创建升级包,任意键继续,Ctrl-C取消!!"
  cd $update_dir  
  zip -r update-unsigned.zip .  
  cd -

cd ../update-from-phone/
zip -r update-unsigned.zip .  
cd -
SIGNAPKJAR=out/host/linux-x86/framework/signapk.jar
public_key=build/target/product/security/testkey.x509.pem
private_key=build/target/product/security/testkey.pk8
java -Xmx1536m -jar $SIGNAPKJAR -w $public_key  $private_key  ../update-from-phone/update-unsigned.zip  ../update.zip
  #rm $update_dir/update-unsigned.zip -rfv
}

function usage()
{
  local cmd=`basename $0`
echoTextGreen "使用说明:"
echoTextRed "$cmd --unpack-ramdisk -i ramdisk.gz/ramdisk.img  -o output 
$cmd --unpack-boot    -i boot.img                -o output 
$cmd --repack-ramdisk -i root_dir                -o output 
$cmd --repack-boot  --kernel kernel  --ramdisk ramdisk.img  -o output 
$cmd --modify-boot    -i boot_input.img          -o boot_output.img 
$cmd --apktool-d      -i ~/turbofly3d_1.apk      -o /tmp/turbofly3d_1
$cmd --apktool-b      -i /tmp/turbofly3d_1       -o /tmp/turbofly3d_1.apk
$cmd --baksmali       -i class.dex               -o classout
$cmd --smali          -i classout                -o class.dex
$cmd --dex2jar        -i ~/desktop/share/apks/GameCube.apk -o /tmp/gamegube
$cmd --jdgui          -i ~/desktop/share/apks/GameCube.apk -o /tmp/gamegube
$cmd --ota-icrs       -i \"target1 target2\"                 -o /update-icrs
$cmd --ota-full       -i \"target1 target2\"                 -o /update-icrs
$cmd --ota-out       -i  out/target/product/target_devices   -o /path/to/update.zip
$cmd --ota-rom       -i  /path/to/rom/file                   -o /path/to/update.zip
$cmd --ota-phone     -o  /path/to/update.zip
"
}

function extract_tools()
{
local sh_name=$1
tools_dir=/tmp/`basename $sh_name`
if test ! -d $tools_dir; then
  result=`sh_split_shc $sh_name`
  if [ -n "$result" ]; then
    mkdir -pv $tools_dir 
    tar -xf $result -C $tools_dir
  fi
fi
for d in `ls  ${tools_dir} -l | awk '/^d/{print $NF}'`
do
export PATH=${tools_dir}/${d}:$PATH
done
export PATH=${tools_dir}:$PATH
}
function reset_env()
{
  local name=$1
  echo "name=$1"
  
  if test ! -d frameworks; then
    echo "frameworks/frameworks/frameworks/"
    menu_list="`ls  $tools_dir/ota -l | awk '/^d/{print $NF}' | grep releasetools_`"
    echoTextBlue "Please select"
    result=`sh_menu_select2 "$menu_list"` 
  fi
  export PATH=$tools_dir/ota/$result:$PATH
}



input=
output=
#脚本入口
#参数预处理begin
script_name=$0
script_args=`getopt -a -o m:i:o:  -l modify-boot,unpack-boot,unpack-ramdisk,url:,help -- "$@"` 
[ $? -ne 0 ] && usage $script_name $@ && exit $?
if [ $# = 0 ]; then usage $script_name $@;exit $?; fi
eval set --"${script_args}"
#参数预处理
script_args=
while test $# != 0
do
  case $1 in
    --help)
      usage $script_name $@&&exit
      ;; 
    -m)
      shift
      mode=$1
      ;; 
    -i)
      shift
      input="$1"
      ;; 
    -o)
      shift
      output=$1
      ;; 
    --unpack-ramdisk)
      func=unpack_ramdisk
      ;;

    --unpack-boot)
      func=unpack_boot
      ;;
    --repack-ramdisk)
      func=repack_ramdisk
      ;;
    --repack-boot)
      func=repack_boot
      ;;
    --modify-boot)
      func=modify_boot
      ;;
    --update-zip)
      func=create_update_zip
      ;;
    --apktool-d)
      func=apktool_d
      ;;
    --apktool-b)
      func=apktool_b
      ;;
    --baksmali)
      func=baksmali
      ;;
    --smali)
      func=smali
      ;;
    --dex2jar)
      func=dex2jar
      ;;
    --jdgui)
      func=jdgui
      ;;
    --ota-icrs)
      reset_env $1
      func=ota_icrs
      ;;
    --ota-full)
      reset_env $1
      func=ota_full
      ;;	
    --ota-out)
      reset_env $1
      func=ota_out
      ;;	
    --ota-rom)
      reset_env $1
      func=ota_rom
      ;;	
    --ota-phone)
      reset_env $1
      func=ota_phone
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
if [ -z "$func" ]; then
  usage
  exit
fi

echoTextBlue "==> calling .... $func $input $output"
$func "$input" "$output"




