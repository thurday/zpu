library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library std;
use std.textio.all;

library work;
use work.zpu_config.all;
use work.zpupkg.all;
use work.txt_util.all;

entity zpu_bus_trace is
    generic (
        log_file            : string := "bus_trace.txt"
    );
    port (
        clk                 : in std_ulogic;
        reset               : in std_ulogic;
        --
        in_mem_busy         : in std_ulogic; 
        mem_read            : in std_ulogic_vector(wordSize-1 downto 0);
        mem_write           : in std_ulogic_vector(wordSize-1 downto 0);              
        out_mem_addr        : in std_ulogic_vector(maxAddrBitIncIO downto 0);
        out_mem_writeEnable : in std_ulogic; 
        out_mem_readEnable  : in std_ulogic
    );
end entity zpu_bus_trace;


architecture trace of zpu_bus_trace is

    file l_file : text open write_mode is log_file;

    function get_name( mem_addr : std_ulogic_vector(maxAddrBitIncIO downto 0)) return string is
    begin
        case mem_addr is
            when x"80000000" => return("debug console");
            when x"80000100" => return("uart data");
            when x"80000104" => return("uart status");
            when x"80000108" => return("uart control");
            when x"8000010c" => return("uart scaler");
            when x"80000110" => return("uart fifo debug");
            when x"80000200" => return("timer scaler value");
            when x"80000204" => return("timer scaler reload value");
            when x"80000208" => return("timer config");
            when x"80000210" => return("timer 0 counter value");
            when x"80000214" => return("timer 0 reload value");
            when x"80000218" => return("timer 0 control");
            when x"80000220" => return("timer 1 counter value");
            when x"80000224" => return("timer 1 reload value");
            when x"80000228" => return("timer 1 control");
            when x"80000230" => return("timer 2 counter value");
            when x"80000234" => return("timer 2 reload value");
            when x"80000238" => return("timer 2 control");
            when x"80000240" => return("timer 3 counter value");
            when x"80000244" => return("timer 3 reload value");
            when x"80000248" => return("timer 3 control");
            when x"80000250" => return("timer 4 counter value");
            when x"80000254" => return("timer 4 reload value");
            when x"80000258" => return("timer 4 control");
            when x"80000260" => return("timer 5 counter value");
            when x"80000264" => return("timer 5 reload value");
            when x"80000268" => return("timer 5 control");
            when x"80000270" => return("timer 6 counter value");
            when x"80000274" => return("timer 6 reload value");
            when x"80000278" => return("timer 6 control");
            when x"80000280" => return("timer 7 counter value");
            when x"80000284" => return("timer 7 reload value");
            when x"80000288" => return("timer 7 control");
            when x"80000400" => return("gpio data"); 
            when x"80000404" => return("gpio output"); 
            when x"80000408" => return("gpio direction");
            when x"8000040c" => return("gpio interrupt mask"); 
            when x"80000410" => return("gpio interrupt polarity"); 
            when x"80000414" => return("gpio interrupt edge"); 
            when x"80000418" => return("gpio bypss"); 
            when x"80000600" => return("vga data");
            when x"80000604" => return("vga background color");
            when x"80000608" => return("vga foreground color");
            when x"80000700" => return("i2c clock prescaler");
            when x"80000704" => return("i2c control");
            when x"80000708" => return("i2c data");
            when x"8000070c" => return("i2c command/status");
            when x"80000C00" => return("eth control");
            when x"80000C04" => return("eth status/interrupt");
            when x"80000C08" => return("eth MAC address msb");
            when x"80000C0C" => return("eth MAC address lsb");
            when x"80000C10" => return("eth MDIO control/status");
            when x"80000C14" => return("eth tx descriptor");
            when x"80000C18" => return("eth rx descriptor");
            when x"80000C1C" => return("eth EDCL IP");
            when x"80000C20" => return("eth hash table msb");
            when x"80000C24" => return("eth hash table lsb");
            when x"80000e00" => return("dcm ready");
            when x"80000e04" => return("dcm dec ps");
            when x"80000e08" => return("dcm inc ps");
            when x"80000f00" => return("ahb status");
            when x"80000f04" => return("ahb failing address");
            when x"fff00000" => return("sdram control");
            when x"fff00004" => return("sdram config");
            when x"fff00008" => return("sdram power saving");
            when x"fff0000c" => return("sdram reserved");
            when x"fff00010" => return("sdram status read");
            when x"fff00014" => return("sdram phy config 0");
            when x"fff00018" => return("sdram phy config 1");
            when others      => 
                if (mem_addr >= x"00000000") and ( unsigned(mem_addr) < (4 * bram_words)) then return("bram"); end if;
                if (mem_addr >= x"a0000000") and (mem_addr <= x"a0003fff") then return("sram"); end if;
                if (mem_addr >= x"90000000") and (mem_addr <= x"90003fff") then return("ddr ram"); end if;
                return("unkown");
        end case;
    end function get_name;


    function ignore_addr( mem_addr : std_ulogic_vector(maxAddrBitIncIO downto 0)) return boolean is
    begin
        case mem_addr is
            when x"80000000" => return( true); --"debug console";
            when x"80000100" => return( true); --"uart data";
            when x"80000104" => return( true); --"uart status";
            when others      => 
                if (mem_addr >= x"00000000") and ( unsigned(mem_addr) < (4 * bram_words)) then return( true); end if; --"bram");
                return( false);
        end case;
    end function ignore_addr;



begin
    
    
    process
        variable l         : line;
        variable read_addr : std_ulogic_vector(31 downto 0);
    begin
        wait until rising_edge( clk);
        if reset = '1' then
            -- ignore everything
            null;
        else
            if (out_mem_writeEnable = '1') and not ignore_addr( out_mem_addr) then
                wait until in_mem_busy = '0';
                wait until rising_edge( clk);
                print(         "mem write on address: 0x" & hstr(out_mem_addr) & "   data : 0x" & hstr( mem_write) & "  (" & get_name(out_mem_addr) & ")" );
                print( l_file, "mem write on address: 0x" & hstr(out_mem_addr) & "   data : 0x" & hstr( mem_write) & "  (" & get_name(out_mem_addr) & ")" );
            end if; -- mem_write

            if (out_mem_readEnable = '1') and not ignore_addr( out_mem_addr) then
                read_addr := out_mem_addr;
                wait until in_mem_busy = '0';
                wait until rising_edge( clk);
                print(         "mem read  on address: 0x" & hstr(read_addr) & "   data : 0x" & hstr( mem_read) & "  (" & get_name(read_addr) & ")" );
                print( l_file, "mem read  on address: 0x" & hstr(read_addr) & "   data : 0x" & hstr( mem_read) & "  (" & get_name(read_addr) & ")" );
            end if; -- mem_read

        end if; -- reset
    end process;

end architecture trace;