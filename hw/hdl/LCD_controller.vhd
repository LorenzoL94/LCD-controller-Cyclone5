-- #############################################################################
-- LCD_controller.vhd
--
-- BOARD         : DE0-Nano-SoC from Terasic
-- Author        : Lorenzo Lazzara, Andrea Manzini
-- Creation date : 05/12/2017
--
-- This is a structural VHDL. It only connects components, only avalon decoder logic is specified here.
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_controller is
	port(
		-- System signals
		clk		: in std_logic;
		reset_n	: in std_logic;
		
		--Avalon Slave signals
		avs_address				: in  std_logic_vector(1 downto 0):="00";
		avs_write			: in  std_logic:='0';
		avs_writedata		: in  std_logic_vector(31 downto 0):=(others => '0');
		avs_read				: in  std_logic:='0';
		avs_readdata			: out std_logic_vector(31 downto 0);
		avs_waitrequest		: out std_logic;

		--Avalon Master signals
		avm_address				: out std_logic_vector(31 downto 0);
		avm_read				: out std_logic;
		avm_readdata			: in  std_logic_vector(31 downto 0):=(others => '0');
		avm_waitrequest		: in  std_logic := '0';
		avm_byteenable	   	: out std_logic_vector(3 downto 0);
		avm_burstcount		: out std_logic_vector(7 downto 0);
		avm_readdatavalid	: in  std_logic := '0';
		
		-- ILI9341 communication signals	(8080 I interface)
		csx		: out std_logic;
		dcx		: out std_logic;
		wrx		: out std_logic;
		data	: out std_logic_vector(15 downto 0);
		
		-- LT24 global signals, registered outputs
		LCD_on		: out std_logic;
		LCD_resn	: out std_logic
		
		);
end LCD_controller;

architecture struct of LCD_controller is

	-- Avalon decoder
	signal iwrite_to_DMA: std_logic;
	signal iwrite_to_LT24: std_logic;
	signal iwait_from_DMA: std_logic;
	signal iwait_from_LT24: std_logic;
	
	-- Interconnection signals
	signal ififo_data_in	: std_logic_vector(15 DOWNTO 0);
	signal ififo_data_out	: std_logic_vector(15 DOWNTO 0);
	signal ififo_sclr		: std_logic;
	signal ififo_wrreq		: std_logic;
	signal ififo_rdreq		: std_logic;
	signal ififo_almost_full: std_logic;
	
	component LT24_interface
		port(

			-- System signals
			ck		: in std_logic;
			res_n	: in std_logic;
			
			-- Avalon Slave signals
			as_wrdata		: in std_logic_vector(31 downto 0);
			as_write		: in std_logic;
			as_waitrequest	: out std_logic;
			
			-- FIFO interface signals
			fifo_data	: in std_logic_vector(15 downto 0);
			almost_full	: in std_logic;
			rd_req		: out std_logic;
			
			-- ILI9341 communication signals	(8080 I interface)
			csx		: out std_logic;
			dcx		: out std_logic;
			wrx		: out std_logic;
			data	: out std_logic_vector(15 downto 0);
			
			-- LT24 global signals, registered outputs
			LCD_on		: out std_logic;
			LCD_resn	: out std_logic

		);
	end component;
	
	component Master_DMA
		port(
			clk					: in  std_logic;
			reset_n				: in  std_logic;
			
			--Avalon Slave signals
			as_addr				: in  std_logic_vector(1 downto 0);
			as_write			: in  std_logic;
			as_writedata		: in  std_logic_vector(31 downto 0);
			as_read				: in  std_logic;
			as_readdata			: out std_logic_vector(31 downto 0);
			as_waitrequest		: out std_logic;

			--Avalon Master signals
			am_addr				: out std_logic_vector(31 downto 0);
			am_read				: out std_logic;
			am_readdata			: in  std_logic_vector(31 downto 0);
			am_waitrequest		: in  std_logic;
			am_byteenable	   	: out std_logic_vector(3 downto 0);
			am_burstcount		: out std_logic_vector(7 downto 0);
			am_readdatavalid	: in  std_logic;
			
			--FIFO signals
			data				: out std_logic_vector(15 downto 0);
			wrreq				: out std_logic;
			almost_full			: in  std_logic;
			sclr				: out std_logic
		);
	end component;
	
	component FIFO
		PORT
		(
			clock		: IN STD_LOGIC ;
			data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
			rdreq		: IN STD_LOGIC ;
			sclr		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			almost_full	: OUT STD_LOGIC ;
			q			: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
		);
	END component;
	
	begin
	
		-- Avalon slave decoder
		iwrite_to_DMA 	<= avs_write when avs_address /= "11" else '0';
		iwrite_to_LT24 	<= avs_write when avs_address = "11" else '0';
		avs_waitrequest <= iwait_from_DMA or iwait_from_LT24; 
		
		LT24_interface_inst: LT24_interface
			port map(
				-- System signals
				ck		=> clk,
				res_n	=> reset_n,
				
				-- Avalon Slave signals
				as_wrdata		=> avs_writedata,
				as_write		=> iwrite_to_LT24,
				as_waitrequest	=> iwait_from_LT24,
				
				-- FIFO interface signals
				fifo_data	=> ififo_data_out,
				almost_full	=> ififo_almost_full,
				rd_req		=> ififo_rdreq,
				
				-- ILI9341 communication signals	(8080 I interface)
				csx		=> csx,
				dcx		=> dcx,
				wrx		=> wrx,
				data	=> data,
				
				-- LT24 global signals, registered outputs
				LCD_on		=> LCD_on,
				LCD_resn	=> LCD_resn
			);
			
		Master_DMA_inst: Master_DMA
			port map(
				clk					=> clk,
				reset_n				=> reset_n,
				
				--Avalon Slave signals
				as_addr				=> avs_address(1 downto 0),
				as_write				=> iwrite_to_DMA,
				as_writedata		=> avs_writedata,
				as_read				=> avs_read,
				as_readdata			=> avs_readdata,
				as_waitrequest		=> iwait_from_DMA,

				--Avalon Master signals
				am_addr				=> avm_address,
				am_read				=> avm_read,
				am_readdata			=> avm_readdata,
				am_waitrequest		=> avm_waitrequest,
				am_byteenable	   	=> avm_byteenable,
				am_burstcount		=> avm_burstcount,
				am_readdatavalid	=> avm_readdatavalid,
				
				--FIFO signals
				data				=> ififo_data_in,
				wrreq				=> ififo_wrreq,
				almost_full			=> ififo_almost_full,
				sclr				=> ififo_sclr
			);
		
		FIFO_inst: FIFO
			port map
			(
				clock		=> clk,
				data		=> ififo_data_in,
				rdreq		=> ififo_rdreq,
				sclr		=> ififo_sclr,
				wrreq		=> ififo_wrreq,
				almost_full	=> ififo_almost_full,
				q			=> ififo_data_out
			);
			
end architecture struct;