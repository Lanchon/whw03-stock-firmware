#/bin/sh

HW_VERSION="$(syscfg get device::hw_revision)"

SetGPIO()
{
	local l_gpio=$1
	local l_value=$2

	echo "$l_value" >/sys/class/gpio/gpio"$l_gpio"/value
}

ZBReset()
{
	local l_value=$1

	SetGPIO 49 "$l_value"
}

ZBNwake()
{
	local l_value=$1

	if [ "$HW_VERSION" = "1" ];then
		#VelopV1
		SetGPIO 55 "$l_value"
	else
		#VelopV2
		SetGPIO 31 "$l_value"
	fi
}

ZBRunStandAloneBootloader()
{
	ZBReset 0
	ZBNwake 0

	ZBReset 1
	sleep 3

	ZBNwake 1
	sleep 1
}

ZBRunStandAloneBootloader
