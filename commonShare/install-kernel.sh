#!/bin/bash

# stolen from
# https://gist.github.com/smoser/4d6371b9e3823b88a65c84ff40d1fd88

msg() { echo "$@" 1>&2; }
error() { echo "$@" 1>&2; }
fail() { [ $# -eq 0 ] || msg "$@"; exit 1; }
Usage() {
    cat <<EOF
Usage: ${0##*/} [options] [kernel]

   call grub-reboot or grub-set-default to boot the provided kernel.

   options:
      -n | --dry-run      do not make changes, only report what would be done.
           --setup-only   only setup 'saved' in /etc/default/grub.
                          do not supply kernel with --setup-only.
           --default      run 'grub-set-default' rather than 'grub-reboot'

   Examples:
     * boot kernel /boot/vmlinuz-4.13.0-17-generic next time.
       ${0##*/} /boot/vmlinuz-4.13.0-17-generic

     * edit /etc/default/grub to enable 'saved'
       ${0##*/} --setup-only
EOF
}


find_kernel() {
    local kernel_in="$1" kernel=""
    if [ -f "$kernel_in" ]; then
        kernel=${kernel_in}
    elif [ -f "/boot/$kernel_in" ]; then
        kernel="/boot/${kernel_in}"
    else
        kmatch="$kernel_in"
        if [ "${kmatch#*/}" = "$kmatch" ]; then
            kmatch="/boot/vmlinu?-${kmatch#vmlinu?-}*"
        else
            kmatch="/boot/$kmatch"
        fi
        for f in $kmatch; do
            if [ -f "$f" ]; then
                if [ -n "$kernel" ]; then
                    error "multiple kernels match $kmatch"
                    return 1
                fi
                kernel="$f"
            fi
        done
    fi
    [ -f "$kernel" ] || {
        error "did not find kernel matching '$kernel_in'";
        return 1;
    }
    echo "$kernel"
}

read_value() {
    local gdef="" fname="$1"
    gdef=$(sh -ec '
        fail() { ret=$1; shift; echo "$@" 1>&2; exit $ret; }
        fname=$1
        . "$fname" || fail $? "failed source $fname"
        for i in /etc/default/grub.d/*.cfg; do
            [ -f "$i" ] || continue
            . "$i" || fail $? "failed source $i"
        done
        echo $GRUB_DEFAULT' -- "$fname") || {
            error "Failed to read '$var' setting";
            return 1;
        }
    _RET="$gdef"
}

setup_grub() {
    local dry_run="$1" gdef="" var="GRUB_DEFAULT"
    local grubfile="/etc/default/grub" modfile=""
    read_value "$grubfile" ||
        { error "failed reading value of GRUB_DEFAULT"; return 1; }
    gdef="$_RET"

    if [ "$gdef" = "saved" ]; then
        msg "GRUB_DEFAULT already set to 'saved'. no change necessary."
        return 0
    fi

    msg "changing GRUB_DEFAULT from $gdef to \"saved\" in $grubfile"
    modfile=$(mktemp "${TMPDIR:-/tmp/${0##*/}.XXXXXX}") ||
        { error "failed to make temp file"; return 1; }
    sed "s,^$var=.*,$var=saved," "$grubfile" > "$modfile" || {
        error "failed to edit $grubfile to a tempfile"
        rm -f "$modfile"
        return 1
    }

    read_value "$modfile" || {
        error "failed to read GRUB_DEFAULT from edited file";
        rm -f "$modfile"
        return 1
    }
    [ "$_RET" = "saved" ] || {
        error "change of GRUB_DEFAULT in $grubfile did not make a change."
        rm -f "$modfile"
        return 1
    }

    msg "apply change to $grubfile";
    diff -u "$grubfile" "$modfile" | sed 's,^,   ,g' 1>&2
    if [ "$dry_run" != "true" ]; then
        cp "$modfile" "$grubfile" || {
            error "failed to update $grubfile."
            rm -f "$modfile"
            return 1
        }
        rm "$modfile"
    fi

    msg execute: update-grub
    if [ "$dry_run" != "true" ]; then
        update-grub || {
            error "failed update-grub to apply $var=saved";
            return 1;
        }
    fi
}

get_entry() {
    local submenu="Advanced options for Ubuntu"
    local prefix="Ubuntu, with Linux "
    # VER-FLAV like '3.13.0-79-generic'
    local kernel="$1" verflav=""

    # /boot/vmlinuz-VER-FLAV -> vmlinuz-VER-FLAV
    verflav=${kernel##*/}
    # vmlinuz-VER-FLAV - VER-FLAV
    verflav=${verflav#*-}

    entry="${submenu:+${submenu}}>${prefix}$verflav"
    if ! grep -q "$prefix$verflav" "/boot/grub/grub.cfg"; then
        error "no $prefix$verflav entry in /boot/grub/grub.cfg"
        return 1
    fi
    echo "$entry"
}

main() {
	local short_opts="hn"
	local long_opts="help,default,dry-run,setup-only"
	local getopt_out=""
	getopt_out=$(getopt --name "${0##*/}" \
		--options "${short_opts}" --long "${long_opts}" -- "$@") &&
		eval set -- "${getopt_out}" ||
		{ Usage 1>&2; return; }

	## <<insert default variables here>>
    local dry_run=false setup_only=false mode="reboot"
	local cur="" next="" kernel="" kernel_in=""
	while [ $# -ne 0 ]; do
		cur="$1"; next="$2";
		case "$cur" in
			-h|--help) Usage ; exit 0;;
			   --default) mode="set-default";;
			-n|--dry-run) dry_run=true;;
			   --setup-only) setup_only=true;;
			--) shift; break;;
		esac
		shift;
	done

    if [ "$setup_only" = "true" ]; then
        [ $# -eq 0 ] || {
            Usage 1>&2; echo "got $# args, expected 0 for setup-only"
            return 1;
        }
    else
        [ $# -eq 1 ] || {
            Usage 1>&2; echo "got $# args, expected 1. must provide kernel."
            return 1;
        }
        if [ "$setup_only" = "false" ]; then
            kernel_in="$1"
            kernel=$(find_kernel "${kernel_in}") || return
        fi
    fi

    setup_grub "$dry_run" || return
    if [ "$setup_only" = "true" ]; then
        return
    fi

    entry=$(get_entry "$kernel") || fail
    msg "selected $kernel. entry: ${entry}"

    cmd="grub-$mode"

    msg "execute: $cmd \"$entry\""
    if [ "$dry_run" != "true" ]; then
        "$cmd" "$entry" || {
            error "failed: $cmd \"$entry\""
            return 1
        }
    fi
    return 0
}

set -e

POSITIONAL=()
DEBUG=0
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -d | --debug)
    DEBUG=1
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done

apt update

version=${POSITIONAL[0]}
echo "Installing version ${version}"
echo "DEBUG is ${DEBUG}"

apt install -y linux-headers-${version}-generic linux-image-${version}-generic

if [ "$DEBUG" -eq "1" ]
then 
   apt install linux-image-${version}-generic-dbgsym;
fi


main --default /boot/vmlinuz-${version}-generic
