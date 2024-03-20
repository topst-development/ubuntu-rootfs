@echo off

echo Start the FWDN V8 for ubuntu image

if exist %deploy-images\boot-firmware (
	echo Connect FWDN V8 to Board
	fwdn.exe --fwdn deploy-images\boot-firmware\fwdn.json

	echo Ubuntu File System install for main core
	if exist %deploy-images\automotive-linux-platform-image-tcc8050-main.ext4 (
		fwdn.exe -w deploy-images\automotive-linux-platform-image-tcc8050-main.ext4 --storage emmc --area user --part system
	) else (
		echo Not exist automotive-linux-platform-image-tcc8050-main.ext4
	)

	echo End !!
	exit /b
) else (
	echo Not exist boot-fimware file
)