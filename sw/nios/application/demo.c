/*
 * demo.c
 *
 * This demo loads 8 images in the DRAM of the board
 * and display them in a loop in order to simulate a video.
 * The images are extracted from a GIF found on the web
 * and converted in the required binary format with a matlab script.
 *
 *  Created on: 15/dic/2017
 *      Author: Andrea Manzini, Lorenzo Lazzara
 */

#include "lcd_controller_utils.h"


// USER DEFINED CONSTANTS
#define BURST_LENGTH 16
#define FRAME_PIXEL 76800

#define TRANSFER_LENGTH FRAME_PIXEL/BURST_LENGTH
#define FRAME_DEFAULT_ADDRESS DRAM_WINDOW_BASE
#define FRAME_SPAN FRAME_PIXEL*4


int main()

{

	int* start_frame = FRAME_DEFAULT_ADDRESS;

	load_gif(start_frame, FRAME_SPAN, FRAME_PIXEL);
	init_LCD();
	init_DMA(TRANSFER_LENGTH, BURST_LENGTH);
	START_DMA(start_frame);
	start_LCD();
	print_gif(start_frame, FRAME_SPAN);
	
	return 0;
}
