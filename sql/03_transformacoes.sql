-- 03_transformacoes
-- Etapa 2 - Transformações de dados (Parte 3)
-- Banco: PostgreSQL | Rodar depois de 01_ddl_postgres.sql e importar.py


-- Pedidos de compra
SELECT
    pc.produto_id || COALESCE(' - ' || NULLIF(TRIM(pc.descricao_produto), ''), '') AS "Produto",
    pc.qtde_pedida                                                                 AS "Qtde Requisitada",
    TO_CHAR(pc.data_pedido, 'DD/MM/YYYY')                                          AS "Data Solicitação"
FROM public.pedido_compra pc
ORDER BY pc.data_pedido, pc.produto_id;

-- Vendas (a descrição vem de produtos_filial; vendas sem cadastro saem só com o código)
SELECT
    v.produto_id || COALESCE(' - ' || NULLIF(TRIM(p.descricao), ''), '') AS "Produto",
    v.qtde_vendida                                                       AS "Qtde Vendida",
    TO_CHAR(v.data_emissao, 'DD/MM/YYYY')                                AS "Data Emissão"
FROM public.venda v
LEFT JOIN (
    SELECT produto_id, MAX(descricao) AS descricao
    FROM public.produtos_filial
    GROUP BY produto_id
) p ON p.produto_id = v.produto_id
ORDER BY v.data_emissao, v.produto_id;

-- Produtos
SELECT
    pf.produto_id || COALESCE(' - ' || NULLIF(TRIM(pf.descricao), ''), '') AS "Produto",
    pf.filial_id                                                           AS "Filial",
    pf.estoque                                                             AS "Estoque"
FROM public.produtos_filial pf
ORDER BY pf.filial_id, LENGTH(pf.produto_id), pf.produto_id;


-- 3.3  Apenas os produtos requisitados "mais de 10 vezes" no período

CREATE OR REPLACE FUNCTION public.fn_requisicoes_mais_de(
    p_data_ini DATE,
    p_data_fim DATE,
    p_minimo   NUMERIC DEFAULT 10
)
RETURNS TABLE (
    produto          TEXT,
    qtde_requisitada NUMERIC,
    data_solicitacao TEXT
)
LANGUAGE sql STABLE AS $$
    WITH periodo AS (
        SELECT *
        FROM public.pedido_compra
        WHERE data_pedido BETWEEN p_data_ini AND p_data_fim
    ),
    produtos_filtrados AS (
        SELECT produto_id
        FROM periodo
        GROUP BY produto_id
        HAVING SUM(qtde_pedida) > p_minimo
    )
    SELECT
        pc.produto_id || COALESCE(' - ' || NULLIF(TRIM(pc.descricao_produto), ''), ''),
        pc.qtde_pedida::NUMERIC,
        TO_CHAR(pc.data_pedido, 'DD/MM/YYYY')
    FROM periodo pc
    JOIN produtos_filtrados f ON f.produto_id = pc.produto_id
    ORDER BY pc.data_pedido, pc.produto_id;
$$;


SELECT * FROM public.fn_requisicoes_mais_de('2025-02-01', '2025-02-28');


-- 3.4  Trigger que gera automaticamente um novo idfornecedor na tabela
--      de produtos, relacionado à tabela de fornecedor.


ALTER TABLE public.produtos_filial DROP CONSTRAINT IF EXISTS fk_produtos_filial_fornecedor;
ALTER TABLE public.produtos_filial
    ADD CONSTRAINT fk_produtos_filial_fornecedor
    FOREIGN KEY (idfornecedor) REFERENCES public.fornecedor (idfornecedor);

DROP SEQUENCE IF EXISTS public.seq_idfornecedor;
CREATE SEQUENCE public.seq_idfornecedor;
SELECT setval(
    'public.seq_idfornecedor',
    COALESCE((SELECT MAX(SUBSTRING(idfornecedor FROM '[0-9]+')::INT) FROM public.fornecedor), 0) + 1,
    false
);

CREATE OR REPLACE FUNCTION public.fn_gera_idfornecedor()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_novo_id VARCHAR(25);
BEGIN
    IF NEW.idfornecedor IS NULL OR TRIM(NEW.idfornecedor) = '' THEN
        v_novo_id := 'F' || nextval('public.seq_idfornecedor');

        INSERT INTO public.fornecedor (idfornecedor, razao_social)
        VALUES (v_novo_id, 'FORNECEDOR A DEFINIR ' || v_novo_id);

        NEW.idfornecedor := v_novo_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_gera_idfornecedor ON public.produtos_filial;
CREATE TRIGGER trg_gera_idfornecedor
    BEFORE INSERT ON public.produtos_filial
    FOR EACH ROW
    EXECUTE FUNCTION public.fn_gera_idfornecedor();



