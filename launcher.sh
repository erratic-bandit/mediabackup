#!/bin/bash
echo "Running MediaBackup, will run until stopped or an error occurs..."
while ./mediabackup.sh; do :; done