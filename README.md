# 📱 haze_simcard — Sistema Canônico de Chips SIM, Operadoras Lore e Telefonia Tática

> **Framework:** QBox (`qbx_core`)  
> **Inventário:** `ox_inventory` (slot-based + metadados estendidos)  
> **Banco de Dados:** `oxmysql` (prepared statements)  
> **UI & Interação:** `ox_lib` + `ox_target` (Design System Lation Modern UI)  
> **Compatibilidade de Telefones:** Bridge universal multi-sistema (`haze_phone`, `lb-phone`, `npwd`)

---

## 📖 Visão Geral

O **`haze_simcard`** revoluciona o ecossistema de telefonia do servidor FiveM substituindo o modelo de "telefone mágico com número eterno" por um sistema imersivo de **chips SIM físicos**, operadoras telefônicas oficiais com peso real no roleplay, telefones descartáveis (Burners) com autodestruição em 24h, portabilidade numérica entre operadoras e equipamentos táticos de guerra eletrônica (triangulador de antenas ERB e bloqueador de frequência RF).

---

## 🏢 As 4 Operadoras Lore-Friendly de San Andreas

Cada operadora possui posicionamento de mercado, lojas físicas, NPCs de atendimento e vantagens mecânicas no jogo:

| Operadora | Slogan | Vantagem Mecânica no RP | Ponto Fraco | Público-Alvo |
| :--- | :--- | :--- | :--- | :--- |
| **Badger Wireless** 🦡 | *"Conectando Los Santos desde 1995"* | **Custo Popular:** Chips e 2ª via acessíveis. Entregue a novos cidadãos. | Sinal oscila em áreas rurais/montanhosas. | Civis, iniciantes e trabalhadores. |
| **Whiz Mobile** ⚡ | *"Fast, Reliable, Whiz"* | **Rede 5G Imbatível:** Sinal 100% estável em todo o estado (inclusive Chiliad e Paleto). | Preço premium elevado. | Empresários, alta sociedade e pilotos. |
| **EyeFind Telecom** 🌐 | *"Rede Corporativa e de Serviços Governamentais"* | **Blindagem Anti-IMSI:** Triangulações via `phone_tracker` sofrem **+150m de dispersão**. Gratuito para policiais em serviço. | Exige documento oficial obrigatório (zero anonimato). | Policiais, médicos e servidores públicos. |
| **Bittersweet Mobile** 🍬 | *"Privacidade Absoluta e Tecnologia Criptográfica"* | **Alerta de Interceptação:** Emite bips e notificações SMS de advertência ao titular se a linha for alvo de varredura. | Custo de boutique de luxo (Rockford Hills). | Criminosos de elite, hackers e corretores. |

### 🕶️ AnonSIM Descartável (Burner 24h)
- Vendido exclusivamente por contrabandistas no **Mercado Clandestino** (Cypress Flats).
- **Sem vínculo de titular:** Na consulta policial, retorna *"LINHA PRÉ-PAGA CLANDESTINA (SEM REGISTRO DE TITULAR)"*.
- **Queima Automática:** Autodestrói seus circuitos após **24 horas reais**, virando `burned_sim` ("Chip Queimado / Lixo Eletrônico").

---

## 🛰️ Equipamentos Táticos & Guerra Eletrônica

### 1. `phone_tracker` (Triangulador IMSI de Sinal)
- Dispositivo portátil de interceptação e triangulação de antenas celulares ERB.
- Solicita o número alvo através de diálogo `lib.inputDialog`.
- Checa se o alvo está com o aparelho **LIGADO** e conectado à rede.
- **Área Circular Tática:** Cria uma área de busca circular translúcida vermelha no mapa com diâmetro entre 180m e 330m (com dispersão do centro, evitando wallhack milimétrico).
- **Pings Periódicos de Recalibragem:** A cada 12 segundos (duração total de 40s), o rastreador faz varreduras para atualizar o quadrante caso o alvo esteja em fuga.
- Se o alvo desligar o telefone ou ligar um Jammer, o sinal é interrompido imediatamente.

### 2. `signal_jammer` (Bloqueador de Frequência RF)
- Emite ruído eletromagnético ativo em uma bolha de **20 metros de raio**, blindando o portador e qualquer aliado próximo contra triangulações e grampos.
- **Consumo de Bateria Real:** Drena **1% de bateria a cada 60 segundos** ligado. Ao atingir 0%, desliga automaticamente.
- **Interferência Bilateral:** Enquanto o próprio jogador estiver com o Jammer ativo, o sinal do seu próprio telefone fica sem rede.
- **Serviço de Recarga:** No hacker clandestino, o jogador pode substituir as baterias gastas do Jammer por **$300**, restaurando a carga para 100%.

---

## 🔄 Comportamento Inteligente de Transferência (`swapItems`)

O resource implementa um hook inteligente no `ox_inventory`:
- **Transferência P2P (Troca Direta, Revista Policial ou Roubo):**
  - O celular **se mantém LIGADO**.
  - A rota do número é imediatamente transferida para o novo jogador conectado.
  - Se alguém ligar para o número, o celular **toca imediatamente nas mãos de quem o está segurando**.
- **Transferência para Armazenamentos (Baú, Porta-Luvas, Porta-Malas, Lixeira ou Chão):**
  - O aparelho é automaticamente **desligado** (`phone_status = "Desligado"`) para não ficar tocando no vácuo.

---

## 🚓 Sistema de Investigação Policial

1. **Terminais Policiais Físicos:**
   - Pontos de target (`ox_target`) instalados nos computadores de investigação nas delegacias:
     - **MRPD (Mission Row)**
     - **Davis Sheriff Station**
     - **Sandy Shores Sheriff Station**
     - **Paleto Bay Sheriff Station**
     - **FIB Headquarters**
     - Balcões de todas as lojas oficiais de operadoras.
2. **Comando de Investigação:**
   - `/consultarchip [numero]`
   - Exclusivo para policiais em serviço (`onduty == true`).
   - Permite consulta no terminal da delegacia ou de dentro de viaturas policiais equipadas com MDT (`VC_EMERGENCY`).
3. **Relatório Forense Completo:**
   - Número formatado, Operadora, Titular/Documento, Situação cadastral, **Status do Sinal em Tempo Real** (`📡 Sinal ativo detectado nas antenas` ou `📵 Aparelho sem sinal ou desligado`) e cópia dos dados para a área de transferência com um clique.

---

## 📦 Lista de Itens (`ox_inventory`)

| Item | Nome de Exibição | Peso | Descrição |
| :--- | :--- | :--- | :--- |
| `phone` | Celular | 190g | Smartphone com suporte a chips físicos e botões de gerenciamento. |
| `sim_badger` | Chip SIM - Badger Wireless | 10g | Linha oficial da operadora Badger Wireless. |
| `sim_whiz` | Chip SIM - Whiz Mobile | 10g | Linha de alta velocidade 5G da Whiz Mobile. |
| `sim_eyefind` | Chip SIM - EyeFind Telecom | 10g | Linha governamental blindada com bônus anti-triangulação. |
| `sim_bittersweet` | Chip SIM - Bittersweet Mobile | 10g | Linha criptografada de luxo com sensor de interceptação. |
| `sim_burner` | AnonSIM Descartável | 10g | Chip pré-pago sem titular com autodestruição em 24h. |
| `burned_sim` | Chip SIM Queimado | 10g | Circuito torrado e inútil (lixo eletrônico). |
| `custom_number_card` | Voucher Número VIP | 5g | Permite escolher número personalizado de 6 a 10 dígitos. |
| `phone_tracker` | Triangulador IMSI de Sinal | 800g | Dispositivo de varredura ERB para triangulação de celulares. |
| `signal_jammer` | Bloqueador de Frequência Portátil | 600g | Jammer de ruído eletromagnético com bateria recarregável. |

---

## ⚡ Comandos & Integrações

- `/consultarchip [numero]` — Consulta forense para policiais em serviço.
- `exports.haze_simcard:openPhone(data, slot)` — Abre o telefone se estiver ligado e com chip.
- `exports.haze_simcard:useSimCard(data, slot)` — Insere o chip no aparelho celular.
- `exports.haze_simcard:useTracker(data, slot)` — Aciona o triangulador IMSI.
- `exports.haze_simcard:useJammer(data, slot)` — Liga/desliga o bloqueador de frequência.

---

## 🔒 Hardening e Regras Invioláveis do Servidor

- **Validação de Proximidade Server-Side:** Todas as compras e serviços exigem presença física do jogador a $\le 5.0m$ do balcão.
- **Rate-Limiting Rigoroso:** Todas as ações financeiras e consultas ao banco contam com trava anti-spam de $\ge 2.0s$.
- **Transações Seguras:** Banco de dados gerenciado com prepared statements (`?` no `oxmysql`) e queries atômicas.
- **Log Forense de Auditoria:** Todas as transações financeiras e investigações policiais são registradas no console do servidor.
