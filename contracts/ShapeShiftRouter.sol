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
    // setRegistry can be set by whom? currently yearn governance. Should this be us or them?
    //
    // If a user calls withdraw for tokens that are in a vault that this contract never interacted with
    // that vault with not have an approval from this contract.  Should we add the ability for the owner to
    // approve a fault as a safeguard, or maybe just better to direct caller to use yearn directly in that scenario.
    // should we add a re-entrant guard for extra security
    // gas optimizations in the withdraw functionality iterating over vaults[id]

    uint256 constant MIGRATE_EVERYTHING = type(uint256).max;
    // VaultsAPI.depositLimit is unlimited
    uint256 constant UNCAPPED_DEPOSITS = type(uint256).max;

    constructor(address _registry) public BaseRouter(_registry) {}

    /**
    @notice called to deposit the callers token into the current best vault.  Caller must approve this contract
    to utilize the ERC20 or this call will revert.
    @param _token address of the ERC20 token being deposited
    @param _recipient address to send the issued vault tokens
    @param _amount ERC20 amount to be deposited, any remaining is refunded,
    BaseRouter.sol will iterate through vaults until this amount reached or no more vaults
    */
    function deposit(
        address _token,
        address _recipient,
        uint256 _amount
    ) external returns (uint256) {
        return _deposit(IERC20(_token), msg.sender, _recipient, _amount, true);
    }

    /**
    @notice called to withdraw the callers token from underlying vault(s) with the proceeds distributed to the 
    recipient. Caller must approve their yearn vault tokens for use by this contract.
    @param _token address of the ERC20 token to withdraw from vaults
    @param _recipient address to send the withdrawn tokens
    @param _amount specific amount to withdraw from vaults. 
    BaseRouter.sol will iterate through vaults until this amount reached or no more vaults
    @param _withdrawFromBest should assets be removed from the "best" vault. useful for migrating / consolidating
    */
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

    /**
    @notice called to withdraw all callers token from underlying vault(s) with the proceeds distributed to the 
    recipient. Caller must approve their yearn vault tokens for use by this contract.
    @param _token address of the ERC20 token to withdraw from vaults
    @param _recipient address to send the withdrawn tokens
    */
    function withdraw(address _token, address _recipient)
        external
        returns (uint256)
    {
        return
            _withdraw(
                IERC20(_token),
                msg.sender,
                _recipient,
                WITHDRAW_EVERYTHING,
                true
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
