#!/usr/bin/env bash

awk -F',' '/banana/ { print $3 }' fruits.csv 