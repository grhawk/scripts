#!/bin/bash

# Dir where script lives (pay attention: this do not work if the dir is a symlink)
DIR="$(dirname "${BASH_SOURCE[0]}")"
DIR_STRUCT="${DIR}/struct"
DIR_DRIVER_RUN="${DIR}/driver_run"
DIR_TEMPLATE="${DIR}/template"
DIR_SCRIPTS="$HOME/Codes/scripts/"

DRIVER_TEMPLATE='dftb_in.ipi'
DRIVER='IPI'                 # Available: IPI, DFTB
IPI_DRIVER='DFTB'            # IPI always need another driver (that must be available here)
IPI_TEMPLATE='ipi-geop.xml.template' # When using i-pi you need also a driver!

CONCURRENCY=1                  # With i-pi always concurrency 1! (Only one regtest at time!)

function main {
  local processes_running=0

  # clean dftbp_run
  rm -rf $DIR_DRIVER_RUN/*

  prepare_test

  # create driver input files
  echo "Preparing the test..."
  for f in $DIR_STRUCT/test*xyz; do
    prepare_input $f
    exit
  done
  echo "...Done"

  # run the driver only
  echo "Running computation for the driver only..."
  for f in $DIR_DRIVER_RUN/*test; do
    echo " * Running: $f"
    run_driver $f &
    let processes_running+=1
    if [[ $processes_running -eq $CONCURRENCY ]]; then
      wait
      processes_running=0
    fi
  done
  echo
  echo "...Finished"

}

function prepare_test {
  local ERR=0

  case $DRIVER in
    'DFTB')
      which xyz2gen &> /dev/null || let ERR+=1
      which dftb+ &> /dev/null || let ERR+=1
      ;;
    'IPI')
      # Since i-pi needs a driver, rerun this function with a different driver:
      local actual_driver=$DRIVER
      DRIVER=$IPI_DRIVER
      prepare_test
      DRIVER=$actual_driver

      # test if i-pi and i-pi-test are around
      which i-pi &> /dev/null || let ERR+=1
      which i-pi-regtest &> /dev/null || let ERR+=1
      ;;
    *)
      >&2 echo "!E! Driver $DRIVER not implemented in the testing system."
      let ERR+=1
  esac

  if [[ $ERR -ne 0 ]]; then
    >&2 echo "!E! Preaparation failed!"
    exit $ERR
  fi
}

function prepare_input {
  # Create input files to be used only with the driver
  local ERR=0
  local xyz_file=$1
  local filename=`tmp=$(basename $xyz_file); echo ${tmp/.xyz/} ` # This is the file name without extension

  # Check if input file exist
  if [[ ! -f $xyz_file ]]; then
    >&2 echo "!E! File $xyz_file do not exist!"
    let ERR+=1
    exit $ERR
  fi

  # Create a dir named filename.test into the $DIR_DRIVER_RUN
  local dir_test=$DIR_DRIVER_RUN/${filename}.test
  mkdir -p $dir_test

  case $DRIVER in
    'DFTB' )
      gen_file=${xyz_file/.xyz/.gen}
      xyz2gen $xyz_file
      grep 'CELL' $xyz_file &>/dev/null && $DIR_SCRIPTS/cellerize_genfile/cellerize.py $xyz_file $gen_file
      mv $gen_file $dir_test
      sed s/'pippopluto.genstruct'/${filename}.gen/g $DIR_TEMPLATE/$DRIVER_TEMPLATE > $dir_test/dftb_in.hsd
      ;;

    'IPI' )
      # Since i-pi needs a driver, rerun this function with a different driver:
      local actual_driver=$DRIVER
      DRIVER=$IPI_DRIVER
      prepare_input $xyz_file
      DRIVER=$actual_driver

      # Prepare input for i-pi
      cp $xyz_file $dir_test
      sed s/'pippopluto.struct'/${filename}.xyz/g $DIR_TEMPLATE/$IPI_TEMPLATE > $dir_test/ipi.xml
      [[ "$IPI_DRIVER" == "DFTB" ]] &&  sed -i s/'pippopluto.genstruct'/${filename}.gen/g $dir_test/ipi.xml
      ;;
    * )
      >&2 echo "!E! Driver $DRIVER not implemented in the prepare_input_driver function."
      let ERR+=1
  esac

  if [[ $ERR -ne 0 ]]; then
    >&2 echo "!E!  prepare_input_driver failed!"
    exit $ERR
  fi

  }

function run_driver {
  # Run the driver
  local ERR=0
  local DRIVER_FAIL=0
  local test_dir=$1
  local actual_path=${PWD}

  cd $test_dir                  # Move to the folder containing the test
  case $DRIVER in
    'DFTB' )
      if [[ ! -f 'dftb.out' ]]; then
        dftb+ &> dftb.out || let DRIVER_FAIL+=1
      fi
      ;;

    'IPI' )
      cd $actual_path           # i-PI must be ran in the =root= folder
      i-pi-regtest --create-reference --folder-run=$DIR/"IPI-REGTESTS" --tests-folder=$DIR_DRIVER_RUN
      # i-pi-regtest will take care of everything. do not run more than 1!
      wait
      exit $?
      ;;

    * )
      >&2 echo "!E! Driver $DRIVER not implemented in the run_driver_only function."
      let ERR+=1
  esac

  cd $actual_path
  if [[ $DRIVER_FAIL -ne 0 ]]; then
    >&2 echo "Driver fail for test " $(basename $testdir)
  fi
  if [[ $ERR -ne 0 ]]; then
    >&2 echo "!E!  prepare_input_driver failed!"
    exit $ERR
  fi
}

main
