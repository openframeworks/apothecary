$MSYS2_PATH\usr\bin\pacman --noconfirm --needed -Su

$MSYS2_PATH\usr\bin\bash -lc "scripts/calculate_formulas.sh"
choco install -y strawberryperl

PATH=$PATH;$MSYS2_PATH/usr/bin;
