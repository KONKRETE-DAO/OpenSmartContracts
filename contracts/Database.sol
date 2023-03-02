// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
@title Database is the kyc and whitelist handler of the v1.
* this version is on l2 so we prefered to use mappings instead of less plastic merkle root.
 */
contract Database is AccessControl {
  /**
   *****************************Constants******************************************
   */
  bytes32 public constant KONKRETE = DEFAULT_ADMIN_ROLE;
  bytes32 public constant DEV = keccak256("DEV");
  bytes32 public constant SIGNER = keccak256("SIGNER");
  /** @notice  this unreachable country code is the equivalent of a blacklist */
  uint16 public constant BLACKLIST = type(uint16).max;
  /**
   *****************************Variables******************************************
   */
  bool whitelistActivated = true;

  /**
   *****************************Mappings (it's okay we're on L2)******************************************
   */
  /**
   * @notice Country numeric code from the ISO 3166, if the countrycode = BlackListed, even if user has been whitelisted, he cannot buy
   */
  mapping(address => uint16) public countryCode;
  mapping(address => uint) public nonce;
  /// @notice uint countrycode
  mapping(uint => bool) public cannotBuy;
  mapping(address => bool) public isWhitelisted;

  /**
     *****************************Constructor******************************************
     @param multisig  Konkrete multisig
     */
  constructor(address multisig, address[] memory signers) {
    _grantRole(KONKRETE, multisig);
    _grantRole(DEV, msg.sender);
    _grantRole(SIGNER, msg.sender);
    _setRoleAdmin(SIGNER, DEV);
    uint len = signers.length;
    unchecked {
      for (uint i = 0; i != len; ) {
        _grantRole(SIGNER, signers[i]);
        ++i;
      }
    }

    cannotBuy[0] = true;
    cannotBuy[BLACKLIST] = true;
  }

  /**
   *****************************External functions******************************************
   */
  //Users functions
  function addKycPermit(
    address toKyc,
    uint16 countryCode_,
    uint64 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) external {
    require(block.timestamp < deadline, "Signature has expired");
    uint nonce_ = nonce[toKyc];

    bytes32 hash_ = ECDSA.toEthSignedMessageHash(
      keccak256(
        abi.encodePacked(
          toKyc,
          countryCode_,
          deadline,
          address(this),
          nonce_,
          block.chainid
        )
      )
    );

    require(hasRole(SIGNER, ECDSA.recover(hash_, v, r, s)), "Invalid signer");
    nonce[toKyc] = nonce_ + 1;

    _addKyc(toKyc, countryCode_);
  }

  /**
@dev Need no nonce, if you're blacklisted , can't buy
 */
  function addWhitelistPermit(
    address toWhitelist,
    uint64 deadline,
    bytes32 r,
    bytes32 s,
    uint8 v
  ) external {
    require(block.timestamp < deadline, "Signature has expired");

    bytes32 hash_ = ECDSA.toEthSignedMessageHash(
      keccak256(
        abi.encodePacked(toWhitelist, deadline, address(this), block.chainid)
      )
    );

    require(hasRole(SIGNER, ECDSA.recover(hash_, v, r, s)), "Invalid signer");

    isWhitelisted[toWhitelist] = true;
  }

  /// @dev AccessControlled functions
  function changeCountryCode(
    address customer,
    uint16 countryCode_
  ) external onlyRole(DEV) {
    require(countryCode[customer] > 0, "Not a Kyced address");
    countryCode[customer] = countryCode_;
  }

  function blackList(address toBlackList) external onlyRole(DEV) {
    countryCode[toBlackList] = BLACKLIST;
  }

  function changeCountryAuthorisation(
    uint16 toChange,
    bool canBuy_
  ) external onlyRole(DEV) {
    cannotBuy[toChange] = !canBuy_;
  }

  function addKyc(
    address toKyc,
    uint16 countryCode_
  ) external onlyRole(SIGNER) {
    require(countryCode[toKyc] == 0, "Already kyced");
    _addKyc(toKyc, countryCode_);
  }

  function addKycs(
    address[] calldata toKyc,
    uint16[] calldata countryCodes
  ) external onlyRole(DEV) {
    uint kycLen = toKyc.length;
    require(kycLen > 0, "Empty array");
    require(kycLen == countryCodes.length, "Arrays length doesn't match");
    unchecked {
      for (uint i = 0; i < kycLen; ) {
        _addKyc(toKyc[i], countryCodes[i]);
        ++i;
      }
    }
  }

  function revokeKyc(address toUnKyc) external {
    require(
      hasRole(DEV, _msgSender()) || toUnKyc == _msgSender(),
      "Revoke Kyc: Not Authorized"
    );
    countryCode[toUnKyc] = 0;
  }

  function addWhitelist(address toWhitelist) external onlyRole(SIGNER) {
    _addWhitelist(toWhitelist);
  }

  function addWhitelists(
    address[] calldata toWhitelist
  ) external onlyRole(DEV) {
    uint toWhitelistLen = toWhitelist.length;
    require(toWhitelistLen > 0, "Empty array");
    unchecked {
      for (uint i = 0; i < toWhitelistLen; ) {
        _addWhitelist(toWhitelist[i]);
        ++i;
      }
    }
  }

  function revokeWhitelist(address toUnWhitelist) external onlyRole(DEV) {
    isWhitelisted[toUnWhitelist] = false;
  }

  /**
   *****************************Public functions ******************************************
   */

  // View functions
  function canBuy(address toCheck) public view returns (bool) {
    return
      !cannotBuy[countryCode[toCheck]] &&
      (!whitelistActivated || isWhitelisted[toCheck]);
  }

  function isKyced(address toCheck) public view returns (bool) {
    return countryCode[toCheck] > 0;
  }

  function isDatabase() public pure returns (bool) {
    return true;
  }

  /**
   *****************************Internal Functions******************************************
   */
  function _addKyc(address toKyc, uint16 countryCode_) internal {
    countryCode[toKyc] = countryCode_;
  }

  function _addWhitelist(address toWhitelist) internal {
    isWhitelisted[toWhitelist] = true;
  }
}
