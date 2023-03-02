// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./Contract.t.sol";

contract SellOrderTest is ContractTest {}
//   function testOTCsellOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 100) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     ///SELLLER
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     vm.startPrank(addr1);
//     dollar.approve(address(retToken), max);
//     dollar.mint(addr1, firstPrice);
//     retToken.buy(addr1, firstPrice);
//     require(retToken.balanceOf(addr1) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr1,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       1
//     );
//     orderPlatform.initSellOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price,
//       max,
//       v,
//       r,
//       s
//     );
//     require(retToken.balanceOf(addr1) == 0, "Sell Order ft error");
//     require(
//       retToken.balanceOf(address(orderPlatform)) == tokenAmount,
//       "Sell Order ft error"
//     );
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, price);
//     dollar.approve(address(orderPlatform), max);
//     orderPlatform.buy(address(retToken), 0);
//     vm.stopPrank();
//     //CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     console.log(uint64(block.chainid));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }

//   function testFailOTCCancelsellOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     console.log(otherToken.isKonkreteCompatible());
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 100) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     ///SELLLER
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     vm.startPrank(addr1);
//     dollar.approve(address(retToken), max);
//     dollar.mint(addr1, firstPrice);
//     retToken.buy(addr1, firstPrice);
//     require(retToken.balanceOf(addr1) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr1,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       1
//     );
//     orderPlatform.initSellOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price,
//       max,
//       v,
//       r,
//       s
//     );
//     require(retToken.balanceOf(addr1) == 0, "Sell Order ft error");
//     require(
//       retToken.balanceOf(address(orderPlatform)) == tokenAmount,
//       "Sell Order ft error"
//     );
//     orderPlatform.cancelOrder(address(retToken), true, 0);
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, price);
//     dollar.approve(address(orderPlatform), max);
//     orderPlatform.buy(address(retToken), 0);
//     vm.stopPrank();
//     //CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     console.log(uint64(block.chainid));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }

//   function testFailWrongTokenOTCsellOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 100) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     ///SELLLER
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     orderPlatform.addToken(otherToken);
//     vm.startPrank(addr1);
//     dollar.approve(address(retToken), max);
//     dollar.mint(addr1, firstPrice);
//     retToken.buy(addr1, firstPrice);
//     require(retToken.balanceOf(addr1) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr1,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       1
//     );
//     orderPlatform.initSellOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price,
//       max,
//       v,
//       r,
//       s
//     );
//     require(retToken.balanceOf(addr1) == 0, "Sell Order ft error");
//     require(
//       retToken.balanceOf(address(orderPlatform)) == tokenAmount,
//       "Sell Order ft error"
//     );
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, price);
//     dollar.approve(address(orderPlatform), max);
//     orderPlatform.buy(address(otherToken), 0);
//     vm.stopPrank();
//     //CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     console.log(uint64(block.chainid));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }
// }
