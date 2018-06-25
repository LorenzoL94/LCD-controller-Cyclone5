# LCD_controller DEMO

### Authors: Manzini A., Lazzara L.
### Created on: 27/12/2017

## Getting started with the demo
	
	* Create a BSP template project in Eclipse based on the LCD_controller system. Make sure to enable the hostfs functionality, in order to transfer images from the PC to the DRAM of the board.
	* Copy "demo.c", "lcd_controller_utils.c" and "lcd_controller_utils.h" in the main directory of the project.
	* Copy also the folder "gif" in the same directory. It contains the images of the GIF.
	* In Eclipse, run the project on the board in debug mode.
	* Enjoy Jim Carrey.
	
## Notes:
	* Debug mode is needed otherwise the hostfs expansion does not work.
	* Writing the 8 images on the DRAM can take a while (up to 20 minutes).
	* The file "lenna.bin" contains another test image, which can be loaded on the DRAM using the function load_image included in "lcd_controller_utils.h".
	* Use the matlab script "../../matlab/image_preprocessing.m" if you want to create and load new images.