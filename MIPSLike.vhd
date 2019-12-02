library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity MIPSLike is
	port(
		--Memórias de instrução e dados
		instruction_memory_adress : out std_logic_vector(15 downto 0);
		instruction_memory_in : in std_logic_vector(15 downto 0);
		data_memory_adress : out std_logic_vector(15 downto 0);
		data_memory_in : in std_logic_vector(15 downto 0);
		data_memory_out : out std_logic_vector(15 downto 0);
		
		--Sinais de controle
		destiny_register_sig : in std_logic_vector(1 downto 0);
		write_register_sig : in std_logic;
		alu_mux_sig : in std_logic;
		alu_sig : in std_logic_vector(2 downto 0);
		shift_sig : in std_logic;
		write_memory_sig : in std_logic;
		read_memory_sig : in std_logic;
		data_to_reg_sig : in std_logic_vector(1 downto 0);
		bgez_sig : in std_logic;
		beq_sig : in std_logic;
		jump_sig : in std_logic;
		
		clock : in std_logic
	);
end MIPSLike;

architecture behavior of MIPSLike is
	--Registradores
	signal pc : std_logic_vector(15 downto 0) := (others => '0');
	type bank_reg is array(15 downto 0) of std_logic_vector(15 downto 0);
	signal regs : bank_reg := (others => "0000000000000000");

	
	--Dados intermediários
	signal rs_data : std_logic_vector(15 downto 0);
	signal rt_data : std_logic_vector(15 downto 0);
	signal i_extended : std_logic_vector(15 downto 0);
	signal alu_A : std_logic_vector(15 downto 0);
	signal alu_b : std_logic_vector(15 downto 0);
	signal alu_out : std_logic_vector(15 downto 0);
	signal shift_out : std_logic_vector(15 downto 0);
	signal reg_to_write : std_logic_vector(3 downto 0);
	signal data_to_reg : std_logic_vector(15 downto 0);
	
	--sinais da ula
	signal Z : std_logic;
	signal N : std_logic;
	
	--Dados intermediários referentes a saltos
	signal pc_plus2 : std_logic_vector(15 downto 0);
	signal jump : std_logic_vector(15 downto 0);
	signal conditional_jump : std_logic_vector(15 downto 0);
	signal pc_font : std_logic;
	signal jump_mux1 : std_logic_vector(15 downto 0);
	signal jump_mux2 : std_logic_vector(15 downto 0);
	
	constant two : std_logic_vector(15 downto 0) := ("0000000000000010");
	
begin
	--Leitura da próxima instrução
	instruction_memory_adress <= pc;
	
	--calculo de pc + 2
	pc_plus2 <= pc + two;
	
	--Calculo do salto incodicional
	jump <= pc_plus2(15 downto 12)&instruction_memory_in(11 downto 0);
	
	--Dados de rs e rt
	rs_data <= regs(conv_integer(unsigned(instruction_memory_in(11 downto 8))));
	
	with bgez_sig select
		rt_data <= regs(conv_integer(unsigned(instruction_memory_in(7 downto 4)))) when '0',
					  regs(0) when '1',
					  (others => '-') when others;
	
	--Extensão de i
	i_extended <= "00000000"&instruction_memory_in(7 downto 0);
	
	--leitura dos registradores e campo i
	alu_a <= rs_data;
	
	with alu_mux_sig select
		alu_b <= rt_data when  '0',
			i_extended when '1',
			(others => '-') when others;
					
	--calculo do salto condicional
	conditional_jump <= pc_plus2 + i_extended;
					
	--calculo ula
	with alu_sig select
		alu_out <= alu_a and alu_b when "000",
					  alu_a or alu_b when "001",
					  alu_a + alu_b when "010",
					  alu_a - alu_b when "110",
					  --set or less then when "111"
					  (others => '-') when others;
					  
	if_1 : process(alu_out)
	begin
		if (alu_out = "0000000000000000") then
			Z <= '1';
			N <= '0';
		elsif (alu_out(15) = '1') then
			Z <= '0';
			N <= '1';
		else
			Z <= '0';
			N <= '0';
		end if;
	end process if_1;
	
	--Conferir salto condicional
	pc_font <= (bgez_sig and not N) or (beq_sig and Z);
	
	--Calculo da próxima instrução
	with pc_font select
		jump_mux1 <= pc_plus2 when '0',
						 conditional_jump when '1',
						 (others => '-') when others;
	with jump_sig select
		jump_mux2 <= jump_mux1 when '0',
						 jump when '1',
						 (others => '-') when others;
						 
	--Calculo do deslocador
	shift_out <= alu_out; -- Não sei como fazer ainda
	
	--Acesso à memória de dados (leitura ou escrita)
	if_2 : process(write_memory_sig, read_memory_sig, shift_out, rt_data)
	begin
		if(write_memory_sig = '1') then
			data_memory_adress <= shift_out;
			data_memory_out <= rt_data;
		elsif (read_memory_sig = '1') then
			data_memory_adress <= shift_out;
		end if;
	end process if_2;
	
	--Escrita no banco de registradores
	with data_to_reg_sig select
		data_to_reg <= data_memory_in when "00",
							pc_plus2 when "01",
							shift_out when "10",
							(others => '-') when others;
	
	with destiny_register_sig select
		reg_to_write <= instruction_memory_in(7 downto 4) when "00",
							 "0001" when "01",
							 "0010" when "10",
							 instruction_memory_in(3 downto 0) when "11",
							 (others => '-') when others;
							 
	if_3 : process(clock, write_register_sig, reg_to_write, data_to_reg)
	begin
		if(rising_edge(clock) and write_register_sig = '1') then
			regs(conv_integer(unsigned(reg_to_write))) <= data_to_reg;
		end if;
	end process if_3;
	
	--Escrita em pc
	if_4: process(clock)
	begin
		if(rising_edge(clock)) then
			pc <= jump_mux2;
		end if;
	end process if_4;
	
	
end behavior;