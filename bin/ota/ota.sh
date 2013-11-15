ac_test=true
if [ "$ac_test" = "true" ]; then
ac_dir=
ota_tool=build/tools/releasetools/ota_from_target_files
host_linux_dir=tools/bin/
signature=build/target/product/security/testkey
else
ac_dir=/home/mhf/workspace/gphone/dailybuild/APQ8064_jb_rel-A8064AAAAANLYA161032-sdk
ota_tool=$ac_dir/build/tools/releasetools/ota_from_target_files
host_linux_dir=$ac_dir/out/host/linux-x86/bin
signature=$ac_dir/build/target/product/security/testkey
fi
function gen_update_patchzip()
{
	local zipfrom="$1"
	local zipto="$2"
	local target="$3"
	mkdir -p `dirname $target`
	echo "$ota_tool -i $zipfrom -p $host_linux_dir -k $signature $zipto $target"
	$ota_tool -i $zipfrom -p $host_linux_dir -k $signature $zipto $target
}
ac_zipfrom=/opt/workspace/gphone/dailybuild/MT6582_ALPS.JB2.MP.V1_W_20130219/out/target/product/bbk89_we_jb2/obj/PACKAGING/target_files_intermediates/bbk89_we_jb2-target_files-eng.mhf.zip
ac_zipto=/opt/workspace/gphone/dailybuild/MT6582_ALPS.JB2.MP.V1_W_20130219/bbk89_we_jb2-target_files-eng.mhf_new.zip
ac_update=/tmp/update.zip
gen_update_patchzip $ac_zipfrom $ac_zipto $ac_update


