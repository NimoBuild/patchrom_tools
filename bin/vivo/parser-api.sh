#!/bin/bash

current_project_path=`pwd`
vendor_vivo_path=$current_project_path"/vendor/vivo"
database_name=
platform_name="4_2_apq8064"
version_number="XXXXX"




check_path="-f $current_project_path/frameworks/base/core -f  $current_project_path/frameworks/base/graphics -f  $current_project_path/frameworks/base/media -f $current_project_path/frameworks/base/policy -f $current_project_path/frameworks/base/services -f $current_project_path/frameworks/base/telephony -f $current_project_path/vendor/vivo/source/common/frameworks-ext "

java -Xmx1024m -jar parser-android-api.jar -c $current_project_path $check_path -p $platform_name -r $version_number  -drop   -showsourcefile

