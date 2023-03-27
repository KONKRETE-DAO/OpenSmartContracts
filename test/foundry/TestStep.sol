pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TestSteps is ContractTest {
    function testStep() internal {
        require(SaleStep(vault.getStep()) == SaleStep.PREAUCTION, "PreAuction step error");
        vm.warp(StopDate);
        require(SaleStep(vault.getStep()) == SaleStep.SALE_FAILED, "Sale failed step error");
        vm.warp(StartDate);
        require(SaleStep(vault.getStep()) == SaleStep.SALE, "Sale step error");
        goToSaleWithOneWallet();
        require(SaleStep(vault.getStep()) == SaleStep.SALE_COMPLETE, "Sale complete step error");
        vm.startPrank(addr[BANK]);
        uint256 collected = vault.collectCapital();
        vault.refundCapital((collected));
        require(SaleStep(vault.getStep()) == SaleStep.CAPITAL_REFUNDED, "SaleStep.CAPITAL_REFUNDED error");
    }
}
