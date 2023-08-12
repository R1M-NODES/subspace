#!/bin/bash

source <(curl -s https://raw.githubusercontent.com/R1M-NODES/utils/master/common.sh)

printLogo

VERSION=$(echo 'BEGIN {
    while (!/flags/) if (getline < "/proc/cpuinfo" != 1) exit 1
    if (/lm/&&/cmov/&&/cx8/&&/fpu/&&/fxsr/&&/mmx/&&/syscall/&&/sse2/) level = 1
    if (level == 1 && /cx16/&&/lahf/&&/popcnt/&&/sse4_1/&&/sse4_2/&&/ssse3/) level = 2
    if (level == 2 && /avx/&&/avx2/&&/bmi1/&&/bmi2/&&/f16c/&&/fma/&&/abm/&&/movbe/&&/xsave/) level = 3
    if (level == 3 && /avx512f/&&/avx512bw/&&/avx512cd/&&/avx512dq/&&/avx512vl/) level = 4
    if (level > 0) { print level; exit level + 1 }
    exit 1
}' | awk -f -)

if [[ $VERSION -ne 2 && $VERSION -ne 3 ]]
  then
    printGreen "Our script doesn't support your processor"
    exit
fi

URL=https://github.com/subspace/subspace-cli/releases/download/v0.5.3-alpha-2/subspace-cli-ubuntu-x86_64-v2-v0.5.3-alpha-2
PS3='Enter your option: '
options=("Install node" "Update node")
selected="You choose the option"

function installNode {
  sudo apt update && sudo apt install curl ocl-icd-opencl-dev libopencl-clang-dev libgomp1 -y
  cd $HOME || return
  wget -O subspace-cli $URL
  sudo chmod +x subspace-cli
  sudo mv subspace-cli /usr/local/bin/
  sudo rm -rf $HOME/.config/subspace-cli

  echo "alias subspace-cli='/usr/local/bin/subspace-cli'" >> $HOME/.bashrc
  touch $HOME/.bash_profile && source $HOME/.bashrc && sleep 1

  subspace-cli init

  source $HOME/.bash_profile
  sleep 1

  sudo tee /etc/systemd/system/subspaced.service > /dev/null << EOF
  [Unit]
  Description=Subspace Node
  After=network-online.target
  [Service]
  User=$USER
  ExecStart=$(which subspace-cli) farm --verbose
  Restart=on-failure
  RestartSec=10
  LimitNOFILE=1000000
  [Install]
  WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable subspaced
  sudo systemctl restart subspaced

  if [[ `service subspaced status | grep active` =~ "running" ]]; then
      printGreen "Your node has been installed successfully"
      printGreen "Check your node status: journalctl -u subspaced -f -o cat"
    else
      printGreen "Your node hasn't been installed. Re-install it!"
  fi
}

function updateNode {

    printGreen "Nothing to update!"
    exit 1

    sudo systemctl stop subspaced

    cd $HOME || return
    wget -O subspace-cli $URL
    sudo chmod +x subspace-cli
    sudo rm /usr/local/bin/subspace-cli
    sudo mv subspace-cli /usr/local/bin/

    source $HOME/.bash_profile
    sudo systemctl restart subspaced

    if [[ `service subspaced status | grep active` =~ "running" ]]; then
          printGreen "Your node has been updated successfully"
          printGreen "Check your node status: journalctl -u subspaced -f -o cat"
        else
          printGreen "Your node hasn't been updated correctly."
      fi
}

select opt in "${options[@]}"
do
    case $opt in
        "${options[0]}")
            echo "$selected $opt"
            sleep 1
            installNode
            break
            ;;
        "${options[1]}")
            echo "$selected $opt"
            sleep 1
            updateNode
            break
            ;;
        "${options[2]}")
			echo "$selected $opt"
            break
            ;;
        *) echo "unknown option $REPLY";;
    esac
done
