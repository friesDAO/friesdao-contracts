// SPDX-License-Identifier: Apache-2.0

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
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";        //e

import "hardhat/console.sol";

// FRIES token interface

interface IFriesDAOToken is IERC20 {
    function mint(uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

contract FriesDAOTokenSale is ReentrancyGuard, Ownable {

    IERC20 public immutable USDC;                // USDC token
    IFriesDAOToken public immutable FRIES;       // FRIES token
    uint256 public constant FRIES_DECIMALS = 18; // FRIES token decimals
    uint256 public constant USDC_DECIMALS = 6;   // USDC token decimals

    bool public whitelistSaleActive = false;
    bool public publicSaleActive = false;
    bool public redeemActive = false;
    bool public refundActive = false;

    uint256 public salePrice;           // Sale price of FRIES per USDC
    uint256 public baseWhitelistAmount; // Base whitelist amount of USDC available to purchase
    uint256 public totalCap;            // Total maximum amount of USDC in sale
    uint256 public totalPurchased = 0;  // Total amount of USDC purchased in sale

    mapping (address => uint256) public purchased; // Mapping of account to total purchased amount in FRIES
    mapping (address => uint256) public redeemed;  // Mapping of account to total amount of redeemed FRIES
    mapping (address => bool) public vesting;      // Mapping of account to vesting of purchased FRIES after redeem
    bytes32 public merkleRoot;                     // Merkle root representing tree of all whitelisted accounts

    address public treasury;       // friesDAO treasury address
    uint256 public vestingPercent; // Percent tokens vested /1000

    // Events

    event WhitelistSaleActiveChanged(bool active);
    event PublicSaleActiveChanged(bool active);
    event RedeemActiveChanged(bool active);
    event RefundActiveChanged(bool active);

    event SalePriceChanged(uint256 price);
    event BaseWhitelistAmountChanged(uint256 baseWhitelistAmount);
    event TotalCapChanged(uint256 totalCap);

    event Purchased(address indexed account, uint256 amount);
    event Redeemed(address indexed account, uint256 amount);
    event Refunded(address indexed account, uint256 amount);

    event TreasuryChanged(address treasury);
    event VestingPercentChanged(uint256 vestingPercent);

    // Initialize sale parameters

    constructor(address usdcAddress, address friesAddress, address treasuryAddress, bytes32 root) {
        USDC = IERC20(usdcAddress);           // USDC token
        FRIES = IFriesDAOToken(friesAddress); // Set FRIES token contract

        salePrice = 42;                            // 42 FRIES per USDC
        totalCap = 10696969 * 10 ** USDC_DECIMALS; // Total 10,696,969 max USDC raised
        merkleRoot = root;                         // Merkle root for whitelisted accounts

        treasury = treasuryAddress; // Set friesDAO treasury address
        vestingPercent = 850;       // 85% vesting for vested allocations
    }

    /*
     * ------------------
     * EXTERNAL FUNCTIONS
     * ------------------
     */

    // Buy FRIES with USDC in whitelisted token sale

    function buyWhitelistFries(uint256 value, uint256 whitelistLimit, bool vestingEnabled, bytes32[] calldata proof) external {
        require(whitelistSaleActive, "FriesDAOTokenSale: whitelist token sale is not active");
        require(value > 0, "FriesDAOTokenSale: amount to purchase must be larger than zero");

        bytes32 leaf = keccak256(abi.encodePacked(_msgSender(), whitelistLimit, vestingEnabled));                // Calculate merkle leaf of whitelist parameters
        require(MerkleProof.verify(proof, merkleRoot, leaf), "FriesDAOTokenSale: invalid whitelist parameters"); // Verify whitelist parameters with merkle proof

        uint256 amount = value * 10 ** (FRIES_DECIMALS - USDC_DECIMALS) * salePrice;                                   // Calculate amount of FRIES at sale price with USDC value
        require(purchased[_msgSender()] + amount <= whitelistLimit, "FriesDAOTokenSale: amount over whitelist limit"); // Check purchase amount is within whitelist limit

        vesting[_msgSender()] = vestingEnabled;           // Set vesting enabled for account
        USDC.transferFrom(_msgSender(), treasury, value); // Transfer USDC amount to treasury
        purchased[_msgSender()] += amount;                // Add FRIES amount to purchased amount for account
        totalPurchased += value;                          // Add USDC amount to total USDC purchased

        emit Purchased(_msgSender(), amount);
    }

    // Buy FRIES with USDC in public token sale

    function buyFries(uint256 value) external {
        require(publicSaleActive, "FriesDAOTokenSale: public token sale is not active");
        require(value > 0, "FriesDAOTokenSale: amount to purchase must be larger than zero");
        require(totalPurchased + value < totalCap, "FriesDAOTokenSale: amount over total sale limit");

        USDC.transferFrom(_msgSender(), treasury, value);                            // Transfer USDC amount to treasury
        uint256 amount = value * 10 ** (FRIES_DECIMALS - USDC_DECIMALS) * salePrice; // Calculate amount of FRIES at sale price with USDC value
        purchased[_msgSender()] += amount;                                           // Add FRIES amount to purchased amount for account
        totalPurchased += value;                                                     // Add USDC amount to total USDC purchased

        emit Purchased(_msgSender(), amount);
    }

    // Redeem purchased FRIES for tokens

    function redeemFries() external {
        require(redeemActive, "FriesDAOTokenSale: redeeming for tokens is not active");

        uint256 amount = purchased[_msgSender()] - redeemed[_msgSender()]; // Calculate redeemable FRIES amount
        require(amount > 0, "FriesDAOTokenSale: invalid redeem amount");
        redeemed[_msgSender()] += amount;                                  // Add FRIES redeem amount to redeemed total for account

        if (!vesting[_msgSender()]) {
            FRIES.transfer(_msgSender(), amount);                                  // Send redeemed FRIES to account
        } else {
            FRIES.transfer(_msgSender(), amount * (1000 - vestingPercent) / 1000); // Send available FRIES to account
            FRIES.transfer(treasury, amount * vestingPercent / 1000);              // Send vested FRIES to treasury
        }

        emit Redeemed(_msgSender(), amount);
    }

    // Refund FRIES for USDC at sale price

    function refundFries(uint256 amount) external nonReentrant {
        require(refundActive, "FriesDAOTokenSale: refunding redeemed tokens is not active");
        require(redeemed[_msgSender()] >= amount, "FriesDAOTokenSale: refund amount larger than tokens redeemed");

        FRIES.burnFrom(_msgSender(), amount);                                                                     // Remove FRIES refund amount from account
        purchased[_msgSender()] -= amount;                                                                        // Reduce purchased amount of account by FRIES refund amount
        redeemed[_msgSender()] -= amount;                                                                         // Reduce redeemed amount of account by FRIES refund amount
        USDC.transferFrom(treasury, _msgSender(), (amount / 10 ** (FRIES_DECIMALS - USDC_DECIMALS)) / salePrice); // Send refund USDC amount at sale price to account
        
        emit Refunded(_msgSender(), amount);
    }

    /*
     * --------------------
     * RESTRICTED FUNCTIONS
     * --------------------
     */

    // Set merkle root
    function setRoot(bytes32 _root) external onlyOwner {    //e
        merkleRoot = _root;
    }

    // Set whitelist sale enabled status

    function setWhitelistSaleActive(bool active) external onlyOwner {
        whitelistSaleActive = active;
        emit WhitelistSaleActiveChanged(whitelistSaleActive);
    }

    // Set public sale enabled status

    function setPublicSaleActive(bool active) external onlyOwner {
        publicSaleActive = active;
        emit PublicSaleActiveChanged(publicSaleActive);
    }

    // Set redeem enabled status

    function setRedeemActive(bool active) external onlyOwner {
        redeemActive = active;
        emit RedeemActiveChanged(redeemActive);
    }

    // Set refund enabled status

    function setRefundActive(bool active) external onlyOwner {
        refundActive = active;
        emit RefundActiveChanged(refundActive);
    }

    // Change sale price

    function setSalePrice(uint256 price) external onlyOwner {
        salePrice = price;
        emit SalePriceChanged(salePrice);
    }

    // Change sale total cap

    function setTotalCap(uint256 amount) external onlyOwner {
        totalCap = amount;
        emit TotalCapChanged(totalCap);
    }

    // Change friesDAO treasury address

    function setTreasury(address treasuryAddress) external {
        require(_msgSender() == treasury, "FriesDAOTokenSale: caller is not the treasury");
        treasury = treasuryAddress;
        emit TreasuryChanged(treasury);
    }

    // Change vesting percent

    function setVestingPercent(uint256 percent) external onlyOwner {
        vestingPercent = percent;
        emit VestingPercentChanged(vestingPercent);
    }

}
