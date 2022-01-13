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

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract FriesVesting is Context {

    struct VestingSchedule {
        uint256 amount;      // FRIES vested in schedule
        uint256 period;      // Vesting duration
        uint256 end;         // Vesting end time
        uint256 lastClaimed; // Last FRIES claimed time
    }

    IERC20 public immutable FRIES;

    mapping (address => VestingSchedule[]) public vesting;

    // Initialize vesting contract parameters

    constructor(address friesAddress) {
        FRIES = IERC20(friesAddress);
    }

    /*
     * ------------------
     * EXTERNAL FUNCTIONS
     * ------------------
     */
    
    // Vest FRIES from caller for caller

    function vest(uint256 amount, uint256 period) external {
        _vest(_msgSender(), amount, period);
    }

    // Vest FRIES from caller for account

    function vestFor(address account, uint256 amount, uint256 period) external {
        _vest(account, amount, period);
    }

    // Claim claimable vested FRIES

    function claimFries(uint256 scheduleId) external {
        VestingSchedule storage schedule = vesting[_msgSender()][scheduleId];
        require(block.timestamp > schedule.lastClaimed && schedule.lastClaimed < schedule.end, "FriesVesting: nothing to claim");

        uint256 duration = (block.timestamp > schedule.end ? schedule.end : block.timestamp) - schedule.lastClaimed; // Calculate number of seconds elapsed
        uint256 claimable = schedule.amount * duration / schedule.period;                                            // Calculate claimable FRIES
        schedule.lastClaimed = block.timestamp > schedule.end ? schedule.end : block.timestamp;                      // Update last claimed time in schedule
        FRIES.transfer(_msgSender(), claimable);                                                                     // Send claimable FRIES to account
    }

    /*
     * ------------------
     * INTERNAL FUNCTIONS
     * ------------------
     */

    // Vest FRIES from caller for account on vesting period
    
    function _vest(address account, uint256 amount, uint256 period) internal {
        require(amount > 0, "FriesVesting: amount to vest must be larger than zero");
        require(period > 0, "FriesVesting: period to vest must be longer than zero");

        FRIES.transferFrom(_msgSender(), address(this), amount); // Transfer FRIES from caller to vesting contract
        vesting[account].push(VestingSchedule({                  // Add vesting schedule to account
            amount: amount,
            period: period,
            end: block.timestamp + period,
            lastClaimed: block.timestamp
        }));
    }

    /*
     * --------------
     * VIEW FUNCTIONS
     * --------------
     */
    
    // Get claimable FRIES for account and schedule

    function claimableFries(address account, uint256 scheduleId) external view returns (uint256) {
        VestingSchedule memory schedule = vesting[account][scheduleId];
        if (block.timestamp <= schedule.lastClaimed || schedule.lastClaimed >= schedule.end) {
            return 0;
        }
        uint256 duration = (block.timestamp > schedule.end ? schedule.end : block.timestamp) - schedule.lastClaimed; // Calculate number of seconds elapsed
        return schedule.amount * duration / schedule.period;                                                         // Calculate claimable FRIES
    }

}