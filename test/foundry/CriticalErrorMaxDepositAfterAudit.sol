pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "../../contracts/WrongVault.sol";

contract WrongVaultError is ContractTest {
    uint256 constant ATTACKER = 2;
    address public wrongVault_ = address(new WrongVault());
    bytes initializing_ = abi.encodeWithSelector(
        IKonkreteVault.initialize.selector,
        address(usdc),
        "KnkreteToken",
        "Kon",
        "ipfs://URI",
        addr[MSIG],
        addr[BANK],
        address(db),
        10_000 * 1e6,
        10_001 * 1e6,
        0,
        StopDate
    );
    IKonkreteVault public wVault = IKonkreteVault(
        address(
            new TransparentUpgradeableProxy(
                    address(wrongVault_),
                    address(adminProxy),
                    initializing_
                )
        )
    );

    function testFailSaleFailedBecauseOfTokenSent(bool below1) public {
        uint256 halfSoftCap = wVault.softCap() / 2;
        uint256 harCapSoftCapDiffPlus1 = wVault.hardCap() - wVault.softCap() + 1;
        wVault.setDepositLimitsPerUser(0, halfSoftCap);

        vm.prank(addr[ATTACKER]);
        usdc.transfer(address(wVault), harCapSoftCapDiffPlus1);

        vm.startPrank(addr[0]);
        usdc.approve(address(wVault), type(uint256).max);
        wVault.deposit(halfSoftCap, addr[0]);
        vm.stopPrank();
        uint256 reducing = below1 ? 1 : 0;
        //The sale cannot be completed
        vm.startPrank(addr[1]);
        usdc.approve(address(wVault), type(uint256).max);
        wVault.deposit(halfSoftCap - reducing, addr[1]);
        vm.stopPrank();
        require(uint256(wVault.getStep()) == 2, "Sale not complete");
    }

    // function testByPassMaxPerUser() public {
    //     wVault.setDepositLimitsPerUser(0, 10_000 * 1e6);
    //     vm.startPrank(addr[0]);
    //     usdc.approve(address(wVault), type(uint256).max);
    //     wVault.deposit(10_000 * 1e6, addr[0]);
    //     wVault.transfer(addr[1], 10_000 * 1e6);
    //     vm.stopPrank();
    //     vm.startPrank(addr[1]);
    //     usdc.approve(address(wVault), type(uint256).max);
    //     wVault.deposit(10_000 * 1e6, addr[1]);
    //     uint256 addr1Bal = wVault.balanceOf(addr[1]);
    //     /// UnderFlowError
    //     wVault.redeem(addr1Bal, addr[1], addr[1]);

    //     vm.stopPrank();
    // }
}
