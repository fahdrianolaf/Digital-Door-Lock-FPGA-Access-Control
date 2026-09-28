----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/13/2026 02:15:47 PM
-- Design Name: 
-- Module Name: doorlock5 - rtl_arch
-- Project Name: 
-- Target Devices: Nexys A7 100T
-- Tool Versions: 
-- Description: Sistem keamanan pintu dengan verifikasi kode akses dan fitur ubah password
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.04 - Fixed Multiple Driver issue completely
-- Additional Comments:

----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity doorlock5 is
  Port (
    switch_in     : in std_logic_vector(15 downto 0);  -- ini utk mendefisnisikan  port input vektor 16-bit yang utk  16 switch 
    enter         : in std_logic;                      -- ini mendefinisikan tombol enter (N17)
    change_btn    : in std_logic;                      -- ini mendefinisikan tombol ubah password (M17)
    override_btn  : in std_logic;                      -- ini mendefinisikan tombol override (P17)
    clk           : in std_logic;                      -- ini mendefinisikan input sinyal clock, dibawah2 kegunaanya utk timing
    output        : out std_logic;                     -- ini mendefinisikan led v11 kalau password benar
    led_change    : out std_logic;                     -- ini mendefinisikan led h17 kalau mode change password 
    led_part2     : out std_logic;                     -- ini mendefinisikan led v12indikator input bagian 2 (T16)
    led_override  : out std_logic;                     -- LED override M16 (green)
    led_error     : out std_logic;                     -- LED merah N16 (wrong password)
    buzzer        : out std_logic                      -- Buzzer C17
  );
end doorlock5;

architecture Behavioral of doorlock5 is
  -- bagian ini gunanya utk menyimpan kode
  signal segment_awal : std_logic_vector(15 downto 0) := (others => '0');
  signal mode_input   : std_logic := '0';  -- kalo 0  = segmen awal, 1 = segmen akhir
  
  -- untuk indikator dan penanda akses
  signal indikator_aktif : std_logic := '0';
  signal akses_terbuka   : std_logic := '0';
  signal timer_val       : integer := 0;  -- Pencacah waktu
  
  signal kode_bagian1 : std_logic_vector(15 downto 0) := "0001" & "0010" & "0011" & "0100";  -- password default digit 1 samppai 4
  signal kode_bagian2 : std_logic_vector(15 downto 0) := "0101" & "0110" & "0111" & "1000";  -- password default digit 5 sampai 8
  
  -- utk pendeteksi penekanan tombol
  signal enter_prev : std_logic := '0';
  signal tombol_tekan : std_logic := '0';
  
  signal change_prev : std_logic := '0';
  signal change_tekan : std_logic := '0';
  
  signal override_prev : std_logic := '0';
  signal override_tekan : std_logic := '0';
  
  -- fsm
  type state_type is (NORMAL, UNLOCKED, CHANGE_PART1, CHANGE_PART2, OVERRIDE_MODE, WRONG_PASSWORD);
  signal current_state : state_type := NORMAL;
  
  signal new_password_part1 : std_logic_vector(15 downto 0) := (others => '0');
  signal change_mode_led : std_logic := '0';
  signal part2_indicator : std_logic := '0';  -- indikator utk led kalo masuk ke segmen 2
  signal override_indicator : std_logic := '0';  -- indikator utk led kalo mode override
  signal error_indicator : std_logic := '0';  -- indikator utk led kalau password salah
  
  -- utk led kelap kelip pas mode change password
  signal blink_counter : integer := 0; -- untuk jumlah kalo ngeblink lednya
  constant BLINK_PERIOD : integer := 50000000; -- artinya kelap kelip setiap 0,5 ms
  
  -- untuk mengendalikan buzzer
  signal buzzer_active : std_logic := '0';
  signal trigger_correct : std_logic := '0';  -- trigger kalau password benar
  signal trigger_wrong : std_logic := '0';    -- trigger untuk password salah
  signal trigger_override : std_logic := '0'; -- trigger kalau mendeteksi override
  signal buzzer_type : std_logic := '0';     --  -- 0 = wrong (panjang berulang), 1 = correct/override (pendek 1x)
  constant BEEP_SHORT : integer := 10000000;      -- biar ngebeep 100ms sekali kalau password bena
  constant BEEP_LONG : integer := 5000000;        -- 50ms per beep panjang
  constant BEEP_LONG_PAUSE : integer := 5000000;  -- 50ms pause untuk beep panjang
  constant BEEP_REPEAT : integer := 7;            -- Jumlah beep untuk password salah
  
  type buzzer_state_type is (IDLE, BEEPING, PAUSING);
  signal buzzer_state : buzzer_state_type := IDLE;
  signal buzzer_counter : integer := 0;
  signal beep_count : integer := 0;
  
begin
  -- proses utk mendeteksi transisi penekanan tombol enter (menggunakan konsep edge detection)
  process(clk)
  begin
    if rising_edge(clk) then
      tombol_tekan <= enter and (not enter_prev);
      enter_prev <= enter;
    end if;
  end process;
  
  -- proses utk mendeteksi tansisi tombol change password (menggunakan konsep edge detection) 
  process(clk)
  begin
    if rising_edge(clk) then
      change_tekan <= change_btn and (not change_prev);
      change_prev <= change_btn;
    end if;
  end process;
  
  -- proses utk mendeteksi transisi tombol override (menggunakan konsep edge detection)
  process(clk)
  begin
    if rising_edge(clk) then
      override_tekan <= override_btn and (not override_prev);
      override_prev <= override_btn;
    end if;
  end process;
  
  -- proses agar led berkedip pas lgi mode change password LED
  process(clk)
  begin
    if rising_edge(clk) then
      if current_state = CHANGE_PART1 or current_state = CHANGE_PART2 then
        if blink_counter < BLINK_PERIOD then
          blink_counter <= blink_counter + 1;
        else
          change_mode_led <= not change_mode_led;
          blink_counter <= 0;
        end if;
      else
        change_mode_led <= '0';
        blink_counter <= 0;
      end if;
    end if;
  end process;
  
  -- process sistem pas mode default
  process(clk)
  begin
    if rising_edge(clk) then
      -- ini kegunaanya biar reset trigger setiap satu cycle
      trigger_correct <= '0';
      trigger_wrong <= '0';
      trigger_override <= '0';
      
      -- ini logika biar override bisa ditekan kapan saja
      if override_tekan = '1' and current_state /= OVERRIDE_MODE then
        current_state <= OVERRIDE_MODE;
        indikator_aktif <= '1';
        override_indicator <= '1';
        akses_terbuka <= '1';
        error_indicator <= '0';
        timer_val <= 0;
        trigger_override <= '1';  -- ini utk trigger buzzer saat override tertekan
      else
        case current_state is
        
        when NORMAL =>
          -- ini saat mode normal, yakni bagian masukin password bagian 1
          part2_indicator <= mode_input;  -- ini utk mengupdate indikator bagian 2
          
          if tombol_tekan = '1' then
            if mode_input = '0' then
            -- ini tahap 1, yakni mengstore segment prtama
              segment_awal <= switch_in;
              mode_input <= '1';
            else
              -- ini tahap 2, yakni mengcompare segment pertama dan segment kedua
              if (segment_awal & switch_in) = (kode_bagian1 & kode_bagian2) then
                -- ini logika jika password yg dimasukkan benar
                current_state <= UNLOCKED;
                akses_terbuka <= '1';
                indikator_aktif <= '1';
                error_indicator <= '0';
                timer_val <= 0;
                trigger_correct <= '1';  -- ini menyebabkan trigger berbunyi 2 kali
              else
                -- ini logika jika password yg dimasukkan salah
                current_state <= WRONG_PASSWORD;
                akses_terbuka <= '0';
                indikator_aktif <= '0';
                error_indicator <= '1';
                timer_val <= 0;
                trigger_wrong <= '1';  -- ini bakal trigger buzzer 1x
              end if;
              mode_input <= '0';
            end if;
          end if;
        
        when WRONG_PASSWORD =>
        -- ini indikator jika password salah, led akan menyala selama 2 detik
          part2_indicator <= '0';
          
          if timer_val < 199999999 then  -- waktu (s) = (nilai_counter + 1) / frekuensi_clock, ini membuat waktu selama 2 detik
          -- waktu (s) = (199999999 + 1) / 100 juta = 200 juta / 100 juta = 2 
            timer_val <= timer_val + 1;
          else
            -- ini yg terjadi jika 2 detik sudah berlalu, maka sistem akan kembali ke mode normal
            current_state <= NORMAL;
            error_indicator <= '0';
            timer_val <= 0;
          end if;
        
        when UNLOCKED =>
          -- ini indikator jika password benar, maka led akan menyala selama 4 detik
          -- dalam jangka waktu 4 detik ini, kita bisa tekan tombol change password
          part2_indicator <= '0';  -- ini kegunaannya utk mengreset led yg menandakan kita sedang menginput segment bagian 2
          error_indicator <= '0';
          
          if change_tekan = '1' then
            -- ini yg terjadi jika sudah menekan tombol mode change password 
            current_state <= CHANGE_PART1;
            indikator_aktif <= '0';
            akses_terbuka <= '0';
            timer_val <= 0;
          elsif timer_val < 399999999 then  -- ini akan menyebabkan waktu selama 4 detik
            timer_val <= timer_val + 1;
          else
            -- ini yg terjadi jika 4 detik sudah lewat, mode akan kembali ke mode normal
            current_state <= NORMAL;
            indikator_aktif <= '0';
            akses_terbuka <= '0';
            timer_val <= 0;
          end if;
        
        when CHANGE_PART1 =>
        -- ini logika input bagian 1 saat mode ganti password
          part2_indicator <= '0';  -- karena kita masih bagian 1, lampu v12 harus mati
          error_indicator <= '0';
          
          if tombol_tekan = '1' then
            new_password_part1 <= switch_in;
            current_state <= CHANGE_PART2;
          end if;
        
        when CHANGE_PART2 =>
          -- ini logika input bagian 2 saat mode ganti password
          part2_indicator <= '1';  -- karena berada di bagian 2, lampu v12 harus menyala
          error_indicator <= '0';
          
          if tombol_tekan = '1' then
            -- ini kegunaannya utk mengstore password yg baru Simpan password baru
            kode_bagian1 <= new_password_part1;
            kode_bagian2 <= switch_in; -- password bagian 2 didefinisikan sebagai switch_in karena itu merupakan bagian yg 
            -- ini kegunaanya utk mengindikasikan dengan led menyala
            indikator_aktif <= '1';
            timer_val <= 0;
            current_state <= NORMAL;
          end if;
        
        when OVERRIDE_MODE =>
        -- ini yg terjadi jika kita menekan tombol overide
          -- mode override aktif, yang kegunaanya mengsimulasikan pintu terbuka dari dalam
          part2_indicator <= '0';  -- ini utk mematikan lampu v12 karena kita tidak sedang menginput kode bagian 2
          error_indicator <= '0';
          
          if timer_val < 399999999 then  -- pas tekan tombol override ada waktu 4 detik sebelum pintu terkunci dan lampu v11 mati 
            timer_val <= timer_val + 1;
          else
            -- kalau 4 detik sudah berlalu, maka sistem akan kembali ke mode normal
            current_state <= NORMAL;
            indikator_aktif <= '0';
            override_indicator <= '0';
            akses_terbuka <= '0';
            timer_val <= 0;
          end if;
        
      end case;
      end if;
      
      -- Auto-off LED konfirmasi setelah ubah password
      -- ini kegunaanya utk mematikan led kelap kelip setelah sudah mengubah password
      if current_state = NORMAL and indikator_aktif = '1' and akses_terbuka = '0' then
        if timer_val < 99999999 then  -- 1 detik
          timer_val <= timer_val + 1;
        else
          indikator_aktif <= '0';
          timer_val <= 0;
        end if;
      end if;
      
    end if;
  end process;
  
  -- ini utk mengkontrol buzzer 
  process(clk)
  begin
    if rising_edge(clk) then
      case buzzer_state is
        when IDLE =>
          buzzer_active <= '0';
          buzzer_counter <= 0;
          beep_count <= 0;
          
          -- ini kegunaanya utk mendeteksi trigger dari state machine
          if trigger_wrong = '1' then
            buzzer_state <= BEEPING;
            buzzer_type <= '0';  -- ini yg terjadi jika password salah, bakal ada beep panjang yg berulang 
            beep_count <= 0;
          elsif trigger_correct = '1' or trigger_override = '1' then
            buzzer_state <= BEEPING;
            buzzer_type <= '1';  -- ini yg terjadi jika password benar, bakal ada beep pendek 1x 
            beep_count <= 0;
          end if;
        
        when BEEPING =>
          buzzer_active <= '1';
          
          if buzzer_type = '1' then
            -- pada password benar, bakal ada 1 beep selama 100ms
            if buzzer_counter < BEEP_SHORT then
              buzzer_counter <= buzzer_counter + 1;
            else
              buzzer_state <= IDLE;
              buzzer_counter <= 0;
            end if;
          else
            -- pada password salah, bakal ada beep pendek tapi berulang ulang, tiap beep jeda waktunya 50ms
            if buzzer_counter < BEEP_LONG then
              buzzer_counter <= buzzer_counter + 1;
            else
              buzzer_counter <= 0;
              beep_count <= beep_count + 1;
              
              if beep_count + 1 >= BEEP_REPEAT then
                -- ini utk selesaikan semua beep
                buzzer_state <= IDLE;
              else
                -- ini bakal membuat beep lagi
                buzzer_state <= PAUSING;
              end if;
            end if;
          end if;
        
        when PAUSING =>
          buzzer_active <= '0';
          if buzzer_counter < BEEP_LONG_PAUSE then
            buzzer_counter <= buzzer_counter + 1;
          else
            buzzer_counter <= 0;
            buzzer_state <= BEEPING;
          end if;
      
      end case;
    end if;
  end process;
  
  output <= indikator_aktif;
  led_change <= change_mode_led;
  led_part2 <= part2_indicator;  -- ini kegunaanya utk mengaktifkan led V12 saat mau input bagian 2 
  led_override <= override_indicator;  -- ini kegunaanya utk mengaktifkan led M16 (hijau) saat override aktif
  led_error <= error_indicator;  -- ini kegunaanya utk mengaktifkan led N16 (merah) saat password salah
  buzzer <= buzzer_active;  -- ini utk mengaktifkan buzzer yg pinnya C17
  
end Behavioral;