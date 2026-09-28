-- Testbench untuk doorlock5
-- Target: Nexys A7 100T
-- Date: 19 Jan 2026
-- Description: Comprehensive testbench untuk sistem keamanan pintu
--
-- Test scenarios:
-- 1. Password BENAR (normal unlock)
-- 2. Password SALAH
-- 3. Override dari dalam
-- 4. Ubah password (change password mode)
-- 5. Test password baru setelah diubah

library ieee;
use ieee.std_logic_1164.all;

entity tb_doorlock5 is
end tb_doorlock5;

architecture tb of tb_doorlock5 is

    component doorlock5
        port (switch_in    : in std_logic_vector (15 downto 0);
              enter        : in std_logic;
              change_btn   : in std_logic;
              override_btn : in std_logic;
              clk          : in std_logic;
              output       : out std_logic;
              led_change   : out std_logic;
              led_part2    : out std_logic;
              led_override : out std_logic;
              led_error    : out std_logic;
              buzzer       : out std_logic);
    end component;

    signal switch_in    : std_logic_vector (15 downto 0);
    signal enter        : std_logic;
    signal change_btn   : std_logic;
    signal override_btn : std_logic;
    signal clk          : std_logic;
    signal output       : std_logic;
    signal led_change   : std_logic;
    signal led_part2    : std_logic;
    signal led_override : std_logic;
    signal led_error    : std_logic;
    signal buzzer       : std_logic;
    
    -- Clock period definition (100 MHz = 10ns period)
    constant clk_period : time := 10 ns;
    
    -- Password default dari design: 
    -- kode_bagian1 = "0001" & "0010" & "0011" & "0100" (digit 1-4)
    -- kode_bagian2 = "0101" & "0110" & "0111" & "1000" (digit 5-8)
    constant PASSWORD_PART1 : std_logic_vector(15 downto 0) := "0001001000110100";
    constant PASSWORD_PART2 : std_logic_vector(15 downto 0) := "0101011001111000";
    
    -- Password baru untuk test
    constant NEW_PASSWORD_PART1 : std_logic_vector(15 downto 0) := "1001100001010011";
    constant NEW_PASSWORD_PART2 : std_logic_vector(15 downto 0) := "1100101011100001";

begin

    dut : doorlock5
    port map (switch_in    => switch_in,
              enter        => enter,
              change_btn   => change_btn,
              override_btn => override_btn,
              clk          => clk,
              output       => output,
              led_change   => led_change,
              led_part2    => led_part2,
              led_override => led_override,
              led_error    => led_error,
              buzzer       => buzzer);

    -- Clock generation process
    clk_process : process
    begin
        clk <= '0';
        wait for clk_period/2;
        clk <= '1';
        wait for clk_period/2;
    end process;

    -- Stimulus process
    stimuli : process
    begin
        -- Inisialisasi semua signal
        switch_in <= (others => '0');
        enter <= '0';
        change_btn <= '0';
        override_btn <= '0';
        
        -- Tunggu beberapa clock cycles untuk stabilisasi
        wait for 100 ns;
        
        -- ========================================
        -- TEST 1: PASSWORD BENAR (Normal Unlock)
        -- ========================================
        report "TEST 1: Input password BENAR";
        
        -- Input bagian 1 (digit 1-4)
        switch_in <= PASSWORD_PART1;
        wait for 50 ns;
        
        -- Tekan enter
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;  -- Tunggu transisi ke mode input bagian 2
        
        -- Input bagian 2 (digit 5-8)
        switch_in <= PASSWORD_PART2;
        wait for 50 ns;
        
        -- Tekan enter lagi
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        
        -- Tunggu LED hijau menyala 3 detik + buzzer "titt"
        wait for 500000000 ns;  -- 500ms untuk simulasi (seharusnya 3-4 detik)
        
        -- ========================================
        -- TEST 2: PASSWORD SALAH
        -- ========================================
        report "TEST 2: Input password SALAH";
        
        -- Input bagian 1 yang salah
        switch_in <= "1111000011110000";
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;
        
        -- Input bagian 2 yang salah
        switch_in <= "0000111100001111";
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        
        -- Tunggu LED merah + buzzer "tititititit" (7x beep)
        wait for 300000000 ns;  -- 300ms untuk simulasi
        
        -- ========================================
        -- TEST 3: OVERRIDE DARI DALAM
        -- ========================================
        report "TEST 3: Override button dari dalam";
        
        -- Reset switches
        switch_in <= (others => '0');
        wait for 50 ns;
        
        -- Tekan override button
        override_btn <= '1';
        wait for 20 ns;
        override_btn <= '0';
        
        -- Tunggu LED override menyala + buzzer "titt"
        wait for 500000000 ns;  -- 500ms untuk simulasi
        
        -- ========================================
        -- TEST 4: UBAH PASSWORD
        -- ========================================
        report "TEST 4: Ubah password";
        
        -- Step 1: Input password lama yang benar
        switch_in <= PASSWORD_PART1;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;
        
        switch_in <= PASSWORD_PART2;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;
        
        -- Step 2: Tekan change button saat UNLOCKED state
        change_btn <= '1';
        wait for 20 ns;
        change_btn <= '0';
        wait for 100 ns;  -- LED change akan blink
        
        -- Step 3: Input password baru bagian 1
        switch_in <= NEW_PASSWORD_PART1;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;  -- LED part2 akan menyala
        
        -- Step 4: Input password baru bagian 2
        switch_in <= NEW_PASSWORD_PART2;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        
        -- Tunggu konfirmasi (LED hijau 1 detik)
        wait for 200000000 ns;  -- 200ms untuk simulasi
        
        -- ========================================
        -- TEST 5: TEST PASSWORD BARU
        -- ========================================
        report "TEST 5: Test password BARU setelah diubah";
        
        -- Input password baru yang sudah disimpan
        switch_in <= NEW_PASSWORD_PART1;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;
        
        switch_in <= NEW_PASSWORD_PART2;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        
        -- Tunggu unlock dengan password baru
        wait for 500000000 ns;  -- 500ms untuk simulasi
        
        -- ========================================
        -- TEST 6: PASSWORD LAMA (Seharusnya SALAH)
        -- ========================================
        report "TEST 6: Test password LAMA (harus gagal)";
        
        -- Input password lama (seharusnya sudah tidak valid)
        switch_in <= PASSWORD_PART1;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        wait for 100 ns;
        
        switch_in <= PASSWORD_PART2;
        wait for 50 ns;
        
        enter <= '1';
        wait for 20 ns;
        enter <= '0';
        
        -- Tunggu LED error
        wait for 300000000 ns;  -- 300ms untuk simulasi
        
        -- ========================================
        -- SELESAI
        -- ========================================
        report "Simulasi selesai - semua test cases berhasil dijalankan";
        wait;
        
    end process;

end tb;

-- Configuration block below is required by some simulators. Usually no need to edit.
configuration cfg_tb_doorlock5 of tb_doorlock5 is
    for tb
    end for;
end cfg_tb_doorlock5;