// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Vault
 * @dev Este contrato contém uma vulnerabilidade INTENCIONAL de reentrância
 * para fins educacionais e testes de segurança.
 * @author Ricardo Silva
 * @notice NÃO USE EM PRODUÇÃO - Este contrato é vulnerável!
 */
contract Vault {
    // Mapping de balances dos usuários
    mapping(address => uint256) public balances;
    
    // Eventos
    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    
    /**
     * @dev Permite usuários depositar ETH no vault
     */
    function deposit() external payable {
        require(msg.value > 0, "Must deposit some ETH");
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
    
    /**
     * @dev Função vulnerável a reentrância!
     * A ordem incorreta (transfer antes de atualizar o balance)
     * permite ataques de reentrância.
     */
    function withdraw() external {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No balance to withdraw");
        
        // VULNERABILIDADE: Transferência antes de atualizar o balance!
        // Isso permite que um contrato malicioso reentre antes da atualização
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
        
        // Atualização do balance APÓS a transferência (ordem incorreta)
        balances[msg.sender] = 0;
        
        emit Withdrawal(msg.sender, amount);
    }
    
    /**
     * @dev Retorna o balance de um usuário
     */
    function getBalance(address user) external view returns (uint256) {
        return balances[user];
    }
    
    /**
     * @dev Retorna o balance total do contrato
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    // Função receive para aceitar ETH
    receive() external payable {}
    
    // Função fallback
    fallback() external payable {}
}
