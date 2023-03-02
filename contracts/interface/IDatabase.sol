// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/IAccessControl.sol";

interface IDatabase is IAccessControl {
  function BLACKLIST() external view returns (uint16);

  function DEFAULT_ADMIN_ROLE() external view returns (bytes32);

  function DEV() external view returns (bytes32);

  function KONKRETE() external view returns (bytes32);

  function SIGNER() external view returns (bytes32);

  function addKyc(address toKyc, uint16 countryCode_) external;

  function addKycPermit(
    address toKyc,
    uint16 countryCode_,
    uint64 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) external;

  function addKycs(
    address[] memory toKyc,
    uint256[] memory countryCodes
  ) external;

  function addWhitelist(address toWhitelist) external;

  function addWhitelistPermit(
    address toWhitelist,
    uint64 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) external;

  function addWhitelists(address[] memory toWhitelist) external;

  function blackList(address toBlackList) external;

  function canBuy(address toCheck) external view returns (bool);

  function changeCountryAuthorisation(uint16 toChange, bool canBuy_) external;

  function changeCountryCode(address customer, uint16 countryCode_) external;

  function countryCode(address) external view returns (uint16);

  function isDatabase() external pure returns (bool);

  function isKyced(address toCheck) external view returns (bool);

  function nonce(address) external view returns (uint256);

  function renounceRole(bytes32 role, address account) external;

  function revokeKyc(address toUnKyc) external;

  function revokeWhitelist(address toUnWhitelist) external;
}
