pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KYCTest is ContractTest {
    // uint16 countryCode = 33;
    // uint64 deadline = StartDate - 1;
    // function testSignedDatabase() public {
    //   useSigForSigTest(countryCode, deadline);
    // }
    // function testSignedDatabaseWithPrank() public {
    //   address sigTest = vm.addr(7);
    //   vm.startPrank(sigTest);
    //   useSigForSigTest(countryCode, deadline);
    //   vm.stopPrank();
    // }
    // function testFailPostDl() public {
    //   vm.warp(StartDate);
    //   useSigForSigTest(countryCode, deadline);
    // }
    // function testFailCannotBuyBlacklist() public {
    //   useSigForSigTest(db.BLACKLIST(), deadline);
    // }
    // function testFailChangedCountryAuth() public {
    //   db.changeCountryAuthorisation(countryCode, false);
    //   useSigForSigTest(countryCode, deadline);
    // }
    // /**
    //  * Basic function
    //  */
    // function useSigForSigTest(uint16 countryCode_, uint64 deadline_) public {
    //   // address sigTest = vm.addr(7);
    //   // bytes32 hash_ = keccak256(
    //   //   abi.encodePacked(
    //   //     sigTest,
    //   //     countryCode_,
    //   //     deadline_,
    //   //     address(db),
    //   //     db.nonce(sigTest),
    //   //     block.chainid
    //   //   )
    //   // );
    //   // (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PKEY, hash_);
    //   // db.addKyc(sigTest, countryCode_, deadline_, r, s, v);
    //   // require(db.countryCode(sigTest) == countryCode_, "Wrong CountriCode");
    //   // require(db.canBuy(sigTest), " Cannot buy");
    // }
    // function keccakDatabase(
    //   address toDatabase,
    //   uint16 countryCode_,
    //   uint64 deadline_,
    //   address to
    // ) public view returns (bytes32 hash_) {
    //   hash_ = keccak256(
    //     abi.encodePacked(
    //       toDatabase,
    //       countryCode_,
    //       deadline_,
    //       address(db),
    //       db.nonce(to),
    //       block.chainid
    //     )
    //   );
    // }
    // function getSignature(
    //   bytes32 hash_,
    //   uint privateKey
    // ) public returns (uint8 v, bytes32 r, bytes32 s) {
    //   (v, r, s) = vm.sign(privateKey, hash_);
    // }
}
