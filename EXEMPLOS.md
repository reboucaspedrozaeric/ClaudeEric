# 📝 Exemplos de Solicitações para Claude Code

Este arquivo contém exemplos prontos de como fazer solicitações efetivas para Claude Code. Use como template para suas próprias demandas!

## 🐛 Exemplo 1: Corrigir um Bug

### Cenário
Seu app tem um erro onde o formulário de login não funciona em Safari.

### Solicitação Efetiva

```
Tem um bug no formulário de login que só acontece no Safari.
Quando o usuário entra o email e senha e clica em "Entrar",
o formulário fica travado e não envia. Não há erro no console.

O formulário está em `src/components/LoginForm.js`.

Podes debugar esse erro? O esperado é que o form envie
normalmente como funciona em Chrome e Firefox.
```

### O que Vou Fazer

1. Acessar o arquivo mencionado
2. Verificar o código do formulário
3. Procurar por incompatibilidades com Safari
4. Testar localmente se possível
5. Fazer as correções necessárias
6. Criar um commit claro com a correção

---

## ✨ Exemplo 2: Implementar uma Nova Feature

### Cenário
Você quer adicionar a capacidade de exportar relatórios em PDF.

### Solicitação Efetiva

```
Preciso adicionar um botão de exportar relatórios em PDF 
no dashboard de vendas.

Requisitos:
- Botão "Exportar PDF" na página de relatórios
- Deve incluir nome da empresa, data, e tabela de dados
- Formas com bordas cinzas e texto em preto
- Funcionar offline (não chamar API)

Arquivos relevantes:
- src/pages/SalesReport.js
- src/services/data.js

Pode implementar isso? Sugestão: usa uma library como 
jsPDF ou similar se achar melhor.
```

### O que Vou Fazer

1. Pesquisar melhor library para o caso de uso
2. Implementar o botão na UI
3. Criar função de exportação em PDF
4. Testar com dados reais
5. Garantir que funciona offline
6. Fazer commit com a implementação completa

---

## 🔧 Exemplo 3: Refatorar Código

### Cenário
Sua pasta de utilities tem muitos arquivos com lógica duplicada.

### Solicitação Efetiva

```
Os arquivos em src/utils/ estão cheios de duplicação:
- helpers.js tem 150 linhas
- validators.js tem 200 linhas
- formatters.js tem 180 linhas

Muitas funções fazem coisas parecidas.

Podes:
1. Analisar a duplicação
2. Reorganizar em uma estrutura mais limpa
3. Manter a API pública igual (sem quebrar imports)
4. Manter todos os testes passando

Aproveita e melhora os nomes das funções também!
```

### O que Vou Fazer

1. Analisar toda a pasta utils
2. Identificar duplicações e padrões
3. Criar uma nova estrutura modular
4. Mover/refatorar funções mantendo compatibilidade
5. Executar todos os testes
6. Fazer commits claros para cada mudança

---

## 🧪 Exemplo 4: Criar Testes

### Cenário
Você tem uma função complexa de cálculo de preços que não tem testes.

### Solicitação Efetiva

```
Preciso de testes para a função calculateFinalPrice 
em src/utils/pricing.js

A função:
- Recebe preço base, taxa de imposto, e código de desconto
- Retorna o preço final
- Deve suportar desconto em % ou valor fixo
- Código de desconto "VIP" dá 20% off, "TRIAL" dá 10%

Preciso de testes para:
- Preço normal sem desconto
- Com desconto percentual (VIP)
- Com desconto fixo
- Múltiplos descontos não são permitidos (deve usar o maior)
- Códigos inválidos devem ser ignorados

Usa Jest + React Testing Library se fizer componentes.
```

### O que Vou Fazer

1. Entender a lógica da função completamente
2. Criar testes para todos os cenários
3. Incluir edge cases (preços negativos, descontos > 100%, etc)
4. Estruturar com describe e it
5. Executar os testes para garantir que passam
6. Deixar pronto para CI/CD

---

## 🔍 Exemplo 5: Revisar Código de Segurança

### Cenário
Você tem uma API que conecta com banco de dados e quer revisar segurança.

### Solicitação Efetiva

```
Faz uma revisão de segurança da API em src/api/users.js

Contexto:
- Express.js
- MongoDB com Mongoose
- Autenticação com JWT
- Usuários podem atualizar seu próprio perfil

Concentra em:
- SQL/NoSQL injection
- XSS
- CSRF
- Autenticação e autorização
- Validação de input

Avisa se encontrar issues e sugere correções.
```

### O que Vou Fazer

1. Analisar toda a API de users
2. Verificar validação de inputs
3. Checar queries para injection
4. Revisar autenticação
5. Procurar por XSS vulnerabilities
6. Listar todas as issues encontradas
7. Sugerir e aplicar correções

---

## 📚 Exemplo 6: Criar Documentação

### Cenário
Você tem uma biblioteca interna e quer documentar os endpoints.

### Solicitação Efetiva

```
Preciso de documentação completa para a API de autenticação 
em src/api/auth.js

A documentação deve ter:
- Descrição de cada endpoint
- Métodos HTTP e URLs
- Parâmetros aceitos
- Responses esperadas (com exemplos)
- Códigos de erro possíveis
- Exemplos de curl

Formato: Markdown que posso colocar em um readme.

Os endpoints são:
- POST /auth/login
- POST /auth/signup
- POST /auth/logout
- POST /auth/refresh
```

### O que Vou Fazer

1. Analisar cada endpoint
2. Extrair informações importantes
3. Estruturar com seções claras
4. Criar exemplos de requisições/respostas
5. Documentar possíveis erros
6. Gerar um markdown pronto para publicar

---

## 💡 Exemplo 7: Otimizar Performance

### Cenário
Sua aplicação está lenta em carregar uma lista grande.

### Solicitação Efetiva

```
A página de produtos está muito lenta. Tem 5 segundos 
para carregar 1000 produtos.

Contexto:
- React frontend em src/pages/Products.js
- Backend em Node/Express
- Dados vêm de MongoDB
- Mostra grid de 100 produtos por vez

Pode otimizar? Foca em:
- Lazy loading / paginação
- Índices do banco
- Cache
- Queries otimizadas
- Imagens otimizadas

Depois de otimizar, testa a performance novamente.
```

### O que Vou Fazer

1. Analisar onde está o gargalo
2. Implementar paginação se não tiver
3. Adicionar índices necessários
4. Otimizar queries do banco
5. Lazy load de imagens
6. Adicionar cache estratégico
7. Medir performance antes/depois

---

## 🎁 Exemplo 8: Setup Inicial de Projeto

### Cenário
Começando um novo projeto Node.js/React.

### Solicitação Efetiva

```
Vou começar um novo projeto React + Node.

Pode:
1. Criar estrutura de pastas padrão
2. Gerar package.json com dependências principais
3. Adicionar prettier e eslint
4. Criar arquivo .env.example
5. Criar .gitignore
6. Adicionar um README básico

Tecnologias:
- Frontend: React 18, Vite
- Backend: Express
- Banco: MongoDB
- Autenticação: JWT
- Deploy: Vercel + Heroku
```

### O que Vou Fazer

1. Criar estrutura de pastas
2. Gerar configs de build e lint
3. Preparar scripts npm úteis
4. Criar templates de variáveis de ambiente
5. Deixar pronto para começar a codificar

---

## ✅ Dicas para Suas Solicitações

### Bom

```
"Cria um componente Button com variantes: primary, secondary, danger
com estados: normal, hover, disabled, loading.
Deve aceitar props: onClick, label, variant, isLoading, disabled"
```

### Evite

```
"Cria um botão lindo"
```

---

## 🎯 Template Genérico

Use este template quando não souber como formular:

```
[Descrição breve do problema/tarefa]

Contexto:
- Arquivos/componentes afetados
- Tecnologias usadas
- Restrições ou requisitos especiais

Detalhes:
- Comportamento esperado
- Casos de uso principais
- Casos de erro/edge cases

Requisitos:
- [ ] Item 1
- [ ] Item 2
- [ ] Item 3

Pode fazer isso? Sugira a melhor abordagem.
```

---

## 🚀 Próximas Ações

1. **Personalize**: Adapte esses exemplos para seu projeto
2. **Experimente**: Comece com uma tarefa pequena
3. **Refine**: Veja os resultados e melhore suas solicitações
4. **Escale**: Aumente a complexidade gradualmente

---

**Lembre-se**: Quanto mais claro e específico, melhor o resultado! 🎯
