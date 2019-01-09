-- Projet DE10-LITE; DUT GEII SALON 2018-2019; SIN1 TP VHDL
-- Auteur : Daniel THIRION Gr1A
-- Nom : Generateur1A.vhd
-- Carte : DE10-LITE (MAX10 Family - 50K LE)
-- Description :
--      Ce programme permet d'encoder un carillon dans la mémoire de la carte, puis de le rejouer
--      Il ressort le carillon sous forme d'une dent-de-scie, d'un sinus (sur 4 bits) ou d'un signal
--      modulé en largeur (PWM), qui peut être lu grace à un filtre passe bas.
-- Controles :
-- Le switch le plus à gauche permet de passer en mode "setup" où l'on peut régler le carillon.
--      En mode setup, l'afficheur 7 segment s'allume.
-- Le second switch permet d'enregistrer la note et de passer à la suivante au front montant.
--      On peut suivre la note actuellement modifiée grace aux LEDs qui affichent en binaire le compte.
-- Les 8 derniers switchs sont un "piano", de DO à DO. La note la plus à gauche prends le dessus si plusieurs
--      sont enfoncées.
-- Le fait d'en enfoncer aucune permet de faire une note vierge, une pause dans le carillon.
-- Le fait de toutes les enfoncer permet de marquer la fin du carillon. Le programme reviendra a la première
--      note si il rencontre ce signal.
--
-- Le carillon est composé de maximum 32 notes. Il se joueras automatiquement lorsque l'on est hors du "setup"
-- La sortie PWM est sur GPIO(0), le sinus sur la sortie bleue du VGA, et la dent de scie sur la sortie rouge.

library ieee ;
	use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

entity Generateur1A is
  port (
    MAX10_CLK1_50 : in std_logic; -- Horloge 50Mhz de la carte
    GPIO : buffer std_logic_vector(1 downto 0); -- Sorties GPIO
    SW : in unsigned(9 downto 0); -- Switchs pour le setup et le piano
    HEX0 : out std_logic_vector(0 downto 0); -- Affichage pour montrer le mode setup
    LEDR : out unsigned(4 downto 0); -- LEDs pour afficher quelle note est modifiée
    VGA_R : out unsigned(3 downto 0); -- DAC sortie rouge du connecteur D-SUB
    VGA_B : out unsigned(3 downto 0) -- DAC sortie bleue du connecteur D-SUB
  );
end Generateur1A ;

architecture arch of Generateur1A is
    signal counter : unsigned(24 downto 0); -- Compteur de division de l'horloge
    signal sawtooth_value : unsigned(3 downto 0); -- Valeure actuelle du dent de scie
    signal sine_value : unsigned(3 downto 0); -- Valeur actuelle du sinus
    signal pwm_counter : unsigned(3 downto 0); -- Compteur de rampe pour la modulation d'impulsion

    -- Alias pour les switchs.
    alias noteSW is SW(7 downto 0);
    alias setupMode is SW(9);
    alias setupNext is SW(8);

    signal break : std_logic; -- 1 = Pause
    signal breakCounter : integer range 0 to 19; -- Permet de compter une courte pause a la fin de chaque note

    signal speedCounter : unsigned(24 downto 0); -- Permet de timer chaque fois que l'on change de note
    signal playClock : std_logic; -- Horloge divisée qui dit quand passer à la note suivante
    signal currentfreq : unsigned(24 downto 0); -- Fréquence de la note jouée
    signal pause : std_logic; -- 1 = Pause
    signal currentNote : unsigned(4 downto 0) := "00000"; -- Numéro de la note lue sur la feuille du carillon

    type NOTE_SHEET_TYPE is array(0 to 31) of unsigned(3 downto 0);
    signal NOTE_SHEET : NOTE_SHEET_TYPE; -- FEUILLE DE NOTES DU CARILLON. 32 NOTES MAX.

    signal setupNoteCounter : unsigned(4 downto 0) := "00000"; -- Numéro de la note actuellement modifiée
begin

    clk_div : process( MAX10_CLK1_50 ) -- Diviseur d'horloge pour la vraie fréquence de la note
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

    carillon_clkdiv : process( MAX10_CLK1_50 ) -- Diviseur pour la cadence des notes
    begin
        if rising_edge( MAX10_CLK1_50 ) then
            if speedCounter = 625000 then
                speedCounter <= to_unsigned(0,counter'length);
                breakCounter <= breakCounter + 1;
                if breakCounter = 19 then
                    break <= '1';
                elsif (breakCounter = 0) or (breakCounter = 10) then
                    playClock <= not playClock;
                    break <= '0';
                end if ;
            else
                speedCounter <= speedCounter + 1;
            end if ;
        end if ;
    end process ; -- carillon_clkdiv

    carillon_read : process( playClock ) -- Lecture et convertion du carillon en diviseur de fréq.
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
            if NOTE_SHEET(to_integer(currentNote)) = "1111" then -- Remet au début de la feuille si on trouve le signal de fin
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
        variable ret : unsigned(3 downto 0);
    begin
        if rising_edge(setupNext) and setupMode = '1' then -- Conversion Piano --> Note en binaire
            case( to_integer(noteSW) ) is
                when 255 => ret := "1111";
                when 254 downto 128 => ret := "0001";
                when 127 downto 64 => ret := "0010";
                when 63 downto 32 => ret := "0011";
                when 31 downto 16 => ret := "0100";
                when 15 downto 8 => ret := "0101";
                when 7 downto 4 => ret := "0110";
                when 3 downto 2 => ret := "0111";
                when 1 => ret := "1000";
                when others => ret := "0000";
            end case ;
            NOTE_SHEET(to_integer(setupNoteCounter)) <= ret;

            setupNoteCounter <= setupNoteCounter + 1;
        end if ;
    end process;

    HEX0(0) <= not setupMode; -- Affiche l'état du setup sur le 7seg
    LEDR <= setupNoteCounter; -- Affiche quelle note est modifiée sur les LEDs.

end architecture ; -- arch