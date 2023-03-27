// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "../../contracts/ERC20DecimalsMock.sol";
import "../../contracts/KonkreteVault.sol";
import "../../contracts/interface/IKonkreteVault.sol";
import "../../contracts/Database.sol";

uint256 constant PERCENTX100 = 1;
bytes32 constant DEV = keccak256("DEV");
bytes32 constant SIGNER = keccak256("SIGNER");
uint256 constant SIGNER_PKEY = 6;
uint256 constant MSIG = 3;
uint256 constant BANK = 4;
uint256 constant SIG = 5;

contract Treasury is Ownable {
    uint256[25] public slot;

    constructor() {}
}

contract ContractTest is Test {
    function acceptableInterval(uint256 amount, uint256 target) public pure returns (bool) {
        return ((target < PERCENTX100 || amount >= target - PERCENTX100) && amount <= target + PERCENTX100);
    }

    function checkPercentage(uint256 val1, uint256 val2, uint256 mantissa, uint256 expected, bool negative)
        public
        view
        returns (bool)
    {
        if ((val2 > val1 && negative) || (val2 < val1 && !negative)) return false;
        uint256 newMantissa = mantissa / 1e4;
        val1 /= newMantissa;
        val2 /= newMantissa;
        uint256 gap = negative ? val1 - val2 : val2 - val1;
        console.log("Gap", gap);
        return (acceptableInterval(gap, expected));
    }

    uint32 Monday = 1656322810;
    uint32 StartDate = Monday + 1 days;
    uint32 StopDate = Monday + 2 days;
    uint32 Thursday = Monday + 3 days;
    uint32 Friday = Monday + 4 days;
    uint32 Saturday = Monday + 5 days;
    uint32 Sunday = Monday + 6 days;
    Treasury public trez = new Treasury();

    address[6] addr = [vm.addr(1), vm.addr(2), vm.addr(3), vm.addr(4), address(trez), vm.addr(6)];
    address[] sig = [address(this)];
    Database public db = new Database(addr[MSIG], sig);
    uint256 public constant MAX = type(uint256).max;

    ERC20DecimalsMock public usdc = new ERC20DecimalsMock("USDC", "USDC", 6);
    ERC20DecimalsMock public agEur = new ERC20DecimalsMock("Angle Euro", "agEur", 18);

    uint256 public usdcMantissa = 1e6;
    uint256 public agEurMantissa = 1e18;
    // Buyer[] buyers;
    address[] addresses;
    uint256 amountToMintPerUser = 1e4;
    ProxyAdmin public adminProxy = new ProxyAdmin();
    bytes public bytesToSend = new bytes(0);
    KonkreteVault public vaultInterface = new KonkreteVault();
    bytes initializing = abi.encodeWithSelector(
        IKonkreteVault.initialize.selector,
        address(usdc),
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
    TransparentUpgradeableProxy public vaultRaw = new TransparentUpgradeableProxy(
      address(vaultInterface),
      address(adminProxy),
      initializing
    );
    IKonkreteVault vault = IKonkreteVault(address(vaultRaw));
    uint256 stableMantissa;
    uint256 softCap;
    uint256 amountMintedFirst;

    function setUp() public {
        stableMantissa = usdcMantissa;
        uint256 buffer = 0x11111;
        bytes32 store = bytes32(buffer);
        db.grantRole(SIGNER, addr[SIG]);
        db.grantRole(keccak256("SIGNER"), address(this));
        vm.store(addr[BANK], store, bytes32(MAX));

        amountToMintPerUser = 50_000;
        softCap = amountToMintPerUser * stableMantissa;
        amountMintedFirst = type(uint128).max;

        vm.prank(addr[MSIG]);
        vault.setTreasury(addr[BANK]);
        vault.setDepositLimitsPerUser(0, amountToMintPerUser * stableMantissa);
        vm.warp(Monday);

        for (uint256 i = 0; i < 6; i++) {
            vm.startPrank(addr[i]);
            if (i != BANK) {
                usdc.mint(addr[i], amountMintedFirst);
                agEur.mint(addr[i], amountToMintPerUser * agEurMantissa);
            }
            agEur.approve(address(vault), MAX);
            usdc.approve(address(vault), MAX);
            vm.stopPrank();
            db.addWhitelist(addr[i]);
            db.addKyc(addr[i], 33);
        }
    }

    function goToSaleWithOneWallet() internal {
        vm.warp(StartDate);
        vm.prank(addr[0]);
        vault.mint(softCap, addr[0]);

        vm.warp(StopDate);
    }
}
