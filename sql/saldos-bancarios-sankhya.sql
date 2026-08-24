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
     3) NAO use variaveis de substituicao (&NOME) nem bind (:NOME) nas
        queries abaixo: em varias ferramentas isso gera ORA-01008 ("nem
        todas as variaveis sao limitadas"). Onde aparece 999, edite o
        numero direto no texto da query antes de executar.
     4) As colunas do cadastro TSICTA variam entre versoes/bases do Sankhya.
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
       Troque o 999 pelo CODCTABCOINT que quer auditar (sem & - veja nota no topo).
   -------------------------------------------------------------------------- */
SELECT NUBCO, DTLANC, VLRLANC, RECDESP, VLRLANC * RECDESP AS VLR_COM_SINAL,
       CODTIPOPER, NUMDOC, CONCILIADO, HISTORICO, ORIGMOV
  FROM TGFMBC
 WHERE CODCTABCOINT = 999   /* <<< TROQUE 999 pelo codigo da conta */
 ORDER BY DTLANC, NUBCO;

/* Detalhe de um mes especifico (conferir o movimento da query [1]) */
SELECT NUBCO, DTLANC, VLRLANC, RECDESP, HISTORICO, NUMDOC, CONCILIADO
  FROM TGFMBC
 WHERE CODCTABCOINT = 999   /* <<< TROQUE 999 pelo codigo da conta */
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


/* ============================================================================
   [6] DIAGNOSTICO - conta com saldo NEGATIVO indevido (tipico em APLICACAO)
       Rode na ordem. Troque o 999 pelo CODCTABCOINT da aplicacao.
   ============================================================================ */

/* [6.1] Entradas x saidas da conta: a conta so tem saida?
        Se TOT_ENTRADAS = 0 (ou muito menor que as saidas), a contrapartida
        das aplicacoes nao esta sendo gravada nesta conta -> causa (B) ou (C). */
SELECT CODCTABCOINT,
       COUNT(*)                                                    AS QTD_LANC,
       MIN(DTLANC)                                                 AS PRIMEIRO_LANC,
       MAX(DTLANC)                                                 AS ULTIMO_LANC,
       SUM(CASE WHEN RECDESP =  1 THEN VLRLANC ELSE 0 END)         AS TOT_ENTRADAS,
       SUM(CASE WHEN RECDESP = -1 THEN VLRLANC ELSE 0 END)         AS TOT_SAIDAS,
       SUM(VLRLANC * RECDESP)                                      AS SALDO_ATUAL
  FROM TGFMBC
 WHERE CODCTABCOINT = 999   /* <<< TROQUE 999 pelo codigo da conta */
 GROUP BY CODCTABCOINT;

/* [6.2] Mesma coisa para TODAS as contas de uma vez - mostra quais so tem saida */
SELECT CODCTABCOINT,
       COUNT(*)                                            AS QTD_LANC,
       MIN(DTLANC)                                         AS PRIMEIRO_LANC,
       SUM(CASE WHEN RECDESP =  1 THEN VLRLANC ELSE 0 END) AS TOT_ENTRADAS,
       SUM(CASE WHEN RECDESP = -1 THEN VLRLANC ELSE 0 END) AS TOT_SAIDAS,
       SUM(VLRLANC * RECDESP)                              AS SALDO
  FROM TGFMBC
 GROUP BY CODCTABCOINT
HAVING SUM(VLRLANC * RECDESP) < 0
 ORDER BY SALDO;

/* [6.3] Por TOP (tipo de operacao) e sinal: qual TOP esta gerando o negativo?
        Se a TOP de "aplicacao/resgate" aparece so com RECDESP = -1,
        o sinal esta invertido ou falta a contrapartida. */
SELECT MBC.CODTIPOPER,
       TOP.DESCROPER,
       MBC.RECDESP,
       COUNT(*)          AS QTD,
       SUM(MBC.VLRLANC)  AS VALOR
  FROM TGFMBC MBC
  LEFT JOIN TGFTOP TOP
         ON TOP.CODTIPOPER = MBC.CODTIPOPER
        AND TOP.DHALTER    = MBC.DHTIPOPER
 WHERE MBC.CODCTABCOINT = 999   /* <<< TROQUE 999 pelo codigo da conta */
 GROUP BY MBC.CODTIPOPER, TOP.DESCROPER, MBC.RECDESP
 ORDER BY MBC.CODTIPOPER, MBC.RECDESP;

/* [6.4] VLRLANC ja vem com sinal em alguma linha? Isso quebra VLRLANC*RECDESP
        (menos com menos vira mais). Se retornar linhas, use a formula
        alternativa do bloco [6.7]. */
SELECT COUNT(*) AS QTD_VLRLANC_NEGATIVO
  FROM TGFMBC
 WHERE VLRLANC < 0;

/* [6.5] RECDESP fora do esperado (NULL ou diferente de 1 / -1)?
        NULL faz o lancamento sumir da soma (NULL * qualquer coisa = NULL). */
SELECT NVL(TO_CHAR(RECDESP),'(NULO)') AS RECDESP, COUNT(*) AS QTD
  FROM TGFMBC
 GROUP BY RECDESP
 ORDER BY 1;

/* [6.6] Olhar os lancamentos na mao - o mais confiavel para entender a conta.
        Compare esta lista com o extrato da aplicacao no proprio Sankhya. */
SELECT NUBCO, DTLANC, VLRLANC, RECDESP, VLRLANC * RECDESP AS VLR_COM_SINAL,
       CODTIPOPER, NUMDOC, CONCILIADO, ORIGMOV, HISTORICO
  FROM TGFMBC
 WHERE CODCTABCOINT = 999   /* <<< TROQUE 999 pelo codigo da conta */
 ORDER BY DTLANC, NUBCO;

/* [6.7] FORMULA ALTERNATIVA - use SOMENTE se a [6.4] apontou VLRLANC negativo.
        ABS() neutraliza o sinal ja gravado no valor:
            SUM(ABS(MBC.VLRLANC) * MBC.RECDESP)
        Se o valor ja carrega o sinal correto sozinho, o certo e:
            SUM(MBC.VLRLANC)
        Nunca as duas coisas ao mesmo tempo. */


/* ============================================================================
   [7] SALDO FINAL = SALDO INICIAL DO CADASTRO + MOVIMENTOS DA TGFMBC
       Use quando a abertura da conta NAO esta lancada na TGFMBC.

       PASSO OBRIGATORIO: rode a [7.0] e confirme o nome da coluna de valor.
       Os nomes mudam entre versoes/bases (nem sempre existe coluna de DATA
       do saldo inicial - por isso a [7.1] nao usa nenhuma).
   ============================================================================ */

/* [7.0] Quais colunas de saldo existem no cadastro desta base */
SELECT COLUMN_NAME, DATA_TYPE, DATA_LENGTH
  FROM ALL_TAB_COLUMNS
 WHERE TABLE_NAME = 'TSICTA'
   AND (COLUMN_NAME LIKE '%SALDO%' OR COLUMN_NAME LIKE '%SLD%'
        OR COLUMN_NAME LIKE '%INIC%' OR COLUMN_NAME LIKE '%ABERT%')
 ORDER BY COLUMN_ID;


/* [7.1] PRINCIPAL - saldos em 30/04, 31/05 e 30/06 de 2026, com abertura
        Sem coluna de data: assume que o saldo inicial e a posicao ANTERIOR
        a qualquer lancamento da TGFMBC, entao soma todos os movimentos.
        Troque SALDOINI se a [7.0] mostrar outro nome.                        */
SELECT
       CTA.CODCTABCOINT                                       AS COD_CONTA,
       CTA.DESCRICAO                                          AS CONTA,
       NVL(CTA.SALDOINI, 0)                                   AS SALDO_INICIAL,

       NVL(CTA.SALDOINI, 0) +
       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/05/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_04_2026,

       NVL(CTA.SALDOINI, 0) +
       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/06/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_31_05_2026,

       NVL(CTA.SALDOINI, 0) +
       NVL(SUM(CASE WHEN MBC.DTLANC < TO_DATE('01/07/2026','DD/MM/YYYY')
                    THEN MBC.VLRLANC * MBC.RECDESP END), 0)   AS SALDO_30_06_2026
  FROM TSICTA CTA
  LEFT JOIN TGFMBC MBC
         ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
        AND MBC.DTLANC       < TO_DATE('01/07/2026','DD/MM/YYYY')
 GROUP BY CTA.CODCTABCOINT, CTA.DESCRICAO, CTA.SALDOINI
 ORDER BY CTA.DESCRICAO;


/* [7.2] Contas SEM saldo inicial preenchido no cadastro.
        Se uma aplicacao aparecer aqui E nao tiver abertura na TGFMBC,
        nao existe de onde tirar o saldo - o cadastro precisa ser corrigido. */
SELECT CODCTABCOINT, DESCRICAO, SALDOINI
  FROM TSICTA
 WHERE NVL(SALDOINI, 0) = 0
 ORDER BY DESCRICAO;


/* [7.3] SE a [7.0] mostrar TAMBEM uma coluna de DATA do saldo inicial
        (algo como DTSALDOINI / DTSALDO / DTINIC), entao o saldo inicial vale
        a partir daquela data e os lancamentos ANTERIORES a ela ja estao
        dentro dele - somar tudo contaria em dobro. Nesse caso, acrescente o
        filtro de data no JOIN da [7.1], trocando NOME_DA_COLUNA_DATA:

          LEFT JOIN TGFMBC MBC
                 ON MBC.CODCTABCOINT = CTA.CODCTABCOINT
                AND MBC.DTLANC >= NVL(CTA.NOME_DA_COLUNA_DATA,
                                      TO_DATE('01/01/1900','DD/MM/YYYY')) + 1
                AND MBC.DTLANC <  TO_DATE('01/07/2026','DD/MM/YYYY')

        (o "+ 1" assume saldo inicial = posicao no FECHAMENTO daquela data;
         se for posicao na ABERTURA do dia, use "+ 0". Sem lancamento na
         propria data da abertura, os dois dao o mesmo resultado.)
        Lembre de incluir a coluna de data no GROUP BY.                       */


/* [7.4] CONFERENCIA FINAL - rode a [7.1] e compare o SALDO_30_06_2026 de
        duas ou tres contas com o saldo que a tela de Movimentacao Bancaria
        (ou o Extrato de Conta) do Sankhya mostra em 30/06/2026.
        Batendo nas contas correntes E nas aplicacoes, a query esta pronta. */
