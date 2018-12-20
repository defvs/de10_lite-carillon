-- Projet DE10-LITE; DUT GEII SALON 2018-2019; SIN1 TP VHDL
-- Auteur : Daniel THIRION Gr1A
-- Nom : Generateur1A.vhd
-- Carte : DE10-LITE (MAX10 Family - 50K LE)
-- Description :
--     Cette description logique a pour but de générer différents signaux numériques et analogiques, puis de les
--     sortir sur la fiche VGA.
--     Trois signaux seront générés à partir de l'horloge interne de 50MHz de la carte (que l'on pourra diviser par un facteur)
--         - Dent de scie
--         - Sinusoidale
--         - PWM (Modulation en largeur d'impulsions ou MLI en français)
-- 
-- L'horloge d'entrée de 50Mhz pourra être divisée par un facteur déterminé par les switch (facteur sur 10 bits, 0 à 1023)

library ieee ;
	use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity Generateur1A is
  port (
    MAX10_CLK1_50 : in std_logic; -- Horloge 50Mhz de la carte
    GPIO : buffer std_logic_vector(1 downto 0); -- Sorties GPIO
    -- KEY : in std_logic_vector(1 downto 0);
    SW : in unsigned(5 downto 0);
    HEX0 : out std_logic_vector(0 downto 0);
    LEDR : out unsigned(4 downto 0);
    VGA_R : out unsigned(3 downto 0); -- DAC sortie rouge du connecteur D-SUB
    VGA_B : out unsigned(3 downto 0) -- DAC sortie bleue du connecteur D-SUB
  );
end Generateur1A ;

architecture arch of Generateur1A is
    signal counter : unsigned(24 downto 0); -- Compteur de division de l'horloge
    signal sawtooth_value : unsigned(3 downto 0); -- Valeure actuelle du dent de scie
    signal sine_value : unsigned(3 downto 0); -- Valeur actuelle du sinus
    signal pwm_counter : unsigned(3 downto 0); -- Compteur de rampe pour la modulation d'impulsion

    alias noteSW is SW(5 downto 2);
    alias setupMode is SW(1);
    alias setupNext is SW(0);

    signal break : std_logic;
    signal breakCounter : std_logic;

    -- signal playedNote : unsigned(3 downto 0);
    signal speedCounter : unsigned(24 downto 0);
    signal playClock : std_logic;
    signal currentfreq : unsigned(24 downto 0);
    signal pause : std_logic;
    signal currentNote : unsigned(4 downto 0) := "00000";

    type NOTE_SHEET_TYPE is array(0 to 31) of unsigned(3 downto 0);
    signal NOTE_SHEET : NOTE_SHEET_TYPE;

    -- Carillon personalisé
    signal setupNoteCounter : unsigned(4 downto 0) := "00000";
    -- signal setupMode : std_logic := '0';
begin

    clk_div : process( MAX10_CLK1_50 ) -- Diviseur d'horloge
    begin
        if rising_edge(MAX10_CLK1_50) and (pause = '0') and (break = '0') then
            if counter = (currentfreq) then
                counter <= to_unsigned(0, counter'length); -- Reset du compteur, on a atteint la division
                GPIO(0) <= not GPIO(0); -- On inverse l'état de notre nouvelle horloge
            else
                counter <= counter + 1; -- Incrémentation du compteur
            end if ;
        end if ;
    end process ; -- clk_div

    carillon_clkdiv : process( MAX10_CLK1_50 )
    begin
        if rising_edge( MAX10_CLK1_50 ) then
            if speedCounter = 12500000 then
                speedCounter <= to_unsigned(0,counter'length);
                playClock <= not playClock;
                break <= '0';
                breakCounter <= not breakCounter;
            else
                speedCounter <= speedCounter + 1;
            end if ;

            if speedCounter = 10000000 and breakCounter = '1' then
                break <= '1';
            end if ;
        end if ;
    end process ; -- carillon_clkdiv

    carillon_read : process( playClock )
    begin
        if (rising_edge(playClock) and setupMode = '0') then
            case( to_integer(NOTE_SHEET(to_integer(currentNote))) ) is
                when 1 => currentfreq <= to_unsigned(11928,currentfreq'length); pause <= '0';
                when 2 => currentfreq <= to_unsigned(10629,currentfreq'length); pause <= '0';
                when 3 => currentfreq <= to_unsigned(9470,currentfreq'length); pause <= '0';
                when 4 => currentfreq <= to_unsigned(8929,currentfreq'length); pause <= '0';
                when 5 => currentfreq <= to_unsigned(7972,currentfreq'length); pause <= '0';
                when 6 => currentfreq <= to_unsigned(7102,currentfreq'length); pause <= '0';
                when 7 => currentfreq <= to_unsigned(6326,currentfreq'length); pause <= '0';
                when 8 => currentfreq <= to_unsigned(5964,currentfreq'length); pause <= '0';
                when 9 => currentfreq <= to_unsigned(5315,currentfreq'length); pause <= '0';
                when 10 => currentfreq <= to_unsigned(4735,currentfreq'length); pause <= '0';
                when others => pause <= '1';
            end case ;
            if NOTE_SHEET(to_integer(currentNote)) = "1111" then
                currentNote <= "00000";
            else
                currentNote <= currentNote + 1;
            end if ;
        end if ;
    end process ; -- carillon_read

    sawtooth_generator : process( GPIO(0) ) -- Générateur de dent de scie
    begin
        if rising_edge(GPIO(0)) then -- Au front montant de l'horloge divisée
            if sawtooth_value = 15 then
                sawtooth_value <= (others => '0'); -- Remise à zéro de la dent de scie
            else
                sawtooth_value <= sawtooth_value + 1; -- Montée de la dent de scie
            end if ;
        end if ;
    end process ; -- sawtooth_generator

    VGA_R <= sawtooth_value;

    sine_generator : process( sawtooth_value ) -- Générateur de sinusoidale
    begin
        case( to_integer(sawtooth_value) ) is
            -- positif
            when 1|9 => sine_value <= to_unsigned(8, sine_value'length);
            when 2|8 => sine_value <= to_unsigned(11, sine_value'length);
            when 3|7 => sine_value <= to_unsigned(13, sine_value'length);
            when 4|6 => sine_value <= to_unsigned(14, sine_value'length);
            when 5 => sine_value <= to_unsigned(15, sine_value'length);

            -- négatif
            when 10|16 => sine_value <= to_unsigned(5, sine_value'length);
            when 11|15 => sine_value <= to_unsigned(3, sine_value'length);
            when 12|14 => sine_value <= to_unsigned(2, sine_value'length);
            when 13 => sine_value <= to_unsigned(1, sine_value'length);

            -- en cas de problème... On met la moyenne du sinus !
            when others => sine_value <= to_unsigned(6, sine_value'length);
        
        end case ;
    end process ; -- sine_generator

    VGA_B <= sine_value;



    pwm_generator : process( MAX10_CLK1_50 ) -- Générateur de PWM
    begin
        if rising_edge(MAX10_CLK1_50) then -- Au front montant de l'horloge 50Mhz
            if pwm_counter = 15 then -- Comptage rampe
                pwm_counter <= (others => '0'); -- Remise à 0 de la rampe
                GPIO(1) <= '0';
            else
                pwm_counter <= pwm_counter + 1; -- Montée de la rampe
    
                if pwm_counter = sine_value then -- On module lorsque la rampe = le sinus
                    GPIO(1) <= '1';
                end if ;
            end if ;
        end if ;
    end process ; -- pwm_generator



    -- Setup du carillon (choix des notes par l'utilisateur)

    note_save_trigger : process( setupNext )
    begin
        if rising_edge(setupNext) and setupMode = '1' then
            NOTE_SHEET(to_integer(setupNoteCounter)) <= noteSW;

            setupNoteCounter <= setupNoteCounter + 1;
        end if ;
    end process;

    HEX0(0) <= setupMode;
    LEDR <= setupNoteCounter;

    -- edit_mode_display : process( setupNoteCounter )
    -- begin
    --     case( to_integer(setupNoteCounter) ) is
    --         when 
    --     end case ;
    -- end process ; -- edit_mode_display

end architecture ; -- arch