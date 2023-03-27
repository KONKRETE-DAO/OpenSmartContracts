pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "./TestVault.sol";
import "../../contracts/KonkreteVaultV2.sol";
import "../../contracts/interface/IVaultWithInterest.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestUpdate is ContractTest {
    /**
     * @notice
     * @param multiplierx100_ interest ( -100% min or  +500% max)
     * @param amounts amounts minted per user ( > 2**26 is too much in the case of usdc)
     * @param softCapMultiplier if softCapMultiplier < 10  goToWithdrawAfterFail , to check if withdrawing in sale failed are ok
     */
    function testMultiPleProcessUpgrade(int16 multiplierx100_, uint64 amounts, uint8 softCapMultiplier, bool testBool)
        public
    {
        address v2Interface = address(new KonkreteVaultV2());
        adminProxy.upgrade(vaultRaw, address(v2Interface));
        IVaultWithInterest v2 = IVaultWithInterest(address(vaultRaw));
        require(v2.totalSupply() == 0, "Ts error ");
        require(v2.depositsStart() == StartDate, "Date  error ");
        int256 multiplierx100 = int256(multiplierx100_);
        if (amounts < stableMantissa) amounts += uint64(stableMantissa);
        if (multiplierx100 > 200) multiplierx100 %= 200;
        vm.assume(multiplierx100 >= -100);
        softCap = softCapMultiplier / 10 > 0 ? uint256(amounts) * 2 : uint256(amounts) * 3;
        v2.setCaps(softCap, MAX);
        multipleInvestments(v2, amounts);
        console.logUint(v2.tokenPrice());

        vm.warp(StopDate);
        if (v2.getStep() == 3) {
            withdrawAfterFail(v2);
        } else if (multiplierx100 > 1 && testBool) {
            withdrawRollerCoaster(v2, uint256(multiplierx100), uint256(amounts));
        } else {
            interestRollerCoaster(v2, multiplierx100, uint256(amounts));
        }
    }

    function testSimpleMintAndDepositSofCapx2(IVaultWithInterest v2) internal {
        vm.warp(StartDate);
        vm.prank(addr[0]);
        v2.mint(softCap, addr[0]);
        vm.prank(addr[1]);
        v2.deposit(softCap, addr[1]);

        require(usdc.balanceOf(addr[0]) == 0, "Wrong usdc Minter Balance");
        require(usdc.balanceOf(addr[1]) == 0, "Wrong usdc Depositer Balance");
        require(v2.balanceOf(addr[0]) == softCap, "Wrong v Minter Balance");
        require(v2.balanceOf(addr[1]) == softCap, "Wrong v Depositer Balance");
        uint256 vaultBal = usdc.balanceOf(address(v2));
        require(vaultBal == v2.collectedCapital() && vaultBal == softCap + softCap, "WrongCollectedCapital");
    }

    function withdrawRollerCoaster(IVaultWithInterest v2, uint256 multiplierx100, uint256 amountsMintedAtTheFirstStep)
        internal
    {
        require(v2.balanceOf(addr[BANK]) == 0, "Bankbal not empty");

        vm.prank(addr[BANK]);
        uint256 collectedCapital = v2.collectCapital();

        uint256 interest = (collectedCapital * multiplierx100) / 100;
        bool gainOrLoss = interest < 0;
        uint256 bankBalBefore = usdc.balanceOf(addr[BANK]);

        usdc.mint(addr[BANK], interest > type(uint128).max ? interest / 2 : interest);
        if (interest < 2) return;
        vm.prank(addr[BANK]);
        v2.refundInterest(uint256(interest / 2));

        require(
            v2.tokenPrice() == v2.priceImpact(collectedCapital + interest / 2),
            "Token price unexpected after 1 refund interest"
        );
        uint256 maxWithdraw1 = v2.maxWithdraw(addr[1]);
        console.log("Balance addr[1] token %d", v2.balanceOf(addr[1]));
        bool balVaultSuperriorMaxTotal = usdc.balanceOf(address(v2)) > maxWithdraw1;
        console.log(v2.convertToShares(v2.maxWithdraw(addr[1])));
        console.log(v2.maxRedeem(addr[1]));
        console.log(v2.previewWithdraw(maxWithdraw1));
        console.log(v2.maxRedeem(addr[1]));
        vm.prank(addr[1]);
        v2.withdraw(maxWithdraw1, addr[1], addr[1]);
        if (!balVaultSuperriorMaxTotal) {
            require(usdc.balanceOf(address(v2)) == 0, "Balance not emptied");
        } else {
            require(v2.balanceOf(addr[1]) == 0, "Balance not emptied");
        }
        vm.prank(addr[BANK]);
        v2.refundCapitalAndInterest(collectedCapital, uint256(interest / 2));

        maxWithdraw1 = v2.maxWithdraw(addr[1]);
        uint256 maxRedeem0 = v2.maxRedeem(addr[0]);
        uint256 maxWithdraw0 = v2.maxWithdraw(addr[0]);
        require(maxWithdraw0 > maxWithdraw1, "Error max withdraw");
        require(maxWithdraw0 > maxRedeem0, "Error max withdraw/reddem ratio");
        vm.prank(addr[1]);
        v2.withdraw(maxWithdraw1, addr[1], addr[1]);
        vm.prank(addr[0]);
        v2.withdraw(maxWithdraw0, addr[0], addr[0]);

        require(usdc.balanceOf(addr[1]) < usdc.balanceOf(addr[0]), "Early withdrawer have more money than keepr");
        require(v2.balanceOf(addr[1]) < 2 && v2.balanceOf(addr[0]) < 2, "Not withdrawn all");
        console.log("%d", usdc.balanceOf(addr[0]) - usdc.balanceOf(addr[1]));
        require(v2.totalSupply() < 2, "supply not emptied");
        require(
            usdc.balanceOf(address(v2)) < (collectedCapital + interest) / 1e5, //less than 0.01 % is retained in the vault
            "Vault not emptied"
        );
    }

    function multipleInvestments(IVaultWithInterest v2, uint128 amounts) internal {
        vm.warp(StartDate);

        v2.setDepositLimitsPerUser(1, softCap);
        vm.prank(addr[0]);
        v2.mint(amounts, addr[0]);
        vm.prank(addr[1]);
        v2.deposit(amounts, addr[1]);
    }

    function interestRollerCoaster(IVaultWithInterest v2, int256 multiplierx100, uint256 amountsMintedAtTheFirstStep)
        internal
    {
        require(v2.balanceOf(addr[BANK]) == 0, "Bankbal not empty");
        vm.prank(addr[BANK]);
        int256 collectedCapital = int256(v2.collectCapital());

        bool multiplierEqual0 = int256(multiplierx100) == int256(0);
        bool collectedEqual0 = collectedCapital == int256(0);

        int256 interest;
        if ((!multiplierEqual0 && !collectedEqual0)) {
            interest = ((collectedCapital * int256(multiplierx100)) / int256(100));
        }
        bool gainOrLoss = interest < 0;
        // console.log(interest);
        uint256 bankBalBefore = usdc.balanceOf(addr[BANK]);
        require(bankBalBefore == uint256(collectedCapital), " diff between bank ball and collected capital");
        if (interest < 0) {
            require(bankBalBefore - uint256(-interest) >= 0, "Error number");
            usdc.burn(addr[BANK], uint256(-interest));
        } else if (interest > 0) {
            usdc.mint(addr[BANK], uint256(interest));
        }
        uint256 bankBal = usdc.balanceOf(addr[BANK]);
        console.log(bankBal);

        if (bankBal == 0) {
            console.log("Empty capital back");
            vm.prank(addr[MSIG]);
            v2.emptyCapitalBack(true);
            console.log("Empty capital back end");
        } else if (interest > 0) {
            console.log("Interest > 0");
            vm.prank(addr[BANK]);
            v2.refundCapitalAndInterest(bankBalBefore, uint256(interest));
            console.log("Interest > 0 end");
        } else {
            console.log("Loss of interst");
            vm.prank(addr[BANK]);
            v2.refundCapitalAndInterest(bankBal, 0);
            console.log("Loss of interst end");
        }

        require(usdc.balanceOf(address(vault)) == bankBal, " Wrong vault balance");
        uint256 tokenPrice = v2.tokenPrice();
        require(tokenPrice == v2.priceImpact(bankBal), "Price is not equal to priceImpact");
        uint256 expectedPrice =
            uint256(int256(stableMantissa) + int256(((int256(stableMantissa) * multiplierx100) / int256(100))));
        console.log("TokenPrice %d", tokenPrice);
        console.log("ExpectedPrice %d", expectedPrice);

        require(acceptableInterval(tokenPrice, expectedPrice), "Price has not risen correctly");

        // uint256 usdcUserBalanceBefore = usdc.balanceOf(addr[0]);
        uint256 maxWithdraw = v2.maxWithdraw(addr[1]);
        uint256 maxRedeem = v2.maxRedeem(addr[0]);
        require(maxRedeem == amountsMintedAtTheFirstStep, "Max redeem not corresponding to amount");
        vm.prank(addr[0]);
        v2.redeem(amountsMintedAtTheFirstStep, addr[0], addr[0]);
        vm.prank(addr[1]);
        v2.withdraw(maxWithdraw, addr[1], addr[1]);
        uint256 stableBalAddr0Final = usdc.balanceOf(addr[0]);
        uint256 stableBalAddr1Final = usdc.balanceOf(addr[1]);

        require(acceptableInterval(stableBalAddr0Final, stableBalAddr1Final), "Price has not risen correctly");
    }

    function withdrawAfterFail(IVaultWithInterest v2) internal {
        uint256 maxRedeem0 = v2.maxRedeem(addr[0]);
        uint256 maxWithdraw1 = v2.maxWithdraw(addr[1]);
        require(maxRedeem0 == maxWithdraw1, "Redeem and withdraw are different");
        vm.prank(addr[0]);
        v2.redeem(maxRedeem0, addr[0], addr[0]);
        vm.prank(addr[1]);
        v2.withdraw(maxWithdraw1, addr[1], addr[1]);

        require(usdc.balanceOf(addr[1]) == amountMintedFirst);
        require(usdc.balanceOf(addr[0]) == amountMintedFirst);
        require(usdc.balanceOf(address(vault)) == 0);
    }
}
