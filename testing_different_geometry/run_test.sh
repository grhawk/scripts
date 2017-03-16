#!/bin/bash

# Dir where script lives (pay attention: this do not work if the dir is a symlink)
DIR="$(dirname "${BASH_SOURCE[0]}")"
DIR_STRUCT="${DIR}/struct"
DIR_DRIVER_RUN="${DIR}/driver_run"
DIR_TEMPLATE="${DIR}/template"

DRIVER_TEMPLATE='dftb_in.geop'
DRIVER='DFTB'
CONCURRENCY=4


function main {
  local processes_running=0

  # clean dftbp_run
  rm -rf $DIR_DRIVER_RUN/*

  prepare_test

  # create driver input files
  echo "Preparing the test..."
  for f in $DIR_STRUCT/test*xyz; do
    prepare_input_driver $f
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
    *)
      >&2 echo "!E! Driver $DRIVER not implemented in the testing system."
      let ERR+=1
  esac

  if [[ $ERR -ne 0 ]]; then
    >&2 echo "!E! Preaparation failed!"
    exit $ERR
  fi
}

function prepare_input_driver {
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
      mv $gen_file $dir_test
      sed s/'pippopluto.struct'/${filename}.gen/g $DIR_TEMPLATE/$DRIVER_TEMPLATE > $dir_test/dftb_in.hsd
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

  cd $test_dir
  case $DRIVER in
    'DFTB' )
      if [[ ! -f 'dftb.out' ]]; then
        dftb+ &> dftb.out || let DRIVER_FAIL+=1
      fi
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
