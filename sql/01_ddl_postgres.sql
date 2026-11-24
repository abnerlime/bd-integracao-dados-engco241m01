-- DDL exatamente como veio no enunciado do cliente.
-- Rode, veja os erros e crie as suas versões corrigidas:
--   sql/01_ddl_postgres.sql e sql/01_ddl_mysql.sql

CREATE TABLE public.venda (
 venda_id int8 NOT NULL,
 data_emissao date NOT NULL,
 horariomov varchar(8) DEFAULT '00:00:00'::character varying NOT NULL,
 produto_id varchar(25) DEFAULT ''::character varying NOT NULL,
 qtde_vendida float8 NULL,
 valor_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
 filial_id int8 DEFAULT 1 NOT NULL,
 item int4 DEFAULT 0 NOT NULL,
 unidade_medida varchar(3) NULL,
 CONSTRAINT pk_consumo PRIMARY KEY (filial_id, venda_id, data_emissao, produto_id, item, horariomov)
 );

 
CREATE TABLE public.pedido_compra (
 pedido_id float8 DEFAULT 0 NOT NULL,
 data_pedido date NULL, item float8 DEFAULT 0 NOT NULL,
 produto_id varchar(25) DEFAULT '0' NOT NULL,
 descricao_produto varchar(255) NULL,
 ordem_compra float8 DEFAULT 0 NOT NULL,
 qtde_pedida float8 NULL,
 filial_id int4 NULL,
 data_entrega date NULL,
 qtde_entregue float8 DEFAULT 0 NOT NULL,
 qtde_pendente float8 DEFAULT 0 NOT NULL,
 preco_compra float8 DEFAULT 0 NULL,
 fornecedor_id int4 DEFAULT 0 NULL,
 CONSTRAINT pedido_compra_pkey PRIMARY KEY (pedido_id , produto_id, item)
 );
 
CREATE TABLE public.entradas_mercadoria (
 data_entrada date NULL,
 nro_nfe varchar(255) NOT NULL,
 item float8 DEFAULT 0 NOT NULL,
 produto_id varchar(25) DEFAULT '0' NOT NULL,
 descricao_produto varchar(255) NULL,
 qtde_recebida float8 NULL,
 filial_id int4 NULL,
 custo_unitario numeric(12, 4) DEFAULT 0 NOT NULL,
 CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (item, produto_id, nro_nfe)
	-- Adicionei a coluna ordem_compra pois na coluna da planilha há ess 
 );
 
CREATE TABLE public.produtos_filial (
 filial_id int4 NULL,
 produto_id varchar(255) NOT NULL,
 decricao varchar(255) NOT NULL,
 estoque float8 DEFAULT 0 NOT NULL,
 preco_unitario float8 DEFAULT 0 NOT NULL,
 preco_compra float8 DEFAULT 0 NOT NULL,
 preco_venda float8 DEFAULT 0 NOT NULL,
 idfonecedor int4 NULL,
CONSTRAINT produtos_filial_pkey PRIMARY KEY (filial_id, produto_id)
	-- Em algumas colunas o comando default estava sendo usando de forma incorreta. Estava '0' ao inves de usar apenas o numeral 0. 
	-- A penúltima linha não possuía vírgula para separar os itens.
	/*A coluna mencionada na PK estava com um nome diferente da 
	coluna existente na tabela ( Estava idproduto ao invés de produto_id.*/ 
);

CREATE TABLE public.fornecedor (
idforncedor varchar(25) NOT NULL,
razao_social varchar(255) NOT NULL,
CONSTRAINT fornecedor_pkey PRIMARY KEY (idforncedor)
	-- Removi uma das colunas mencionadas na PK (idproduto) não existe na tabela. 
);

-- Alguns erros só notei depois, então tive que usar comandos especificos para alterar estruturas.

ALTER TABLE public.fornecedor RENAME COLUMN idforncedor TO idfornecedor;

ALTER TABLE public.produtos_filial RENAME COLUMN decricao TO descricao;
ALTER TABLE public.produtos_filial RENAME COLUMN idfonecedor TO idfornecedor;
ALTER TABLE public.entradas_mercadoria ADD COLUMN ordem_compra float8 DEFAULT 0 NOT NULL;

-- Precisei excluir a constraint antiga que continha apenas 3 colunas na PK, para não conflitar com a nova.
ALTER TABLE public.entradas_mercadoria DROP CONSTRAINT entradas_mercadoria_pkey;

-- Adicionei a coluna ordem compra pois era necessário para a PK.
ALTER TABLE public.entradas_mercadoria ADD CONSTRAINT entradas_mercadoria_pkey PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe);

-- Alterei o tipo de dado da coluna para não dar conflito com o tipo contido na planilha.
ALTER TABLE public.produtos_filial ALTER COLUMN idfornecedor TYPE varchar(25);

-- Alterei o nome da coluna para ficar de acordo com a coluna da tabela fornecedor.
ALTER TABLE public.pedido_compra RENAME COLUMN fornecedor_id TO idfornecedor;

