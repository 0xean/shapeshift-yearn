// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {VaultAPI} from "@yearnvaults/contracts/BaseWrapper.sol";
import {BaseRouter} from "./BaseRouter.sol";

contract ShapeShiftRouter is BaseRouter {
    // TODO:
    // BaseRouter not yet included in the 0.4.3 tagged release.
    // use ownable from oz
    // additional information in smart contract?
    // events for rewards?
    // FOX?

    uint256 constant MIGRATE_EVERYTHING = type(uint256).max;
    // VaultsAPI.depositLimit is unlimited
    uint256 constant UNCAPPED_DEPOSITS = type(uint256).max;

    constructor(address _registry) public BaseRouter(_registry) {}

    function deposit(
        address _token,
        address _recipient,
        uint256 _amount
    ) external returns (uint256) {
        return _deposit(IERC20(_token), msg.sender, _recipient, _amount, true);
    }

    function withdraw(
        address _token,
        address _recipient,
        uint256 _amount,
        bool _withdrawFromBest
    ) external returns (uint256) {
        return
            _withdraw(
                IERC20(_token),
                msg.sender,
                _recipient,
                _amount,
                _withdrawFromBest
            );
    }

    function migrate(address _token, uint256 _amount)
        external
        returns (uint256)
    {
        return _migrate(IERC20(_token), _amount);
    }

    function migrate(address _token) external returns (uint256) {
        return _migrate(IERC20(_token), MIGRATE_EVERYTHING);
    }

    function _migrate(IERC20 _token, uint256 _amount)
        internal
        returns (uint256 migrated)
    {
        VaultAPI currentBestVault = bestVault(address(_token));

        // NOTE: Only override if we aren't migrating everything
        uint256 depositLimitOfVault = currentBestVault.depositLimit();
        uint256 totalAssetsInVault = currentBestVault.totalAssets();

        if (depositLimitOfVault <= totalAssetsInVault) return 0; // Nothing to migrate (not a failure)

        uint256 amount = _amount;

        if (
            depositLimitOfVault < UNCAPPED_DEPOSITS &&
            amount < WITHDRAW_EVERYTHING
        ) {
            // Can only deposit up to this amount
            uint256 depositLeft = depositLimitOfVault.sub(totalAssetsInVault);
            if (amount > depositLeft) amount = depositLeft;
        }

        if (amount > 0) {
            // NOTE: `false` = don't withdraw from `_bestVault`
            uint256 withdrawn = _withdraw(
                _token,
                msg.sender,
                address(this),
                amount,
                false
            );
            if (withdrawn == 0) return 0; // Nothing to migrate (not a failure)

            // NOTE: `false` = don't do `transferFrom` because it's already local
            migrated = _deposit(
                _token,
                address(this),
                msg.sender,
                withdrawn,
                false
            );
        } // else: nothing to migrate! (not a failure)
    }
}
