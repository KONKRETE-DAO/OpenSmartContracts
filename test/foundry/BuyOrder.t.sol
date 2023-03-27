// // SPDX-License-Identifier: UNLICENSED
// pragma solidity ^0.8.13;

// import "./Contract.t.sol";

// contract BuyOrderTest is ContractTest {
//   function testOTCBuyOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     console.log(block.chainid);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 1000) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     /// Begin
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     ///SELLLER
//     vm.startPrank(addr1);
//     dollar.approve(address(orderPlatform), max);
//     dollar.mint(addr1, price);
//     require(dollar.balanceOf(addr1) == price, "Buy ft error");
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     orderPlatform.initBuyOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price
//     );
//     require(dollar.balanceOf(addr1) == 0, "Buy Order ft error");
//     require(
//       dollar.balanceOf(address(orderPlatform)) == price,
//       "Sell Order ft error"
//     );
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, firstPrice);
//     dollar.approve(address(retToken), firstPrice);
//     retToken.buy(addr2, firstPrice);
//     require(retToken.balanceOf(addr2) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr2,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       2
//     );
//     // retToken.approve(address(orderPlatform), firstPrice);
//     (
//       ,
//       ,
//       uint64 indexr,
//       ,
//       ,
//       address buyerr,
//       uint256 feer,
//       uint256 pricer,
//       uint256 tokenAmountr,

//     ) = orderPlatform.buyOrderByToken(address(retToken), 0);
//     require(tokenAmountr == tokenAmount, "Amount err");
//     require(indexr == 0, "Index err");
//     console.log(addr1);
//     console.log(buyerr);
//     require(buyerr == addr1, "Buyer problem");
//     require(pricer == price, "Buyer problem");
//     if (fee > 0) require(feer == (price * fee) / 1000, "fee problems");
//     orderPlatform.sell(address(retToken), uint64(0), max, v, r, s);
//     vm.stopPrank();
//     // CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }

//   function testFailOTCCancelBuyOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     console.log(block.chainid);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 1000) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     /// Begin
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     ///SELLLER
//     vm.startPrank(addr1);
//     dollar.approve(address(orderPlatform), max);
//     dollar.mint(addr1, price);
//     require(dollar.balanceOf(addr1) == price, "Buy ft error");
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     orderPlatform.initBuyOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price
//     );
//     require(dollar.balanceOf(addr1) == 0, "Buy Order ft error");
//     require(
//       dollar.balanceOf(address(orderPlatform)) == price,
//       "Sell Order ft error"
//     );
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, firstPrice);
//     dollar.approve(address(retToken), firstPrice);
//     retToken.buy(addr2, firstPrice);
//     require(retToken.balanceOf(addr2) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr2,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       2
//     );
//     // retToken.approve(address(orderPlatform), firstPrice);
//     (
//       ,
//       ,
//       uint64 indexr,
//       ,
//       ,
//       address buyerr,
//       uint256 feer,
//       uint256 pricer,
//       uint256 tokenAmountr,

//     ) = orderPlatform.buyOrderByToken(address(retToken), 0);
//     orderPlatform.cancelOrder(address(retToken), false, 0);
//     require(tokenAmountr == tokenAmount, "Amount err");
//     require(indexr == 0, "Index err");
//     console.log(addr1);
//     console.log(buyerr);
//     require(buyerr == addr1, "Buyer problem");
//     require(pricer == price, "Buyer problem");
//     if (fee > 0) require(feer == (price * fee) / 1000, "fee problems");
//     orderPlatform.sell(address(retToken), uint64(0), max, v, r, s);
//     vm.stopPrank();
//     // CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }

//   function testFailOTCWrongTokenBuyOrder(
//     uint256 firstPrice,
//     uint256 price,
//     uint16 fee
//   ) public {
//     retToken.setStep(1);
//     retToken.setCexRatio(10000);
//     console.log(block.chainid);
//     vm.assume(fee < 1000);
//     vm.assume(firstPrice / 10 < (retToken.MAX_SUPPLY() / 1000) * 30);
//     vm.assume(firstPrice > 1000);
//     vm.assume(price > 1000);
//     vm.assume(price < max / 1000);
//     /// Begin
//     OTC orderPlatform = new OTC(address(dollar), feePot, fee);
//     orderPlatform.addToken(retToken);
//     assert(orderPlatform.isToken(retToken));
//     orderPlatform.addToken(otherToken);
//     ///SELLLER
//     vm.startPrank(addr1);
//     dollar.approve(address(orderPlatform), max);
//     dollar.mint(addr1, price);
//     require(dollar.balanceOf(addr1) == price, "Buy ft error");
//     uint256 tokenAmount = firstPrice / retToken.TOKEN_PRICE();
//     orderPlatform.initBuyOrder(
//       address(retToken),
//       address(dollar),
//       tokenAmount,
//       price
//     );
//     require(dollar.balanceOf(addr1) == 0, "Buy Order ft error");
//     require(
//       dollar.balanceOf(address(orderPlatform)) == price,
//       "Sell Order ft error"
//     );
//     vm.stopPrank();
//     //BUYER
//     vm.startPrank(addr2);
//     dollar.mint(addr2, firstPrice);
//     dollar.approve(address(retToken), firstPrice);
//     retToken.buy(addr2, firstPrice);
//     require(retToken.balanceOf(addr2) == tokenAmount, "Buy ft error");
//     (uint8 v, bytes32 r, bytes32 s) = ContractTest.getVRS(
//       address(retToken),
//       addr2,
//       address(orderPlatform),
//       tokenAmount,
//       max,
//       2
//     );
//     // retToken.approve(address(orderPlatform), firstPrice);
//     (
//       ,
//       ,
//       uint64 indexr,
//       ,
//       ,
//       address buyerr,
//       uint256 feer,
//       uint256 pricer,
//       uint256 tokenAmountr,

//     ) = orderPlatform.buyOrderByToken(address(retToken), 0);
//     require(tokenAmountr == tokenAmount, "Amount err");
//     require(indexr == 0, "Index err");
//     console.log(addr1);
//     console.log(buyerr);
//     require(buyerr == addr1, "Buyer problem");
//     require(pricer == price, "Buyer problem");
//     if (fee > 0) require(feer == (price * fee) / 1000, "fee problems");
//     orderPlatform.sell(address(otherToken), uint64(0), max, v, r, s);
//     vm.stopPrank();
//     // CONTRACT
//     orderPlatform.withdrawFee(address(dollar));
//     require(((price * fee) / 1000) == dollar.balanceOf(feePot), "FeeProblem");
//   }
// }
