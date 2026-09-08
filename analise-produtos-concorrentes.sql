/* =====================================================================
   ANALISE DE PRODUTOS CONCORRENTES POR REFERENCIA (TGFPRO.REFERENCIA)
   =====================================================================
   Agrupa os produtos que compartilham a mesma REFERENCIA (numero de
   referencia cruzada usado para identificar itens equivalentes de
   marcas diferentes) e monta, por grupo, a mesma visao do exemplo:

     Descricao | Qtd Marcas | Marcas | Qtd SKUs | Faturamento (R$) | Valor em Estoque (R$)

   Ajuste antes de rodar:
     - Periodo de faturamento (TO_DATE(...) na CTE vendas abaixo)
     - Filtro de empresa (CODEMP) nas CTEs de venda e estoque, se aplicavel
     - Campo de custo usado na valorizacao do estoque (hoje: PRO.CUSTOPROD)
     - HAVING COUNT(*) > 1 na CTE marcas_agg: mantem so referencias com
       mais de uma marca (ou seja, com concorrencia real)
   ===================================================================== */

WITH marcas_ref AS (
   /* uma linha por (REFERENCIA, MARCA) distintos, ja normalizando texto */
   SELECT DISTINCT
      PRO.REFERENCIA,
      UPPER(TRIM(PRO.MARCA)) AS MARCA
     FROM TGFPRO PRO
    WHERE PRO.REFERENCIA IS NOT NULL
      AND PRO.MARCA IS NOT NULL
      AND PRO.ATIVO = 'S'
),
marcas_agg AS (
   SELECT
      REFERENCIA,
      COUNT(*) AS QTD_MARCAS,
      LISTAGG(MARCA, ', ') WITHIN GROUP (ORDER BY MARCA) AS MARCAS
     FROM marcas_ref
    GROUP BY REFERENCIA
   HAVING COUNT(*) > 1
),
produtos AS (
   /* descricao representativa do grupo (a mais frequente) e contagem de SKUs */
   SELECT
      REFERENCIA,
      COUNT(DISTINCT CODPROD) AS QTD_SKUS,
      MIN(DESCRPROD) KEEP (
         DENSE_RANK FIRST ORDER BY QTD_DESCR DESC, DESCRPROD
      ) AS DESCRICAO
     FROM (
            SELECT
               PRO.REFERENCIA,
               PRO.CODPROD,
               PRO.DESCRPROD,
               COUNT(*) OVER (PARTITION BY PRO.REFERENCIA, PRO.DESCRPROD) AS QTD_DESCR
              FROM TGFPRO PRO
             WHERE PRO.REFERENCIA IS NOT NULL
               AND PRO.ATIVO = 'S'
          )
    GROUP BY REFERENCIA
),
vendas AS (
   SELECT
      PRO.REFERENCIA,
      SUM(ITE.VLRTOT) AS FATURAMENTO
     FROM TGFITE ITE
     JOIN TGFCAB CAB ON CAB.NUNOTA = ITE.NUNOTA
     JOIN TGFTOP TOP ON TOP.CODTIPOPER = CAB.CODTIPOPER
     JOIN TGFPRO PRO ON PRO.CODPROD = ITE.CODPROD
    WHERE TOP.TIPMOV = 'V'
      AND CAB.STATUSNOTA = 'L'
      AND PRO.REFERENCIA IS NOT NULL
      AND CAB.DTNEG BETWEEN TO_DATE('01/01/2026', 'DD/MM/YYYY')
                        AND TO_DATE('31/12/2026', 'DD/MM/YYYY')
    GROUP BY PRO.REFERENCIA
),
estoque AS (
   SELECT
      PRO.REFERENCIA,
      SUM(EST.ESTOQUE * PRO.CUSTOPROD) AS VALOR_ESTOQUE
     FROM TGFEST EST
     JOIN TGFPRO PRO ON PRO.CODPROD = EST.CODPROD
    WHERE PRO.REFERENCIA IS NOT NULL
    GROUP BY PRO.REFERENCIA
)
SELECT
   PRD.DESCRICAO                AS "Descricao",
   MAR.QTD_MARCAS                AS "Qtd Marcas",
   MAR.MARCAS                    AS "Marcas",
   PRD.QTD_SKUS                  AS "Qtd SKUs",
   NVL(VEN.FATURAMENTO, 0)       AS "Faturamento (R$)",
   NVL(EST.VALOR_ESTOQUE, 0)     AS "Valor em Estoque (R$)"
  FROM produtos PRD
  JOIN marcas_agg MAR ON MAR.REFERENCIA = PRD.REFERENCIA
  LEFT JOIN vendas VEN ON VEN.REFERENCIA = PRD.REFERENCIA
  LEFT JOIN estoque EST ON EST.REFERENCIA = PRD.REFERENCIA
 ORDER BY NVL(VEN.FATURAMENTO, 0) DESC
