#!/bin/bash
#功能函数
vendor_root=vendor/vivo
funcs=${vendor_root}/host/bin/functions.sh
if test ! -f $funcs; then
    funcs=`which functions.sh`
    if [ "$funcs" = "" ]; then
        echo "functions.sh not exist!!"
        return
    else
        #echo "funcs=$funcs"
	. $funcs
    fi
else
    #echo "funcs=$funcs"
    . $funcs  
fi
function sh_get_value_from_prop()
{
  local prop_file=$1
  local keyword=$2
  local result=
  if [ -n "$keyword" ]; then
    result=`cat $prop_file  | grep ${keyword}] | awk -F":" '{print $2}'|tr -d '[]'`
  fi
  echo "$result"
}

echoTextBlue "====> 获取系统属性......"
prop_file=/tmp/system.prop
update_info=/tmp/update.info
update_zip=/tmp/update.zip
sudo adb shell getprop > $prop_file
[ $? -ne 0 ] && echoTextRed "====> 操作设备出错!" && exit $?
dos2unix  $prop_file
project=`sh_get_value_from_prop $prop_file ro.product.model.bbk|tr -d ' '`
model=`sh_get_value_from_prop $prop_file ro.product.model`
version=`sh_get_value_from_prop $prop_file ro.build.version.bbk|tr -d ' '`
hversion=`sh_get_value_from_prop $prop_file ro.hardware.bbk|tr -d ' '`
custom=`sh_get_value_from_prop $prop_file ro.product.customize.bbk|tr -d ' '`
public_model1=`echo $model| awk '{print $1}'`
public_model2=`echo $model| awk '{print $2}'`
model=`echo $model|tr -d ' '`
if [ -n "$public_model2" ]; then
public_model="${public_model1}+${public_model2}"
else
public_model=${public_model1}
fi
elapsedtime=`date +%s`
cmd="http://sysupgrade.bbk.com/update/query?"
imei="865409018517935"
nversion=`echo ${version##*_}`
version=${model}_${hversion}_${nversion}
#非rom协议
post_data1="model=${model}&imei=$imei&version=$version&hboot=1.1.0&protocalversion=1.0"
if [ -n "$custom" ]; then
version=${project}_${custom}_${hversion}_${nversion}
else
version=${project}_${hversion}_${nversion}
fi
#rom协议
post_data2="model=${project}&imei=${imei}&version=${version}&hboot=1.1.0&protocalversion=1.0&flag=1&public_model=${public_model}&elapsedtime=${elapsedtime}"
#model=vivoS7&imei=865393010006727&version=vivoS7_PD1207WMA_2.0.5&hboot=1.1.0&protocalversion=1.0
#model=PD1225&imei=865407010000009&version=PD1225_N_PD1225MA_5.5.4&hboot=1.1.0&protocalversion=1.0
#&flag=1&public_model=vivo+Xplay&elapsedtime=61497863

echoTextBlue "====> 获取升级包信息......"
#"model={1}&imei={2}&version={3}&hboot={4}&protocalversion={5}&flag={6}&public_model={7}&elapsedtime={8}"
echoTextGreen "${cmd}${post_data1}"
echoTextGreen "${cmd}${post_data2}"
args="--no-verbose --append-output=wget.log"
echo "wget --post-data=\"$post_data1\" $args --output-document=$update_info $cmd"
wget --post-data="$post_data1" $args --output-document=$update_info $cmd
if [ -n "`cat $update_info |grep e -w`" ]; then
  echoTextRed "====> 使用老协议通信出错，尝试使用新协议......"
  echo "wget --post-data=\"$post_data2\" $args --output-document=$update_info $cmd"
  wget --post-data="$post_data2" $args --output-document=$update_info $cmd
fi
if [ -n "`cat $update_info |grep e -w`" ]; then
  echoTextRed "====> 获取版本信息出错!"
  exit
elif [ -n "`cat $update_info |grep n -w`" ]; then
  echoTextRed "====> 手机当前版本已经最新!"
  exit
else
  dos2unix  $update_info
  post_data=`cat $update_info | awk -F"\"DownloadURL\":" '{print $2}'|tr -d '"}'|awk -F'?' '{print $2}'`
fi
echoTextBlue "====> 开始下载软件包到 update.zip......"
cmd=`cat $update_info | awk -F"\"DownloadURL\":" '{print $2}'|tr -d '"}'|awk -F'?' '{print $1}'`?
download_url=`cat $update_info | awk -F"\"DownloadURL\":" '{print $2}'|tr -d '"}'|tr -d ' '`
update_file=`basename $download_url`
#echo "wget --post-data=\"$post_data\" --no-verbose --append-output=wget.log --output-document=$update_zip $cmd"
if [ -n "$post_data" ]; then
wget --post-data="$post_data" --output-document=$update_zip $cmd
fi
exit
#天天记录 - Android抓包 - 抓取HTTP，TCP协议数据 http://blog.csdn.net/androiddevelop/article/details/8150567  
#使用 tcpdump 抓取数据,通过 wireshark 分析 sudo apt-get install wireshark
# adb push tcpdump /system/bin/tcpdump  
# adb shell chmod 6755 /system/bin/tcpdump  
#adb shell tcpdump -i any -p -s  0  -w /sdcard/capture.pcap 
