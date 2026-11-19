##  AgroMarkt

## Comparador de Insumos e Fertilizantes Agrícolas

O AgroMarkt é uma plataforma desenvolvida para facilitar a pesquisa, comparação de preços e solicitação de cotações de insumos agrícolas, conectando produtores rurais e fornecedores.

## Acesse o sistema

Aplicação online:** https://agromarkt-web.onrender.com/

Acesse pelo navegador, tanto no computador quanto no celular.

## Funcionalidades

### Produtor
- Consultar o catálogo de produtos agrícolas.
- Pesquisar fertilizantes, insumos e defensivos.
- Comparar preços entre produtos.
- Consultar preços por unidade (R$/kg e R$/L).
- Solicitar cotações aos fornecedores.
- Acompanhar solicitações e consultar históricos.

### Fornecedor
- Cadastrar produtos.
- Editar e gerenciar produtos.
- Cadastrar e administrar ofertas.
- Consultar informações comerciais.
- Acompanhar registros e históricos de ofertas.

### Administrador
- Acessar o painel administrativo.
- Gerenciar funcionalidades da plataforma.
- Administrar usuários e permissões.
- Acompanhar informações do sistema.

## Como utilizar

1. Acesse https://agromarkt-web.onrender.com/.
2. Entre na aplicação utilizando seu usuário e senha.
3. O sistema identificará seu perfil de acesso.
4. Utilize as funcionalidades disponíveis no seu ambiente.

### Fluxo do produtor
1. Acesse o catálogo.
2. Pesquise o produto desejado.
3. Consulte as informações e os preços.
4. Compare diferentes produtos.
5. Realize uma solicitação de cotação.
6. Acompanhe suas solicitações.

### Fluxo do fornecedor
1. Acesse o ambiente do fornecedor.
2. Cadastre ou consulte seus produtos.
3. Gerencie os preços e as ofertas.
4. Acompanhe os registros comerciais.

### Fluxo do administrador
1. Acesse o ambiente administrativo com uma conta autorizada.
2. Consulte as funcionalidades de gerenciamento.
3. Administre os recursos disponíveis conforme suas permissões.

## Tecnologias utilizadas

| Tecnologia | Utilização |
|---|---|
| Flutter | Interface da aplicação |
| Dart | Linguagem do frontend |
| Provider | Gerenciamento de estado |
| Node.js | Backend |
| Express | API REST |
| PostgreSQL | Banco de dados |
| Neon | Hospedagem do banco de dados |
| Render | Hospedagem da aplicação e API |

## Estrutura do projeto

```text
AgroMarkt/
├── backend/       # API e regras de negócio
├── lib/           # Aplicação Flutter
│   ├── adapters/
│   ├── config/
│   ├── controllers/
│   ├── models/
│   └── views/
├── test/          # Testes automatizados
├── web/           # Configurações da versão web
├── pubspec.yaml
└── README.md
```

## Disponibilidade

- Acesso pelo navegador.
- Interface adaptada para computadores e celulares.
- Algumas funcionalidades disponíveis offline.

## Projeto acadêmico

Desenvolvido como projeto acadêmico do curso de **Bacharelado em Ciência da Computação**, da Universidade do Estado de Mato Grosso (UNEMAT).

**Versão:** 1.0.0  
**Tipo:** MVP — Produto Mínimo Viável
