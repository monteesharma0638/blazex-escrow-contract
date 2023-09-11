// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BlazexEscrow is Ownable, ReentrancyGuard {
    address public manager = msg.sender;
    address public blazexWallet = msg.sender; // can update to staking contract later.

    uint112 public blazexFeePercent = 1000;  //10% default (please put percent in multiple of 100)

    struct Project {
        uint256 amount;
        uint256 blazexFee;
        address user;
        address token;
        bool paid;
        bool deposited;
        bool refunded;
        uint256 callerId;
        uint256 callId;
        uint256 chain;
    }

    modifier onlyManager() {
        require(
            address(msg.sender) == manager,
            "Escrow: Caller is not manager"
        );
        _;
    }

    mapping(uint256 => Project) public projects;

    constructor() {}

    function deposit(
        uint256 amount,
        uint256 callerId,
        uint256 callId,
        address token,
        uint256 chain
    ) external payable nonReentrant {
        require(amount > 0, "Escrow: amount must be greater then 0");

        Project storage project = projects[callId];
        require(project.amount == 0, "Escrow: Call id exist");
        require(!project.deposited, "Escrow: deposited already");
        require(
            msg.value >= amount,
            "Escrow: Insufficient value"
        );
        payable(address(this)).transfer(msg.value);

        project.deposited = true;
        project.amount = amount;
        project.callerId = callerId;
        project.callId = callId;
        project.token = token;
        project.blazexFee = (blazexFeePercent*amount)/10000;
        project.user = address(msg.sender);
        project.chain = chain;
    }

    function refund(uint256 callId) public onlyManager nonReentrant {
        Project storage project = projects[callId];
        require(
            project.deposited,
            "Escrow: Not deposited yet"
        );
        require(
            !project.paid,
            "Escrow: Not Paid yet"
        );
        require(
            !project.refunded,
            "Escrow: Refunded"
        );

        project.refunded = true;
        payable(project.user).transfer(project.amount);
    }

    function pay(
        uint256 callId,
        address influencer
    ) external onlyManager nonReentrant {
        Project storage project = projects[callId];
        require(!project.paid, "Escrow: Paid already");
        require(!project.refunded, "Escrow: Refunded");
        require(project.deposited, "Escrow: Not deposited yet");
        project.paid = true;
        uint256 blazexFee = project.blazexFee;
        uint256 amount = project.amount - blazexFee;
        payable(address(blazexWallet)).transfer(blazexFee);
        (bool sent,) = influencer.call{value: amount}("");
        require(sent, "Address privided can't receive payments. Please use a different ethereum address");
    }

    function changeManager(address _newManager) external onlyOwner {
        manager = _newManager;
    }

    function changeBlazexWallet(address _newFeeWallet) external onlyOwner {
      blazexWallet = _newFeeWallet;
    }

    // put in multiple of 100
    function changeBlazexFeePercent(uint112 _feePercent) external onlyOwner {
      blazexFeePercent = _feePercent;
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        // this function call is prohibited only call this function when there is stuck funds in the contract
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
