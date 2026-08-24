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
     3) Filtre CODEMP se quiser apenas uma empresa (linha comentada abaixo).
   ============================================================================ */


/* ----------------------------------------------------------------------------
   [1] PRINCIPAL - uma linha por conta, uma coluna por data de corte
   -------------------------------------------------------------------------- */
SELECT
       CTA.CODCTABCOINT                                       AS COD_CONTA,
       CTA.DESCRICAO                                          AS CONTA,
       BCO.CODBCO                                             AS COD_BANCO,
       BCO.NOMEBCO                                            AS BANCO,
       CTA.NUMAGENCIA                                         AS AGENCIA,
       CTA.NUMCONTA                                           AS NUM_CONTA,
       CTA.CODEMP                                             AS COD_EMPRESA,
       CTA.TIPO                                               AS TIPO_CONTA,
       CTA.ATIVA                                              AS ATIVA,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/05/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_04_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/06/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_31_05_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/07/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_06_2026,

       /* movimento liquido de cada mes, util para conferencia */
       NVL(SUM(CASE WHEN MBC.DTLANC >= TO_DATE('01/05/2026','DD/MM/YYYY')
                     AND MBC.DTLANC <  TO_DATE('01/06/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS MOVIMENTO_MAI_2026,

       NVL(SUM(CASE WHEN MBC.DTLANC >= TO_DATE('01/06/2026','DD/MM/YYYY')
                     AND MBC.DTLANC <  TO_DATE('01/07/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS MOVIMENTO_JUN_2026
  FROM TSICTA CTA
  LEFT JOIN TSIBCO BCO
         ON BCO.CODBCO = CTA.CODBCO
  LEFT JOIN TGFMBC MBC
         ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
        AND MBC.DTLANC       < TO_DATE('01/07/2026','DD/MM/YYYY')   /* limite da maior data */
 WHERE 1 = 1
   /* AND CTA.ATIVA  = 'S' */          -- descomente para so contas ativas
   /* AND CTA.CODEMP = 1    */          -- descomente para filtrar empresa
   /* AND CTA.TIPO   = 'C'  */          -- 'C' conta corrente / 'X' caixa / 'A' aplicacao
 GROUP BY CTA.CODCTABCOINT, CTA.DESCRICAO, BCO.CODBCO, BCO.NOMEBCO,
          CTA.NUMAGENCIA, CTA.NUMCONTA, CTA.CODEMP, CTA.TIPO, CTA.ATIVA
 ORDER BY BCO.NOMEBCO, CTA.DESCRICAO;


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
       BCO.NOMEBCO                               AS BANCO,
       NVL((SELECT SUM(M.VLRLANC * M.RECDESP)
              FROM TGFMBC M
             WHERE M.CODCTABCOINT = CTA.CODCTABCOINT
               AND M.DTLANC       < D.DT_SALDO + 1), 0) AS SALDO
  FROM TSICTA CTA
 CROSS JOIN DATAS D
  LEFT JOIN TSIBCO BCO ON BCO.CODBCO = CTA.CODBCO
 WHERE 1 = 1
   /* AND CTA.ATIVA = 'S' */
 ORDER BY D.DT_SALDO, BCO.NOMEBCO, CTA.DESCRICAO;


/* ----------------------------------------------------------------------------
   [3] SALDO CONCILIADO (extrato batido) x SALDO GERENCIAL
       Use quando precisar comparar com o extrato do banco.
   -------------------------------------------------------------------------- */
SELECT
       CTA.CODCTABCOINT                                     AS COD_CONTA,
       CTA.DESCRICAO                                        AS CONTA,
       BCO.NOMEBCO                                          AS BANCO,
       NVL(SUM(MBC.VLRLANC * MBC.RECDESP), 0)               AS SALDO_GERENCIAL_30_06,
       NVL(SUM(CASE WHEN MBC.CONCILIADO = 'S'
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0) AS SALDO_CONCILIADO_30_06,
       NVL(SUM(CASE WHEN NVL(MBC.CONCILIADO,'N') <> 'S'
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0) AS PENDENTE_CONCILIACAO
  FROM TSICTA CTA
  LEFT JOIN TSIBCO BCO ON BCO.CODBCO = CTA.CODBCO
  LEFT JOIN TGFMBC MBC
         ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
        AND MBC.DTLANC       < TO_DATE('01/07/2026','DD/MM/YYYY')
 GROUP BY CTA.CODCTABCOINT, CTA.DESCRICAO, BCO.NOMEBCO
 ORDER BY BCO.NOMEBCO, CTA.DESCRICAO;


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
       Primeiro descubra o nome real das colunas:
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
