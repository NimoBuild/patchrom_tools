#!/bin/bash

function sh_get_cert_serial_number()
{
  local ac_zip_file=$1
  local ac_cert_serial_number=
  # -inform arg  输入格式 DER or PEM
  # -serial 输出  serial=FA7D5A103E600178 格式
  # -noout 不输出结果
  if [ -n "$ac_zip_file" ]; then
    if [ -z "`file  $ac_zip_file |grep  -i -P \"zip|archive\"`" ]; then
      echo "Error not zip file" >&2
      exit -2
    else
      ac_cert_serial_number=$(unzip -p $ac_zip_file META-INF/*.RSA | openssl pkcs7 -inform DER -print_certs | openssl x509 -noout -serial)
      ac_cert_serial_number=`echo $ac_cert_serial_number | awk -F"=" '{print $2}'|tr -d ' '`
    fi
  fi
  echo "$ac_cert_serial_number"
}

function sh_get_cert_class()
{
  local  ac_cert=PRESIGNED
  local  ac_keyword=$1
  local  result=PRESIGNED
  if [ "$ac_keyword" = "FA7D5A103E600178" ]; then
    result=test
  elif [ "$ac_keyword" = "8B2CAE75C49B2161" ]; then
    result=shared
  elif [ "$ac_keyword" = "B153730D8A352539" ]; then
    result=platform
  elif [ "$ac_keyword" = "B9B348555D6B7561" ]; then
    result=media
  fi
  echo "$result"
}


if [ -z $1 ]
then
   echo "usage: $0 <apks_dir>"
   exit 1
fi

if test -d $1; then
files_list="`find.sh -d $1 -t "apk"`"
for f in $files_list
do
  ac_cert_sn=`sh_get_cert_serial_number $f`
  ac_cert_class=`sh_get_cert_class $ac_cert_sn`
  echo "$ac_cert_sn $ac_cert_class $f"
done
else
  ac_cert_sn=`sh_get_cert_serial_number $1`
  if [ $? != 0 ] ; then
     exit -2
  fi
  ac_cert_class=`sh_get_cert_class $ac_cert_sn`
  echo "$ac_cert_sn $ac_cert_class $1"
fi
