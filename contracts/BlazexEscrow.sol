// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BlazexEscrow is Ownable, ReentrancyGuard {
    uint64 public escrowFeePercent = 1000; // 10 % default (must be multiple of 100)
    uint256 public feeAmountCollected;

    address public manager = msg.sender;
    address public blazexWallet = msg.sender;

    uint256 public nextCallId = 0;

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

    event RequestAdded(
        address caller,
        uint256 amount,
        uint256 blazexFee,
        uint256 callerId,
        uint256 callId,
        string telegramId,
        address token,
        uint256 chain,
        uint256 blockTime
    );

    event Refunded(
      uint256 callId,
      uint256 blockTime
    );

    constructor() {}

    function newRequest(
        uint256 amount,
        uint256 blazexFee,
        uint256 callerId,
        string memory telegramId,
        address token,
        address caller,
        uint256 chain
    ) external payable nonReentrant {
        require(amount > 0, "Escrow: amount must be greater then 0");
        uint256 callId = nextCallId;
        nextCallId++;
        Project storage project = projects[callId];
        if (msg.value > 0) {
            require(
                msg.value >= amount,
                "Escrow: pay Equivalent to amount or 0 for later"
            );
            payable(address(this)).transfer(msg.value);
            project.paid = true;
        }

        project.blazexFee = blazexFee;
        project.amount = amount;
        project.callerId = callerId;
        project.callId = callId;
        project.telegramId = telegramId;
        project.token = token;
        project.caller = caller;
        project.chain = chain;

        emit RequestAdded(
            caller,
            amount,
            blazexFee,
            callerId,
            callId,
            telegramId,
            token,
            chain,
            block.timestamp
        );
    }

    function callRefund(uint256 callId) public onlyManager nonReentrant {
        Project storage project = projects[callId];
        require(
            project.paid && !project.refunded,
            "Escrow: Not paid yet Or Refunded"
        );

        project.refunded = true;
        payable(project.caller).transfer(project.amount);

    }

    function payEscrow(uint256 callId) external payable nonReentrant {
      Project storage project = projects[callId];
      require(!project.paid, "Escrow: Already paid");
      require(project.amount <= msg.value, "Escrow: Insufficient Value");
      require(address(msg.sender) == project.caller, "Escrow: Invalid caller");
      payable(address(this)).transfer(msg.value);
      project.paid = true;
    }

    function acceptRequest(uint256 callId, address influencer) external onlyManager() nonReentrant {
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

    function withdrawFee() external onlyOwner nonReentrant {
        require(feeAmountCollected > 0, "Escrow: No Fee collected yet");
        feeAmountCollected = 0;
        payable(owner()).transfer(feeAmountCollected);
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        // this function call is prohibited only call this function when there is stuck funds in the contract
        feeAmountCollected = 0;
        payable(owner()).transfer(address(this).balance);
    }

    receive() external payable {}
}
