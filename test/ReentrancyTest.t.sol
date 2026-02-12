// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/Vault.sol";
import "../src/Attack.sol";

/**
 * @title ReentrancyTest
 * @dev Testes em Foundry para detectar a vulnerabilidade de reentrância
 * @author Ricardo Silva
 */
contract ReentrancyTest is Test {
    Vault public vault;
    Attack public attack;
    
    // Endereços para teste
    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public attacker = address(0x666);
    
    // Eventos para teste
    event AttackStarted(uint256 initialBalance);
    event ReentrancyExecuted(uint256 amount, uint256 count);
    event AttackCompleted(uint256 totalStolen);
    
    function setUp() public {
        // Deploy do Vault
        vault = new Vault();
        
        // Configurar saldos iniciais
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(attacker, 5 ether);
        
        // Usuários depositam no Vault
        vm.prank(user1);
        vault.deposit{value: 5 ether}();
        
        vm.prank(user2);
        vault.deposit{value: 5 ether}();
        
        // Deploy do contrato de ataque
        vm.prank(attacker);
        attack = new Attack(payable(address(vault)));
    }
    
    /**
     * @dev Teste 1: Verifica se o vault aceita depósitos corretamente
     */
    function test_DepositWorks() public {
        uint256 balance = vault.getBalance(user1);
        assertEq(balance, 5 ether, "User1 should have 5 ETH");
        
        uint256 contractBalance = vault.getContractBalance();
        assertEq(contractBalance, 10 ether, "Vault should have 10 ETH total");
    }
    
    /**
     * @dev Teste 2: Verifica se o saque normal funciona
     */
    function test_NormalWithdrawal() public {
        uint256 initialBalance = user1.balance;
        
        vm.prank(user1);
        vault.withdraw();
        
        uint256 finalBalance = user1.balance;
        assertEq(finalBalance, initialBalance + 5 ether, "User1 should receive 5 ETH");
        assertEq(vault.getBalance(user1), 0, "User1 balance should be 0");
    }
    
    /**
     * @dev Teste 3: DETECTA A VULNERABILIDADE DE REENTRÂNCIA
     * Este teste demonstra como o ataque funciona
     */
    function test_ReentrancyAttack() public {
        // Saldo inicial do vault
        uint256 vaultInitialBalance = vault.getContractBalance();
        assertEq(vaultInitialBalance, 10 ether, "Vault should start with 10 ETH");
        
        // Saldo inicial do atacante
        uint256 attackerInitialBalance = attacker.balance;
        
        // Executar o ataque
        vm.prank(attacker);
        attack.attack{value: 1 ether}();
        
        // Verificar quantos ataques foram executados
        uint256 attackCount = attack.getAttackCount();
        console.log("Number of reentrancy attacks:", attackCount);
        
        // O atacante deve ter mais de 1 ETH (o que depositou)
        uint256 attackContractBalance = attack.getBalance();
        console.log("Attack contract balance:", attackContractBalance);
        
        // Verificar se o vault foi drenado
        uint256 vaultFinalBalance = vault.getContractBalance();
        console.log("Vault balance after attack:", vaultFinalBalance);
        
        // O vault deve ter perdido ETH (vulnerabilidade confirmada)
        assertLt(vaultFinalBalance, vaultInitialBalance, "Vault should have lost ETH to reentrancy");
        
        // O contrato de ataque deve ter mais ETH do que depositou
        assertGt(attackContractBalance, 1 ether, "Attack contract should have more than 1 ETH");
        
        // Retirar os fundos roubados
        vm.prank(attacker);
        attack.withdrawStolenFunds();
        
        // Verificar saldo final do atacante
        uint256 attackerFinalBalance = attacker.balance;
        console.log("Attacker initial balance:", attackerInitialBalance);
        console.log("Attacker final balance:", attackerFinalBalance);
        
        // O atacante deve ter lucrado (ter mais ETH do que começou)
        assertGt(attackerFinalBalance, attackerInitialBalance, "Attacker should profit from reentrancy");
    }
    
    /**
     * @dev Teste 4: Calcula o prejuízo exato
     */
    function test_ReentrancyProfitCalculation() public {
        uint256 vaultInitialBalance = vault.getContractBalance();
        
        // Executar ataque
        vm.prank(attacker);
        attack.attack{value: 1 ether}();
        
        // Calcular prejuízo
        uint256 vaultFinalBalance = vault.getContractBalance();
        uint256 loss = vaultInitialBalance - vaultFinalBalance;
        
        console.log("Initial vault balance:", vaultInitialBalance);
        console.log("Final vault balance:", vaultFinalBalance);
        console.log("Total loss:", loss);
        console.log("Attacker profit (minus 1 ETH deposit):", loss - 1 ether);
        
        // O prejuízo deve ser maior que o depósito (prova de reentrância)
        assertGt(loss, 1 ether, "Loss should exceed the 1 ETH deposit");
    }
    
    /**
     * @dev Teste 5: Simula proteção contra reentrância (demonstra a solução)
     */
    function test_HowReentrancyProtectionShouldWork() public {
        // Em um contrato seguro, a ordem deveria ser:
        // 1. Atualizar o balance primeiro (effects)
        // 2. Depois fazer a transferência (interactions)
        // 
        // Isso segue o padrão Checks-Effects-Interactions
        
        console.log("VULNERABILIDADE DETECTADA:");
        console.log("O Vault.sol transfere ETH antes de atualizar o balance.");
        console.log("Isso permite reentrada antes da atualizacao.");
        console.log("");
        console.log("SOLUCAO:");
        console.log("Alterar a ordem em withdraw():");
        console.log("  balances[msg.sender] = 0;  // Primeiro");
        console.log("  (bool success, ) = msg.sender.call{value: amount}('');  // Depois");
        console.log("");
        console.log("Ou usar modificador nonReentrant do OpenZeppelin");
        
        // Este teste sempre passa, serve como documentação
        assertTrue(true, "Documentation test");
    }
    
    /**
     * @dev Teste 6: Fuzzing - Testa com valores aleatórios
     */
    function testFuzz_ReentrancyWithDifferentAmounts(uint256 depositAmount) public {
        // Limitar valores para evitar overflow
        vm.assume(depositAmount > 0.1 ether && depositAmount < 100 ether);
        
        // Dar ETH ao atacante
        vm.deal(attacker, depositAmount + 1 ether);
        
        // Recriar contrato de ataque
        vm.prank(attacker);
        Attack newAttack = new Attack(payable(address(vault)));
        
        // Usuário deposita o valor de fuzzing
        address fuzzUser = address(uint160(uint256(keccak256(abi.encodePacked(depositAmount)))));
        vm.deal(fuzzUser, depositAmount);
        vm.prank(fuzzUser);
        vault.deposit{value: depositAmount}();
        
        uint256 vaultBalanceBefore = vault.getContractBalance();
        
        // Tentar ataque
        vm.prank(attacker);
        try newAttack.attack{value: 1 ether}() {
            // Ataque executado
            uint256 vaultBalanceAfter = vault.getContractBalance();
            
            // Se o vault tinha mais que 1 ETH, deveria ter perdido fundos
            if (vaultBalanceBefore > 1 ether) {
                assertLt(vaultBalanceAfter, vaultBalanceBefore, "Reentrancy should drain vault");
            }
        } catch {
            // Ataque pode falhar em alguns casos, isso é ok
            console.log("Attack failed for deposit amount:", depositAmount);
        }
    }
    
    /**
     * @dev Teste 7: Verifica eventos emitidos durante o ataque
     */
    function test_ReentrancyEvents() public {
        // Preparar para capturar eventos
        vm.expectEmit(true, false, false, true);
        emit AttackStarted(10 ether);
        
        // Executar ataque
        vm.prank(attacker);
        attack.attack{value: 1 ether}();
        
        // Verificar se eventos de reentrada foram emitidos
        uint256 attackCount = attack.getAttackCount();
        assertGt(attackCount, 0, "Should have reentrancy events");
        
        console.log("Reentrancy attack executed successfully");
        console.log("Number of recursive calls:", attackCount);
    }
}
