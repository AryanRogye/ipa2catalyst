#!/bin/bash

log stream --level debug --predicate 'process == "amfid" || message contains "amfi"'
