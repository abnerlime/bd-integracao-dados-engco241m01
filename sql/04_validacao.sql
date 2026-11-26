-- 04_validacao

-- Etapa 3 - Consultas de validação com o cliente (Parte 4)

SELECT 'fornecedor' AS tabela, COUNT(*) AS linhas FROM public.fornecedor
UNION ALL SELECT 'produtos_filial',     COUNT(*) FROM public.produtos_filial
UNION ALL SELECT 'pedido_compra',       COUNT(*) FROM public.pedido_compra
UNION ALL SELECT 'entradas_mercadoria', COUNT(*) FROM public.entradas_mercadoria
UNION ALL SELECT 'venda',               COUNT(*) FROM public.venda;

-- - Totais de controle de fevereiro/2025 (vendas)
SELECT COUNT(*)                                         AS linhas_de_venda,
       COUNT(DISTINCT v.venda_id)                       AS vendas,
       ROUND(SUM(v.qtde_vendida::NUMERIC), 2)           AS qtde_total,
       ROUND(SUM(v.qtde_vendida::NUMERIC * v.valor_unitario), 2) AS valor_total_rs
FROM public.venda v
WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01';

-- - Fevereiro/2025 por filial
SELECT v.filial_id,
       COUNT(*)                                          AS linhas_de_venda,
       ROUND(SUM(v.qtde_vendida::NUMERIC), 2)            AS qtde_total,
       ROUND(SUM(v.qtde_vendida::NUMERIC * v.valor_unitario), 2) AS valor_total_rs
FROM public.venda v
WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
GROUP BY v.filial_id
ORDER BY v.filial_id;

-- - Fevereiro/2025 por produto, com indicação de produto sem cadastro
SELECT v.produto_id,
       COALESCE(p.descricao, '(sem cadastro)')                   AS descricao,
       SUM(v.qtde_vendida)                                       AS qtde_total,
       ROUND(SUM(v.qtde_vendida::NUMERIC * v.valor_unitario), 2) AS valor_total_rs,
       CASE WHEN p.produto_id IS NULL THEN 'SIM' ELSE 'não' END  AS sem_cadastro
FROM public.venda v
LEFT JOIN (SELECT produto_id, MAX(descricao) AS descricao
           FROM public.produtos_filial GROUP BY produto_id) p
       ON p.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
GROUP BY v.produto_id, p.descricao, p.produto_id
ORDER BY LENGTH(v.produto_id), v.produto_id;

-- - Fevereiro/2025 dia a dia
SELECT TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS dia,
       COUNT(*)                                          AS linhas_de_venda,
       ROUND(SUM(v.qtde_vendida::NUMERIC), 2)            AS qtde_total,
       ROUND(SUM(v.qtde_vendida::NUMERIC * v.valor_unitario), 2) AS valor_total_rs
FROM public.venda v
WHERE v.data_emissao >= DATE '2025-02-01' AND v.data_emissao < DATE '2025-03-01'
GROUP BY v.data_emissao
ORDER BY v.data_emissao;

-- - Vendas na base por mês (escopo do período)
SELECT TO_CHAR(data_emissao, 'YYYY-MM') AS mes,
       COUNT(*)                               AS linhas_de_venda,
       ROUND(SUM(qtde_vendida::NUMERIC * valor_unitario), 2) AS valor_total_rs
FROM public.venda
GROUP BY 1
ORDER BY 1;

-- - Testes de sanidade da venda (todos devem retornar 0)
SELECT 'quantidade nula ou <= 0' AS teste, COUNT(*) AS ocorrencias
FROM public.venda WHERE qtde_vendida IS NULL OR qtde_vendida <= 0
UNION ALL
SELECT 'valor unitário <= 0', COUNT(*) FROM public.venda WHERE valor_unitario <= 0
UNION ALL
SELECT 'horário em formato inválido', COUNT(*) FROM public.venda
WHERE horariomov !~ '^([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9]$'
UNION ALL
SELECT 'mesma venda repetida (filial, data, hora, produto, qtde, valor)', COUNT(*)
FROM (SELECT 1 FROM public.venda
      GROUP BY filial_id, data_emissao, horariomov, produto_id, qtde_vendida, valor_unitario
      HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'código de produto com espaço ou minúscula', COUNT(*) FROM public.venda
WHERE produto_id <> UPPER(TRIM(produto_id));

-- - Compras de fevereiro/2025: pedidos feitos no mês e situação de recebimento
SELECT p.pedido_id, p.produto_id, TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS data_pedido,
       p.qtde_pedida,
       COALESCE(SUM(e.qtde_recebida), 0) AS qtde_recebida,
       CASE WHEN COUNT(e.nro_nfe) = 0 THEN 'SEM ENTRADA' ELSE 'com entrada' END AS situacao
FROM public.pedido_compra p
LEFT JOIN public.entradas_mercadoria e
       ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE p.data_pedido >= DATE '2025-02-01' AND p.data_pedido < DATE '2025-03-01'
GROUP BY p.pedido_id, p.produto_id, p.data_pedido, p.qtde_pedida
ORDER BY p.data_pedido, p.pedido_id;

-- - Entradas de mercadoria sem pedido correspondente (deve retornar 0)
SELECT e.nro_nfe, e.ordem_compra, e.produto_id
FROM public.entradas_mercadoria e
WHERE NOT EXISTS (
    SELECT 1 FROM public.pedido_compra p
    WHERE p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
);

-- - Resumo de todos os erros encontrados (uma linha por erro)
SELECT * FROM (
SELECT 'E01' AS erro, 'Pedido com data de entrega anterior à data do pedido' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT pedido_id, produto_id,
       TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega,
       (data_pedido - data_entrega) AS dias_de_diferenca
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id
) q_e01
UNION ALL
SELECT 'E02' AS erro, 'Entrada de mercadoria com data anterior à data do pedido' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT e.nro_nfe, e.ordem_compra, e.produto_id,
       TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.data_entrada < p.data_pedido
ORDER BY e.ordem_compra
) q_e02
UNION ALL
SELECT 'E03' AS erro, 'Vendas de produtos sem cadastro (inclui as filiais 2 e 3)' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT v.venda_id, v.filial_id, v.produto_id,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao,
       v.qtde_vendida,
       ROUND(v.qtde_vendida::NUMERIC * v.valor_unitario, 2) AS valor_rs
FROM public.venda v
WHERE NOT EXISTS (
    SELECT 1 FROM public.produtos_filial f
    WHERE f.filial_id = v.filial_id AND f.produto_id = v.produto_id
)
ORDER BY v.venda_id
) q_e03
UNION ALL
SELECT 'E04' AS erro, 'Fornecedor do pedido diferente do fornecedor cadastrado para o produto' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT p.pedido_id, p.produto_id,
       p.idfornecedor AS fornecedor_no_pedido,
       f.idfornecedor AS fornecedor_no_cadastro
FROM public.pedido_compra p
JOIN public.produtos_filial f
  ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
WHERE p.idfornecedor <> f.idfornecedor
ORDER BY p.pedido_id
) q_e04
UNION ALL
SELECT 'E05' AS erro, 'Quantidade recebida diferente da quantidade entregue registrada no pedido' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT e.ordem_compra, e.produto_id, p.qtde_pedida,
       p.qtde_entregue  AS entregue_no_pedido,
       e.qtde_recebida  AS recebida_na_entrada
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.qtde_recebida <> p.qtde_entregue
ORDER BY e.ordem_compra
) q_e05
UNION ALL
SELECT 'E06' AS erro, 'Quantidade recebida maior que a quantidade pedida' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT e.ordem_compra, e.produto_id,
       p.qtde_pedida, e.qtde_recebida,
       e.qtde_recebida - p.qtde_pedida AS excedente
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.qtde_recebida > p.qtde_pedida
ORDER BY e.ordem_compra
) q_e06
UNION ALL
SELECT 'E07' AS erro, 'Pedido com quantidade entregue zero, mas com entrada de mercadoria registrada' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT p.pedido_id, p.ordem_compra, p.produto_id,
       p.qtde_pedida, p.qtde_entregue AS entregue_no_pedido,
       e.qtde_recebida AS recebida_na_entrada
FROM public.pedido_compra p
JOIN public.entradas_mercadoria e
  ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE p.qtde_entregue = 0
ORDER BY p.pedido_id
) q_e07
UNION ALL
SELECT 'E08' AS erro, 'Pedidos possivelmente duplicados (mesmo produto e mesma data)' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT produto_id, TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
       COUNT(*) AS qtde_pedidos,
       STRING_AGG(pedido_id::TEXT, ', ' ORDER BY pedido_id) AS pedidos,
       SUM(qtde_pedida) AS qtde_total
FROM public.pedido_compra
GROUP BY produto_id, data_pedido
HAVING COUNT(*) > 1
ORDER BY LENGTH(produto_id), produto_id
) q_e08
UNION ALL
SELECT 'E09' AS erro, 'Produto com preço de venda menor que o preço de compra' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT filial_id, produto_id, preco_compra, preco_venda,
       ROUND((preco_venda - preco_compra)::NUMERIC, 2) AS margem_unitaria
FROM public.produtos_filial
WHERE preco_venda < preco_compra
ORDER BY margem_unitaria
) q_e09
UNION ALL
SELECT 'E10' AS erro, 'Preço de compra diferente entre pedido, entrada e cadastro' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT p.pedido_id, p.produto_id,
       p.preco_compra  AS preco_no_pedido,
       e.custo_unitario AS custo_na_entrada,
       f.preco_compra  AS preco_no_cadastro
FROM public.pedido_compra p
JOIN public.produtos_filial f
  ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
LEFT JOIN public.entradas_mercadoria e
  ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE ROUND(p.preco_compra::NUMERIC, 2) <> ROUND(f.preco_compra::NUMERIC, 2)
   OR ROUND(p.preco_compra::NUMERIC, 2) <> ROUND(e.custo_unitario, 2)
ORDER BY p.pedido_id
) q_e10
UNION ALL
SELECT 'E11' AS erro, 'Valor unitário da venda diferente do preço de venda do cadastro' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT v.venda_id, v.produto_id,
       v.valor_unitario AS preco_praticado,
       f.preco_venda    AS preco_cadastro
FROM public.venda v
JOIN public.produtos_filial f
  ON f.filial_id = v.filial_id AND f.produto_id = v.produto_id
WHERE ROUND(v.valor_unitario, 2) <> ROUND(f.preco_venda::NUMERIC, 2)
ORDER BY v.venda_id
) q_e11
UNION ALL
SELECT 'E12' AS erro, 'Quantidade vendida fracionada em unidade UN' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM public.venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida::NUMERIC % 1 <> 0
ORDER BY venda_id
) q_e12
UNION ALL
SELECT 'E13' AS erro, 'Data de recebimento diferente da data de entrega do pedido' AS descricao, COUNT(*) AS ocorrencias FROM (
SELECT e.ordem_compra, e.produto_id,
       TO_CHAR(p.data_entrega, 'DD/MM/YYYY') AS data_entrega_no_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_da_entrada,
       (e.data_entrada - p.data_entrega) AS dias_de_diferenca
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.data_entrada <> p.data_entrega
ORDER BY e.ordem_compra
) q_e13
) resumo
ORDER BY erro;


-- - Pedido com data de entrega anterior à data do pedido
-- A entrega é prevista ou ocorre antes de o pedido existir.
SELECT pedido_id, produto_id,
       TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(data_entrega, 'DD/MM/YYYY') AS data_entrega,
       (data_pedido - data_entrega) AS dias_de_diferenca
FROM public.pedido_compra
WHERE data_entrega < data_pedido
ORDER BY pedido_id;

-- - Entrada de mercadoria com data anterior à data do pedido
-- A mercadoria aparece como recebida antes de o pedido de compra ser feito.
SELECT e.nro_nfe, e.ordem_compra, e.produto_id,
       TO_CHAR(p.data_pedido, 'DD/MM/YYYY') AS data_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_entrada
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.data_entrada < p.data_pedido
ORDER BY e.ordem_compra;

-- - Vendas de produtos sem cadastro (inclui as filiais 2 e 3)
-- Há vendas dos produtos P21 a P28 que não existem em produtos_filial. O cadastro de produtos só tem a filial 1, mas há vendas nas filiais 2 e 3.
SELECT v.venda_id, v.filial_id, v.produto_id,
       TO_CHAR(v.data_emissao, 'DD/MM/YYYY') AS data_emissao,
       v.qtde_vendida,
       ROUND(v.qtde_vendida::NUMERIC * v.valor_unitario, 2) AS valor_rs
FROM public.venda v
WHERE NOT EXISTS (
    SELECT 1 FROM public.produtos_filial f
    WHERE f.filial_id = v.filial_id AND f.produto_id = v.produto_id
)
ORDER BY v.venda_id;

-- - Fornecedor do pedido diferente do fornecedor cadastrado para o produto
-- O mesmo produto aparece com um fornecedor no pedido de compra e com outro no cadastro de produtos.
SELECT p.pedido_id, p.produto_id,
       p.idfornecedor AS fornecedor_no_pedido,
       f.idfornecedor AS fornecedor_no_cadastro
FROM public.pedido_compra p
JOIN public.produtos_filial f
  ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
WHERE p.idfornecedor <> f.idfornecedor
ORDER BY p.pedido_id;

-- - Quantidade recebida diferente da quantidade entregue registrada no pedido
-- O recebimento (entradas_mercadoria) não bate com a quantidade entregue que consta no pedido (pedido_compra).
SELECT e.ordem_compra, e.produto_id, p.qtde_pedida,
       p.qtde_entregue  AS entregue_no_pedido,
       e.qtde_recebida  AS recebida_na_entrada
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.qtde_recebida <> p.qtde_entregue
ORDER BY e.ordem_compra;

-- - Quantidade recebida maior que a quantidade pedida
-- Chegou mais mercadoria do que foi requisitada.
SELECT e.ordem_compra, e.produto_id,
       p.qtde_pedida, e.qtde_recebida,
       e.qtde_recebida - p.qtde_pedida AS excedente
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.qtde_recebida > p.qtde_pedida
ORDER BY e.ordem_compra;

-- - Pedido com quantidade entregue zero, mas com entrada de mercadoria registrada
-- O pedido diz que nada foi entregue, e a tabela de entradas mostra recebimento para a mesma ordem.
SELECT p.pedido_id, p.ordem_compra, p.produto_id,
       p.qtde_pedida, p.qtde_entregue AS entregue_no_pedido,
       e.qtde_recebida AS recebida_na_entrada
FROM public.pedido_compra p
JOIN public.entradas_mercadoria e
  ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE p.qtde_entregue = 0
ORDER BY p.pedido_id;

-- - Pedidos possivelmente duplicados (mesmo produto e mesma data)
-- Os pedidos 21 a 29 repetem o produto e a data de pedidos já existentes (12 a 20), com quantidade diferente e sem nenhuma entrada.
SELECT produto_id, TO_CHAR(data_pedido, 'DD/MM/YYYY') AS data_pedido,
       COUNT(*) AS qtde_pedidos,
       STRING_AGG(pedido_id::TEXT, ', ' ORDER BY pedido_id) AS pedidos,
       SUM(qtde_pedida) AS qtde_total
FROM public.pedido_compra
GROUP BY produto_id, data_pedido
HAVING COUNT(*) > 1
ORDER BY LENGTH(produto_id), produto_id;

-- - Produto com preço de venda menor que o preço de compra
-- O cadastro indica que o produto é vendido abaixo do custo.
SELECT filial_id, produto_id, preco_compra, preco_venda,
       ROUND((preco_venda - preco_compra)::NUMERIC, 2) AS margem_unitaria
FROM public.produtos_filial
WHERE preco_venda < preco_compra
ORDER BY margem_unitaria;

--  Preço de compra diferente entre pedido, entrada e cadastro
-- O preço de compra de um mesmo produto é diferente no pedido (pedido_compra), no recebimento (custo_unitario) e no cadastro (produtos_filial).
SELECT p.pedido_id, p.produto_id,
       p.preco_compra  AS preco_no_pedido,
       e.custo_unitario AS custo_na_entrada,
       f.preco_compra  AS preco_no_cadastro
FROM public.pedido_compra p
JOIN public.produtos_filial f
  ON f.filial_id = p.filial_id AND f.produto_id = p.produto_id
LEFT JOIN public.entradas_mercadoria e
  ON e.ordem_compra = p.ordem_compra AND e.produto_id = p.produto_id
WHERE ROUND(p.preco_compra::NUMERIC, 2) <> ROUND(f.preco_compra::NUMERIC, 2)
   OR ROUND(p.preco_compra::NUMERIC, 2) <> ROUND(e.custo_unitario, 2)
ORDER BY p.pedido_id;

-- - Valor unitário da venda diferente do preço de venda do cadastro
-- O preço praticado nas vendas não coincide com o preço de venda cadastrado para o produto.
SELECT v.venda_id, v.produto_id,
       v.valor_unitario AS preco_praticado,
       f.preco_venda    AS preco_cadastro
FROM public.venda v
JOIN public.produtos_filial f
  ON f.filial_id = v.filial_id AND f.produto_id = v.produto_id
WHERE ROUND(v.valor_unitario, 2) <> ROUND(f.preco_venda::NUMERIC, 2)
ORDER BY v.venda_id;

-- - Quantidade vendida fracionada em unidade UN
-- Há vendas de 'UN' (unidade) com casas decimais, como 2,86 unidades.
SELECT venda_id, produto_id, qtde_vendida, unidade_medida
FROM public.venda
WHERE unidade_medida = 'UN'
  AND qtde_vendida::NUMERIC % 1 <> 0
ORDER BY venda_id;

-- - Data de recebimento diferente da data de entrega do pedido
-- A entrada de mercadoria acontece em uma data diferente da data de entrega registrada no pedido.
SELECT e.ordem_compra, e.produto_id,
       TO_CHAR(p.data_entrega, 'DD/MM/YYYY') AS data_entrega_no_pedido,
       TO_CHAR(e.data_entrada, 'DD/MM/YYYY') AS data_da_entrada,
       (e.data_entrada - p.data_entrega) AS dias_de_diferenca
FROM public.entradas_mercadoria e
JOIN public.pedido_compra p
  ON p.ordem_compra = e.ordem_compra AND p.produto_id = e.produto_id
WHERE e.data_entrada <> p.data_entrega
ORDER BY e.ordem_compra;


