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

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FriesDAOLiquidityStaking is Ownable {

    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of FRIES
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accFriesPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accFriesPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. FRIES to distribute per block.
        uint256 lastRewardBlock;  // Last block number that FRIES distribution occurs.
        uint256 accFriesPerShare; // Accumulated FRIES per share, times 1e12. See below.
        uint256 totalStaked;      // Total amount of LP token staked in pool.
    }

    IERC20 public FRIES;          // friesDAO token
    uint256 public friesPerBlock; // Amount of FRIES distributed per block between all pools

    PoolInfo[] public poolInfo;                                         // Info of each pool
    mapping (uint256 => mapping (address => UserInfo)) public userInfo; // Info of each user by pool ID

    uint256 public totalAllocPoint = 0; // Total allocation points for all pools
    uint256 public startBlock;          // Block rewards start

    // Events

    event FriesPerBlockChanged(uint256 friesPerBlock);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    // Check token is not already added in a pool

    modifier nonDuplicate(IERC20 token) {
        for (uint256 p = 0; p < poolInfo.length; p ++) {
            require(token != poolInfo[p].lpToken);
        }
        _;
    }

    // Initialize liquidity staking data

    constructor(address fries) {
        FRIES = IERC20(fries);
        friesPerBlock = 1 ether; // 1 FRIES distributed per block
        startBlock = 0;          // Rewards start at block 0
    }

    // Return number of pools

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add new staking reward pool

    function add(uint256 _allocPoint, IERC20 _lpToken, bool _withUpdate) external onlyOwner nonDuplicate(_lpToken) {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint += _allocPoint;
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accFriesPerShare: 0,
            totalStaked: 0
        }));
    }

    // Update FRIES allocation points of a pool

    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint - poolInfo[_pid].allocPoint + _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Update FRIES distribution rate per block

    function setFriesPerBlock(uint256 ratePerBlock) external onlyOwner {
        massUpdatePools();
        friesPerBlock = ratePerBlock;
        emit FriesPerBlockChanged(friesPerBlock);
    }

    // Calculate reward multiplier between blocks

    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to - _from;
    }

    // Calculate pending FRIES reward for a user on a pool

    function pendingFries(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accFriesPerShare = pool.accFriesPerShare;
        uint256 lpSupply = pool.totalStaked;

        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 friesReward = multiplier * friesPerBlock * pool.allocPoint / totalAllocPoint;
            accFriesPerShare += friesReward * 1e12 / lpSupply;
        }

        return user.amount * accFriesPerShare / 1e12 - user.rewardDebt;
    }

    // Update reward data on all pools

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; pid ++) {
            updatePool(pid);
        }
    }

    // Update reward data of a pool

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) return;

        uint256 lpSupply = pool.totalStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 friesReward = multiplier * friesPerBlock * pool.allocPoint / totalAllocPoint;
        pool.accFriesPerShare += friesReward * 1e12 / lpSupply;
        pool.lastRewardBlock = block.number;
    }

    // Deposit tokens for FRIES distribution

    function deposit(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accFriesPerShare / 1e12 - user.rewardDebt;
            if (pending > 0) {
                safeFriesTransfer(_msgSender(), pending);
            }
        }

        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(address(_msgSender()), address(this), _amount);
            user.amount += _amount;
        }

        user.rewardDebt = user.amount * pool.accFriesPerShare / 1e12;
        emit Deposit(_msgSender(), _pid, _amount);
    }

    // Withdraw tokens from staking

    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_msgSender()];
        require(user.amount >= _amount, "FriesDAOLiquidityStaking: insufficient balance for withdraw");
        updatePool(_pid);

        uint256 pending = user.amount * pool.accFriesPerShare / 1e12 - user.rewardDebt;
        if (pending > 0) {
            safeFriesTransfer(_msgSender(), pending);
        }

        if (_amount > 0) {
            user.amount -= _amount;
            pool.lpToken.safeTransfer(address(_msgSender()), _amount);
        }

        user.rewardDebt = user.amount * pool.accFriesPerShare / 1e12;
        emit Withdraw(_msgSender(), _pid, _amount);
    }

    // Withdraw ignoring FRIES rewards

    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(_msgSender()), amount);

        emit EmergencyWithdraw(_msgSender(), _pid, amount);
    }

    // Safe FRIES transfer

    function safeFriesTransfer(address _to, uint256 _amount) internal {
        uint256 friesBal = FRIES.balanceOf(address(this));
        if (_amount > friesBal) {
            FRIES.transfer(_to, friesBal);
        } else {
            FRIES.transfer(_to, _amount);
        }
    }

}