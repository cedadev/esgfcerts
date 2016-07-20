#!/bin/bash

#
# we have inputs: 
#                 allca.tgz from Nicolas
#
#                 certificate 09184877.0 to replace existing 993715d8.0
#                 and associated signing policy file
#                 (the hash has changed because the subject name changed slightly)
#
#                 439ce3f7.0 to replace existing 439ce3f7.0
#                 (the hash has not changed)
#
# The script will create:
#
#   - One tarball in which we *add* existing certs without removing the old one.  This is useful
#     during an overlap period.  In this tarball, where there is a clash of certificates with the 
#     same hash, we use the ".1" suffix for the new one.
#
#   - Another tarball in which we *remove* existing certs and replace with the new ones.  Useful 
#     later, after overlap period.
#  


base=/home/iwi/Desktop/cert   # <==== CHANGE THIS TO POINT TO FULL PATH OF DIRECTORY CONTAINING THE SCRIPT
indir=$base/inputs
outdir_add=$base/new-with-add
outdir_replace=$base/new-with-replace

bigtar=allca.tgz
cdir=esg_trusted_certificates
pass=changeit
tstore=esg-truststore.ts
bundle=esgf-ca-bundle.crt

prep()
{
    dir=$1

    rm -fr $dir
    mkdir $dir
    (
	cd $dir
	tar xfz $indir/$bigtar
	tar xf $cdir.tar
	rm $cdir.tar
	rm $bundle
	rm *.md5
    )
}

add_file()
{
    dir=$1
    name=$2
    orig_name=$3  # OPTIONAL

    [ -z $orig_name ] && orig_name=$name
    cp -v $indir/$orig_name $dir/$cdir/$name
}

del_file()
{
    dir=$1
    name=$2

    rm -v $dir/$cdir/$name
}

add_cert()
{
    dir=$1
    name=$2
    orig_name=$3  # OPTIONAL

    add_file $dir $name $orig_name
    alias=${name/\.0/}  # strip .0 but preserve .1
    tmpname=$name.dsr
    (
	cd $dir
	echo adding key $name as alias $alias in $dir
	openssl x509 -in $cdir/$name -outform DRS -out $tmpname
	keytool -import -noprompt -keystore $tstore -storepass $pass -alias $alias -file $tmpname
	rm $tmpname
    )
}

del_cert()
{
    dir=$1
    name=$2

    del_file $dir $name
    alias=${name/\.0/}
    (
	cd $dir
	echo removing key $alias in $dir
	keytool -delete -noprompt -keystore $tstore -storepass $pass -alias $alias
    )
}

package()
{
    dir=$1
    tarname=$2

    (
	cd $dir
	chmod -R g-w .
	tar cf $cdir.tar $cdir

        # concatenate certs - some of which may lack final newline
	for cert in $cdir/*.[0-9]*
	do
	    echo $cert
	    cat $cert
	    echo
	done | egrep . > $bundle

	files=""
	for f in $cdir.tar $tstore $bundle
	do
	    md5sum $f > $f.md5
	    files="$files $f $f.md5"
	done
	chmod g-w $files
	tar cfz $base/$tarname $files

	echo packaged $dir as $tarname
    )
}

prep $outdir_add
add_cert $outdir_add 439ce3f7.1 439ce3f7.0
add_cert $outdir_add 09184877.0
add_file $outdir_add 09184877.signing_policy
package $outdir_add allca-with-new-ceda-added.tgz

echo

prep $outdir_replace
del_cert $outdir_replace 439ce3f7.0
del_cert $outdir_replace 993715d8.0
del_file $outdir_replace 993715d8.signing_policy
add_cert $outdir_replace 439ce3f7.0
add_cert $outdir_replace 09184877.0
add_file $outdir_replace 09184877.signing_policy
package $outdir_replace allca-with-ceda-replaced.tgz
