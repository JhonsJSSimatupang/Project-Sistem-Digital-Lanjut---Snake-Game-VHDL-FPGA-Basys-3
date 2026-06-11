library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ps2_keyboard is
    Port (
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        ps2_clk : in STD_LOGIC;
        ps2_data : in STD_LOGIC;
        scan_code : out STD_LOGIC_VECTOR(7 downto 0);
        scan_ready : out STD_LOGIC
    );
end ps2_keyboard;

architecture Behavioral of ps2_keyboard is
    signal ps2_clk_sync : STD_LOGIC_VECTOR(2 downto 0) := "111";
    signal ps2_data_sync : STD_LOGIC_VECTOR(1 downto 0) := "11";
    signal ps2_clk_fall : STD_LOGIC;
    signal bit_count : INTEGER range 0 to 10 := 0;
    signal shift_reg : STD_LOGIC_VECTOR(10 downto 0);
    signal parity_check : STD_LOGIC := '0';
begin
    -- Synchronize PS2 signals to avoid metastability
    process(clk, reset)
    begin
        if reset = '1' then
            ps2_clk_sync <= "111";
            ps2_data_sync <= "11";
        elsif rising_edge(clk) then
            ps2_clk_sync <= ps2_clk_sync(1 downto 0) & ps2_clk;
            ps2_data_sync <= ps2_data_sync(0) & ps2_data;
        end if;
    end process;
    
    -- Detect falling edge of PS2 clock
    ps2_clk_fall <= '1' when ps2_clk_sync = "100" else '0';
    
    -- PS2 data reception
    process (clk, reset)
    begin
        if reset = '1' then
            bit_count <= 0;
            shift_reg <= (others => '0');
            scan_code <= (others => '0');
            scan_ready <= '0';
            parity_check <= '0';
        elsif rising_edge(clk) then
            scan_ready <= '0';
            
            if ps2_clk_fall = '1' then
                if bit_count = 0 then
                    -- Start bit (should be 0)
                    if ps2_data_sync(1) = '0' then
                        bit_count <= bit_count + 1;
                    end if;
                elsif bit_count > 0 and bit_count <= 8 then
                    -- Data bits
                    shift_reg(bit_count-1) <= ps2_data_sync(1);
                    bit_count <= bit_count + 1;
                elsif bit_count = 9 then
                    -- Parity bit
                    parity_check <= ps2_data_sync(1);
                    bit_count <= bit_count + 1;
                elsif bit_count = 10 then
                    -- Stop bit (should be 1)
                    if ps2_data_sync(1) = '1' then
                        -- PARITY CHECK DISABLED FOR COMPATIBILITY
                        scan_code <= shift_reg(7 downto 0);
                        scan_ready <= '1';
                    end if;
                    bit_count <= 0;
                end if;
            end if;
        end if;
    end process;
end Behavioral;