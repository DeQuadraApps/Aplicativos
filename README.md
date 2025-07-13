# Quadra Vendas

**Quadra Vendas** é um sistema de gestão de vendas completo, desenhado para ser robusto, profissional e funcionar perfeitamente mesmo sem ligação à internet. Construído com Flutter e Firebase, oferece uma solução completa desde o registo de clientes e produtos até à finalização da venda e geração de relatórios em PDF.

---

## ✨ Funcionalidades Principais

O sistema foi construído com um foco na usabilidade e na robustez, garantindo que o utilizador possa trabalhar de forma eficiente em qualquer situação.

### **Gestão de Autenticação e Utilizadores**
* **Login e Registo Seguro:** Autenticação completa com e-mail e senha através do Firebase Authentication.
* **Termos de Uso Obrigatórios:** Fluxo de registo profissional com um checkbox obrigatório para aceitação dos Termos e Condições de Uso.
* **Onboarding de Instituição:** Após o registo, o utilizador é guiado para criar a sua própria "instituição", garantindo o isolamento dos dados.
* **Controlo de Licença:** O acesso à aplicação é controlado por uma data de expiração da licença, com uma tela informativa e opções de contacto para renovação.

### **Arquitetura Offline-First**
* **Funcionamento Completo Offline:** O utilizador pode registar novos clientes, produtos e realizar vendas completas sem qualquer ligação à internet.
* **Sincronização Automática:** Assim que a ligação é restabelecida, todos os dados guardados offline são automaticamente sincronizados com a nuvem do Firebase, sem qualquer intervenção do utilizador.
* **Cache de Dados:** Os dados de clientes e produtos são guardados localmente, permitindo a consulta e utilização mesmo offline.
* **Feedback Claro:** A aplicação informa o utilizador quando está offline e adapta a sua interface, como no caso do dashboard.

### **Gestão de Dados**
* **CRUD de Clientes:** Sistema completo para criar, ler, atualizar e apagar clientes, com um formulário de registo em duas etapas para uma melhor experiência do utilizador.
* **CRUD de Produtos e Categorias:** Gestão total de produtos e das suas respetivas categorias.
    * **Exclusão em Cascata:** Ao apagar uma categoria, todos os produtos associados a ela são também apagados de forma segura.
* **Importação Inteligente de Excel:** Uma ferramenta poderosa que permite ao utilizador importar uma lista completa de produtos e categorias a partir de um ficheiro `.xlsx`.
    * **Leitura Dinâmica:** O sistema lê ficheiros Excel complexos, com múltiplas abas e secções, identificando cabeçalhos e dados de forma inteligente.
    * **Resolução de Conflitos:** Se uma categoria importada já existir, a aplicação pergunta ao utilizador se deseja substituir os dados existentes ou criar uma nova categoria.

### **Fluxo de Vendas Profissional**
* **Passo a Passo Guiado:** Uma tela de "Nova Venda" com 3 passos claros: selecionar cliente, adicionar produtos e finalizar.
* **Pesquisa Integrada:** Campos de pesquisa para encontrar clientes e produtos rapidamente.
* **Carrinho de Compras:** Interface intuitiva para adicionar produtos e ajustar quantidades.
* **Geração de PDF:** Ao finalizar uma venda, é gerado um relatório em PDF profissional, com os detalhes da venda, do cliente, e uma marca d'água da empresa.
* **Partilha Fácil:** O PDF gerado pode ser partilhado instantaneamente através de qualquer aplicação (WhatsApp, E-mail, etc.).
* **Histórico de Vendas:** Uma tela dedicada para consultar todas as vendas realizadas, com a opção de visualizar ou partilhar novamente o PDF de cada uma.

### **Interface e Usabilidade**
* **Tema Claro e Escuro:** O utilizador pode escolher entre um tema claro, um tema escuro, ou deixar que a aplicação siga o tema do sistema operativo. A sua preferência é guardada.
* **Tour de Apresentação:** Na primeira vez que o utilizador entra na aplicação, um diálogo pergunta se ele deseja fazer um tour guiado pelas principais funcionalidades. O tour pode ser revisto a qualquer momento.
* **Ícone Personalizado:** Uma identidade visual única e profissional, com um ícone de aplicação que funciona em todas as plataformas (Android, iOS e Web).
* **Design Responsivo:** A interface foi construída para se adaptar a diferentes tamanhos de ecrã.

---

## 🚀 Tecnologias Utilizadas

* **Framework:** Flutter
* **Linguagem:** Dart
* **Backend & Base de Dados:** Firebase (Authentication, Firestore)
* **Hospedagem Web:** Firebase Hosting
* **Gestão de Estado:** Provider
* **Pacotes Principais:**
    * `cloud_firestore` & `firebase_auth`
    * `provider`
    * `shared_preferences`
    * `showcaseview` (Tour da aplicação)
    * `pdf` & `printing` (Geração e visualização de PDF)
    * `share_plus` & `path_provider` (Partilha de ficheiros)
    * `connectivity_plus` (Deteção de rede)
    * `excel` & `file_picker` (Importação de Excel)
    * `intl` (Formatação de data e moeda)

---

## 👨‍💻 Desenvolvido por

**DeQuadraApps**
