-- #############################################################################
-- Master_DMA.vhd
--
-- BOARD         : DE0-Nano-SoC from Terasic
-- Author        : Lorenzo Lazzara, Andrea Manzini
-- Creation date : 05/12/2017
--
-- Signals specifications:
--	
--	clk: 50 MHz
--	reset_n: Active low
--
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Master_DMA is
	port(
		clk					: in  std_logic;
		reset_n				: in  std_logic:='1';
		
		--Avalon Slave signals
		as_addr				: in  std_logic_vector(1 downto 0);
		as_write			: in  std_logic:='0';
		as_writedata		: in  std_logic_vector(31 downto 0);
		as_read				: in  std_logic:='0';
		as_readdata			: out std_logic_vector(31 downto 0);
		as_waitrequest		: out std_logic;

		--Avalon Master signals
		am_addr				: out std_logic_vector(31 downto 0);
		am_read				: out std_logic;
		am_readdata			: in  std_logic_vector(31 downto 0):=(others => '0');
		am_waitrequest		: in  std_logic := '0';
		am_byteenable	   	: out std_logic_vector(3 downto 0);
		am_burstcount		: out std_logic_vector(7 downto 0);
		am_readdatavalid	: in  std_logic:='1';
		
		--FIFO signals
		data				: out std_logic_vector(15 downto 0);
		wrreq				: out std_logic;
		almost_full			: in  std_logic:='0';
		sclr				: out std_logic
	);
end entity Master_DMA;

architecture behav of Master_DMA is

	signal image_start_address	:	std_logic_vector(31 downto 0):=(others => '0');
	--transfer lenght is the total number of burst transfer we need in order to transfer the image
	signal transfer_length		:	unsigned(20 downto 0);
	--number of burst for each burst transfer
	signal burst_number			:	unsigned(7 downto 0);
	signal start_transfer		:	std_logic;
	--status bit which stays high during the transfer of the image
	signal busy					:	std_logic;
	signal transfer_accepted	:	std_logic;	-- go high for 1 cycle every time a transfer is initiated
	signal restart 				: 	std_logic;
	
	--transfer_counter contains the total number of burst transfers we are doing
	signal transfer_counter		:	integer;	
	--counts the bursts in one transfer
	signal burst_counter		:	unsigned(5 downto 0);
	
	signal reading	: std_logic;	-- flag for waitrequest control
	signal iaddr	: unsigned(31 downto 0);
	
	type states is (INIT, IDLE, READ_REQUEST, WAIT_DATA, CHECK_TRANSFER);
	signal state, next_state	:	states;
	
begin
	
	--take the 5 (or 6 for green) most significative bits out of 8 for each color
	data(4 downto 0)	<=	am_readdata(7 downto 3);
	data(10 downto 5)	<=	am_readdata(15 downto 10);
	data(15 downto 11)	<=	am_readdata(23 downto 19);
		
	-- waitrequest control: once the reading starts, deassert waitrequest
	as_waitrequest <= '0' when reading='1' else as_read;
	
	as_read_routine: process(clk, reset_n) is
	begin
			if reset_n = '0' then
					as_readdata <= (others => '0');
			elsif rising_edge(clk) then
					as_readdata <= (others => '0');
					reading <= '0';
					
					if as_read = '1' then
						reading <= '1'; -- reading flag is needed for waitrequest control
						
						case as_addr is
							when "00" =>
									as_readdata <= image_start_address;
							when "01" =>
									as_readdata(31 downto 29) <= (others=>'0');
									as_readdata(28 downto 8) <= std_logic_vector(transfer_length);
									as_readdata(7 downto 0)  <= std_logic_vector(burst_number);
							when "10" =>
									as_readdata(31 downto 2) <= (others=>'0');
									as_readdata(1)	<= busy;
									as_readdata(0)	<= '0';
							when others =>
								null;
						end case;
					end if;
			end if;
	end process as_read_routine;
	
	as_write_routine: process(clk, reset_n) is
	begin
			if reset_n = '0' then
					image_start_address	 <= (others => '0');
					transfer_length		 <= (others => '0');
					
					burst_number		 <= (others => '0');
					start_transfer		 <= '0';
					restart				 <= '0';
					
			elsif rising_edge(clk) then
			
					-- transfer_accepted allows to reset start_transfer
					-- from the DMA process, otherwise there is a conflict
					if transfer_accepted = '1' then
						start_transfer <= '0';
					end if;
					
					-- Make restart to be high only for one cycle
					if restart = '1' then
						start_transfer <= '0';
						restart		   <= '0';
					end if;
			
					if as_write = '1' then
						case as_addr is
							when "00" =>
									image_start_address	<= as_writedata;
									start_transfer		<= '1';
									
							when "01" =>
									burst_number 		<= unsigned(as_writedata(7 downto 0));
									transfer_length 	<= unsigned(as_writedata(28 downto 8));
									
							when "10" =>
									restart				<= as_writedata(0);
									start_transfer 		<= as_writedata(4);
									
							when others =>
								null;
						end case;
					end if;
			end if;
	end process as_write_routine;
	
--The control on the start_transfer bit is used to block the transfer if we send command to the LCD 
	fsm_states: process(reset_n, state, start_transfer, am_waitrequest, almost_full, burst_counter, transfer_counter, burst_number, transfer_length, am_readdatavalid, iaddr, restart) is
	begin
	
			-- Default values
			transfer_accepted <= '0';
			sclr 			  <= '0';
			wrreq 			  <= '0';
			am_read			  <= '0';
			am_burstcount	  <= (others => '0');
			am_addr			  <= (others => '0');
				
			if reset_n = '0' then
				next_state <= INIT;
				
			else 
				case state is
					when INIT =>
					--clear the fifo at the restart or reset of the DMA to avoid any kind of misalignment
						sclr <= '1';
						next_state <= IDLE;
						
					when IDLE =>
						--stay in the IDLE state until the flag bit start transfer is 1
						if restart = '1' then
							next_state <= INIT;
						elsif start_transfer = '1' then
							next_state <= READ_REQUEST;
							transfer_accepted <= '1';
						else
							next_state <= IDLE;
						end if;
							
					when READ_REQUEST =>
						--stay in the READ_REQUEST state until the slave (memory) is ready for the transfer or the fifo is almost_full
						
						if almost_full = '0' then
							am_addr 	  <= std_logic_vector(iaddr);
							am_burstcount <= std_logic_vector(burst_number);
							am_read 	  <= '1';
						end if;
						
						if restart = '1' then
							next_state <= INIT;
						elsif am_waitrequest = '1' then
							next_state <= READ_REQUEST;
						elsif almost_full = '1' then
							next_state <= READ_REQUEST;
						else
							next_state <= WAIT_DATA;
						end if;
							
					when WAIT_DATA =>
						--the signal am_readdatavalid is asserted only when valid data is available
						--hence we can use it to drive the wreq signal of the fifo
						wrreq 	<= am_readdatavalid;
						
						--wait until burst_number data are read
						if restart = '1' then
							next_state <= INIT;
						elsif burst_counter = burst_number then
							next_state <= CHECK_TRANSFER;
						else
							next_state <= WAIT_DATA;
						end if;
						
					when CHECK_TRANSFER =>
						--if the entire image has been read go in IDLE and wait for another start
						
						if restart = '1' then
							next_state <= INIT;
						elsif transfer_counter = to_integer(transfer_length) - 1 then
							next_state <= IDLE;
						else
							next_state <= READ_REQUEST;
						end if;
						
					when others =>
						next_state <= INIT;
				end case;
			end if;
	end process fsm_states;
	
	-- Wired connection of DMA
	am_byteenable    <= "1111";
	
	DMA_routine: process(clk, reset_n) is
	begin
			if reset_n = '0' then
				burst_counter 	 <= (others => '0');
				transfer_counter <= 0;
				iaddr 			 <= (others => '0');
				busy			 <= '0';
				
			elsif rising_edge(clk) then
				case state is
					when INIT =>
						null;
				
					when IDLE =>
						burst_counter 	 	<= (others => '0');
						transfer_counter 	<= 0;
						iaddr 				<= unsigned(image_start_address);
						busy				<= '0';
						
						if start_transfer = '1' then
							busy <= '1';
						end if;
						
					when READ_REQUEST =>
						
						if almost_full = '0' then
							--reset burst_counter to zero when we are doing another burst transfer
							burst_counter <= (others => '0');
						end if;
							
					when WAIT_DATA =>
							if am_readdatavalid = '1' then
								burst_counter <= burst_counter + 1;
							end if;
							
					when CHECK_TRANSFER =>
						transfer_counter <= transfer_counter + 1;
						iaddr 		  	 <= iaddr + 4*burst_number;
					
				end case;
			end if;
	end process DMA_routine;
	
	state_register: process(clk, reset_n) is
	begin
			if reset_n = '0' then
				state <= INIT;
			elsif rising_edge(clk) then
				state <= next_state;
			end if;
	end process state_register;
	
end behav;