// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "./interface/IKonkreteVault.sol";
import "./interface/IDatabase.sol";

/**
@title KonkreteVault is the vault made for the v1.
He's upgradable and pausable in case of emergency/upgrades.
Since the capital and interest are refunded at the end of maturity ,
the price raise is check every time we've got the confirmation of the interest from the investment fund.
After  sale is completed , the funds are locked till refund.
This version is on l2 so we balanced the readability and  gas optimization
 */
contract WrongVault is
  ERC4626Upgradeable,
  AccessControlEnumerableUpgradeable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable
{
  using MathUpgradeable for uint256;
  using MathUpgradeable for int256;
  using SafeERC20 for IERC20;

  /**
   *****************************Constants******************************************
   */
  /**
      @dev AccessControl constants
 */
  bytes32 public constant KONKRETE = DEFAULT_ADMIN_ROLE;
  bytes32 public constant TIMELOCK = keccak256("TIMELOCK");
  bytes32 public constant DEV = keccak256("DEV");

  /**@dev commonMantissa will never changes (considered as immutable), it correspond to 1/1 asset/token 
  It  can be used as originalPrice */
  uint256 private commonMantissa;

  /**
   *****************************Variables******************************************
   */

  /**
  @notice Check if an address is whitelisted and kyced (In a non forbidden country)
  -canBuy -> returns a boolean]
  check {./interface/IDatabase.sol}*/
  IDatabase public dataBase;

  address public treasury;

  bool public refunded;

  uint256 public depositsStart;
  uint256 public depositsStop;

  uint256 public maxDepositPerUser;
  uint256 public minInvestPerUser;

  /// @notice is the minimum amount of assets needed at depositsStop, if not reached , sale failed.
  uint256 public softCap;
  /// @notice Max cap of the vault
  uint256 public hardCap;

  /// @notice Price raises artifically , following the interests, every update from the R.W.A.It's reajusted with the total refund.
  uint256 public tokenPrice; // Its a uint  price with decimals.

  uint256 public collectedCapital;

  string public vaultURI;

  /**
   *****************************Mappings******************************************
   */

  mapping(address => uint256) paid;

  /**
   *****************************Events******************************************
   */
  event TotalRefunded(address from, uint256 amount);
  event InterestUpdated(address from, int256 amount);
  event UnclaimedFundsCollected(uint256 amount);
  event CapitalCollected(uint256 amount);
  event CapitalLoss(
    uint256 originalCapital,
    uint256 remainingCapital,
    uint256 loss
  );
  event InterestRefunded(uint256 refunded);
  event CapitalRefunded(uint256 amount, uint256 collected);

  event TimesUpdated(uint256 depositsStart, uint256 depositsStop);
  event CapsUpdated(uint256 softCap, uint256 hardCap);
  event VaultURIUpdated(string vaultURI_);
  event TreasuryUpdated(address oldTreasury, address newTreasury);
  event PriceUpdated(uint256 oldPrice, uint256 newPrice);
  /**
   *****************************Errors******************************************
   */
  error WrongDecimalNumber(
    uint256 expected1,
    uint256 expected2,
    uint256 current
  );
  error BelowMinimumInvest(uint256 minimum, uint256 amount);

  error WrongSaleTimeStamps();
  error TryToCollectZeroFund();
  error WrongCaps();
  error WrongDatabase();
  error WrongTreasury(address treasury);
  error WrongVaultURI(string vaultURI_);
  error WrongMaxDepositPerUser(uint256 max, uint256 amountWanted);
  error WrongMinDepositPerUser(uint256 maxDeposit, uint256 minInvest);
  error NegativeCapital(int256 capitalAndInterest);
  error InmpossibleInterest(int256 interest);

  error NotExpectedStep(SaleStep expected, SaleStep currentStep);
  error WrongStep(SaleStep currentStep);
  error MsgSenderUnauthorized(address msgSender);
  error ReceiverUnauthorized(address receiver);

  constructor() initializer {}

  /**
     *****************************Constructor (initializer)******************************************
     @dev ERC4626 standard mimic the decimals of the asset related to it.
     In  case of a succeeded decimal call from the assets' contract.
     by checking if decimals are not fancy , we're sure the erc4626 will copy this one.
     That's why we can use commonMantissa.
     @param asset_ asset used to buy tokens
     @param name_ token name
     @param symbol_  token symbol
     @param multisig  Konkrete multisig ,used as Treasur for the moment
     @param dataBase_  Nft checking if msg.sender have made his kyc
     */

  function initialize(
    address asset_,
    string memory name_,
    string memory symbol_,
    string memory vaultURI_,
    address multisig,
    IDatabase dataBase_,
    uint256 softCap_,
    uint256 hardcap_,
    uint256 depositsStart_,
    uint256 depositsStop_
  ) external initializer {
    __Pausable_init();
    __ERC4626_init(IERC20Upgradeable(asset_));
    __ERC20_init(name_, symbol_);
    __ReentrancyGuard_init();

    if (!dataBase_.isDatabase()) revert WrongDatabase();
    uint256 assetDecimals = IERC20MetadataUpgradeable(asset_).decimals();
    if (assetDecimals != 18 && assetDecimals != 6)
      revert WrongDecimalNumber(18, 6, assetDecimals);
    uint256 commonMantissa_ = 10 ** assetDecimals;

    _grantRole(KONKRETE, multisig);
    _grantRole(DEV, multisig);
    _grantRole(DEV, _msgSender());

    vaultURI = vaultURI_;

    softCap = softCap_;
    hardCap = hardcap_;

    depositsStart = depositsStart_;
    depositsStop = depositsStop_;

    treasury = multisig;
    dataBase = dataBase_;

    maxDepositPerUser = softCap / 3;
    minInvestPerUser = 500 * commonMantissa_;

    commonMantissa = tokenPrice = commonMantissa_;
  }

  /**
   *****************************External Functions******************************************
   */
  /** External Write functions
   @notice accessControlled  functions
  /

  /**@dev Check if not address 0 or treasury is a contract (mutlisig , or other)*/
  function setTreasury(address treasury_) external onlyRole(KONKRETE) {
    if (treasury_.code.length == 0) revert WrongTreasury(treasury_);
    emit TreasuryUpdated(treasury, treasury_);

    treasury = treasury_;
  }

  // TIMELOCK functions

  /**@notice Reddeem unclaimed assets after a certain time (seedphrase lost, forgotten, asset sent by mistake etc...) */
  function collectUnclaimedFunds()
    external
    onlyRole(TIMELOCK)
    returns (uint256 pendingFunds)
  {
    pendingFunds = _collect(SaleStep.CAPITAL_REFUNDED);
    emit UnclaimedFundsCollected(pendingFunds);
  }

  // DEV functions
  /** 
@notice  Collect capital 👍
@dev Use balanceOf instead of collectedCapital , for token sent by mistake (or wallet trying inflation attack)
 */
  function collectCapital() external returns (uint256 collected) {
    address treasury_ = treasury;
    if (_msgSender() != treasury_) revert WrongTreasury(_msgSender());
    collected = _collect(SaleStep.SALE_COMPLETE);
    emit CapitalCollected(collected);
  }

  /**
  @notice Refund after maturity, reset price and activate withdraw
  @param capitalAndInterest is the total amount refunded at the end of maturity
 */
  function refundCapital(uint256 capitalAndInterest) external {
    if (_msgSender() != treasury) revert WrongTreasury(_msgSender());
    SaleStep step = getStep();
    if (step != SaleStep.SALE_COMPLETE && step != SaleStep.CAPITAL_REFUNDED)
      revert WrongStep(step);

    uint256 collectedCapital_ = collectedCapital;
    if (collectedCapital_ > 0)
      IERC20(asset()).safeTransferFrom(
        _msgSender(),
        address(this),
        capitalAndInterest
      );

    emit CapitalRefunded(capitalAndInterest, collectedCapital_);

    int256 interest = int256(capitalAndInterest) - int256(collectedCapital_);
    uint256 oldPrice = tokenPrice;

    if (interest < 0) {
      emit CapitalLoss(
        collectedCapital_,
        capitalAndInterest,
        uint256(-interest)
      );
    } else if (interest > 0) {
      emit InterestRefunded(uint256(interest));
    }
    uint256 newPrice = priceImpact(capitalAndInterest);
    tokenPrice = newPrice;
    refunded = true;
    emit PriceUpdated(oldPrice, newPrice);
  }

  /** 
@notice  This function just raise the price artificially with price impact of the theoric raw interest
@dev Use balanceOf instead of collectedCapital , for token sent by mistake (or wallet trying inflation attack)
 */

  function updateInterest(int256 interest) external onlyRole(DEV) {
    SaleStep step = getStep();
    if (step != SaleStep.SALE_COMPLETE) revert WrongStep(step);
    uint256 oldPrice = tokenPrice;
    uint256 newPrice;
    if (interest < 0) {
      uint256 decrement = priceImpact(uint256(-interest));
      if (decrement > oldPrice) revert InmpossibleInterest(interest);
      newPrice = oldPrice - decrement;
      emit InterestUpdated(_msgSender(), interest);
    } else {
      uint256 increment = priceImpact(uint256(interest));
      newPrice = oldPrice + increment;
      emit InterestUpdated(_msgSender(), interest);
    }

    tokenPrice = newPrice;

    emit PriceUpdated(oldPrice, newPrice);
  }

  function setDatabase(IDatabase database_) external onlyRole(DEV) {
    if (!database_.isDatabase()) revert WrongDatabase();
    dataBase = database_;
  }

  function setTimes(uint256 start, uint256 stop) external onlyRole(DEV) {
    SaleStep step = getStep();
    if (uint256(step) > 2) revert WrongStep(step);
    if (start > stop || start < block.timestamp) revert WrongSaleTimeStamps();
    depositsStart = start;
    depositsStop = stop;
    emit TimesUpdated(start, stop);
  }

  function setCaps(uint256 soft, uint256 hard) external onlyRole(DEV) {
    if (soft == 0 || soft > hard) revert WrongCaps();
    softCap = soft;
    hardCap = hard;
    emit CapsUpdated(soft, hard);
  }

  function setDepositLimitsPerUser(
    uint256 minInvest_,
    uint256 maxDeposit_
  ) external onlyRole(DEV) {
    uint256 softCap_ = softCap;
    if (maxDeposit_ > softCap_)
      revert WrongMaxDepositPerUser(softCap_, maxDeposit_);
    if (minInvest_ >= maxDeposit_)
      revert WrongMaxDepositPerUser(softCap_, minInvest_);
    maxDepositPerUser = maxDeposit_;
    minInvestPerUser = minInvest_;
  }

  /** 
@notice  Set vaults' URI  ( vaults information)  👍
@param vaultURI_ require to not be an empty string
 */
  function setVaultURI(string calldata vaultURI_) external onlyRole(KONKRETE) {
    if (bytes(vaultURI_).length == 0) revert WrongVaultURI(vaultURI_);

    emit VaultURIUpdated(vaultURI_);
    vaultURI = vaultURI_;
  }

  function pause() external onlyRole(DEV) {
    _pause();
  }

  function unpause() external onlyRole(KONKRETE) {
    _unpause();
  }

  /**
  @notice Inverse of priceImpact
   */
  function amountImpact(
    uint256 priceRaiseOrLower
  ) external view returns (uint256) {
    return priceRaiseOrLower.mulDiv(totalSupply(), commonMantissa);
  }

  /**
    @notice check the originalPrice */
  function originalPrice() external view returns (uint256) {
    return commonMantissa;
  }

  /**
   *****************************Public Functions******************************************
   */

  //Public Write functions

  /** 
  @notice Deposit amount of @param assets in the vault and mint share to the @param receiver
  @dev See {IERC4626-deposit}. 
  Upgrades :
  -modifiers
  - See {function _invest(uint256 amount,address sender,address receiver,bool isDeposit) internal
  )
  */
  function deposit(
    uint256 assets,
    address receiver
  ) public override nonReentrant whenNotPaused returns (uint256) {
    _invest(assets, _msgSender(), receiver);
    return assets;
  }

  /** 
  @notice Mint amount of @param shares in the vault and ask for the assets in return @param receiver
  @dev See {IERC4626-mint}. 
  Upgrades :
  - Minting is  a mirror deposit function (no freemint or etc...).
  */
  function mint(
    uint256 shares,
    address receiver
  ) public override nonReentrant whenNotPaused returns (uint256) {
    _invest(shares, _msgSender(), receiver);
    return shares;
  }

  /** @notice Withdraw amount of assets when funds are ont the contract
   @dev  See {IERC4626-withdraw}.
   Upgrades : 
   -Checking the sale periode
   -Reduce collected capital if it happens before refund
    */
  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) public override nonReentrant whenNotPaused returns (uint256 shares) {
    SaleStep step = getStep();
    if (uint256(step) == uint256(SaleStep.SALE_COMPLETE))
      revert WrongStep(step);
    shares = previewWithdraw(assets);
    require(shares <= balanceOf(owner), "ERC4626: withdraw more than max");

    _withdraw(_msgSender(), receiver, owner, assets, shares);

    paid[owner] -= assets;
  }

  /** @notice Withdraw asset for a given @param shares (token) amount 
    @dev Mirror function of withdraw
   */
  function redeem(
    uint256 shares,
    address receiver,
    address owner
  ) public override nonReentrant whenNotPaused returns (uint256 assets) {
    SaleStep step = getStep();
    if (uint256(step) == uint256(SaleStep.SALE_COMPLETE))
      revert WrongStep(step);

    require(shares <= balanceOf(owner), "ERC4626: redeem more than max");

    assets = previewRedeem(shares);
    _withdraw(_msgSender(), receiver, owner, assets, shares);

    paid[owner] -= assets;
  }

  //Public View functions
  function minInvest(address user) public view returns (uint256) {
    uint256 userPaid = paid[user];
    uint256 minInvestPerUser_ = minInvestPerUser;

    return userPaid >= minInvestPerUser_ ? 0 : minInvestPerUser_ - userPaid;
  }

  /** 
  @notice Return the maximum asset Deposit that @param user can do. 
  @dev See {IERC4626-maxDeposit}.
  Upgrades:
  =If he's not authorized return zero ,see the EIPs' standard) */
  function maxDeposit(address user) public view override returns (uint256) {
    return getStep() != SaleStep.SALE ? 0 : _maxDeposit(user);
  }

  /** 
  @notice Return the maximum shares Mint that @param user can do. 
  @dev Same changes as maxDeposit
  */
  function maxMint(address user) public view override returns (uint256) {
    return getStep() != SaleStep.SALE ? 0 : _maxDeposit(user);
  }

  /** 
  @notice Return the maximum shares Redeem that @param user can do. 
  @dev Same changes as maxDeposit
  */
  function maxRedeem(address owner) public view override returns (uint256) {
    return getStep() == SaleStep.SALE_COMPLETE ? 0 : balanceOf(owner);
  }

  /** 
  @notice Return the maximum asset Withdraw that @param user can do. 
  @dev Same changes as maxDeposit
  */
  function maxWithdraw(address owner) public view override returns (uint256) {
    return
      getStep() == SaleStep.SALE_COMPLETE
        ? 0
        : _convertToAssets(balanceOf(owner), MathUpgradeable.Rounding.Down);
  }

  /** 
  @notice Check the vault's period
  @return step  {see ./interface/IKonkreteVault.sol}
 */
  function getStep() public view returns (SaleStep step) {
    if (block.timestamp < depositsStart) return SaleStep.PREAUCTION;
    if (block.timestamp < depositsStop) return SaleStep.SALE;
    if (collectedCapital < softCap) return SaleStep.SALE_FAILED;
    return refunded ? SaleStep.CAPITAL_REFUNDED : SaleStep.SALE_COMPLETE;
  }

  /**@notice Check the absolute impact on the token's price of an @param amountOfInterest
   * @dev  We multiplied by  the token mantissa before to have a real impact and not relative
   * (floating point, which is non existant in solidity)
   */
  function priceImpact(uint256 amountOfInterest) public view returns (uint256) {
    return amountOfInterest.mulDiv(commonMantissa, totalSupply());
  }

  /**
   *****************************Internal Functions******************************************
   */
  /** @notice Common function of mint & deposit
    Because tokenPrice will be equal to commonMantissa till the sale is not completed, functions are pretty the same.
   */
  function _invest(uint256 amount, address sender, address receiver) internal {
    if (!dataBase.canBuy(sender)) revert MsgSenderUnauthorized(sender);

    SaleStep step = getStep();
    if (step != SaleStep.SALE) revert NotExpectedStep(SaleStep.SALE, step);

    require(amount <= _maxDeposit(sender), "ERC4626: deposit more than max");
    uint256 min = minInvest(sender);
    if (amount < min) revert BelowMinimumInvest(min, amount);
    _deposit(sender, receiver, amount, amount);
    collectedCapital += amount;

    paid[sender] += amount;
  }

  /** @notice Common function of collectCapital and collectUnClaimedCapital
    Collect and transfer funds to the treasury
   */
  function _collect(
    SaleStep expectedStep
  ) internal returns (uint256 pendingFunds) {
    SaleStep step = getStep();
    if (step != expectedStep)
      revert NotExpectedStep(SaleStep.CAPITAL_REFUNDED, step);
    IERC20 stable = IERC20(asset());
    pendingFunds = stable.balanceOf(address(this));
    if (pendingFunds == 0) revert TryToCollectZeroFund();
    stable.safeTransfer(treasury, pendingFunds);
  }

  //Internal View functions
  /**
   * @notice Overrides the ERC4626 function check the amount of asset you can get d with a certain amount of share
   * @param shares share = vaultToken amount
   * @param rounding math rounding
   */
  function _convertToAssets(
    uint256 shares,
    MathUpgradeable.Rounding rounding
  ) internal view override returns (uint256 assets) {
    assets = shares > 0
      ? shares.mulDiv(tokenPrice, commonMantissa, rounding)
      : 0;
  }

  /**
   * @notice Same as _convertToAssets but the input and output are reversed
   */

  function _convertToShares(
    uint256 assets,
    MathUpgradeable.Rounding rounding
  ) internal view override returns (uint256 shares) {
    shares = assets > 0
      ? assets.mulDiv(commonMantissa, tokenPrice, rounding)
      : 0;
  }

  /**
   * @notice Internal function to get maxDeposit() without the checks
   * @dev @return  the smallest amount between:
   -capedMax:  the hardcap &  collectedCapitall 's difference
   -userMax:  the maxDepositPerUser &  already paid's difference
    ⚠️This function is only used in deposit phase, the public maxDeposit() return 0 in others⚠️
    We didn't used totalAssets()
     because it doesn't make the difference between assset commited through deposits and sent by mistake)
   */
  function _maxDeposit(address user) internal view returns (uint256) {
    uint256 hardCap_ = hardCap;

    uint256 collectedK_ = collectedCapital;

    uint256 paidByUser = paid[user];
    if (hardCap_ <= collectedK_ || maxDepositPerUser <= paidByUser) return 0;

    uint256 userMax = maxDepositPerUser - paidByUser;
    uint256 capedMax = hardCap_ - collectedK_;

    return userMax > capedMax ? capedMax : userMax;
  }
}
