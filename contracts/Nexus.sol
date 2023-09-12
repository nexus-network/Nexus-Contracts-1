//SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Withdraw} from "./Withdrawal.sol";
import {INexusBridge} from "./interfaces/INexusBridge.sol";
import {Ownable} from "./utils/NexusOwnable.sol";
import {Proxiable} from "./utils/UUPSUpgreadable.sol";

/**
 * @title Nexus Core Contract
 * @dev This contract is heart and soul of Nexus Network and is used for Operations like
 * 1. Onboarding of rollup to Nexus Network
 * 2. Change in staking limit for rollup
 * 3. Whitelisting rollup address
 * 4. Submitting keys to rollup bridge
 * 5. Submitting keyshares to SSV contract
 * 6. Recharge funds in SSV contract for validator operation
 * 7. Reward distribution for rollup to DAO and Nexus Fee Contract
 */
contract Nexus is Ownable,Proxiable{
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;

    struct Rollup {
        address bridgeContract;
        uint16 stakingLimit;
        address withdrawalAddress;
        uint64 validatorCount;
        uint32 operatorCluster;
    }
    EnumerableSet.AddressSet private whitelistedRollups;
    address public offChainBot;
    mapping(address => Rollup) public rollups;
    mapping(uint32 => uint32[]) public operatorClusters;

    event RollupWhitelisted(string name, address rollupAddress);
    error NotNexusBot();
    error AddressAlreadyWhitelisted();
    error AddressNotWhitelisted();
    error RollupAlreadyPresent();
    error RollupAlreadyRegistered();

    event RollupRegistered(address adminAddress,address withdrawalAddress);
    event StakingLimitChanged(uint16 oldStakingLimit, uint16 newStakingLimit);

    modifier onlyOffChainBot() {
        if (msg.sender != offChainBot) revert NotNexusBot();
        _;
    }

    modifier onlyWhitelistedRollup() {
        if (!whitelistedRollups.contains(msg.sender))
            revert AddressNotWhitelisted();
        _;
    }

    function initialize() public initilizeOnce{
        _ownableInit(msg.sender);
    }

    function updateProxy(address newImplemetation) public onlyOwner{
        updateCodeAddress(newImplemetation);
    }

    function registerRollup(
        address bridgeContract,
        uint32 operatorCluster,
        uint16 stakingLimit,
        address daoAddress
    ) external onlyWhitelistedRollup {
        if (rollups[msg.sender].bridgeContract != address(0))
            revert RollupAlreadyRegistered();
        Withdraw withdrawalContract = new Withdraw(daoAddress, 1000);
        rollups[msg.sender] = Rollup(
            bridgeContract,
            stakingLimit,
            address(withdrawalContract),
            0,
            operatorCluster
        );
        INexusBridge(bridgeContract).setWithdrawal(address(withdrawalContract));
        emit RollupRegistered(msg.sender,address(withdrawalContract));
    }

    function changeStakingLimit(
        uint16 newStakingLimit
    ) external onlyWhitelistedRollup {
        emit StakingLimitChanged(
            rollups[msg.sender].stakingLimit,
            newStakingLimit
        );
        rollups[msg.sender].stakingLimit = newStakingLimit;
    }

    function depositValidatorRollup() external onlyOffChainBot {}

    function depositValidatorShares() external onlyOffChainBot {}

    function whitelistRollup(
        string calldata name,
        address rollupAddress
    ) external onlyOwner {
        if (whitelistedRollups.contains(rollupAddress))
            revert AddressAlreadyWhitelisted();
        if (whitelistedRollups.add(rollupAddress)) {
            emit RollupWhitelisted(name, rollupAddress);
        } else {
            revert RollupAlreadyPresent();
        }
    }
}
