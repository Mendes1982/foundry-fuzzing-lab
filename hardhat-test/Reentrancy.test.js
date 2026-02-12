const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("ReentrancyAttack", function () {
  let vault;
  let attack;
  let owner;
  let user1;
  let user2;
  let attacker;

  // Constantes
  const INITIAL_USER_BALANCE = ethers.parseEther("10");
  const VAULT_DEPOSIT = ethers.parseEther("5");
  const ATTACKER_BALANCE = ethers.parseEther("5");
  const ATTACK_DEPOSIT = ethers.parseEther("1");

  beforeEach(async function () {
    // Obter signers
    [owner, user1, user2, attacker] = await ethers.getSigners();

    // Deploy Vault
    const Vault = await ethers.getContractFactory("Vault");
    vault = await Vault.deploy();
    await vault.waitForDeployment();

    // Usuários depositam ETH no Vault
    await vault.connect(user1).deposit({ value: VAULT_DEPOSIT });
    await vault.connect(user2).deposit({ value: VAULT_DEPOSIT });

    // Deploy Attack contract
    const Attack = await ethers.getContractFactory("Attack");
    attack = await Attack.connect(attacker).deploy(await vault.getAddress());
    await attack.waitForDeployment();
  });

  describe("Funcionamento Normal", function () {
    it("Deve aceitar depósitos corretamente", async function () {
      const balance = await vault.getBalance(user1.address);
      expect(balance).to.equal(VAULT_DEPOSIT);

      const contractBalance = await vault.getContractBalance();
      expect(contractBalance).to.equal(ethers.parseEther("10"));
    });

    it("Deve permitir saque normal", async function () {
      const initialBalance = await ethers.provider.getBalance(user1.address);

      await vault.connect(user1).withdraw();

      const finalBalance = await ethers.provider.getBalance(user1.address);
      const userBalanceInVault = await vault.getBalance(user1.address);

      expect(userBalanceInVault).to.equal(0);
      // Verifica se recebeu aproximadamente 5 ETH (considerando gas)
      expect(finalBalance - initialBalance).to.be.closeTo(
        VAULT_DEPOSIT,
        ethers.parseEther("0.01")
      );
    });
  });

  describe("Ataque de Reentrância", function () {
    it("DEVE DETECTAR: Ataque de reentrância drena o vault", async function () {
      // Saldo inicial do vault
      const vaultInitialBalance = await vault.getContractBalance();
      console.log("\n💰 Saldo inicial do Vault:", ethers.formatEther(vaultInitialBalance), "ETH");

      // Saldo inicial do atacante
      const attackerInitialBalance = await ethers.provider.getBalance(attacker.address);
      console.log("💰 Saldo inicial do atacante:", ethers.formatEther(attackerInitialBalance), "ETH");

      // Executar ataque
      console.log("\n⚔️  Executando ataque de reentrância...");
      await attack.connect(attacker).attack({ value: ATTACK_DEPOSIT });

      // Verificar quantos ataques foram executados
      const attackCount = await attack.getAttackCount();
      console.log("🔄 Número de chamadas reentrantes:", attackCount.toString());

      // Saldo do contrato de ataque
      const attackContractBalance = await attack.getBalance();
      console.log("💰 Saldo do contrato de ataque:", ethers.formatEther(attackContractBalance), "ETH");

      // Saldo final do vault
      const vaultFinalBalance = await vault.getContractBalance();
      console.log("💰 Saldo final do Vault:", ethers.formatEther(vaultFinalBalance), "ETH");

      // ASSERÇÕES CRÍTICAS - Detectam a vulnerabilidade
      console.log("\n📊 VERIFICAÇÕES DE SEGURANÇA:");
      
      // 1. O vault deve ter perdido ETH
      expect(vaultFinalBalance).to.be.lessThan(vaultInitialBalance);
      console.log("✅ Vulnerabilidade CONFIRMADA: Vault perdeu ETH");

      // 2. O contrato de ataque deve ter mais de 1 ETH
      expect(attackContractBalance).to.be.greaterThan(ATTACK_DEPOSIT);
      console.log("✅ Vulnerabilidade CONFIRMADA: Contrato de ataque lucrou");

      // 3. Calcular prejuízo
      const loss = vaultInitialBalance - vaultFinalBalance;
      console.log("💸 Prejuízo total:", ethers.formatEther(loss), "ETH");
      console.log("💰 Lucro do atacante (menos 1 ETH de depósito):", ethers.formatEther(loss - ATTACK_DEPOSIT), "ETH");

      // 4. O prejuízo deve ser maior que o depósito (prova de reentrância)
      expect(loss).to.be.greaterThan(ATTACK_DEPOSIT);
      console.log("✅ Vulnerabilidade CONFIRMADA: Prejuízo excede depósito inicial");

      // Retirar fundos roubados
      await attack.connect(attacker).withdrawStolenFunds();

      // Verificar lucro final
      const attackerFinalBalance = await ethers.provider.getBalance(attacker.address);
      console.log("\n💰 Saldo final do atacante:", ethers.formatEther(attackerFinalBalance), "ETH");
      
      // O atacante deve ter lucrado
      expect(attackerFinalBalance).to.be.greaterThan(attackerInitialBalance);
      console.log("✅ Ataque bem-sucedido: Atacante lucrou com reentrância!");
    });

    it("DEVE CALCULAR: Lucro exato do ataque", async function () {
      const vaultInitialBalance = await vault.getContractBalance();
      
      // Executar ataque
      await attack.connect(attacker).attack({ value: ATTACK_DEPOSIT });
      
      const vaultFinalBalance = await vault.getContractBalance();
      const loss = vaultInitialBalance - vaultFinalBalance;
      
      console.log("\n📈 ANÁLISE DO ATAQUE:");
      console.log("   Saldo inicial do vault:", ethers.formatEther(vaultInitialBalance), "ETH");
      console.log("   Saldo final do vault:", ethers.formatEther(vaultFinalBalance), "ETH");
      console.log("   Prejuízo:", ethers.formatEther(loss), "ETH");
      console.log("   Depósito do atacante:", ethers.formatEther(ATTACK_DEPOSIT), "ETH");
      console.log("   Lucro líquido:", ethers.formatEther(loss - ATTACK_DEPOSIT), "ETH");
      
      // O prejuízo deve exceder o depósito (prova de reentrância)
      expect(loss).to.be.greaterThan(ATTACK_DEPOSIT);
    });

    it("DEVE DETECTAR: Múltiplas chamadas reentrantes", async function () {
      await attack.connect(attacker).attack({ value: ATTACK_DEPOSIT });
      
      const attackCount = await attack.getAttackCount();
      console.log("\n🔄 Número de chamadas reentrantes:", attackCount.toString());
      
      // Deve ter múltiplas chamadas reentrantes
      expect(attackCount).to.be.greaterThan(1);
      console.log("✅ Detectadas múltiplas reentradas!");
    });
  });

  describe("Análise de Segurança", function () {
    it("EXPLICA: Por que o vault é vulnerável", async function () {
      console.log("\n🔍 ANÁLISE DA VULNERABILIDADE:");
      console.log("================================");
      console.log("");
      console.log("CÓDIGO VULNERÁVEL (Vault.sol):");
      console.log("------------------------------");
      console.log("function withdraw() external {");
      console.log("    uint256 amount = balances[msg.sender];");
      console.log("    require(amount > 0, 'No balance');");
      console.log("");
      console.log("    ⚠️  VULNERABILIDADE AQUI:");
      console.log("    (bool success, ) = msg.sender.call{value: amount}('');");
      console.log("    require(success, 'Transfer failed');");
      console.log("");
      console.log("    // Atualização TARDIA:");
      console.log("    balances[msg.sender] = 0;");
      console.log("}");
      console.log("");
      console.log("🔴 PROBLEMA:");
      console.log("   A transferência ocorre ANTES da atualização do balance.");
      console.log("   Isso permite que o contrato receptor (Attack)");
      console.log("   chame withdraw() novamente antes da atualização.");
      console.log("");
      console.log("✅ SOLUÇÃO (Checks-Effects-Interactions):");
      console.log("   function withdraw() external {");
      console.log("       uint256 amount = balances[msg.sender];");
      console.log("       require(amount > 0, 'No balance');");
      console.log("       ");
      console.log("       // 1. CHECKS (validações) - OK");
      console.log("       ");
      console.log("       // 2. EFFECTS (atualizações de estado) - PRIMEIRO!");
      console.log("       balances[msg.sender] = 0;");
      console.log("       ");
      console.log("       // 3. INTERACTIONS (chamadas externas) - DEPOIS!");
      console.log("       (bool success, ) = msg.sender.call{value: amount}('');");
      console.log("       require(success, 'Transfer failed');");
      console.log("   }");
      console.log("");
      console.log("✅ OU use OpenZeppelin ReentrancyGuard:");
      console.log("   import '@openzeppelin/contracts/security/ReentrancyGuard.sol';");
      console.log("   contract Vault is ReentrancyGuard {");
      console.log("       function withdraw() external nonReentrant {");
      console.log("           // ... código seguro");
      console.log("       }");
      console.log("   }");
      console.log("");

      expect(true).to.be.true;
    });

    it("COMPARA: Vault vulnerável vs protegido", async function () {
      console.log("\n📊 COMPARAÇÃO: ANTES vs DEPOIS");
      console.log("==============================");
      console.log("");
      console.log("ORDEM DE OPERAÇÕES:");
      console.log("");
      console.log("❌ VULNERÁVEL (Atual):          ✅ SEGURO (Corrigido):");
      console.log("   Transferência                  Atualização");
      console.log("        ↓                             ↓");
      console.log("   Atualização                    Transferência");
      console.log("");
      console.log("PADRÃO CEI (Checks-Effects-Interactions):");
      console.log("   1. CHECKS: Validações (require, assert)");
      console.log("   2. EFFECTS: Atualizações de estado (storage)");
      console.log("   3. INTERACTIONS: Chamadas externas (call, transfer)");
      console.log("");

      expect(true).to.be.true;
    });
  });

  describe("Proteção contra Ataque", function () {
    it("SIMULA: Como um vault seguro se comportaria", async function () {
      console.log("\n🛡️  SIMULAÇÃO DE PROTEÇÃO");
      console.log("=========================");
      console.log("");
      console.log("Se o Vault usasse a ordem correta (CEI):");
      console.log("   1. balances[msg.sender] = 0;  // PRIMEIRO");
      console.log("   2. msg.sender.call{value: amount}('');  // DEPOIS");
      console.log("");
      console.log("Resultado esperado:");
      console.log("   ✅ Na segunda chamada, balance seria 0");
      console.log("   ✅ require(amount > 0) falharia");
      console.log("   ✅ Revert com 'No balance to withdraw'");
      console.log("   ✅ Ataque seria impedido!");
      console.log("");
      console.log("💡 Lição: Sempre atualize estado ANTES de chamadas externas!");
      console.log("");

      expect(true).to.be.true;
    });
  });
});
