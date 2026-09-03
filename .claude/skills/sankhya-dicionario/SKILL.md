---
name: sankhya-dicionario
description: Consulta o dicionário de dados do ERP Sankhya (tabelas TGF* - Comercial/Faturamento/Financeiro/Estoque) extraído do TDDINS/TDDCAM/TDDLIG. Use SEMPRE que o usuário perguntar sobre uma tabela do Sankhya (ex. TGFCAB, TGFITE, TGFPAR), pedir os campos de uma tabela, o que uma instância representa, quais ligações/relacionamentos uma tabela ou instância tem, ou pedir para montar SQL contra tabelas TGF do Sankhya. Não use para tabelas fora do prefixo TGF (essas não estão no dicionário) nem para Ações/Eventos de instância (não cobertos).
---

# Dicionário de Dados Sankhya (tabelas TGF*)

Banco SQLite local com o dicionário de dados do Sankhya, extraído das tabelas
internas do próprio Sankhya (`TDDINS`, `TDDCAM`, `TDDLIG`) via DBExplorer.
Cobre **apenas tabelas cujo nome começa com `TGF`** (Comercial, Faturamento,
Financeiro, Estoque — o núcleo transacional do ERP). Não inclui tabelas de
sistema (`TSI*`, `TDD*`, `TCS*` etc.) nem as abas de Ações/Eventos das
instâncias.

Arquivo: `dicionario_sankhya.db` (mesma pasta deste SKILL.md).

## Quando usar

Antes de escrever ou explicar SQL contra uma tabela `TGF*`, ou responder
"quais campos tem a tabela X", "o que é a instância Y", "com o que a tabela X
se liga" — consulte este banco em vez de supor nomes de coluna. Se a tabela
perguntada não começa com `TGF` ou não aparece no banco, diga isso
explicitamente em vez de inventar campos.

## Estrutura do banco

**`instancias`** — cada instância (tela/entidade) do Sankhya e a tabela física por trás dela.
- `nome_instancia` (ex: `CabecalhoNota`), `descr_instancia` (ex: "Nota/Pedido"), `nome_tabela` (ex: `TGFCAB`)
- Várias instâncias podem apontar para a mesma tabela (ex: `CabecalhoNota`, `CabecalhoNotaSaida`, `NotaOrigem` são todas `TGFCAB`).

**`campos`** — campos de cada tabela física (deduplicados por tabela+campo; um campo pertence à tabela, não à instância).
- `nome_tabela`, `nome_campo`, `descr_campo`, `tipo_campo`, `tipo_apresentacao`, `permite_pesquisa`, `aparece_grid_pesquisa`

**`ligacoes`** — ligações (relacionamentos/FKs lógicos) de cada instância especificamente (instâncias diferentes na mesma tabela podem ter ligações diferentes).
- `nome_instancia`, `nome_tabela`, `origem_dos_dados` (destino da ligação, formato `NomeInstancia [TABELA]`), `filtro_de_ligacao`, `adicional`, `nome_interno`

## Como consultar

Use o módulo `sqlite3` do Python (não depende de instalar o binário `sqlite3` CLI):

```bash
python3 -c "
import sqlite3
conn = sqlite3.connect('.claude/skills/sankhya-dicionario/dicionario_sankhya.db')
cur = conn.cursor()
for r in cur.execute(\"SELECT nome_campo, descr_campo, tipo_campo, tipo_apresentacao FROM campos WHERE nome_tabela='TGFCAB' ORDER BY nome_campo\"):
    print(r)
"
```

Exemplos comuns:

```sql
-- Todos os campos de uma tabela
SELECT * FROM campos WHERE nome_tabela = 'TGFITE';

-- Buscar campo por nome parcial (quando não souber o nome exato da coluna)
SELECT * FROM campos WHERE nome_tabela = 'TGFCAB' AND nome_campo LIKE '%PARC%';

-- Quais instâncias existem para uma tabela
SELECT nome_instancia, descr_instancia FROM instancias WHERE nome_tabela = 'TGFCAB';

-- Ligações de uma instância específica (com quem ela se relaciona)
SELECT origem_dos_dados, nome_interno, filtro_de_ligacao FROM ligacoes WHERE nome_instancia = 'CabecalhoNota';

-- Descobrir a tabela física por trás de uma instância
SELECT nome_tabela FROM instancias WHERE nome_instancia = 'ItemNota';
```

## Limitações — seja transparente sobre isso com o usuário

- Snapshot estático extraído em 2026-09 de um ambiente específico
  (mmarra.sankhyacloud.com.br). Customizações locais (campos `AD_*`
  adicionados depois, novas instâncias) podem não estar refletidas se
  o ambiente mudou desde a extração.
- Não cobre Ações nem Eventos de instância (não foram mapeados).
- Não cobre tabelas fora do prefixo `TGF*` (ex: `TSI*`, `TDD*`, `TCS*`,
  `TFP*` — sistema, financeiro de RH, OS, etc. ficaram de fora).
- Para algo crítico (produção, migração, cliente), confirme contra o
  DBExplorer do ambiente real antes de assumir como verdade absoluta —
  este banco é um ponto de partida rápido, não a fonte de verdade.
