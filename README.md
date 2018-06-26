# LCD-controller-Cyclone5

The aim of the project is to develop an LCD controller, which displays images stored in the
SDRAM. As LCD we use the LT24 module by Terasic, which includes the ILI9341 LCD
driver and a 240x320 display. Incorporating a DMA, our IP reads the data on the SDRAM
through the Avalon Bus, then directly communicates with the LCD driver following an 8080 I
protocol. The design has been developed for the DE0-Nano-Soc Kit. Quartus, Eclipse,
ModelSim and SignalTap were used for development and debugging.

## Setting up the system

* Open hw/quartus/ES_mini_project_TRDB_D5M_LT24.qpf with Quartus
* Compile the project
* Program the board with the compilation output file (.sof).
* Follow the instructions in the software folder to run the demo.

## Getting started with the demo
	
* Create a BSP template project in Eclipse based on the LCD_controller system. Make sure to enable the hostfs functionality,
in order to transfer images from the PC to the DRAM of the board.
* Copy "demo.c", "lcd_controller_utils.c" and "lcd_controller_utils.h" from sw/nios/application in the main directory of the project.
* Copy also the folder "gif" in the same directory. It contains the images of the GIF.
* In Eclipse, run the project on the board in debug mode.
* Enjoy Jim Carrey.
