# Foundry Fuzzing Lab 🔒

<p align="center">
  <img src="https://img.shields.io/badge/Foundry-FF6B6B?style=for-the-badge&logo=ethereum&logoColor=white" alt="Foundry"/>
  <img src="https://img.shields.io/badge/Hardhat-FFF100?style=for-the-badge&logo=ethereum&logoColor=black" alt="Hardhat"/>
  <img src="https://img.shields.io/badge/Solidity-363636?style=for-the-badge&logo=solidity&logoColor=white" alt="Solidity"/>
  <img src="https://img.shields.io/badge/Security-FF0000?style=for-the-badge&logo=security&logoColor=white" alt="Security"/>
</p>

<p align="center">
  <strong>Laboratório de Testes de Segurança com Foundry e Hardhat</strong><br/>
  <em>Demonstração prática de vulnerabilidade de Reentrância</em>
</p>

---

## 📋 Índice

- [Sobre](#sobre)
- [Instalação](#instalação)
- [Estrutura](#estrutura)
- [Vulnerabilidade](#vulnerabilidade)
- [Testes](#testes)
- [Resultados](#resultados)
- [Solução](#solução)
- [Autor](#autor)

---

## 🎯 Sobre

Este laboratório demonstra uma **vulnerabilidade crítica de Reentrância** em contratos inteligentes Ethereum. A reentrância é uma das falhas mais famosas e perigosas em DeFi, responsável por perdas de milhões de dólares (incluindo o hack do DAO em 2016).

### ⚠️ AVISO

**ESTE CÓDIGO É INTENCIONALMENTE VULNERÁVEL!**  
Nunca use em produção. Serve apenas para fins educacionais e demonstração de técnicas de segurança.

---

## 🛠️ Instalação

### Pré-requisitos

- **Foundry** (forge, cast, anvil)
- **Node.js** 18+ e npm
- **Hardhat** com plugins de segurança
- **Slither** (analisador estático)

### Instalação Rápida

```bash
# Clone o repositório
git clone https://github.com/Mendes1982/foundry-fuzzing-lab.git
cd foundry-fuzzing-lab

# Instalar dependências Node.js
npm install

# Instalar dependências Foundry
forge install

# Verificar instalações
forge --version
npx hardhat --version
slither --version
```

---

## 📁 Estrutura

```
foundry-fuzzing-lab/
├── src/
│   ├── Vault.sol          # Contrato vulnerável
│   └── Attack.sol         # Exploit de reentrância
├── foundry-test/
│   └── ReentrancyTest.t.sol    # Testes em Foundry
├── hardhat-test/
│   └── Reentrancy.test.js      # Testes em Hardhat
├── lib/
│   └── forge-std/         # Biblioteca Foundry
├── foundry.toml           # Configuração Foundry
├── hardhat.config.js      # Configuração Hardhat
└── package.json           # Scripts npm
```

---

## 🐛 Vulnerabilidade: Reentrância

### O que é?

Reentrância ocorre quando um contrato malicioso chama de volta o contrato vulnerável antes que o estado seja atualizado, permitindo múltiplos saques indevidos.

### Código Vulnerável (Vault.sol)

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];
    require(amount > 0, "No balance");
    
    // ⚠️ VULNERABILIDADE: Transferência ANTES da atualização!
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
    
    // Atualização TARDIA
    balances[msg.sender] = 0;
}
```

### Por que é perigoso?

1. **Ordem incorreta**: A transferência ocorre antes da atualização do estado
2. **Chamada externa**: `msg.sender.call{}()` permite execução de código no receptor
3. **Reentrada**: O contrato receptor pode chamar `withdraw()` novamente antes da atualização

### Ataque (Attack.sol)

```solidity
receive() external payable {
    if (attackCount < MAX_ATTACKS && address(vault).balance > 0) {
        attackCount++;
        vault.withdraw();  // Reentrada aqui!
    }
}
```

---

## 🧪 Testes

### Executar Todos os Testes

```bash
# Testes em Hardhat + Foundry
npm test
```

### Testes em Hardhat

```bash
# Executar testes Hardhat
npm run test:hardhat

# Com relatório de gas
npm run gas

# Com cobertura
npm run coverage:hardhat
```

### Testes em Foundry

```bash
# Executar testes Foundry
npm run test:foundry

# Modo verbose (detalhado)
npm run test:foundry:verbose

# Com cobertura
npm run coverage:foundry
```

### Análise de Segurança com Slither

```bash
# Executar análise Slither
npm run slither
```

---

## 📊 Resultados

### Hardhat Test Results

```
✅ Vulnerabilidade CONFIRMADA: Vault perdeu ETH
✅ Vulnerabilidade CONFIRMADA: Contrato de ataque lucrou  
✅ Vulnerabilidade CONFIRMADA: Prejuízo excede depósito inicial
✅ Detectadas múltiplas reentradas!
```

### Foundry Test Results

```
[PASS] test_ReentrancyAttack() 
[PASS] test_ReentrancyProfitCalculation()
[PASS] testFuzz_ReentrancyWithDifferentAmounts(uint256)
```

### Métricas do Ataque

| Métrica | Valor |
|---------|-------|
| **Depósito Inicial** | 1 ETH |
| **Prejuízo Vault** | ~4-5 ETH |
| **Lucro Atacante** | ~3-4 ETH |
| **Chamadas Reentrantes** | Múltiplas |

---

## ✅ Solução

### Padrão CEI (Checks-Effects-Interactions)

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];
    require(amount > 0, "No balance");  // 1. CHECKS
    
    balances[msg.sender] = 0;  // 2. EFFECTS (antes!)
    
    (bool success, ) = msg.sender.call{value: amount}("");  // 3. INTERACTIONS (depois!)
    require(success, "Transfer failed");
}
```

### Ou use OpenZeppelin ReentrancyGuard

```solidity
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vault is ReentrancyGuard {
    function withdraw() external nonReentrant {
        // ... código seguro
    }
}
```

---

## 🎓 Aprendizados

1. **Sempre atualize estado antes de chamadas externas**
2. **Use o padrão Checks-Effects-Interactions (CEI)**
3. **Considere ReentrancyGuard para contratos complexos**
4. **Teste com fuzzing para encontrar edge cases**
5. **Use análise estática (Slither) para detectar vulnerabilidades**

---

## 🔧 Scripts Disponíveis

| Comando | Descrição |
|---------|-----------|
| `npm test` | Executa todos os testes |
| `npm run test:hardhat` | Testes em Hardhat |
| `npm run test:foundry` | Testes em Foundry |
| `npm run compile` | Compila contratos |
| `npm run slither` | Análise de segurança |
| `npm run gas` | Relatório de gas |
| `npm run anvil` | Inicia rede local (Foundry) |
| `npm run node` | Inicia rede local (Hardhat) |

---

## 👤 Autor

**Ricardo Silva**  
🔧 QA Automation Engineer  
🔗 Especialista em Blockchain & Web3  
📧 ricardo.silva@example.com  
🐙 GitHub: [@Mendes1982](https://github.com/Mendes1982)

---

## 📄 Licença

Este projeto está licenciado sob a MIT License - veja o arquivo [LICENSE](LICENSE) para detalhes.

---

<p align="center">
  <strong>🔒 Segurança primeiro - Nunca use código vulnerável em produção!</strong>
</p>
