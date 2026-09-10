WITH grupo_por_produto AS (
   /* grupo = numero original (TGFPRO.AD_NUMORIGINAL), normalizado */
   SELECT
      CODPROD,
      UPPER(TRIM(AD_NUMORIGINAL)) AS GRUPO
     FROM TGFPRO
    WHERE AD_NUMORIGINAL IS NOT NULL
      AND ATIVO = 'S'
),
marcas_ref AS (
   SELECT DISTINCT
      GPP.GRUPO,
      UPPER(TRIM(PRO.MARCA)) AS MARCA
     FROM grupo_por_produto GPP
     JOIN TGFPRO PRO ON PRO.CODPROD = GPP.CODPROD
    WHERE PRO.MARCA IS NOT NULL
),
marcas_agg AS (
   SELECT
      GRUPO,
      COUNT(*) AS QTD_MARCAS,
      LISTAGG(MARCA, ', ') WITHIN GROUP (ORDER BY MARCA) AS MARCAS
     FROM marcas_ref
    GROUP BY GRUPO
   HAVING COUNT(*) > 1
),
descricao_contada AS (
   /* quantas vezes cada descricao aparece dentro do grupo */
   SELECT
      GPP.GRUPO,
      PRO.DESCRPROD,
      COUNT(*) OVER (PARTITION BY GPP.GRUPO, PRO.DESCRPROD) AS QTD_DESCR
     FROM grupo_por_produto GPP
     JOIN TGFPRO PRO ON PRO.CODPROD = GPP.CODPROD
),
descricao_grupo AS (
   /* descricao mais frequente de cada grupo (desempate alfabetico) */
   SELECT X.GRUPO, X.DESCRPROD AS DESCRICAO
     FROM (
            SELECT
               GRUPO,
               DESCRPROD,
               ROW_NUMBER() OVER (
                  PARTITION BY GRUPO
                  ORDER BY QTD_DESCR DESC, DESCRPROD
               ) AS RN
              FROM descricao_contada
          ) X
    WHERE X.RN = 1
),
produtos AS (
   SELECT
      GRUPO,
      COUNT(DISTINCT CODPROD) AS QTD_SKUS
     FROM grupo_por_produto
    GROUP BY GRUPO
),
vendas AS (
   SELECT
      GPP.GRUPO,
      SUM(ITE.VLRTOT) AS FATURAMENTO
     FROM TGFITE ITE
     JOIN TGFCAB CAB ON CAB.NUNOTA = ITE.NUNOTA
     JOIN TGFTOP TOP ON TOP.CODTIPOPER = CAB.CODTIPOPER
     JOIN grupo_por_produto GPP ON GPP.CODPROD = ITE.CODPROD
    WHERE TOP.TIPMOV = 'V'
      AND CAB.STATUSNOTA = 'L'
      AND CAB.DTNEG BETWEEN TO_DATE('01/01/2026', 'DD/MM/YYYY')
                        AND TO_DATE('31/12/2026', 'DD/MM/YYYY')
    GROUP BY GPP.GRUPO
),
custo_atual AS (
   /* custo mais recente (CusSemICM) por CODEMP/CODPROD */
   SELECT
      T.CODEMP,
      T.CODPROD,
      T.CUSSEMICM
     FROM TGFCUS T
    WHERE T.DTATUAL = (
             SELECT MAX(T2.DTATUAL)
               FROM TGFCUS T2
              WHERE T2.CODEMP = T.CODEMP
                AND T2.CODPROD = T.CODPROD
          )
),
estoque AS (
   SELECT
      GPP.GRUPO,
      SUM(EST.ESTOQUE * NVL(CUS.CUSSEMICM, 0)) AS VALOR_ESTOQUE
     FROM TGFEST EST
     JOIN grupo_por_produto GPP ON GPP.CODPROD = EST.CODPROD
     LEFT JOIN custo_atual CUS
       ON CUS.CODPROD = EST.CODPROD
      AND CUS.CODEMP = EST.CODEMP
    GROUP BY GPP.GRUPO
)
SELECT
   DSC.DESCRICAO                AS "Descricao",
   MAR.GRUPO                    AS "Referencia",
   MAR.QTD_MARCAS                AS "Qtd_Marcas",
   MAR.MARCAS                    AS "Marcas",
   PRD.QTD_SKUS                  AS "Qtd_SKUs",
   NVL(VEN.FATURAMENTO, 0)       AS "Faturamento_RS",
   NVL(EST.VALOR_ESTOQUE, 0)     AS "Valor_em_Estoque_RS"
  FROM produtos PRD
  JOIN marcas_agg MAR ON MAR.GRUPO = PRD.GRUPO
  JOIN descricao_grupo DSC ON DSC.GRUPO = PRD.GRUPO
  LEFT JOIN vendas VEN ON VEN.GRUPO = PRD.GRUPO
  LEFT JOIN estoque EST ON EST.GRUPO = PRD.GRUPO
 ORDER BY NVL(VEN.FATURAMENTO, 0) DESC

/* =====================================================================
   NOTAS (fora do comando para nao quebrar validadores que exigem que
   a query comece literalmente com SELECT ou WITH)
   =====================================================================
   ANALISE DE PRODUTOS CONCORRENTES POR NUMERO ORIGINAL (AD_NUMORIGINAL)

   TGFPRO.REFERENCIA NAO serve para este cruzamento: e apenas o CODPROD
   com zero a esquerda, unico por produto e nunca compartilhado entre
   marcas (confirmado em dados reais: CODPROD 261466 -> REFERENCIA
   '0261466').

   A primeira tentativa usou TGFPRO.AD_NUMAUX (lista de numeros de
   intercambio separada por virgula, explodida e agrupada pelo menor
   numero normalizado), mas trouxe grupos demais/errados - a lista de
   auxiliares aparentemente inclui numeros que nao sao exclusivos de
   um unico grupo de equivalencia, entao o "menor numero da lista"
   acabava juntando produtos que nao deveriam estar juntos.

   Agora o agrupamento usa TGFPRO.AD_NUMORIGINAL diretamente: um valor
   unico por produto (nao uma lista), normalizado (maiusculas, trim).
   Exemplo real: CODPROD 261466 (SENSOR ELETRONICO PRESSAO, marca
   3RHO) tem AD_NUMORIGINAL = '7733'. Produtos de marcas diferentes
   com o mesmo AD_NUMORIGINAL caem no mesmo grupo.

   So mantem grupos com mais de uma marca (concorrencia real) - ver
   HAVING COUNT(*) > 1 na CTE marcas_agg.

   Isso responde tambem ao pedido de trazer a referencia (nao so a
   descricao) na saida: a coluna "Referencia" mostra o AD_NUMORIGINAL
   usado para juntar as marcas.

   Ainda NAO incorporado (falar se quiser incluir):
     - TGFPAP (aba "Produtos Equivalentes"): mapeia CODPROD para
       codigos equivalentes por parceiro/fornecedor - e uma fonte
       diferente (equivalencia para fins de compra), nao foi somada
       aqui
     - Campo CARACTERISTICAS (aba Geral): e texto livre de aplicacao
       veicular, nao um numero de referencia estruturado - nao usado
       para o agrupamento
     - AD_NUMFABRICANTE / AD_NUMAUX: campos alternativos de referencia
       que nao estao sendo usados nesta versao

   Ajuste antes de rodar:
     - Periodo de faturamento (TO_DATE(...) na CTE vendas)
     - Filtro de empresa (CODEMP), se aplicavel, nas CTEs vendas/estoque
     - Custo: TGFCUS.CUSSEMICM mais recente por CODEMP/CODPROD
   ===================================================================== */
