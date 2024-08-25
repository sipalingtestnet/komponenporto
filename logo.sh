#!/bin/bash

# Fungsi untuk menampilkan logo dengan efek fade in
display_fadein_logo() {
  for brightness in {0..10}; do
    clear
    while IFS= read -r line; do
      echo -e "\e[38;5;${brightness}m$line\e[0m"
    done < <(curl -s https://raw.githubusercontent.com/sipalingtestnet/komponenporto/main/logo2.sh)
    sleep 0.1
  done
}

# Fungsi untuk menambahkan animasi
animate_fadein_logo() {
  while true; do
    display_fadein_logo
    sleep 0.5
  done
}

# Jalankan animasi
animate_fadein_logo
