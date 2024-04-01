#!/bin/sh

FU_Blink()
{
	/etc/led/nodes_led.sh green on
	sleep $1
	/etc/led/nodes_led.sh green off
	sleep $2
}

FU_Start()
{
	return
}

FU_Start2()
{
	# /etc/led/nodes_led_blink.sh green 750

	/etc/led/nodes_led_blink.sh green 150
}

FU_Failed()
{
	return
}

FU_Failed2()
{
	/etc/led/nodes_led.sh green off
}

FU_Success()
{
	return
}

FU_Success2()
{
	# while true
	# do
	#	FU_Blink 0.1 0.1
	# done
	
	# /etc/led/nodes_led_blink.sh green 100

	/etc/led/nodes_led.sh green on
}


case "$1" in

	"fu_start")
		FU_Start
		;;

	"fu_start2")
		FU_Start2
		;;

	"fu_failed")
		FU_Failed
		;;

	"fu_failed2")
		FU_Failed2
		;;

	"fu_success")
		FU_Success
		;;

	"fu_success2")
		FU_Success2
		;;

	*)
		;;
esac
