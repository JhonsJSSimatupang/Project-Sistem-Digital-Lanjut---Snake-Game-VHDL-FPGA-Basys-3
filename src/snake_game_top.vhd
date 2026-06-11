library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity snake_game_top is
    Port ( 
        clk : in STD_LOGIC;
        reset : in STD_LOGIC;
        PS2_CLK : in STD_LOGIC;
        PS2_DATA : in STD_LOGIC;
        vgaRed : out STD_LOGIC_VECTOR(3 downto 0);
        vgaGreen : out STD_LOGIC_VECTOR(3 downto 0);
        vgaBlue : out STD_LOGIC_VECTOR(3 downto 0);
        Hsync : out STD_LOGIC;
        Vsync : out STD_LOGIC
    );
end snake_game_top;

architecture Behavioral of snake_game_top is
    -- VGA timing constants
    constant H_DISPLAY : integer := 640;
    constant H_FRONT : integer := 16;
    constant H_SYNC : integer := 96;
    constant H_BACK : integer := 48;
    constant H_TOTAL : integer := 800;
    
    constant V_DISPLAY : integer := 480;
    constant V_FRONT : integer := 10;
    constant V_SYNC : integer := 2;
    constant V_BACK : integer := 33;
    constant V_TOTAL : integer := 525;
    
    constant GRID_SIZE : integer := 30;
    constant GRID_WIDTH : integer := 21;
    constant GRID_HEIGHT : integer := 16;
    constant MAX_LENGTH : integer := 100;
    
    -- Clock signals
    signal clk_25MHz : std_logic := '0';
    signal div_cnt : unsigned(1 downto 0) := (others => '0');
    signal pix_en : std_logic := '0';
    
    -- VGA signals
    signal h_count : integer range 0 to H_TOTAL-1 := 0;
    signal v_count : integer range 0 to V_TOTAL-1 := 0;
    signal video_on : std_logic;
    
    -- PS/2 Keyboard
    signal scan_code : std_logic_vector(7 downto 0);
    signal scan_ready : std_logic;
    signal prev_scan_ready : std_logic := '0';
    signal ignore_next_scan : std_logic := '0';
    
    -- Game signals
    type position_array is array (0 to MAX_LENGTH-1) of integer;
    signal snake_x : position_array := (others => -1);
    signal snake_y : position_array := (others => -1);
    signal snake_length : integer range 1 to MAX_LENGTH := 3;
    signal food_x : integer range 0 to GRID_WIDTH-1 := 5;
    signal food_y : integer range 0 to GRID_HEIGHT-1 := 5;
    signal food_visible : std_logic := '1';
    
    signal direction : integer range 0 to 3 := 0; -- 0:Right, 1:Down, 2:Left, 3:Up
    signal game_over : std_logic := '0';
    signal game_started : std_logic := '0';
    signal score : integer range 0 to 999 := 0;
    
    signal game_clk : std_logic := '0';
    signal frame_counter : unsigned(23 downto 0) := (others => '0');
    
    constant GAME_SPEED : integer := 10000000; -- Kecepatan lambat (10fps)
    
    signal food_counter : unsigned(7 downto 0) := (others => '0');
    
    -- PS/2 Component
    component ps2_keyboard
        Port (
            clk : in STD_LOGIC;
            reset : in STD_LOGIC;
            ps2_clk : in STD_LOGIC;
            ps2_data : in STD_LOGIC;
            scan_code : out STD_LOGIC_VECTOR(7 downto 0);
            scan_ready : out STD_LOGIC
        );
    end component;
    
    -- Char ROM (Index 0-36)
    type char_rom_type is array (0 to 36, 0 to 15) of std_logic_vector(7 downto 0);
    constant CHAR_ROM : char_rom_type := (
        -- A-Z (0-25)
        (x"18", x"24", x"42", x"66", x"66", x"7E", x"66", x"66", x"66", x"66", x"66", x"66", x"00", x"00", x"00", x"00"), -- A
        (x"FC", x"66", x"66", x"66", x"66", x"7C", x"66", x"66", x"66", x"66", x"66", x"FC", x"00", x"00", x"00", x"00"), -- B
        (x"3C", x"66", x"60", x"60", x"60", x"60", x"60", x"60", x"60", x"60", x"66", x"3C", x"00", x"00", x"00", x"00"),
        (x"F8", x"6C", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"6C", x"F8", x"00", x"00", x"00", x"00"),
        (x"FE", x"62", x"60", x"68", x"78", x"68", x"60", x"60", x"62", x"62", x"FE", x"00", x"00", x"00", x"00", x"00"),
        (x"FE", x"62", x"60", x"68", x"78", x"68", x"60", x"60", x"60", x"60", x"F0", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"60", x"60", x"60", x"6E", x"66", x"66", x"66", x"66", x"3E", x"00", x"00", x"00", x"00", x"00"),
        (x"66", x"66", x"66", x"66", x"7E", x"66", x"66", x"66", x"66", x"66", x"66", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"3C", x"00", x"00", x"00", x"00", x"00"),
        (x"1E", x"0C", x"0C", x"0C", x"0C", x"0C", x"0C", x"CC", x"CC", x"CC", x"78", x"00", x"00", x"00", x"00", x"00"),
        (x"E6", x"66", x"6C", x"78", x"78", x"6C", x"6C", x"66", x"66", x"E6", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"F0", x"60", x"60", x"60", x"60", x"60", x"60", x"60", x"62", x"62", x"FE", x"00", x"00", x"00", x"00", x"00"),
        (x"C6", x"EE", x"FE", x"D6", x"C6", x"C6", x"C6", x"C6", x"C6", x"C6", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"C6", x"E6", x"F6", x"DE", x"CE", x"C6", x"C6", x"C6", x"C6", x"E6", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"3C", x"00", x"00", x"00", x"00", x"00"),
        (x"FC", x"66", x"66", x"66", x"7C", x"60", x"60", x"60", x"60", x"F0", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"66", x"66", x"66", x"66", x"66", x"D6", x"66", x"3B", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"FC", x"66", x"66", x"66", x"7C", x"6C", x"66", x"66", x"66", x"E6", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"60", x"30", x"1C", x"06", x"06", x"06", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"7E", x"5A", x"18", x"18", x"18", x"18", x"18", x"18", x"18", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"66", x"66", x"66", x"66", x"66", x"3C", x"3C", x"18", x"18", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"C6", x"C6", x"C6", x"C6", x"D6", x"FE", x"EE", x"C6", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"C6", x"C6", x"6C", x"38", x"38", x"1C", x"6C", x"C6", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"66", x"66", x"66", x"3C", x"18", x"18", x"18", x"18", x"3C", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"FE", x"86", x"0C", x"18", x"18", x"30", x"60", x"C2", x"FE", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        -- 0-9 (26-35)
        (x"3C", x"66", x"76", x"7E", x"6E", x"66", x"66", x"66", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"18", x"38", x"78", x"18", x"18", x"18", x"18", x"18", x"18", x"7E", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"66", x"06", x"0C", x"18", x"30", x"60", x"66", x"7E", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"06", x"06", x"1C", x"06", x"06", x"06", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"0C", x"1C", x"3C", x"6C", x"CC", x"FE", x"0C", x"0C", x"0C", x"00", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"7E", x"60", x"60", x"7C", x"06", x"06", x"06", x"06", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"60", x"7C", x"66", x"66", x"66", x"66", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"7E", x"66", x"06", x"06", x"0C", x"18", x"18", x"30", x"30", x"30", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"66", x"66", x"3C", x"66", x"66", x"66", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        (x"3C", x"66", x"66", x"66", x"66", x"3E", x"06", x"06", x"66", x"3C", x"00", x"00", x"00", x"00", x"00", x"00"),
        -- SPACE / KOSONG (Index 36)
        (x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00", x"00")
    );
    
    function char_to_index(c: character) return integer is
    begin
        if c >= 'A' and c <= 'Z' then
            return character'pos(c) - character'pos('A');
        elsif c >= '0' and c <= '9' then
            return character'pos(c) - character'pos('0') + 26;
        else
            return 36; -- Default Spasi
        end if;
    end function;
    
    function get_char_pixel(char_index: integer; char_x: integer; char_y: integer) return std_logic is
        variable pixel_bit : std_logic;
    begin
        pixel_bit := '0';
        if char_index >= 0 and char_index <= 36 and char_x >= 0 and char_x < 8 and char_y >= 0 and char_y < 16 then
            pixel_bit := CHAR_ROM(char_index, char_y)(7 - char_x);
        end if;
        return pixel_bit;
    end function;
    
begin
    -- PS/2 Keyboard instance
    keyboard: ps2_keyboard
        port map (
            clk => clk,
            reset => reset,
            ps2_clk => PS2_CLK,
            ps2_data => PS2_DATA,
            scan_code => scan_code,
            scan_ready => scan_ready
        );
    
    -- Clock divider
    process(clk, reset)
    begin
        if reset = '1' then
            div_cnt <= (others => '0');
            pix_en <= '0';
        elsif rising_edge(clk) then
            if div_cnt = "11" then
                div_cnt <= (others => '0');
                pix_en <= '1';
            else
                div_cnt <= div_cnt + 1;
                pix_en <= '0';
            end if;
        end if;
    end process;
    
    -- VGA timing
    process(clk, reset)
    begin
        if reset = '1' then
            h_count <= 0;
            v_count <= 0;
        elsif rising_edge(clk) then
            if pix_en = '1' then
                if h_count = H_TOTAL-1 then
                    h_count <= 0;
                    if v_count = V_TOTAL-1 then
                        v_count <= 0;
                    else
                        v_count <= v_count + 1;
                    end if;
                else
                    h_count <= h_count + 1;
                end if;
            end if;
        end if;
    end process;
    
    Hsync <= '0' when (h_count >= H_DISPLAY + H_FRONT and h_count < H_DISPLAY + H_FRONT + H_SYNC) else '1';
    Vsync <= '0' when (v_count >= V_DISPLAY + V_FRONT and v_count < V_DISPLAY + V_FRONT + V_SYNC) else '1';
    video_on <= '1' when (h_count < H_DISPLAY and v_count < V_DISPLAY) else '0';
    
    -- Game clock
    process(clk, reset)
    begin
        if reset = '1' then
            frame_counter <= (others => '0');
            game_clk <= '0';
            food_counter <= (others => '0');
        elsif rising_edge(clk) then
            food_counter <= food_counter + 1;
            if frame_counter >= GAME_SPEED then
                frame_counter <= (others => '0');
                game_clk <= '1';
            else
                frame_counter <= frame_counter + 1;
                game_clk <= '0';
            end if;
        end if;
    end process;
    
    -- Input Handler
    process(clk, reset)
    begin
        if reset = '1' then
            direction <= 0;
            game_started <= '0';
            ignore_next_scan <= '0';
            prev_scan_ready <= '0';
        elsif rising_edge(clk) then
            prev_scan_ready <= scan_ready;
            
            if scan_ready = '1' and prev_scan_ready = '0' then
                if scan_code = X"F0" then
                    ignore_next_scan <= '1';
                else
                    if ignore_next_scan = '1' then
                        ignore_next_scan <= '0'; 
                    else
                        case scan_code is
                            when X"5A" => -- ENTER
                                if game_started = '0' or game_over = '1' then
                                    game_started <= '1';
                                end if;
                            when X"1D" => -- W
                                if game_started = '1' and game_over = '0' and direction /= 1 then
                                    direction <= 3;
                                end if;
                            when X"1B" => -- S
                                if game_started = '1' and game_over = '0' and direction /= 3 then
                                    direction <= 1;
                                end if;
                            when X"1C" => -- A
                                if game_started = '1' and game_over = '0' and direction /= 0 then
                                    direction <= 2;
                                end if;
                            when X"23" => -- D
                                if game_started = '1' and game_over = '0' and direction /= 2 then
                                    direction <= 0;
                                end if;
                            when others => null;
                        end case;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- Game logic
    process(clk, reset)
        variable new_x, new_y : integer;
        variable collision : std_logic;
        variable temp_food_x, temp_food_y : integer;
        variable food_on_snake : std_logic;
        variable rand_val : unsigned(7 downto 0);
    begin
        if reset = '1' then
            snake_length <= 3;
            snake_x <= (others => -1);
            snake_y <= (others => -1);
            snake_x(0) <= 10; snake_y(0) <= 8;
            snake_x(1) <= 9;  snake_y(1) <= 8;
            snake_x(2) <= 8;  snake_y(2) <= 8;
            
            food_x <= 5;
            food_y <= 5;
            food_visible <= '1';
            game_over <= '0';
            score <= 0;
        elsif rising_edge(clk) then
            if scan_ready = '1' and prev_scan_ready = '0' and ignore_next_scan = '0' then
                if scan_code = X"5A" and (game_started = '0' or game_over = '1') then
                    snake_length <= 3;
                    snake_x <= (others => -1);
                    snake_y <= (others => -1);
                    snake_x(0) <= 10; snake_y(0) <= 8;
                    snake_x(1) <= 9;  snake_y(1) <= 8;
                    snake_x(2) <= 8;  snake_y(2) <= 8;
                    
                    food_x <= 5;
                    food_y <= 5;
                    food_visible <= '1';
                    game_over <= '0';
                    score <= 0;
                end if;
            end if;
            
            if game_clk = '1' and game_over = '0' and game_started = '1' then
                new_x := snake_x(0);
                new_y := snake_y(0);
                
                case direction is
                    when 0 => new_x := new_x + 1;
                    when 1 => new_y := new_y + 1;
                    when 2 => new_x := new_x - 1;
                    when 3 => new_y := new_y - 1;
                    when others => null;
                end case;
                
                if new_x < 0 or new_x >= GRID_WIDTH or new_y < 0 or new_y >= GRID_HEIGHT then
                    game_over <= '1';
                else
                    collision := '0';
                    for i in 1 to MAX_LENGTH-1 loop
                        if i < snake_length then
                            if new_x = snake_x(i) and new_y = snake_y(i) then
                                collision := '1';
                            end if;
                        end if;
                    end loop;
                    
                    if collision = '1' then
                        game_over <= '1';
                    else
                        for i in MAX_LENGTH-1 downto 1 loop
                            snake_x(i) <= snake_x(i-1);
                            snake_y(i) <= snake_y(i-1);
                        end loop;
                        
                        snake_x(0) <= new_x;
                        snake_y(0) <= new_y;
                        
                        if new_x = food_x and new_y = food_y and food_visible = '1' then
                            if snake_length < MAX_LENGTH then
                                snake_length <= snake_length + 1;
                            end if;
                            if score < 999 then
                                score <= score + 1;
                            end if;
                            
                            food_visible <= '0';
                            
                            rand_val := food_counter + to_unsigned(score, 8);
                            temp_food_x := to_integer(rand_val) mod (GRID_WIDTH - 4) + 2;
                            temp_food_y := to_integer(rand_val * 13) mod (GRID_HEIGHT - 4) + 2;
                            
                            food_on_snake := '0';
                            for i in 0 to MAX_LENGTH-1 loop
                                if i < snake_length then
                                    if temp_food_x = snake_x(i) and temp_food_y = snake_y(i) then
                                        food_on_snake := '1';
                                    end if;
                                end if;
                            end loop;
                            
                            if food_on_snake = '1' then
                                temp_food_x := (temp_food_x + 5) mod GRID_WIDTH;
                                temp_food_y := (temp_food_y + 7) mod GRID_HEIGHT;
                            end if;
                            
                            food_x <= temp_food_x;
                            food_y <= temp_food_y;
                            food_visible <= '1';
                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    -- VGA Rendering (Updated with Score and Eyes)
    process(video_on, h_count, v_count, game_started, game_over, snake_x, snake_y, snake_length, food_x, food_y, food_visible, score, direction)
        variable grid_x, grid_y : integer;
        variable is_snake : std_logic;
        variable is_eye : std_logic;
        variable desert_pattern : std_logic;
        variable char_x, char_y : integer;
        variable char_idx : integer;
        variable show_text : std_logic;
        variable rel_x, rel_y : integer; -- Koordinat relatif dalam satu blok grid
        
        -- Score display variables
        variable score_hundreds : integer;
        variable score_tens : integer;
        variable score_units : integer;
        
        constant START_TEXT : string := "PRESS ENTER";
        constant OVER_TEXT : string := "GAME OVER";
        constant SCORE_LABEL : string := "SCORE:";
    begin
        vgaRed <= "0000";
        vgaGreen <= "0000";
        vgaBlue <= "0000";
        
        if video_on = '1' then
            grid_x := h_count / GRID_SIZE;
            grid_y := v_count / GRID_SIZE;
            
            is_snake := '0';
            is_eye := '0';
            show_text := '0';
            
            -- Score decomposition
            score_hundreds := score / 100;
            score_tens := (score / 10) mod 10;
            score_units := score mod 10;
            
            -- Check snake body and Eyes
            for i in 0 to MAX_LENGTH-1 loop
                if i < snake_length then
                    if grid_x = snake_x(i) and grid_y = snake_y(i) then
                        if snake_x(i) >= 0 and snake_y(i) >= 0 then
                            is_snake := '1';
                            
                            -- Logic MATA ULAR (Hanya di kepala / i=0)
                            if i = 0 then
                                rel_x := h_count mod GRID_SIZE;
                                rel_y := v_count mod GRID_SIZE;
                                
                                -- Buat mata hitam 4x4 pixel berdasarkan arah
                                case direction is
                                    when 0 => -- Right: Eyes on right side
                                        if (rel_x > 20 and rel_x < 25) and ((rel_y > 5 and rel_y < 10) or (rel_y > 20 and rel_y < 25)) then
                                            is_eye := '1';
                                        end if;
                                    when 1 => -- Down: Eyes on bottom side
                                        if (rel_y > 20 and rel_y < 25) and ((rel_x > 5 and rel_x < 10) or (rel_x > 20 and rel_x < 25)) then
                                            is_eye := '1';
                                        end if;
                                    when 2 => -- Left: Eyes on left side
                                        if (rel_x > 5 and rel_x < 10) and ((rel_y > 5 and rel_y < 10) or (rel_y > 20 and rel_y < 25)) then
                                            is_eye := '1';
                                        end if;
                                    when 3 => -- Up: Eyes on top side
                                        if (rel_y > 5 and rel_y < 10) and ((rel_x > 5 and rel_x < 10) or (rel_x > 20 and rel_x < 25)) then
                                            is_eye := '1';
                                        end if;
                                    when others => null;
                                end case;
                            end if;
                        end if;
                    end if;
                end if;
            end loop;
            
            -- Desert background
            desert_pattern := '0';
            if ((h_count / 4) mod 3 = 0) or ((v_count / 3) mod 5 = 0) then
                desert_pattern := '1';
            end if;
            
            -- 1. SCORE DISPLAY (Pojok Kanan Atas) - Selalu Tampil
            if v_count >= 20 and v_count < 36 then
                char_y := v_count - 20;
                
                -- Gambar Label "SCORE:" di x=480
                for i in 0 to SCORE_LABEL'length-1 loop
                    if h_count >= 480 + i*12 and h_count < 480 + i*12 + 8 then
                        char_x := h_count - (480 + i*12);
                        char_idx := char_to_index(SCORE_LABEL(i+1));
                        if get_char_pixel(char_idx, char_x, char_y) = '1' then
                            show_text := '1';
                        end if;
                    end if;
                end loop;
                
                -- Gambar Angka Score di x=560
                -- Ratusan
                if h_count >= 560 and h_count < 568 then
                    char_x := h_count - 560;
                    char_idx := score_hundreds + 26; -- 0 starts at index 26
                    if get_char_pixel(char_idx, char_x, char_y) = '1' then
                        show_text := '1';
                    end if;
                end if;
                -- Puluhan
                if h_count >= 572 and h_count < 580 then
                    char_x := h_count - 572;
                    char_idx := score_tens + 26;
                    if get_char_pixel(char_idx, char_x, char_y) = '1' then
                        show_text := '1';
                    end if;
                end if;
                -- Satuan
                if h_count >= 584 and h_count < 592 then
                    char_x := h_count - 584;
                    char_idx := score_units + 26;
                    if get_char_pixel(char_idx, char_x, char_y) = '1' then
                        show_text := '1';
                    end if;
                end if;
            end if;

            -- 2. CENTER TEXT (Press Enter / Game Over)
            if game_started = '0' and game_over = '0' then
                if v_count >= 210 and v_count < 226 then
                    char_y := v_count - 210;
                    for i in 0 to START_TEXT'length-1 loop
                        if h_count >= 230 + i*12 and h_count < 230 + i*12 + 8 then
                            char_x := h_count - (230 + i*12);
                            char_idx := char_to_index(START_TEXT(i+1));
                            if get_char_pixel(char_idx, char_x, char_y) = '1' then
                                show_text := '1';
                            end if;
                        end if;
                    end loop;
                end if;
            elsif game_over = '1' then
                if v_count >= 210 and v_count < 226 then
                    char_y := v_count - 210;
                    for i in 0 to OVER_TEXT'length-1 loop
                        if h_count >= 260 + i*12 and h_count < 260 + i*12 + 8 then
                            char_x := h_count - (260 + i*12);
                            char_idx := char_to_index(OVER_TEXT(i+1));
                            if get_char_pixel(char_idx, char_x, char_y) = '1' then
                                show_text := '1';
                            end if;
                        end if;
                    end loop;
                end if;
            end if;
            
            -- PRIORITY RENDERING
            if show_text = '1' then
                if game_over = '1' and (v_count >= 210) then -- Game Over Text is Red
                    vgaRed <= "1111"; vgaGreen <= "0000"; vgaBlue <= "0000";
                else -- Score Text and Start Text are White
                    vgaRed <= "1111"; vgaGreen <= "1111"; vgaBlue <= "1111";
                end if;
            elsif is_eye = '1' then -- MATA ULAR (Hitam)
                vgaRed <= "0000";
                vgaGreen <= "0000";
                vgaBlue <= "0000";
            elsif is_snake = '1' then -- BADAN ULAR (Hijau)
                vgaRed <= "0000";
                vgaGreen <= "1111";
                vgaBlue <= "0000";
            elsif grid_x = food_x and grid_y = food_y and food_visible = '1' then -- MAKANAN (Merah)
                vgaRed <= "1111";
                vgaGreen <= "0000";
                vgaBlue <= "0000";
            else -- BACKGROUND
                if desert_pattern = '1' then
                    vgaRed <= "1110"; vgaGreen <= "1100"; vgaBlue <= "0100";
                else
                    vgaRed <= "1101"; vgaGreen <= "1010"; vgaBlue <= "0010";
                end if;
            end if;
        end if;
    end process;
    
end Behavioral;