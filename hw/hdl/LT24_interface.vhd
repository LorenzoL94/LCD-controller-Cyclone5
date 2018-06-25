-- #############################################################################
-- LT24_interface.vhd
--
-- BOARD         : DE0-Nano-SoC from Terasic
-- Author        : Lorenzo Lazzara, Andrea Manzini
-- Creation date : 05/12/2017
--
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LT24_interface is
	port(

		-- System signals
		ck		: in std_logic;
		res_n	: in std_logic	:= '1';
		
		-- Avalon Slave signals
		as_wrdata		: in std_logic_vector(31 downto 0)	:= (others=>'0');
		as_write		: in std_logic						:= '0';
		as_waitrequest	: out std_logic;
		
		-- FIFO interface signals
		fifo_data	: in std_logic_vector(15 downto 0)	:= (others=>'0');
		almost_full	: in std_logic						:= '0';
		rd_req		: out std_logic;
		
		-- ILI9341 communication signals, registered outputs (8080 I interface)
		csx		: out std_logic;
		dcx		: out std_logic;
		wrx		: out std_logic;
		data	: out std_logic_vector(15 downto 0);
		
		-- LT24 global signals, registered outputs
		LCD_on		: out std_logic;
		LCD_resn	: out std_logic

	);
end entity LT24_interface;
	
architecture rtl of LT24_interface is

	-- ALIAS
	signal dcx_in			: std_logic;	-- as_wrdata(16)
	signal continue_in		: std_logic;	-- as_wrdata(20)
	signal LCD_on_in		: std_logic;	-- as_wrdata(24)
	signal LCD_resn_in		: std_logic;	-- as_wrdata(25), active_high
	signal regs_write		: std_logic;	-- as_wrdata(28)

	-- REGISTERS
	signal cnt		: unsigned(16 downto 0);	-- to count the number of pixel loaded
	signal continue :	std_logic;	-- high if current command requires following data, accessable by avalon bus
	
	-- CONSTANTS
	constant WR_CODE 	: std_logic_vector(7 downto 0) := "00101100";
	constant FRAME_LENGTH	: integer := 76800;
	
	-- STATE MACHINE
	type states is (CMD_WAIT, CMD1, CMD2, CMD3, WAIT_FIFO, LOAD_START, LOAD1, LOAD2, LOAD3);
	signal state, nstate	: states;
	
	begin
	
		-- WIRED CONNECTIONS
		dcx_in 		<= as_wrdata(16);
		continue_in <= as_wrdata(20);
		LCD_on_in	<= as_wrdata(24);
		LCD_resn_in	<= as_wrdata(25);	--when this signal is high, it drives the LCD_res_n low
		regs_write 	<= as_wrdata(28);
		
		
		state_controller: process(res_n, state, as_write, almost_full, cnt, regs_write, as_wrdata, dcx_in)  is
		-- This unit acts as an interface between the avalon protocol and
		-- the 8080 I protocol. In order to respect the 8080 timing, 
		-- the avalon is asked to wait 4 cycles each transfer.
		--
		-- A loading routine is started when the write command (0x2C) is sent.
		--
		-- During the loading routine, a writing of an instruction from the master has the priority.
		-- It causes the loading to immediately interrupt, then the istruction is sent to the LT24.
		-- Avalon bus in this case is engaged for 5 cycles.
		-- When a loading is interrupted, the content of the GRAM is corrupted, so the master
		-- should request another loading.
		begin
		
			-- Default values
			as_waitrequest <= as_write;
			rd_req <= '0';
		
			if res_n = '0' then
				nstate <= CMD_WAIT;
				
			else
				case state is
					when CMD_WAIT =>
					-- Default state: wait for a command/data write
						if (as_write='1') and (regs_write='0') then
							nstate <= CMD1;
						else
							as_waitrequest <= '0';
							nstate <= CMD_WAIT;
						end if;
						
					when CMD1 =>
					-- Wait cycle to respect the 8080 specification
						nstate <= CMD2;
						
					when CMD2 =>
					-- Wait cycle to respect the 8080 specification
						nstate <= CMD3;
						
					when CMD3 =>
					-- Wait cycle to respect the 8080 specification
						as_waitrequest <= '0';
						
						if ( as_wrdata(7 downto 0) = WR_CODE ) and ( dcx_in='0' ) then
						-- As soon as the write command finish, start a loading
							nstate <= WAIT_FIFO;
						else
							nstate <= CMD_WAIT;
						end if;
						
					when WAIT_FIFO =>
					-- Wait for the FIFO to be almost full. This avoids
					-- starting the loading when the FIFO is not enough full
					-- and then run out of data if the bus is very busy.
						if as_write = '1' then
							nstate <= CMD_WAIT;
						elsif almost_full='1'  then
							rd_req <= '1';
							nstate <= LOAD_START;
						else
							nstate <= WAIT_FIFO;
						end if;
						
					when LOAD_START =>
						if as_write='1' then
						-- cmd writing priority implementation
							nstate <= CMD_WAIT;
						else
							nstate <= LOAD1;
						end if;
					
					when LOAD1 =>
					-- Wait cycle to respect the 8080 specification
						if as_write='1' then
						-- cmd writing priority implementation
							nstate <= CMD_WAIT;
						else
							nstate <= LOAD2;
						end if;
					
					when LOAD2 =>
					-- Wait cycle to respect the 8080 specification
						if as_write='1' then
						-- cmd writing priority implementation
							nstate <= CMD_WAIT;
						else
							nstate <= LOAD3;
						end if;
					
					when LOAD3 =>
					-- Wait cycle to respect the 8080 specification
						if as_write='1' then
						-- cmd writing priority implementation
							nstate <= CMD_WAIT;
							
						elsif cnt = to_unsigned(FRAME_LENGTH - 1, cnt'length)  then
						-- When you finish loading a frame, wait for new one from dma
							nstate <= WAIT_FIFO;
							
						else
							-- Request data from the FIFO
							rd_req <= '1';
							nstate <= LOAD_START;
						end if;
						
					when others =>
						nstate <= CMD_WAIT;
					
				end case;
			end if;
		end process state_controller;
		
		register_controller: process(ck, res_n) is
		begin
			if res_n='0' then
			-- Asynch reset
				continue 	<= '0';
				LCD_on 		<= '1';
				LCD_resn 	<= '1';
				data 		<= (others=>'0');
		
			elsif rising_edge(ck) then
				case state is
					when CMD_WAIT =>
						-- Init signals
						cnt <= (others => '0');
						dcx <= '1';
						wrx <= '1';
						-- Deactivate csx only if last command did not
						-- expect following data (continue flag)
						csx <= not continue;
						
						if as_write='1' then
						-- Prepare signals for a command/data writing if 
						-- the master asks for it, or simply update the 
						-- registers, depending on as_wrdata content
							if regs_write='1' then
								LCD_on <= LCD_on_in;
								LCD_resn <= LCD_resn_in;
								
							else
								csx <= '0';
								dcx <= dcx_in;
								wrx <= '0';
								continue <= continue_in;
								data <= as_wrdata(15 downto 0);
							end if;
						end if;
						
					when CMD2 =>
						wrx <= '1';
						
					when WAIT_FIFO =>
						-- Pause parallel interface
						csx <= '1';
						
					when LOAD_START =>
						csx <= '0';
						dcx <= '1';
						wrx <= '0';
						data <= fifo_data;
					
					when LOAD2 =>
						wrx <= '1';
						
					when LOAD3 =>
						if cnt = to_unsigned(FRAME_LENGTH - 1, cnt'length) then
						-- When you finish loading a frame, reset the counter
							cnt <= (others=>'0');
						else
						-- else increment it
							cnt <= cnt + 1;
						end if;
						
					when others =>
						null;
						
				end case;
			end if;
		end process register_controller;
			
			
		state_regs: process(ck, res_n) is
		begin
		
			if (res_n = '0') then
			-- asynchronous reset
				state <= CMD_WAIT;
			
			elsif rising_edge(ck) then
				state <= nstate;
			
			end if;
			
		end process state_regs;
			
end architecture rtl;
	