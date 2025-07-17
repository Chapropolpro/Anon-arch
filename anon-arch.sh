#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Этот скрипт нужно запускать от root (sudo)"
  exit 1
fi

echo "[1/9] Обновление системы"
pacman -Syu --noconfirm

echo "[2/9] Установка необходимых пакетов (если не установлены)"
pacman -S --needed --noconfirm macchanger systemd-zram-generator

echo "[3/9] Включение zram (сжатый swap в RAM)"
mkdir -p /etc/systemd/zram-generator.conf.d
cat <<EOF > /etc/systemd/zram-generator.conf.d/zram.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF

echo "[4/9] Отключение systemd-resolved (DNS-прокси)"
systemctl disable --now systemd-resolved.service 2>/dev/null || true
rm -f /etc/resolv.conf
echo -e "nameserver 1.1.1.1\nnameserver 9.9.9.9" > /etc/resolv.conf

echo "[5/9] Отключение Predictable Network Interface Names"
ln -sf /dev/null /etc/udev/rules.d/80-net-setup-link.rules

echo "[6/9] Настройка MAC-рандомизации для NetworkManager"
mkdir -p /etc/NetworkManager/conf.d
cat <<EOF > /etc/NetworkManager/conf.d/mac.conf
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
EOF

echo "[7/9] Отключение IPv6"
cat <<EOF > /etc/sysctl.d/99-disable-ipv6.conf
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
sysctl --system

echo "[8/9] Удаление деанон-пакетов (если есть)"
for pkg in geoclue networkmanager-qt packagekit tracker modemmanager blueman zeitgeist; do
  if pacman -Qs "$pkg" > /dev/null; then
    echo "Удаление $pkg"
    pacman -Rns --noconfirm "$pkg"
  fi
done

echo "[9/9] Очистка кэша pacman"
pacman -Scc --noconfirm

echo "Готово. Система очищена, анонимизирована и оптимизирована для безопасной и повседневной работы."
