pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract KonVaulSimpleTest is ContractTest {
  /**@notice
   *@param multiplierx100_ interest ( -100% min or  +500% max)
   *@param amounts amounts minted per user ( > 2**26 is too much in the case of usdc)
   *@param softCapMultiplier if softCapMultiplier < 10  goToWithdrawAfterFail , to check if withdrawing in sale failed are ok
   */
  function testMultiPleProcess(
    int16 multiplierx100_,
    uint64 amounts,
    uint8 softCapMultiplier
  ) public {
    int256 multiplierx100 = int256(multiplierx100_);
    if (amounts < stableMantissa) amounts += uint64(stableMantissa);
    if (multiplierx100 > 200) multiplierx100 %= 200;
    vm.assume(multiplierx100 >= -100);
    softCap = softCapMultiplier / 10 > 0
      ? uint256(amounts) * 2
      : uint256(amounts) * 3;
    vault.setCaps(softCap, MAX);
    multipleInvestments(amounts);
    console.logUint(vault.tokenPrice());

    vm.warp(StopDate);
    if (vault.getStep() == 3) withdrawAfterFail();
    else interestRollerCoaster(multiplierx100, uint256(amounts));
  }

  function testSimpleMintAndDepositSofCapx2() internal {
    vm.warp(StartDate);
    vm.prank(addr[0]);
    vault.mint(softCap, addr[0]);
    vm.prank(addr[1]);
    vault.deposit(softCap, addr[1]);

    require(usdc.balanceOf(addr[0]) == 0, "Wrong usdc Minter Balance");
    require(usdc.balanceOf(addr[1]) == 0, "Wrong usdc Depositer Balance");
    require(vault.balanceOf(addr[0]) == softCap, "Wrong v Minter Balance");
    require(vault.balanceOf(addr[1]) == softCap, "Wrong v Depositer Balance");
    uint256 vaultBal = usdc.balanceOf(address(vault));
    require(
      vaultBal == vault.collectedCapital() && vaultBal == softCap + softCap,
      "WrongCollectedCapital"
    );
  }

  function testInterestUpdate() internal {
    goToSaleWithOneWallet();
    vault.updateInterest(int256(softCap));
    require(
      vault.tokenPrice() / 2 == vault.originalPrice(),
      " WrongPriceRaise"
    );
    vault.updateInterest(-int256(softCap));
    require(vault.tokenPrice() == vault.originalPrice(), " WrongPriceLoss");
  }

  function multipleInvestments(uint128 amounts) internal {
    vm.warp(StartDate);

    vault.setDepositLimitsPerUser(1, softCap);
    vm.prank(addr[0]);
    vault.mint(amounts, addr[0]);
    vm.prank(addr[1]);
    vault.deposit(amounts, addr[1]);
  }

  function interestRollerCoaster(
    int256 multiplierx100,
    uint256 amountsMintedAtTheFirstStep
  ) internal {
    vm.prank(addr[BANK]);
    int256 collectedCapital = int256(vault.collectCapital());

    bool multiplierEqual0 = int256(multiplierx100) == int256(0);
    bool collectedEqual0 = collectedCapital == int256(0);

    int256 interest;
    if ((!multiplierEqual0 && !collectedEqual0))
      interest = ((collectedCapital * int256(multiplierx100)) / int256(100));

    // console.log(interest);
    uint256 bankBalBefore = usdc.balanceOf(addr[BANK]);
    if (interest < 0) {
      require(bankBalBefore - uint256(-interest) >= 0, "Error number");
      usdc.burn(addr[BANK], uint256(-interest));
    } else if (interest > 0) {
      usdc.mint(addr[BANK], uint256(interest));
    }
    uint256 bankBal = usdc.balanceOf(addr[BANK]);
    console.log(bankBal);
    vm.prank(addr[BANK]);
    vault.refundCapital((bankBal));
    require(usdc.balanceOf(address(vault)) == bankBal, " Wrong vault balance");
    uint256 tokenPrice = vault.tokenPrice();
    require(
      tokenPrice == vault.priceImpact(bankBal),
      "Price is not equal to priceImpact"
    );
    uint256 expectedPrice = uint256(
      int256(stableMantissa) +
        int256(((int256(stableMantissa) * multiplierx100) / int256(100)))
    );
    console.log("TokenPrice %d", tokenPrice);
    console.log("ExpectedPrice %d", expectedPrice);

    require(
      acceptableInterval(tokenPrice, expectedPrice),
      "Price has not risen correctly"
    );

    // uint256 usdcUserBalanceBefore = usdc.balanceOf(addr[0]);
    uint256 maxWithdraw = vault.maxWithdraw(addr[1]);
    uint256 maxRedeem = vault.maxRedeem(addr[0]);
    require(
      maxRedeem == amountsMintedAtTheFirstStep,
      "Max redeem not corresponding to amount"
    );
    vm.prank(addr[0]);
    vault.redeem(amountsMintedAtTheFirstStep, addr[0], addr[0]);
    vm.prank(addr[1]);
    vault.withdraw(maxWithdraw, addr[1], addr[1]);
    uint256 stableBalAddr0Final = usdc.balanceOf(addr[0]);
    uint256 stableBalAddr1Final = usdc.balanceOf(addr[1]);

    require(
      acceptableInterval(stableBalAddr0Final, stableBalAddr1Final),
      "Price has not risen correctly"
    );
  }

  function withdrawAfterFail() internal {
    uint256 maxRedeem0 = vault.maxRedeem(addr[0]);
    uint256 maxWithdraw1 = vault.maxWithdraw(addr[1]);
    require(maxRedeem0 == maxWithdraw1, "Redeem and withdraw are different");
    vm.prank(addr[0]);
    vault.redeem(maxRedeem0, addr[0], addr[0]);
    vm.prank(addr[1]);
    vault.withdraw(maxWithdraw1, addr[1], addr[1]);

    require(usdc.balanceOf(addr[1]) == amountMintedFirst);
    require(usdc.balanceOf(addr[0]) == amountMintedFirst);
    require(usdc.balanceOf(address(vault)) == 0);
  }
}
