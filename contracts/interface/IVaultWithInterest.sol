// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import "./IKonkreteVault.sol";

interface IVaultWithInterest is IERC4626Upgradeable, IAccessControlEnumerableUpgradeable {
    event UnclaimedFundsCollected(uint256 amount);
    event CapitalCollected(uint256 amount);
    event CapitalLoss(uint256 originalCapital, uint256 remainingCapital, uint256 loss);
    event InterestRefunded(uint256 refunded);
    event CapitalRefunded(uint256 amount, uint256 collected);
    event DepositLimitsupdated(uint256, uint256);
    event TimesUpdated(uint256 depositsStart, uint256 depositsStop);
    event CapsUpdated(uint256 softCap, uint256 hardCap);
    event VaultURIUpdated(string vaultURI_);
    event TreasuryUpdated(address oldTreasury, address newTreasury);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    error ReceiverIsNullAddress();
    error WrongDecimalNumber(uint256 expected1, uint256 expected2, uint256 current);
    error BelowMinimumInvest(uint256 minimum, uint256 amount);
    error WrongSaleTimeStamps();
    error TryToCollectZeroFund();
    error WrongCaps();
    error WrongDatabase();
    error WrongTreasury(address treasury);
    error WrongVaultURI(string vaultURI_);
    error WrongMaxDepositPerUser(uint256 max, uint256 amountWanted);
    error WrongMinDepositPerUser(uint256 maxDeposit, uint256 minInvest);
    error InvestZeroAmount();
    error NotExpectedStep(SaleStep expected, SaleStep currentStep);
    error WrongStep(SaleStep currentStep);
    error MsgSenderUnauthorized(address msgSender);
    error WrongRefundValue(bool isZero);

    function DEV() external view returns (bytes32);

    function KONKRETE() external view returns (bytes32);

    function TIMELOCK() external view returns (bytes32);

    function collectCapital() external returns (uint256 collected);

    function collectUnclaimedFunds() external returns (uint256 pendingFunds);

    function collectedCapital() external view returns (uint256);

    function dataBase() external view returns (address);

    function depositsStart() external view returns (uint256);

    function depositsStop() external view returns (uint256);

    function emptyCapitalBack(bool doubleChecked) external;

    function getStep() external view returns (uint8 step);

    function hardCap() external view returns (uint256);

    function maxDepositPerUser() external view returns (uint256);

    function minInvest(address user) external view returns (uint256);

    function minInvestPerUser() external view returns (uint256);

    function originalPrice() external view returns (uint256);

    function paid(address) external view returns (uint256);

    function pause() external;

    function paused() external view returns (bool);

    function priceImpact(uint256 amountOfInterest) external view returns (uint256);

    function refundCapitalAndInterest(uint256 capital, uint256 interest) external;

    function refundInterest(uint256 interest) external;

    function refunded() external view returns (bool);

    function setCaps(uint256 soft, uint256 hard) external;

    function setDatabase(address database_) external;

    function setDepositLimitsPerUser(uint256 minInvest_, uint256 maxDeposit_) external;

    function setTimes(uint256 start, uint256 stop) external;

    function setTreasury(address treasury_) external;

    function setVaultURI(string memory vaultURI_) external;

    function softCap() external view returns (uint256);

    function tokenPrice() external view returns (uint256);

    function treasury() external view returns (address);

    function unpause() external;

    function vaultURI() external view returns (string memory);
}
