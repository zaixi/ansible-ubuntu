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
		sudo apt-get install software-properties-common ansible git python-apt -y --allow-unauthenticated
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

all_roles=()
err_roles=()

function get_all_roles(){
	IFS=$'\n'
	for line in `cat $1`
	do
		status=$(echo $line | awk -F'-' '/role:/ {if ($1 !~ /#/) {print "run"}}')

		if [[ ${status} =~ "run" ]]; then
			all_roles[${#all_roles[*]}]=$(echo $line)
		fi
	done
}

function get_err_roles(){
	IFS=$'\n'
	unset err_roles
	old_role=""
	for line in `cat $1`
	do
		role=$(echo $line | awk -F'[' '/TASK \[/ {print $2}' | awk '{print $1}')
		if [[ -n $role && $role != $old_role ]]; then
			old_role=$role
			err_roles[${#err_roles[*]}]=$(echo $role)
		fi
	done
	echo $old_role >> error.list
	rm $1 > /dev/null 2>&1
}

function del_ok_roles(){
	temp_role=""
	for(( j=0;j<${#err_roles[@]};j++ ))
	do
		for(( i=0;i<${#all_roles[@]};i++ ))
		do
			role=$(echo ${all_roles[i]} | awk -F: '{print $2}' | awk '{print $1}' |awk -F} '{print $1}')
			if [[ ${err_roles[j]} == $role ]]; then
				temp_role="${all_roles[i]}"
				all_roles=( "${all_roles[@]:0:i}" "${all_roles[@]:(i+1)}" )
				break
			fi
		done
    done
    #all_roles=("$temp_role" "${all_roles[@]}")
}

function run_role(){
    ret=1
	rm c.yml > /dev/null 2>&1
	rm ansible.log > /dev/null 2>&1
	cat template.yml > c.yml
	echo run_role
	for(( i=0;i<${#all_roles[@]};i++ ))
	do
		echo "${all_roles[i]}" >> c.yml
		echo "${all_roles[i]}"
	done
	ansible-playbook c.yml --extra-vars "ansible_become_pass='$1'"
	ret=$?
	rm c.yml
    return $ret
}

function run_roles(){
	get_all_roles $1
	rm error.list > /dev/null 2>&1
	while [ 1 ]
	do
		run_role $2
		if [ $? == 0 ];then
			unset all_roles
			break
		fi
		echo ---ok--------------------------------------------------------------------
		for(( i=0;i<${#all_roles[@]};i++ ))
		do
			echo "${all_roles[i]}"
		done
		echo --err---------------------------------------------------------------------
		get_err_roles ansible.log
		for(( i=0;i<${#err_roles[@]};i++ ))
		do
			echo "${err_roles[i]}"
		done
		del_ok_roles
		echo ---ok other----------------------------------------------------------------
		for(( i=0;i<${#all_roles[@]};i++ ))
		do
			echo "${all_roles[i]}"
		done
		sleep 5
	done
}

install_while(){
	while [ 1 ]
	do
		run_roles $1 $2
		echo ---start--------
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

install_ansible
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

case $2 in
	"ci")
		echo $2
		#sudo apt-get -y purge "mysql*"
		#sudo rm -rf /etc/mysql/ /var/lib/mysql
		sudo apt autoremove
		sudo apt autoreclean
		;;
	*)
		get_password
		;;
esac
install_while "$playbook" "$password"
