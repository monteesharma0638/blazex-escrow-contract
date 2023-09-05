// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BlazexEscrow is Ownable, ReentrancyGuard {
    address public manager = msg.sender;
    address public blazexWallet = msg.sender; // can update to staking contract later.

    struct Project {
        uint256 amount;
        address caller;
        address token;
        bool callApproved;
        bool paid;
        bool refunded;
        uint256 blazexFee;
        uint256 callerId;
        uint256 callId;
        uint256 chain;
        string telegramId;
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
        uint256 blazexFee,
        uint256 callerId,
        uint256 callId,
        string memory telegramId,
        address token,
        address caller,
        uint256 chain
    ) external payable nonReentrant {
        require(amount > 0, "Escrow: amount must be greater then 0");

        Project storage project = projects[callId];
        require(!project.paid, "Escrow: Paid already");
        require(
            msg.value >= amount,
            "Escrow: Insufficient value"
        );
        payable(address(this)).transfer(msg.value);

        project.paid = true;
        project.blazexFee = blazexFee;
        project.amount = amount;
        project.callerId = callerId;
        project.callId = callId;
        project.telegramId = telegramId;
        project.token = token;
        project.caller = caller;
        project.chain = chain;
    }

    function refund(uint256 callId) public onlyManager nonReentrant {
        Project storage project = projects[callId];
        require(
            project.paid && !project.refunded,
            "Escrow: Not paid yet Or Refunded"
        );

        project.refunded = true;
        payable(project.caller).transfer(project.amount);
    }

    function pay(
        uint256 callId,
        address influencer
    ) external onlyManager nonReentrant {
        Project storage project = projects[callId];
        require(!project.callApproved, "Escrow: Accepted already");
        project.callApproved = true;
        uint256 amount = project.amount - project.blazexFee;
        payable(address(blazexWallet)).transfer(project.blazexFee);
        payable(address(influencer)).transfer(amount);
    }

    function changeManager(address _newManager) external onlyOwner {
        manager = _newManager;
    }

    function changeBlazexWallet(address _newFeeWallet) external onlyOwner {
      blazexWallet = _newFeeWallet;
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        // this function call is prohibited only call this function when there is stuck funds in the contract
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
