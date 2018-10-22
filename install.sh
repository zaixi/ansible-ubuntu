#!/bin/bash

###################
# Install ansible #
install_ansible(){
	if ! grep -q "ansible/ansible" /etc/apt/sources.list /etc/apt/sources.list.d/*; then
		echo "Adding Ansible PPA"
		sudo apt-add-repository ppa:ansible/ansible -y
	fi

	if ! hash ansible >/dev/null 2>&1; then
		echo "Installing Ansible..."
		sudo apt-get update
		sudo apt-get install software-properties-common ansible git python-apt -y
	else
		echo "Ansible already installed"
	fi
}

#####################################
# Display real installation process #
show_use(){
	echo ""
	echo "Customize the playbook ansible-desktop.yml to suit your needs, then run ansible with :"
	echo "  ansible-playbook ansible-desktop.yml --ask-become-pass"
	echo "  ansible-playbook ansible-desktop-all.yml --ask-become-pass"
	echo
	echo "---------------------------------- or --------------------------------------"
	echo
	echo "  $0 all"
	echo "  $0 master"
	echo ""
}

get_password(){
	count=0
	while [ $count -le 2 ]; do
		IFS= read -r -p "[sudo] $USER 的密码:  " -s password
		echo ""
		sudo -k
		if printf "%s\n" "$password" | sudo -lS &> /dev/null
		then
			return
		else
			echo "对不起，请重试"
		fi
		count=$((count + 1))
	done
	echo "sudo: $count 次错误密码尝试"
	exit 1
}

install_while(){
	while [ 1 ]
	do
		ansible-playbook $1 --extra-vars "ansible_become_pass='$2'"
		if [ $? == 0 ];then
			exit
		else
			echo -----------------------------
			echo error
			echo -----------------------------
		fi
		sleep 2
	done
}

case $1 in
	"all")
		playbook="ansible-desktop-all.yml"
		;;
	"master")
		playbook="ansible-desktop.yml"
		;;
	*)
		show_use
		exit
		;;
esac

get_password
install_ansible
install_while "$playbook" "$password"
