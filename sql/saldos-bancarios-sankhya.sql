/* ============================================================================
   SALDOS BANCARIOS POR CONTA - SANKHYA (Oracle)
   Datas de corte: 30/04/2026, 31/05/2026 e 30/06/2026

   Conceito:
     O saldo de uma conta em uma data D e a soma acumulada de TODOS os
     lancamentos da TGFMBC (movimentacao bancaria/caixa) com DTLANC <= D.
     - TGFMBC.RECDESP =  1  -> entrada (credito)
     - TGFMBC.RECDESP = -1  -> saida   (debito)
     - TGFMBC.VLRLANC       -> valor sempre positivo; o sinal vem do RECDESP

   Observacoes importantes:
     1) DTLANC pode ter hora. Por isso o corte usa "< dia seguinte" em vez de
        "<= dia", garantindo que lancamentos das 23h do dia 30 entrem no saldo.
     2) O saldo inicial da conta normalmente ja esta lancado na propria TGFMBC
        (TOP de saldo inicial). Rode a query [4] para conferir; se na sua base
        o saldo inicial estiver so no cadastro da conta, veja o bloco [5].
     3) As colunas do cadastro TSICTA variam entre versoes/bases do Sankhya.
        A query [1] usa APENAS CODCTABCOINT e DESCRICAO, que existem sempre.
        Rode a query [0] para descobrir os nomes reais de banco/agencia/
        empresa na sua base e enriqueca a [1] conforme o bloco [1b].
   ============================================================================ */


/* ----------------------------------------------------------------------------
   [0] DESCOBERTA - quais colunas existem no cadastro de contas desta base
       Rode primeiro. E daqui que saem os nomes de banco/agencia/conta/empresa.
   -------------------------------------------------------------------------- */
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH
  FROM ALL_TAB_COLUMNS
 WHERE TABLE_NAME = 'TSICTA'
 ORDER BY COLUMN_ID;

/* Alternativa rapida: olhar uma linha inteira do cadastro */
-- SELECT * FROM TSICTA WHERE ROWNUM = 1;


/* ----------------------------------------------------------------------------
   [1] PRINCIPAL - uma linha por conta, uma coluna por data de corte
       Versao minima: so usa colunas que existem em qualquer base Sankhya.
   -------------------------------------------------------------------------- */
SELECT
       CTA.CODCTABCOINT                                       AS COD_CONTA,
       CTA.DESCRICAO                                          AS CONTA,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/05/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_04_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/06/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_31_05_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/07/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_06_2026,

       /* movimento liquido de cada mes, util para conferencia:
          saldo anterior + movimento = saldo novo */
       NVL(SUM(CASE WHEN MBC.DTLANC >= TO_DATE('01/05/2026','DD/MM/YYYY')
                     AND MBC.DTLANC <  TO_DATE('01/06/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS MOVIMENTO_MAI_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC >= TO_DATE('01/06/2026','DD/MM/YYYY')
                     AND MBC.DTLANC <  TO_DATE('01/07/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS MOVIMENTO_JUN_2026
  FROM TSICTA CTA
  LEFT JOIN TGFMBC MBC
         ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
        AND MBC.DTLANC       < TO_DATE('01/07/2026','DD/MM/YYYY')   /* limite da maior data */
 GROUP BY CTA.CODCTABCOINT, CTA.DESCRICAO
 ORDER BY CTA.DESCRICAO;


/* ----------------------------------------------------------------------------
   [1b] ENRIQUECIMENTO OPCIONAL - so depois de confirmar os nomes na query [0]
        Exemplos de colunas que costumam existir (confirme antes de usar!):
          CODEMP, CODBCO, NUMAGENCIA / AGENCIA, NUMCONTA / CONTA,
          ATIVA / ATIVO, TIPO / TIPOCTA
        Para trazer o nome do banco, junte com TSIBCO:
          LEFT JOIN TSIBCO BCO ON BCO.CODBCO = CTA.CODBCO
        Lembre de incluir cada coluna nova TAMBEM no GROUP BY.

        Filtros que provavelmente vai querer (descomente na [1]):
          WHERE CTA.ATIVA  = 'S'    -- so contas ativas
          WHERE CTA.CODEMP = 1      -- uma empresa especifica
   -------------------------------------------------------------------------- */


/* ----------------------------------------------------------------------------
   [2] VERSAO "LISTA" - uma linha por conta E por data (bom para exportar/BI)
   -------------------------------------------------------------------------- */
WITH DATAS AS (
       SELECT TO_DATE('30/04/2026','DD/MM/YYYY') AS DT_SALDO FROM DUAL
        UNION ALL
       SELECT TO_DATE('31/05/2026','DD/MM/YYYY') FROM DUAL
        UNION ALL
       SELECT TO_DATE('30/06/2026','DD/MM/YYYY') FROM DUAL
)
SELECT
       D.DT_SALDO,
       CTA.CODCTABCOINT                          AS COD_CONTA,
       CTA.DESCRICAO                             AS CONTA,
       NVL((SELECT SUM(M.VLRLANC * M.RECDESP)
              FROM TGFMBC M
             WHERE M.CODCTABCOINT = CTA.CODCTABCOINT
               AND M.DTLANC       < D.DT_SALDO + 1), 0) AS SALDO
  FROM TSICTA CTA
 CROSS JOIN DATAS D
 ORDER BY D.DT_SALDO, CTA.DESCRICAO;


/* ----------------------------------------------------------------------------
   [3] SALDO CONCILIADO (extrato batido) x SALDO GERENCIAL em 30/06/2026
       Use quando precisar comparar com o extrato do banco.
   -------------------------------------------------------------------------- */
SELECT
       CTA.CODCTABCOINT                                     AS COD_CONTA,
       CTA.DESCRICAO                                        AS CONTA,
       NVL(SUM(MBC.VLRLANC * MBC.RECDESP), 0)               AS SALDO_GERENCIAL_30_06,
       NVL(SUM(CASE WHEN MBC.CONCILIADO = 'S'
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0) AS SALDO_CONCILIADO_30_06,
       NVL(SUM(CASE WHEN NVL(MBC.CONCILIADO,'N') <> 'S'
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0) AS PENDENTE_CONCILIACAO
  FROM TSICTA CTA
  LEFT JOIN TGFMBC MBC
         ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
        AND MBC.DTLANC       < TO_DATE('01/07/2026','DD/MM/YYYY')
 GROUP BY CTA.CODCTABCOINT, CTA.DESCRICAO
 ORDER BY CTA.DESCRICAO;


/* ----------------------------------------------------------------------------
   [4] CONFERENCIA - primeiros lancamentos da conta (o saldo inicial esta aqui?)
       Troque &COD_CONTA pelo CODCTABCOINT que quer auditar.
   -------------------------------------------------------------------------- */
SELECT NUBCO, DTLANC, VLRLANC, RECDESP, VLRLANC * RECDESP AS VLR_COM_SINAL,
       CODTIPOPER, NUMDOC, CONCILIADO, HISTORICO, ORIGMOV
  FROM TGFMBC
 WHERE CODCTABCOINT = &COD_CONTA
 ORDER BY DTLANC, NUBCO
 FETCH FIRST 50 ROWS ONLY;

/* Detalhe de um mes especifico (conferir o movimento da query [1]) */
SELECT NUBCO, DTLANC, VLRLANC, RECDESP, HISTORICO, NUMDOC, CONCILIADO
  FROM TGFMBC
 WHERE CODCTABCOINT = &COD_CONTA
   AND DTLANC >= TO_DATE('01/06/2026','DD/MM/YYYY')
   AND DTLANC <  TO_DATE('01/07/2026','DD/MM/YYYY')
 ORDER BY DTLANC, NUBCO;


/* ----------------------------------------------------------------------------
   [5] SE a sua base guardar saldo inicial NO CADASTRO da conta (e nao na TGFMBC)
       Primeiro descubra o nome real da coluna:
   -------------------------------------------------------------------------- */
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
  FROM ALL_TAB_COLUMNS
 WHERE TABLE_NAME IN ('TSICTA','TGFMBC')
   AND (COLUMN_NAME LIKE '%SALDO%' OR COLUMN_NAME LIKE '%SLD%')
 ORDER BY TABLE_NAME, COLUMN_ID;

/* Depois basta somar a coluna encontrada ao saldo, por exemplo:
       NVL(CTA.SALDOINI, 0)
     + NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/05/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0) AS SALDO_30_04_2026
   (incluindo CTA.SALDOINI no GROUP BY)
*/
