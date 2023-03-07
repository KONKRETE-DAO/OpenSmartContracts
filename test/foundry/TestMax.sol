pragma solidity ^0.8.13;

import "./Contract.t.sol";

contract TestMax is ContractTest {
  function testMaxEmpty() internal view {
    require(vault.maxDeposit(addr[0]) == 0, "maxDeposit error");
    require(vault.maxMint(addr[0]) == 0, "maxMint error");
    require(vault.maxWithdraw(addr[0]) == 0, "maxWithdraw error");
    require(vault.maxRedeem(addr[0]) == 0, "maxRedeem error");
  }

  function testMaxBeforeSale() public view {
    testMaxEmpty();
  }

  function testMaxSaleFailed() public {
    vm.warp(StopDate);
    testMaxEmpty();
  }
}
