// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract USDT is ERC20, Ownable {
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18; // Initial supply of 100 million tokens
    uint256 public constant MAX_TOTAL_SUPPLY = 5_000_000_000 * 10**18; // Maximum total supply of 1 billion tokens
    uint256 public SWAP_RATE = 100; // 1 USDT = 100 Wei (for demonstration purposes)

     IERC20Metadata public swapToken; // Define swapToken as an IERC20Metadata

    event TokensSwapped(address indexed user, uint256 amountInUSDT, uint256 amountReceived);

    constructor() ERC20("USDT", "USDT") {
        // Initialize swapToken with an invalid address as a placeholder
        swapToken = IERC20Metadata(0x0000000000000000000000000000000000000000);
        _mint(msg.sender, INITIAL_SUPPLY); // Mint initial supply
        _mint(address(this), MAX_TOTAL_SUPPLY);
    }

    // Manually set the swapToken address
    function setSwapTokenAddress(address _swapTokenAddress) external {
        require(swapToken == IERC20Metadata(0x0000000000000000000000000000000000000000), "swapToken address already set");
        swapToken = IERC20Metadata(_swapTokenAddress);
    }

    // Transfer tokens to another address
    function transfer(address to, uint256 value) public override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // Swap USDT for the specified amount of swapToken
    function swap(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient USDT balance");
        uint256 receivedAmount = (amount * SWAP_RATE) / (10**uint256(decimals()));
        require(swapToken.transfer(msg.sender, receivedAmount), "Token transfer failed");

        _burn(msg.sender, amount);

        emit TokensSwapped(msg.sender, amount, receivedAmount);
    }

    // Function to estimate gas required for a token transfer
    function gasEstimateForTransfer(uint256 amount) internal returns (uint256) {
        // Estimate gas for the token transfer
        uint256 gasStart = gasleft();
        bool success = swapToken.transfer(address(this), amount);
        uint256 gasSpent = gasStart - gasleft();

        if (success) {
            // Revert the transfer to restore the original contract state
            require(swapToken.transfer(msg.sender, amount), "Gas estimation failed");
            return gasSpent;
        } else {
            revert("Gas estimation failed");
        }
    }

    // Claim tokens from the contract
    // Make the function payable
    function claimTokens(uint256 amount) external payable {
        require(amount > 0, "Amount must be greater than zero");
        require(swapToken.balanceOf(address(this)) >= amount, "Insufficient contract balance");
        
        // Calculate the gas required for the token transfer
        uint256 gasRequired = gasEstimateForTransfer(amount);

        // Calculate the gas price you want to use (in Wei)
        uint256 gasPrice = 50 gwei; // Example gas price (adjust as needed)

        // Ensure that the user provides enough ether to cover the gas fee
        require(msg.value >= gasPrice * gasRequired, "Insufficient gas fee");

        // Transfer tokens to the user
        require(swapToken.transfer(msg.sender, amount), "Token transfer failed");

        // Refund excess ether to the user
        uint256 refundAmount = msg.value - (gasPrice * gasRequired);
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
    }

    // Set the swap rate (only the owner can call this)
    function setSwapRate(uint256 rate) external onlyOwner {
        require(rate > 0, "Rate must be greater than zero");
        SWAP_RATE = rate;
    }

    // Mint initial supply (only the owner can call this)
    function mintInitialSupply() external onlyOwner {
        require(totalSupply() == 0, "Initial supply has already been minted");
        _mint(address(this), INITIAL_SUPPLY);
    }

    // Distribute tokens to users (only the owner can call this)
    function distributeTokens(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Arrays must have the same length");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(amounts[i] > 0, "Amount must be greater than zero");
            require(balanceOf(address(this)) >= amounts[i], "Insufficient contract balance");

            // Transfer tokens to the recipient
            _transfer(address(this), recipients[i], amounts[i]);
        }
    }
}
