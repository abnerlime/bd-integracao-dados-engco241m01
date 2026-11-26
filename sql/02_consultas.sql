-- 02_consultas

-- Etapa 2 - Consultas 
-- 2.1  Total vendido, em quantidade e em R$, por produto - fevereiro/2025

SELECT
    v.produto_id,
    COALESCE(p.descricao, '(sem cadastro)')                       AS descricao,
    SUM(v.qtde_vendida)                                           AS qtde_total,
    ROUND(SUM(v.qtde_vendida::NUMERIC * v.valor_unitario), 2)     AS valor_total_rs
FROM public.venda v
LEFT JOIN (
    SELECT produto_id, MAX(descricao) AS descricao
    FROM public.produtos_filial
    GROUP BY produto_id
) p ON p.produto_id = v.produto_id
WHERE v.data_emissao >= DATE '2025-02-01'
  AND v.data_emissao <  DATE '2025-03-01'
GROUP BY v.produto_id, p.descricao
ORDER BY LENGTH(v.produto_id), v.produto_id;

-- 2.2  Produtos requisitados e não recebidos

SELECT
    pc.produto_id,
    pc.descricao_produto,
    pc.pedido_id,
    pc.ordem_compra,
    pc.qtde_pedida,
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY') AS data_pedido
FROM public.pedido_compra pc
WHERE NOT EXISTS (
    SELECT 1
    FROM public.entradas_mercadoria e
    WHERE e.ordem_compra = pc.ordem_compra
      AND e.produto_id   = pc.produto_id
)
ORDER BY LENGTH(pc.produto_id), pc.produto_id, pc.pedido_id;

-- 2.2
SELECT
    pc.produto_id,
    pc.pedido_id,
    pc.ordem_compra,
    pc.qtde_pedida,
    COALESCE(SUM(e.qtde_recebida), 0)                    AS qtde_recebida,
    pc.qtde_pedida - COALESCE(SUM(e.qtde_recebida), 0)   AS qtde_pendente
FROM public.pedido_compra pc
LEFT JOIN public.entradas_mercadoria e
       ON e.ordem_compra = pc.ordem_compra
      AND e.produto_id   = pc.produto_id
GROUP BY pc.produto_id, pc.pedido_id, pc.ordem_compra, pc.qtde_pedida
HAVING COALESCE(SUM(e.qtde_recebida), 0) < pc.qtde_pedida
ORDER BY LENGTH(pc.produto_id), pc.produto_id, pc.pedido_id;


