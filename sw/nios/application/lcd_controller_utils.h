/*
 * lcd_controller_utils.h
 *
 *  Created on: 15/dic/2017
 *      Author: Andrea Manzini, Lorenzo Lazzara
 */

#ifndef LCD_CONTROLLER_UTILS_H_
#define LCD_CONTROLLER_UTILS_H_

#include <system.h>
#include <io.h>

/* DRAM BASE ADDRESS */
#define DRAM_WINDOW_BASE HPS_0_BRIDGES_BASE

/* ######## DMA MACRO ######## */

#define DRAM_WR_DATA(OFFSET, DATA) \
	IOWR_32DIRECT(DRAM_WINDOW_BASE, OFFSET, DATA)

#define SET_DMA(TRANSFER_LENGTH, BURST_LENGHT) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 4, TRANSFER_LENGTH<<8 | BURST_LENGHT)

#define RESET_DMA() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 8, 0x00000001)

#define START_DMA(FRAME) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 0, FRAME)

#define READ_CONF_REG_DMA() \
	IORD_32DIRECT(LCD_CONTROLLER_0_BASE, 4)

#define IS_DMA_BUSY() \
	IORD_32DIRECT(LCD_CONTROLLER_0_BASE, 8)>1

/* ######## LCD MACRO #########  */

// Send command to the LCD (csx bit low)
#define LCD_WR_REG(REG) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, REG)
	
// Send continuous command to the LCD.
	/* A command is continuous when it requires following
	 * additional data to be sent. This function can be
	 * perfectly substituted by the LCD_WR_REG macro, but
	 * in this way the ILI9341 is paused between each data.
	 * This seems to cause no problems but it's conceptually wrong.
	 */
#define LCD_WRC_REG(REG) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, REG | 0x00100000)

// Send data to the LCD (csx bit high)
#define LCD_WR_DATA(DATA) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, DATA | 0x00010000)
	
// Send continuous data to the LCD
#define LCD_WRC_DATA(DATA) \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, DATA | 0x00110000)


#define SEND_LCD_WR_CMD() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, 0x0000002C)

#define SET_LCD_RST() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, 0x13000000)

#define CLR_LCD_RST() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, 0x11000000)

#define SET_LCD_ON() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, 0x13000000)

#define CLR_LCD_ON() \
	IOWR_32DIRECT(LCD_CONTROLLER_0_BASE, 12, 0x12000000)

/* ######## FUNCTIONS #########  */

// LCD initialization
void init_LCD();

// DMA initialization
void init_DMA(int transfer_length, int burst_length);

// Start loading from FIFO
void start_LCD();

// Load an image from the hostfs
void load_image(int* address, char* path, int frame_pixel);

// Write red and blue frames in the DRAM
void write_DRAM_testRB(int* addr0, int* addr1);

// Load the images of the GIF on the DRAM
void load_gif(int* curr_frame, int frame_span, int frame_pixel);

// Diplay the GIF on the LCD
void print_gif(int* frame, int frame_span);

#endif /* LCD_CONTROLLER_UTILS_H_ */
