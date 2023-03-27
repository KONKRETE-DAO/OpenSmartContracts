pragma solidity ^0.8.13;

import "./Contract.t.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract CheckMantissa is ContractTest {
    function test18Decimals() public {
        ERC20DecimalsMock stable18 = new ERC20DecimalsMock("mock", "mock", 18);

        bytes memory initializing18 = abi.encodeWithSelector(
            IKonkreteVault.initialize.selector,
            address(stable18),
            "KnkreteToken",
            "Kon",
            "ipfs://URI",
            addr[MSIG],
            addr[BANK],
            address(db),
            50_000 * 1e6,
            50_000 * 1e6,
            StartDate,
            StopDate
        );
        IKonkreteVault vault18 = IKonkreteVault(
            address(
                new TransparentUpgradeableProxy(
                    address(vaultInterface),
                    address(adminProxy),
                    initializing18
                )
            )
        );
        require(vault18.decimals() == stable18.decimals(), "Decimals differ");
        require(vault18.originalPrice() == 10 ** stable18.decimals(), "Wrong mantissa/original price");
    }

    function test6Decimals() public {
        ERC20DecimalsMock stable6 = new ERC20DecimalsMock("mock", "mock", 6);

        bytes memory initializing6 = abi.encodeWithSelector(
            IKonkreteVault.initialize.selector,
            address(stable6),
            "KnkreteToken",
            "Kon",
            "ipfs://URI",
            addr[MSIG],
            addr[BANK],
            address(db),
            50_000 * 1e6,
            50_000 * 1e6,
            StartDate,
            StopDate
        );

        IKonkreteVault vault6 = IKonkreteVault(
            address(
                new TransparentUpgradeableProxy(
                    address(vaultInterface),
                    address(adminProxy),
                    initializing6
                )
            )
        );
        require(vault6.decimals() == stable6.decimals(), "Decimals differ");
        require(vault6.originalPrice() == 10 ** stable6.decimals(), "Wrong mantissa/original price");
    }

    function testFailOthersDecimals(uint8 decimals) public {
        if (decimals > 75) decimals %= 70;
        vm.assume(decimals != 18 && decimals != 6);
        ERC20DecimalsMock stable = new ERC20DecimalsMock(
            "mock",
            "mock",
            decimals
        );

        bytes memory initializing_ = abi.encodeWithSelector(
            IKonkreteVault.initialize.selector,
            address(stable),
            "KnkreteToken",
            "Kon",
            "ipfs://URI",
            addr[MSIG],
            address(db),
            50_000 * 1e6,
            50_000 * 1e6,
            StartDate,
            StopDate
        );
        new TransparentUpgradeableProxy(
            address(vaultInterface),
            address(adminProxy),
            initializing_
        );
    }

    function testFailNoDecimalsFunction() public {
        bytes memory initializing_ = abi.encodeWithSelector(
            IKonkreteVault.initialize.selector,
            address(777),
            "KnkreteToken",
            "Kon",
            "ipfs://URI",
            addr[MSIG],
            address(db),
            50_000 * 1e6,
            50_000 * 1e6,
            StartDate,
            StopDate
        );
        new TransparentUpgradeableProxy(
            address(vaultInterface),
            address(adminProxy),
            initializing_
        );
    }
}
