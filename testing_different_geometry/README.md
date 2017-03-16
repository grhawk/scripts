Structure Tester
================

Provide a script that given a template and a number of structure will
automatically run all the necessary computation to get the results for
each of the structure.

All the computation are ran in different directory to allow
cuncurrency.

How to use it
-------------
Put the template file into the `template` directory. Open the
`run_script.sh` file and modify the header variables to perform the
computation you want. Up to now, it only can use `dftb+` as a driver.

How to implement a new driver
-----------------------------
The script `run_test.sh` is based on few functions:

    - prepare_test
    - prepare_input
    - run_driver

Each of the function contains a `case` where the driver can be
choosen. To use different driver it is enoug to implement a new set of
instrction in each of the given function.
