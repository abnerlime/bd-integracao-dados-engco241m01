# Parte 1: Documentação do processo de importação

## Ferramenta utilizada

- **SGBD:** PostgreSQL (banco `Varejao Jutai`, schema `public`).
- **Linguagem do script:** Python 3, com `pandas` para ler o arquivo `base_teste.xlsx` e `psycopg2` para conectar ao PostgreSQL e executar os `INSERT`.
- **Execução:** primeiro o DDL (`sql/01_ddl_postgres.sql`) cria as tabelas; depois o `importar.py` carrega as cinco abas na ordem `fornecedor`, `produtos_filial`, `pedido_compra`, `entradas_mercadoria`, `venda`.

## Estrutura da planilha

| Aba | Coluna | Tipo | Observação |
| --- | --- | --- | --- |
| fornecedor | idfornecedor | Texto | Códigos `F1` a `F20`; chave primária |
| fornecedor | razao_social | Texto | |
| produtos_filial | filial_id | Inteiro | |
| produtos_filial | idproduto | Texto | No banco a coluna se chama `produto_id` (o script faz o mapeamento) |
| produtos_filial | descricao | Texto | |
| produtos_filial | estoque | Inteiro | Gravado como `float8` |
| produtos_filial | preco_unitario | Decimal | |
| produtos_filial | preco_compra | Decimal | |
| produtos_filial | preco_venda | Decimal | |
| produtos_filial | idfornecedor | Texto | Ex.: `F8`; por isso a coluna no banco é `varchar(25)` |
| pedido_compra | pedido_id | Inteiro | |
| pedido_compra | data_pedido | Data | |
| pedido_compra | item | Inteiro | |
| pedido_compra | produto_id | Texto | |
| pedido_compra | descricao_produto | Texto | |
| pedido_compra | ordem_compra | Inteiro | Valor 0 em 11 pedidos (19 a 29) |
| pedido_compra | qtde_pedida | Inteiro | |
| pedido_compra | filial_id | Inteiro | |
| pedido_compra | data_entrega | Data | |
| pedido_compra | qtde_entregue | Inteiro | |
| pedido_compra | preco_compra | Decimal | |
| pedido_compra | fornecedor_id | Inteiro | Numérico (1 a 20), diferente dos códigos `F1`...`F20` do cadastro |
| pedido_compra | (colunas M a W, sem cabeçalho) | Diversos | Colunas auxiliares nas linhas dos pedidos 21 a 29; descartadas pelo script |
| entradas_mercadoria | data_entrada | Data | |
| entradas_mercadoria | nro_nfe | Texto | Ex.: `NFE1` |
| entradas_mercadoria | item | Inteiro | |
| entradas_mercadoria | produto_id | Texto | |
| entradas_mercadoria | descricao_produto | Texto | |
| entradas_mercadoria | ordem_compra | Inteiro | Coluna presente na planilha, mas ausente no DDL do enunciado |
| entradas_mercadoria | qtde_recebida | Inteiro | |
| entradas_mercadoria | filial_id | Inteiro | |
| entradas_mercadoria | custo_unitario | Decimal | |
| venda | venda_id | Inteiro | |
| venda | data_emissao | Data | |
| venda | horariomov | Texto | Formato `HH:MM:SS` |
| venda | produto_id | Texto | |
| venda | qtde_vendida | Decimal | |
| venda | valor_unitario | Decimal | |
| venda | filial_id | Inteiro | |
| venda | item | Inteiro | |
| venda | unidade_medida | Texto | Ex.: `UN` |

## Erros encontrados no DDL e como foram corrigidos

| Tabela | Erro | Correção |
| --- | --- | --- |
| entradas_mercadoria | A PK citava a coluna `ordem_compra`, que não existia na tabela (e existe na planilha) | `ALTER TABLE ... ADD COLUMN ordem_compra float8 DEFAULT 0 NOT NULL` |
| entradas_mercadoria | PK criada com 3 colunas, sem `ordem_compra` | Constraint antiga removida (`DROP CONSTRAINT`) e recriada como `PRIMARY KEY (ordem_compra, item, produto_id, nro_nfe)` |
| produtos_filial | Faltava vírgula entre a última coluna e o `CONSTRAINT` | Vírgula adicionada |
| produtos_filial | A PK citava `idproduto`, mas a coluna se chama `produto_id` | PK corrigida para `(filial_id, produto_id)` |
| produtos_filial | Nome da coluna com erro de digitação: `decricao` | `RENAME COLUMN decricao TO descricao` |
| produtos_filial | Nome da coluna com erro de digitação: `idfonecedor` | `RENAME COLUMN idfonecedor TO idfornecedor` |
| produtos_filial | `DEFAULT '0'` (texto) em colunas numéricas | Trocado por `DEFAULT 0` |
| produtos_filial | `idfornecedor` era `int4`, mas a planilha traz códigos como `F8` | `ALTER COLUMN idfornecedor TYPE varchar(25)` |
| fornecedor | Nome da coluna com erro de digitação: `idforncedor` | `RENAME COLUMN idforncedor TO idfornecedor` |
| fornecedor | A PK incluía `idproduto`, coluna que não existe na tabela | PK mantida somente em `idfornecedor` |

## Erros encontrados no script de importação e como foram corrigidos

| Erro | Efeito | Correção |
| --- | --- | --- |
| A função `excel_para_data` aplicava `int()` diretamente no valor lido. O pandas já entrega as datas como `Timestamp`, então `int()` gerava erro, capturado pelo `except`, que retornava `None` | Todas as datas eram gravadas como `NULL`. Na tabela `venda`, `data_emissao` é `NOT NULL`, então nenhuma venda era inserida | A função passou a tratar `datetime`/`Timestamp` com `.date()`; mantém a conversão de número serial do Excel e, como último recurso, `pd.to_datetime(..., dayfirst=True)` |
| Caminho do arquivo, nome do banco e senha de exemplo | O script não conectava no ambiente do projeto | `ARQUIVO` e `DB` ajustados para o ambiente local (`Varejao Jutai`) |

## Tratamentos aplicados aos dados

- **Datas:** conversão para `date` (valores `Timestamp`, serial do Excel ou texto); data vazia vira `NULL`.
- **Textos:** `strip()` em todos os campos de texto, removendo espaços nas pontas.
- **Tipos numéricos:** conversão explícita para `int` e `float` do Python antes do `INSERT`, evitando tipos do numpy.
- **Valores vazios:** campos numéricos `NOT NULL` recebem `0`; `horariomov` vazio recebe `'00:00:00'`; `filial_id` vazio em `venda` recebe `1`; `item` vazio recebe `0`.
- **Nomes de colunas:** `strip()` nos cabeçalhos e mapeamento `idproduto` → `produto_id` em `produtos_filial`.
- **`pedido_compra`:** o script usa só as 12 primeiras colunas e as renomeia, descartando as colunas auxiliares (M a W). A coluna `qtde_pendente`, que não existe na planilha, é calculada como `qtde_pedida - qtde_entregue`.
- **Duplicidade:** `ON CONFLICT ... DO NOTHING` na chave primária de cada tabela, para que a carga possa ser repetida sem duplicar linhas.
- **Ordem de carga:** tabelas carregadas das que não dependem de outras (`fornecedor`) até as que dependem (`venda`).

### Inconsistências identificadas e ainda não tratadas

- `pedido_compra.fornecedor_id` é inteiro (1 a 20) e `fornecedor.idfornecedor` é texto (`F1` a `F20`): não há chave estrangeira entre as duas, e as colunas não podem ser ligadas por `JOIN` direto.
- Em 11 pedidos (19 a 29) `ordem_compra` é 0; as entradas das ordens 19 e 20 ficam sem pedido correspondente.
- Os pedidos 21 a 29 repetem datas, preços e fornecedor dos pedidos 12 a 20.
- 13 vendas (produtos `P21` a `P28`, filiais 1, 2 e 3) não têm produto cadastrado em `produtos_filial`, que só contém a filial 1.
- Em 20 dos 29 pedidos, `data_entrega` é anterior a `data_pedido`.
- Em 22 dos 29 pedidos, o fornecedor difere do cadastrado em `produtos_filial` para o mesmo produto.
- O banco não possui chaves estrangeiras, então essas inconsistências não impedem a carga.

## Conferência final

| Tabela | Linhas na planilha | Linhas no banco |
| --- | --- | --- |
| fornecedor | 20 | 20 |
| produtos_filial | 20 | 20 |
| pedido_compra | 29 | 29 |
| entradas_mercadoria | 20 | 20 |
| venda | 33 | 33 |
