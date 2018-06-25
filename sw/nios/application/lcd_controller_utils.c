/*
 * lcd_controller_utils.c
 *
 *  Created on: 15/dic/2017
 *      Author: Andrea Manzini, Lorenzo Lazzara
 */

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/alt_cache.h>
#include "lcd_controller_utils.h"


void load_gif(int* curr_frame, int frame_span, int frame_pixel) {
	/* Write the GIF images to the DRAM in sequential locations
	 *
	 * 		curr_frame: start address of the GIF images
	 * 		frame_span: bytes of a frame
	 * 		frame_pixel: pixels in a frame
	 */

	load_image(curr_frame, "/mnt/host/gif/typing0.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing1.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing2.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing3.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing4.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing5.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing6.bin", frame_pixel);
	curr_frame = curr_frame + frame_span;
	load_image(curr_frame, "/mnt/host/gif/typing7.bin", frame_pixel);

}

void print_gif(int* frame, int frame_span) {
	/* Display the gif frames in the LCD every 0.1ms to
	 * produce the "video effect".
	 *
	 * 		frame: start address of the GIF frames in the DRAM
	 * 		frame_span: bytes of a frame
	 *
	 * This function only works if load_gif was previously called.
	 */

	int* first_frame = frame;
	while(1) {
		START_DMA(frame);
		usleep(100000);

		if ( frame == (first_frame + frame_span*7) )
			frame = first_frame;
		else
			frame += frame_span;
	}
}

void load_image(int* address, char* path, int frame_pixel) {
	/* Load an image from the host filesystem and write it in the DRAM.
	 *
	 * 		address: address in the DRAM where to write the image
	 * 		path:	path of the image in the host fs
	 * 		frame_pixel: pixels in a frame
	 *
	 * This function uses the hostfs functionality of the bsp,
	 * so it only works in debug mode.
	 */

	FILE *fp  = fopen(path, "r");

	if (fp ==	NULL) {
		printf ("Cannot	open file hostfs\n");
		exit (1);
	}

	int read_count = fread(address, 4, frame_pixel, fp);

	// Flush data cache to make sure that all the data have been transferred to the DRAM
	alt_dcache_flush_all();
	printf("%d\n", read_count);

	fclose (fp);
}

void write_DRAM_testRB(int* addr0, int* addr1) {
	/* Write two frames in the DRAM. The first is red the second is blue.
	 *
	 * 		addr0: start address of the red frame
	 * 		addr1: start address of the blue frame
	 */

	for (int i=0;i<307200;i=i+4) {
		IOWR_32DIRECT(addr0,i,0x00FF0000);
	}

	for (int i=0;i<307200;i=i+4) {
		IOWR_32DIRECT(addr1,i,0x000000FF);
	}
}

void init_DMA(int transfer_length, int burst_length) {
	/* Initialization routine of the DMA.
	 * Reset the DMA and set the transfer length and the burst length
	 */
	RESET_DMA();
	SET_DMA(transfer_length, burst_length);
}

void test_LCD() {
	/* Directly write into the GRAM of the LCD a single color frame
	 *
	 * Use this function to test the LCD independently from the DMA.
	 */
	SEND_LCD_WR_CMD();
	for (int i=0;i<76800;i++) {
		LCD_WR_DATA(0x0000F800);
	}
}

void start_LCD() {
	/* Send a write command to the LCD and start loading
	 * the frames from the FIFO.
	 *
	 * Once started, the LCD automatically load new frames when
	 * available, so no more action is needed.
	 *
	 * If you want to manually send data to the LCD, call
	 * this function and then use the macro LCD_WR_DATA to send pixels.
	 */

	SEND_LCD_WR_CMD();
}

void init_LCD() {
	/* Initialization routine of the LCD. The LCD is first
	 * reset and then all the setting configuration commands are sent.
	 *
	 * The frame loading is not started in this function, so a call
	 * to start_LCD() is required if you want to load from the FIFO
	 */

	SET_LCD_RST();
	usleep(1000);	// Delay 1ms
	CLR_LCD_RST();
	usleep(10000); // Delay 10ms
	SET_LCD_RST();
	usleep(120000); // Delay 120 ms
	LCD_WR_REG(0x0011); //Exit Sleep
	LCD_WRC_REG(0x00CF);// Power Control B
	LCD_WRC_DATA(0x0000);// Always0x00
	LCD_WRC_DATA(0x0081);//
	LCD_WR_DATA(0X00c0);
	LCD_WRC_REG(0x00ED);// Power on sequencecontrol
	LCD_WRC_DATA(0x0064); // Soft Start Keep1 frame
	LCD_WRC_DATA(0x0003); //
	LCD_WRC_DATA(0X0012);
	LCD_WR_DATA(0X0081);
	LCD_WRC_REG(0x00E8); // Driver timing control A
	LCD_WRC_DATA(0x0085);
	LCD_WRC_DATA(0x0001);
	LCD_WR_DATA(0x00798);
	LCD_WRC_REG(0x00CB); // Power control A
	LCD_WRC_DATA(0x0039);
	LCD_WRC_DATA(0x002C);
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x0034);
	LCD_WR_DATA(0x0002);
	LCD_WRC_REG(0x00F7); // Pumpratio control
	LCD_WR_DATA(0x0020);
	LCD_WRC_REG(0x00EA); // Driver timing control B
	LCD_WRC_DATA(0x0000);
	LCD_WR_DATA(0x0000);
	LCD_WRC_REG(0x00B1); // Frame Control (In Normal Mode)
	LCD_WRC_DATA(0x0000);
	LCD_WR_DATA(0x001b);
	LCD_WRC_REG(0x00B6); // Display FunctionControl
	LCD_WRC_DATA(0x000A);
	LCD_WR_DATA(0x00A2);
	LCD_WRC_REG(0x00C0); //Power control 1
	LCD_WR_DATA(0x0005); //VRH[5:0]
	LCD_WRC_REG(0x00C1); //Power control 2
	LCD_WR_DATA(0x0011); //SAP[2:0];BT[3:0]
	LCD_WRC_REG(0x00C5); //VCM control 1
	LCD_WRC_DATA(0x0045); //3F
	LCD_WR_DATA(0x0045); //3C
	LCD_WRC_REG(0x00C7); //VCM control 2
	LCD_WR_DATA(0X00a2);
	LCD_WRC_REG(0x0036); // Memory Access Control
	LCD_WR_DATA(0x0028);// Invert XY axes to represent 320x240 images, BGR order
	LCD_WRC_REG(0x00F2); // Enable3G
	LCD_WR_DATA(0x0000); // 3Gamma FunctionDisable
	LCD_WRC_REG(0x0026); // Gamma Set
	LCD_WR_DATA(0x0001); // Gamma curve selected
	LCD_WRC_REG(0x00E0); // Positive Gamma Correction, Set Gamma
	LCD_WRC_DATA(0x000F);
	LCD_WRC_DATA(0x0026);
	LCD_WRC_DATA(0x0024);
	LCD_WRC_DATA(0x000b);
	LCD_WRC_DATA(0x000E);
	LCD_WRC_DATA(0x0008);
	LCD_WRC_DATA(0x004b);
	LCD_WRC_DATA(0X00a8);
	LCD_WRC_DATA(0x003b);
	LCD_WRC_DATA(0x000a);
	LCD_WRC_DATA(0x0014);
	LCD_WRC_DATA(0x0006);
	LCD_WRC_DATA(0x0010);
	LCD_WRC_DATA(0x0009);
	LCD_WR_DATA(0x0000);
	LCD_WRC_REG(0X00E1); //NegativeGamma Correction, Set Gamma
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x001c);
	LCD_WRC_DATA(0x0020);
	LCD_WRC_DATA(0x0004);
	LCD_WRC_DATA(0x0010);
	LCD_WRC_DATA(0x0008);
	LCD_WRC_DATA(0x0034);
	LCD_WRC_DATA(0x0047);
	LCD_WRC_DATA(0x0044);
	LCD_WRC_DATA(0x0005);
	LCD_WRC_DATA(0x000b);
	LCD_WRC_DATA(0x0009);
	LCD_WRC_DATA(0x002f);
	LCD_WRC_DATA(0x0036);
	LCD_WR_DATA(0x000f);
	LCD_WRC_REG(0x002A); // ColumnAddressSet
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x0001); //0x0000
	LCD_WR_DATA(0x003f); //00ef
	LCD_WRC_REG(0x002B); // Page AddressSet
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x0000);
	LCD_WRC_DATA(0x0000); //0001
	LCD_WR_DATA(0x00ef); //003f
	LCD_WRC_REG(0x003A); // COLMOD: Pixel Format Set
	LCD_WR_DATA(0x0055);
	LCD_WRC_REG(0x00f6); // Interface Control
	LCD_WRC_DATA(0x0001);
	LCD_WRC_DATA(0x0030);
	LCD_WR_DATA(0x0000);
	LCD_WR_REG(0x0029); //display on
}

