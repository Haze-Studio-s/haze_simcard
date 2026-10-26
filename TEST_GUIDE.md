# 📱 Guia de Teste — haze_simcard

Guia passo a passo para testes funcionais, auditoria de segurança e homologação operacional do resource **`haze_simcard`** (Sistema Canônico de Chips SIM Físicos, Operadoras Lore, AnonSIM Burner e Telefonia Tática) no ecossistema QBox (`qbx_core` / `ox_inventory` / `ox_lib` / `oxmysql`).

---

## 📋 Sumário
1. [Visão Geral & Recursos Principais](#1-visão-geral--recursos-principais)
2. [Pré-requisitos & Dependências](#2-pré-requisitos--dependências)
3. [Comandos & Itens de Teste](#3-comandos--itens-de-teste)
4. [Bateria de Testes Passo a Passo](#4-bateria-de-testes-passo-a-passo)
   - [Caso 1: Validação do Banco de Dados & Tabela SQL](#caso-1-validação-do-banco-de-dados--tabela-sql)
   - [Caso 2: Lojas Oficiais das Operadoras (ox_target)](#caso-2-lojas-oficiais-das-operadoras-ox_target)
   - [Caso 3: Mercado Clandestino (AnonSIM, Jammer & Tracker)](#caso-3-mercado-clandestino-anonsim-jammer--tracker)
   - [Caso 4: Inserção de Chip, Ligar/Desligar e Metadados](#caso-4-inserção-de-chip-ligardesligar-e-metadados)
   - [Caso 5: Hook Inteligente de Transferência (swapItems)](#caso-5-hook-inteligente-de-transferência-swapitems)
   - [Caso 6: Guerra Eletrônica — Bloqueador de Frequência (signal_jammer)](#caso-6-guerra-eletrônica--bloqueador-de-frequência-signal_jammer)
   - [Caso 7: Guerra Eletrônica — Triangulador IMSI (phone_tracker)](#caso-7-guerra-eletrônica--triangulador-imsi-phone_tracker)
   - [Caso 8: Vantagens Exclusivas das Operadoras (EyeFind & Bittersweet)](#caso-8-vantagens-exclusivas-das-operadoras-eyefind--bittersweet)
   - [Caso 9: Investigação Policial Forense (/consultarchip & Terminais)](#caso-9-investigação-policial-forense-consultarchip--terminais)
   - [Caso 10: Auditoria de Segurança, Rate-Limit & Proximidade](#caso-10-auditoria-de-segurança-rate-limit--proximidade)
5. [Checklist Rápido de Homologação (Pass / Fail)](#5-checklist-rápido-de-homologação-pass--fail)
6. [Troubleshooting & Resolução de Problemas](#6-troubleshooting--resolução-de-problemas)

---

## 1. Visão Geral & Recursos Principais

O **`haze_simcard`** substitui a ideia de "telefone mágico" por uma arquitetura física real:
- **Chips SIM Físicos:** O celular só funciona se tiver um chip inserido (`has_sim = true`).
- **4 Operadoras Oficiais Lore-Friendly:**
  - **Badger Wireless:** Acessível, chip padrão de novos cidadãos.
  - **Whiz Mobile:** Cobertura 5G de alta velocidade em todo o estado.
  - **EyeFind Telecom:** Governamental/corporativa; protege contra triangulações (+150m de dispersão).
  - **Bittersweet Mobile:** Linha criptográfica de luxo; avisa por SMS/alerta se você for alvo de rastreamento.
- **AnonSIM Descartável (Burner):** Sem registro de titular, queima após 24 horas reais (`burned_sim`).
- **Hook de Transferência:** Se jogar o celular no chão ou baú, ele desliga automaticamente. Se passar direto para outro jogador (P2P), continua ligado e transfere a chamada imediatamente.
- **Guerra Eletrônica:** Triangulador IMSI (`phone_tracker`) e Bloqueador RF de 20m com consumo de bateria real (`signal_jammer`).

---

## 2. Pré-requisitos & Dependências

| Componente | Estado Requerido | Observações |
| :--- | :--- | :--- |
| **`oxmysql`** | Conectado | Criação da tabela `haze_simcards`. |
| **`ox_inventory`** | `started` | Suporte a metadados estendidos (`displayMetadata`) e hooks. |
| **`ox_target`** | `started` | Interação 3D nos balcões de atendimento e terminais policiais. |
| **`ox_lib`** | `started` | Menus contextuais (`lib.registerContext`), inputs e diálogos. |
| **`qbx_core`** | `started` | Gerenciamento de dinheiro e empregos policiais. |

### Script no `server.cfg`:
```cfg
ensure haze_simcard
```

---

## 3. Comandos & Itens de Teste

### Itens Necessários no `ox_inventory`:
- `phone` — Smartphone físico.
- `sim_badger` — Chip da operadora Badger Wireless.
- `sim_whiz` — Chip da operadora Whiz Mobile.
- `sim_eyefind` — Chip da operadora EyeFind Telecom.
- `sim_bittersweet` — Chip da operadora Bittersweet Mobile.
- `sim_burner` — AnonSIM Descartável (Burner 24h).
- `burned_sim` — Chip Queimado / Lixo Eletrônico.
- `custom_number_card` — Voucher de Número VIP personalizado.
- `phone_tracker` — Triangulador IMSI de Sinal.
- `signal_jammer` — Bloqueador de Frequência RF Portátil.

### Comandos Rápidos de Preparação (Console ou Chat):
```text
/giveitem <seu_id> phone 1
/giveitem <seu_id> sim_badger 1
/giveitem <seu_id> sim_burner 1
/giveitem <seu_id> phone_tracker 1
/giveitem <seu_id> signal_jammer 1
/giveitem <seu_id> custom_number_card 1
```

Para teste policial:
```text
/setjob <seu_id> police 1
/consultarchip [numero]
```

---

## 4. Bateria de Testes Passo a Passo

### Caso 1: Validação do Banco de Dados & Tabela SQL
1. Abra seu gerenciador MySQL (HeidiSQL, DBeaver ou phpMyAdmin).
2. Verifique se a tabela `haze_simcards` foi criada:
   ```sql
   DESCRIBE `haze_simcards`;
   ```
3. Se a tabela não existir, execute manualmente o script em:
   `resources/[ai_create]/haze_simcard/sql/schema.sql`
4. **Resultado Esperado:** Colunas `id`, `number`, `operator`, `owner`, `is_burner`, `is_blocked`, `expires_at`, `created_at` presentes com índices corretos.

---

### Caso 2: Lojas Oficiais das Operadoras (`ox_target`)
1. Teleporte até a Loja Central de Telecomunicações:
   ```text
   /tp -1082.94 -245.92 37.76
   ```
2. Aproxime-se do NPC de atendimento (Molly) atrás do balcão.
3. Mire no NPC com o `ox_target` (Alt esquerdo):
   - Deve aparecer a opção: **"Falar com Atendente de Telefonia"**.
4. Clique para abrir o menu contextual (Padrão Lation Emerald UI):
   - **Comprar Smartphone:** Teste comprar um aparelho novo por $500. Verifique se o item `phone` recebido vem com o status `Sem Chip` e `Desligado`.
   - **Comprar Chip SIM:** Compre um chip da Badger Wireless ($100). Verifique se o item `sim_badger` é entregue no inventário contendo número aleatório iniciado pelo prefixo da operadora (`2`).
   - **Meus Chips Cadastrados:** Abra o submenu e confirme que seu número recém-gerado consta na lista.
   - **Segunda Via / Duplicata:** Teste emitir 2ª via por $80. Verifique se o chip antigo é invalidado e o novo recebe o mesmo número.
   - **Bloqueio de Chip:** Teste bloquear a linha e verifique a confirmação de segurança.
   - **Portabilidade:** Mude a linha de Badger para Whiz Mobile ($500). Verifique a atualização no banco de dados mantendo o mesmo número.
   - **Número VIP Personalizado:** Com o item `custom_number_card` na mochila, solicite a personalização e digite um número de 6 a 10 dígitos (ex: `777777`). Confirme a alteração.

---

### Caso 3: Mercado Clandestino (AnonSIM, Jammer & Tracker)
1. Teleporte para o beco clandestino em Cypress Flats:
   ```text
   /tp 749.72 -1399.07 26.54
   ```
2. Localize o mercador clandestino (NPC encostado na parede, sem blip no mapa):
3. Interaja via `ox_target`:
   - **Comprar AnonSIM Descartável ($200):** O chip vem com prefixo `6`, sem vínculo de titular (`owner = NULL`) e validade configurada para 24 horas reais.
   - **Comprar Triangulador IMSI ($7.500):** Entrega o item `phone_tracker`.
   - **Comprar Bloqueador de Frequência ($5.000):** Entrega o item `signal_jammer` com 100% de bateria nos metadados.
   - **Recarga de Bateria do Jammer ($300):** Restaura baterias gastas para 100%.

---

### Caso 4: Inserção de Chip, Ligar/Desligar e Metadados
1. Abra seu inventário (`TAB`).
2. Observe que você tem um `phone` e um `sim_badger`.
3. **Inserir Chip:**
   - Use o item `sim_badger` pelo inventário ou execute a ação de usar no celular.
   - Uma barra de progresso simula a abertura da gaveta do chip.
   - O item `sim_badger` é consumido e o aparelho `phone` é atualizado.
4. **Verificar Metadados:**
   - Passe o cursor sobre o item `phone` no inventário.
   - Deve exibir:
     - `Número`: (Número formatado, ex: 204-1234)
     - `Operadora`: Badger Wireless
     - `Status`: Desligado
5. **Menu do Celular:**
   - Clique com botão direito no item `phone` (ou use-o na hotbar).
   - Menu abre com opções:
     - **Ligar Aparelho:** Clique para ligar. O status nos metadados muda para `Ligado` e o número se torna ativo na rede do servidor.
     - **Abrir Telefone:** Só abre a NUI do celular se o aparelho estiver **LIGADO**.
     - **Ejetar Chip SIM:** Ejeta o chip de volta para o inventário, voltando o celular para o estado `Sem Chip`.

---

### Caso 5: Hook Inteligente de Transferência (`swapItems`)

Este é um dos recursos mais avançados do `haze_simcard`:

#### Teste A: Armazenamento (Baú / Chão)
1. Deixe seu celular **LIGADO** com um chip dentro.
2. Arraste o celular do seu inventário para o chão (Drop) ou para o porta-luvas de um veículo.
3. Abra o baú/chão e inspecione os metadados do celular:
   - **Resultado Esperado:** O celular **desliga automaticamente** (`Status: Desligado`) e desconecta a linha da rede.

#### Teste B: Transferência P2P (Revista / Comércio / Roubo)
1. Deixe o celular **LIGADO**.
2. Passe o celular diretamente para as mãos de outro jogador conectado (via revista ou /give).
3. **Resultado Esperado:** O celular **permanece LIGADO** e o roteamento de chamadas é transferido imediatamente para o novo jogador. Se alguém discar para o número, o celular toca nas mãos de quem o está segurando!

---

### Caso 6: Guerra Eletrônica — Bloqueador de Frequência (`signal_jammer`)
1. Pegue o item `signal_jammer` no inventário.
2. Use o item para **LIGAR** o Jammer:
   - Uma notificação avisa que o bloqueador de ruído RF está operando em um raio de 20 metros.
   - O state bag do jogador é atualizado: `Player(source).state.hasJammerActive == true`.
3. **Interferência Bilateral:** Enquanto o Jammer estiver ativo, o próprio celular do jogador fica sem sinal.
4. **Consumo de Bateria:** Deixe o Jammer ligado por alguns minutos e verifique se a porcentagem de bateria nos metadados cai 1% a cada 60 segundos. Ao atingir 0%, desliga automaticamente.
5. Use o item novamente para **DESLIGAR** o Jammer quando terminar.

---

### Caso 7: Guerra Eletrônica — Triangulador IMSI (`phone_tracker`)
*(Recomenda-se testar com 2 jogadores ou com uma conta secundária)*

1. Peça ao Jogador B para ligar o celular dele com um chip Badger. Anote o número dele (ex: `201-9988`).
2. No Jogador A, use o item `phone_tracker`.
3. Uma caixa de diálogo (`lib.inputDialog`) solicita o número de telefone a ser triangulado.
4. Digite o número e confirme.
5. **Comportamento Esperado:**
   - Se o alvo estiver com o telefone **LIGADO**:
     - O mapa abre com uma **área circular translúcida vermelha** (raio entre 180m e 330m) indicando o quadrante aproximado do alvo (com dispersão tática).
     - O rastreador emite pings periódicos a cada 10 segundos para atualizar a área caso o alvo se movimente.
   - Se o Jogador B **DESLIGAR** o telefone ou **LIGAR UM JAMMER**:
     - O sinal é perdido imediatamente e uma mensagem informa: *"Sinal perdido ou aparelho fora de alcance das antenas ERB"*.

---

### Caso 8: Vantagens Exclusivas das Operadoras (EyeFind & Bittersweet)

#### Vantagem EyeFind Telecom (Blindagem Anti-IMSI):
1. Instale um chip `sim_eyefind` no celular do Jogador B.
2. Tente rastreá-lo com o `phone_tracker`:
3. **Resultado:** O círculo de busca no mapa sofrerá uma expansão de **+150 metros de dispersão**, tornando quase impossível localizar o quadrante exato.

#### Vantagem Bittersweet Mobile (Alerta Criptográfico):
1. Instale um chip `sim_bittersweet` no celular do Jogador B.
2. Inicie a triangulação do número dele com o `phone_tracker`.
3. **Resultado:** O Jogador B recebe imediatamente um bipe sonoro e uma notificação de emergência:
   > *"ALERTA DE SEGURANÇA: Sua linha Bittersweet foi alvo de uma tentativa de varredura ERB não autorizada!"*

---

### Caso 9: Investigação Policial Forense (`/consultarchip` & Terminais)
1. Coloque seu personagem no emprego da polícia e entre em serviço:
   ```text
   /setjob <seu_id> police 1
   ```
2. Teleporte até a delegacia de Mission Row (MRPD):
   ```text
   /tp 441.87 -981.82 30.69
   ```
3. Aproxime-se da mesa de investigação e use o `ox_target` no computador do terminal de telecomunicações.
4. **Consulta de Linha Oficial:**
   - Digite o número de um chip Badger, Whiz, EyeFind ou Bittersweet.
   - **Resultado:** Exibe relatório forense completo com:
     - Número e Operadora;
     - Nome completo do Titular e Citizen ID;
     - Situação cadastral;
     - Status do sinal em tempo real (Conectado à antena ou Desligado).
5. **Consulta de Linha AnonSIM (Burner Clandestino):**
   - Digite o número de um chip descartável.
   - **Resultado:** O sistema retorna expressamente:
     > *"LINHA PRÉ-PAGA CLANDESTINA (SEM REGISTRO DE TITULAR / DISPOSITIVO ANÔNIMO)"*
6. Teste também o comando de viatura policial:
   ```text
   /consultarchip [numero]
   ```
   *(Funciona de dentro de viaturas policiais ou nas delegacias)*.

---

### Caso 10: Auditoria de Segurança, Rate-Limit & Proximidade

1. **Anti-Spam de Transação Financeira:**
   - Tente clicar repetidamente para comprar aparelhos ou chips na loja.
   - **Resultado:** Bloqueia cliques em intervalo inferior a 2.0 segundos com mensagem amigável de espera.
2. **Validação de Proximidade Física:**
   - Afaste-se do balcão da loja (> 5.0m) e tente acionar o evento de compra por comando/trigger.
   - **Resultado:** O servidor recusa a requisição e gera log de alerta de segurança (`SECURITY_ALERT`) no console.

---

## 5. Checklist Rápido de Homologação (Pass / Fail)

| # | Item de Teste | Critério de Sucesso | Status |
| :---: | :--- | :--- | :---: |
| **01** | Banco de Dados | Tabela `haze_simcards` criada com colunas e chaves corretas. | [ ] |
| **02** | Balcão da Loja | Interação via `ox_target` abre menu de atendimento sem erros. | [ ] |
| **03** | Compra de Celular | Entrega item `phone` com status "Sem Chip" e "Desligado". | [ ] |
| **04** | Inserção de Chip | Chip entra no celular e metadados exibem número e operadora. | [ ] |
| **05** | Ligar / Desligar | Celular alterna estados e só abre interface se estiver ligado. | [ ] |
| **06** | Ejetar Chip | Chip retorna ao inventário intacto e celular volta a ficar sem número. | [ ] |
| **07** | Hook swapItems (Baú) | Celular desliga automaticamente ao ser jogado no chão ou baú. | [ ] |
| **08** | Hook swapItems (P2P) | Celular permanece ligado e migra o número para o novo portador. | [ ] |
| **09** | AnonSIM Burner | Chip clandestino sem titular com autodestruição em 24h. | [ ] |
| **10** | Jammer de Sinal | Bolha de 20m bloqueia rastreadores e drena 1% de bateria/min. | [ ] |
| **11** | Tracker IMSI | Gera área circular translúcida e atualiza com pings a cada 10s. | [ ] |
| **12** | Bittersweet Alerta | Titular recebe notificação SMS quando o número é triangulado. | [ ] |
| **13** | EyeFind Dispersão | Triangulação sofre +150m de imprecisão na busca policial/civil. | [ ] |
| **14** | Forense Policial | `/consultarchip` e terminais no MRPD exibem relatório completo. | [ ] |

---

## 6. Troubleshooting & Resolução de Problemas

- **Problema: Ao passar o cursor no celular no inventário, não aparecem as linhas "Número", "Operadora" ou "Status".**
  - **Causa:** O registro de metadados do `ox_inventory` precisa ser inicializado após o inventário subir.
  - **Solução:** Dê restart no `haze_simcard` com o inventário já iniciado:
    ```text
    restart haze_simcard
    ```

- **Problema: O comando `/consultarchip` diz que você não tem permissão.**
  - **Causa:** O personagem não está com o emprego de polícia configurado em `Config.PoliceJobs` ou não está em serviço (`onduty`).
  - **Solução:** Execute `/setjob <id> police 1` e marque serviço no vestiário ou ponto de ponto da delegacia.

- **Problema: Comprei o aparelho celular, mas não consigo abrir o telefone.**
  - **Causa:** O celular físico comprado vem novo de fábrica: sem chip SIM instalado e desligado.
  - **Solução:** Compre um chip SIM oficial na loja, use o chip no celular para instalá-lo e use o celular para selecionar a opção "Ligar Aparelho".
