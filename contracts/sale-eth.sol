// SPDX-License-Identifier: MIT

/*

  /$$$$$$          /$$                     /$$$$$$$   /$$$$$$   /$$$$$$ 
 /$$__  $$        |__/                    | $$__  $$ /$$__  $$ /$$__  $$
| $$  \__//$$$$$$  /$$  /$$$$$$   /$$$$$$$| $$  \ $$| $$  \ $$| $$  \ $$
| $$$$   /$$__  $$| $$ /$$__  $$ /$$_____/| $$  | $$| $$$$$$$$| $$  | $$
| $$_/  | $$  \__/| $$| $$$$$$$$|  $$$$$$ | $$  | $$| $$__  $$| $$  | $$
| $$    | $$      | $$| $$_____/ \____  $$| $$  | $$| $$  | $$| $$  | $$
| $$    | $$      | $$|  $$$$$$$ /$$$$$$$/| $$$$$$$/| $$  | $$|  $$$$$$/
|__/    |__/      |__/ \_______/|_______/ |_______/ |__/  |__/ \______/ 

*/

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IFriesDAOToken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

contract FriesDAOTokenSale is ReentrancyGuard, Ownable {

    IFriesDAOToken public immutable FRIES;

    bool public whitelistSaleActive = false;
    bool public publicSaleActive = false;
    bool public redeemActive = false;
    bool public refundActive = false;

    uint256 public salePrice;
    uint256 public whitelistCap;
    uint256 public totalCap;

    mapping (address => bool) public whitelist;
    uint256 public whitelistCount = 0;

    mapping (address => uint256) public purchased;
    mapping (address => uint256) public redeemed;
    uint256 public totalPurchased = 0;

    // Events

    event WhitelistSaleActiveChanged(bool active);
    event PublicSaleActiveChanged(bool active);
    event RedeemActiveChanged(bool active);
    event RefundActiveChanged(bool active);

    event SalePriceChanged(uint256 price);
    event WhitelistCapChanged(uint256 amount);

    event Purchased(address indexed account, uint256 amount);
    event Redeemed(address indexed account, uint256 amount);
    event Refunded(address indexed account, uint256 amount);

    // Initialize sale parameters

    constructor(address fries) {
        FRIES = IFriesDAOToken(fries);
        salePrice = 69420;         // 69,420 FRIES per ETH
        whitelistCap = 2100 ether; // 2,100 max ETH sold in whitelisted sale
        totalCap = 4200 ether;     // Total 4,200 max ETH raised
    }

    // Buy FRIES with ETH in whitelisted token sale

    function buyWhitelistFries() external payable {
        require(whitelistSaleActive, "FriesDAOTokenSale: whitelist token sale is not active");
        require(whitelist[_msgSender()], "FriesDAOTokenSale: not whitelisted");
        require(msg.value > 0, "FriesDAOTokenSale: amount to purchase must be larger than zero");

        uint256 amount = msg.value * salePrice;
        require(purchased[_msgSender()] + amount <= whitelistCap * salePrice / whitelistCount, "FriesDAOTokenSale: amount over whitelist limit");

        purchased[_msgSender()] += amount;
        totalPurchased += amount;
        emit Purchased(_msgSender(), purchased[_msgSender()]);
    }

    // Buy FRIES with ETH in public token sale

    function buyFries() external payable {
        require(publicSaleActive, "FriesDAOTokenSale: public token sale is not active");
        require(msg.value > 0, "FriesDAOTokenSale: amount to purchase must be larger than zero");

        uint256 amount = msg.value * salePrice;
        require(totalPurchased + amount <= totalCap * salePrice, "FriesDAOTokenSale: amount over total sale limit");

        purchased[_msgSender()] += amount;
        totalPurchased += amount;
        emit Purchased(_msgSender(), purchased[_msgSender()]);
    }

    // Redeem purchased FRIES for tokens

    function redeemFries() external {
        require(redeemActive, "FriesDAOTokenSale: redeeming for tokens is not active");

        uint256 amount = purchased[_msgSender()] - redeemed[_msgSender()];
        require(amount > 0, "FriesDAOTokenSale: invalid redeem amount");

        redeemed[_msgSender()] += amount;
        FRIES.transfer(_msgSender(), amount);
        emit Redeemed(_msgSender(), amount);
    }

    // Refund FRIES for ETH at sale price

    function refundFries(uint256 amount) external nonReentrant {
        require(refundActive, "FriesDAOTokenSale: refunding redeemed tokens is not active");
        require(redeemed[_msgSender()] >= amount, "FriesDAOTokenSale: refund amount larger than tokens redeemed");

        FRIES.burnFrom(_msgSender(), amount);
        purchased[_msgSender()] -= amount;
        redeemed[_msgSender()] -= amount;
        (bool success,) = _msgSender().call{value: amount / salePrice}("");
        require(success, "FriesDAOTokenSale: refund call failed");
        
        emit Refunded(_msgSender(), amount);
    }

    // Set whitelist sale enabled

    function setWhitelistSaleActive(bool active) external onlyOwner {
        whitelistSaleActive = active;
        emit WhitelistSaleActiveChanged(whitelistSaleActive);
    }

    // Set public sale enabled

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;
        emit PublicSaleActiveChanged(publicSaleActive);
    }

    // Set redeem enabled

    function setRedeemActive(bool active) external onlyOwner {
        redeemActive = active;
        emit RedeemActiveChanged(redeemActive);
    }

    // Set refund enabled

    function setRefundActive(bool active) external onlyOwner {
        refundActive = active;
        emit RefundActiveChanged(refundActive);
    }

    // Change sale price

    function setSalePrice(uint256 price) external onlyOwner {
        salePrice = price;
        emit SalePriceChanged(salePrice);
    }

    // Change whitelist cap

    function setWhitelistCap(uint256 amount) external onlyOwner {
        whitelistCap = amount;
        emit WhitelistCapChanged(amount);
    }

    // Add accounts to whitelist

    function whitelistAccounts(address[] memory accounts) external onlyOwner {
        for (uint256 a = 0; a < accounts.length; a ++) {
            whitelist[accounts[a]] = true;
        }
        whitelistCount += accounts.length;
    }

    // Withdraw ETH from sale contract to owner

    function withdrawETH(uint256 amount) external onlyOwner {
        (bool success,) = owner().call{value: amount}("");
        require(success, "FriesDAOTokenSale: ETH transfer failed");
    }

    // Default functions

    receive() external payable {}

}