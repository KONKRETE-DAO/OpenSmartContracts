// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/interfaces/IERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/IAccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/**
@notice Steps of the vault :
 */
enum SaleStep {
  PREAUCTION,
  SALE,
  SALE_COMPLETE,
  SALE_FAILED,
  CAPITAL_REFUNDED
}

interface IKonkreteVault is IERC4626Upgradeable, IAccessControlUpgradeable {
  error DecimalOverFlow();
  error MsgSenderUnauthorized(address msgSender);
  error NegativeCapital(int256 capital_);
  error NotExpectedStep(uint8 expected, uint8 currentStep);
  error ReceiverUnauthorized(address receiver);
  error WrongDatabase();
  error WrongDecimalNumber(
    uint256 expected1,
    uint256 expected2,
    uint256 current
  );
  error WrongMaxDepositPerUser(uint256 max, uint256 amountWanted);
  error WrongSaleTimeStamps();
  error WrongStep(uint8 currentStep);
  error WrongTreasury(address treasury);
  error InmpossibleInterest(int256 interest);

  event PriceUpdated(uint256 oldPrice, uint256 newPrice);
  event CapitalCollected(uint256 amount);
  event CapitalLoss(
    uint256 originalCapital,
    uint256 remainingCapital,
    uint256 loss
  );
  event CapitalRefunded(uint256 amount);
  event Initialized(uint8 version);
  event InterestRefunded(uint256 expected, uint256 refunded);
  event InterestUpdated(address from, int256 interest);
  event Paused(address account);
  event TimesUpdated(uint256[2]);
  event TotalRefunded(address from, uint256 amount);
  event TreasuryUpdated(address oldTreasury, address newTreasury);
  event UnclaimedFundsCollected(uint256 amount);
  event Unpaused(address account);

  function DEV() external view returns (bytes32);

  function KONKRETE() external view returns (bytes32);

  function TIMELOCK() external view returns (bytes32);

  function TREASURY() external view returns (bytes32);

  function tokenPrice() external view returns (uint256);

  function collectCapital() external returns (uint256);

  function collectUnclaimedFunds() external returns (uint256);

  function collectedCapital() external view returns (uint256);

  function dataBase() external view returns (address);

  function decimals() external view returns (uint8);

  function depositsStart() external view returns (uint256);

  function depositsStop() external view returns (uint256);

  function getStep() external view returns (uint8 step);

  function hardCap() external view returns (uint256);

  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    string memory vaultURI_,
    address multisig,
    address dataBase_,
    uint256 softCap_,
    uint256 hardCap_,
    uint256 depositsStart_,
    uint256 depositsStop_
  ) external;

  function maxDepositPerUser() external view returns (uint256);

  function minInvest(address) external view returns (uint256);

  function minMint() external view returns (uint256);

  function originalPrice() external view returns (uint256);

  function pause() external;

  function paused() external view returns (bool);

  function priceImpact(
    uint256 amountOfInterest
  ) external view returns (uint256);

  function refundCapital(uint capital_) external;

  function refunded() external view returns (bool);

  function setCaps(uint256 soft, uint256 hard) external;

  function setDatabase(address database_) external;

  function setDepositLimitsPerUser(
    uint256 minDeposit_,
    uint maxDeposit_
  ) external;

  function setTimes(uint256 start, uint256 stop) external;

  function setTreasury(address treasury_) external;

  function setVaultURI(string calldata vaultURI_) external;

  function softCap() external view returns (uint256);

  function treasury() external view returns (address);

  function unpause() external;

  function updateInterest(int256 interest) external;

  function vaultURI() external view returns (string calldata);
}
