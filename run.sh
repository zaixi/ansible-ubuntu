#!/bin/bash

sudo date
while [ 1 ]
do
	ansible-playbook ansible-desktop.yml
	if [ $? == 0 ];then
		exit
	else
		echo -----------------------------
		echo error
		echo -----------------------------
	fi
	sleep 2
done
