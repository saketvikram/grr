#!/bin/bash
#
# Script to install pmem memory drivers into GRR.
#
# By default this will use keys in /etc/grr/keys and install into /usr/share/grr
# Note that this will prompt you for passphrases if you have protected your
# signing keys.
#
#

PREFIX="/usr"

PMEM_URL="https://grr.googlecode.com/files/pmem.zip"

CONFIG_UPDATER="${PREFIX}/bin/grr_config_updater.py"

# Variable to store if the user has answered "Yes to All"
ALL_YES=0;


function header()
{
  echo ""
  echo "##########################################################################################"
  echo "     ${*}";
  echo "##########################################################################################"
}

function run_header() { echo "#### Running #### ${*}"; }

function exit_fail() {
  FAIL=$*;
  echo "#########################################################################################";
  echo "FAILURE RUNNING: ${FAIL}";
  echo "#########################################################################################";
  exit 0
};


function run_cmd_confirm()
{
  CMD=$*;
  if [ ${ALL_YES} = 0 ]; then
    echo ""
    read -p "Run ${CMD} [Y/n/a]? " REPLY
    case $REPLY in
      y|Y|'') run_header ${CMD};;
      a|A) echo "Answering yes from now on"; ALL_YES=1;;
      *) return ;;
    esac
  fi
  ${CMD};
  RETVAL=$?
  if [ $RETVAL -ne 0 ]; then
    exit_fail $CMD;
  fi
};


header "Downloading pmem driver archive"
run_cmd_confirm wget --no-verbose -N ${PMEM_URL};
PMEM=$(basename ${PMEM_URL});
run_cmd_confirm unzip -o ${PMEM};
PMEM_OUT="./pmem";

header "Sign and upload OSX pmem driver"
OSX_PMEM="${PMEM_OUT}/OSXPMem.tar.gz";
UNPACKED=$(echo ${OSX_PMEM} | cut -d "." -f -3);

# Hack to remove unecessary files from gzip before we sign them.
# OSX wants tar.gz of directory with just kext dir in it.
run_cmd_confirm gunzip -f ${OSX_PMEM};
run_cmd_confirm tar --delete OSXPMem/osxpmem -f ${UNPACKED};
run_cmd_confirm tar --delete OSXPMem/README -f ${UNPACKED};
run_cmd_confirm gzip ${UNPACKED};
CMD="${CONFIG_UPDATER} --action=BOTH --file=${OSX_PMEM} --type=DRIVER --install_driver_name=pmem --install_device_path=/dev/pmem --install_rewrite_mode=FORCE --signing_key=/etc/grr/keys/driver_sign.pem --verification_key=/etc/grr/keys/driver_sign_pub.pem --platform=OSX --upload_name=pmem --aff4_path=/config/drivers/osx/memory";
run_cmd_confirm ${CMD};

header "Sign and upload Windows pmem drivers (32 & 64 bit)"

CMD="${CONFIG_UPDATER} --action=BOTH --file=${PMEM_OUT}/winpmem_32.sys --type=DRIVER --install_driver_name=pmem --install_device_path=\\\\.\\pmem --install_rewrite_mode=FORCE --signing_key=/etc/grr/keys/driver_sign.pem --verification_key=/etc/grr/keys/driver_sign_pub.pem --platform=WINDOWS --upload_name=winpmem.32.sys --aff4_path=/config/drivers/windows/memory";
run_cmd_confirm ${CMD};

CMD="${CONFIG_UPDATER} --action=BOTH --file=${PMEM_OUT}/winpmem_64.sys --type=DRIVER --install_driver_name=pmem --install_device_path=\\\\.\\pmem --install_rewrite_mode=FORCE --signing_key=/etc/grr/keys/driver_sign.pem --verification_key=/etc/grr/keys/driver_sign_pub.pem --platform=WINDOWS --upload_name=winpmem.64.sys --aff4_path=/config/drivers/windows/memory";
run_cmd_confirm ${CMD};

rm -rf ${PMEM_OUT} ${PMEM};

echo "############################################################################################"
echo "Driver install complete."
echo "If this worked you should now see them under Manage Binaries in the Admin UI."
echo "############################################################################################"
