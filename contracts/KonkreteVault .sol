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
contract KonkreteVaultOld is
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
  bytes32 public constant TREASURY = keccak256("TREASURY");
  bytes32 public constant TIMELOCK = keccak256("TIMELOCK");
  bytes32 public constant DEV = keccak256("DEV");

  /**@dev originalPrice will never changes (considered as immutbale), it correspond to 1/1 asset/token 
  It  can be used as tokenMantissa */
  uint256 public originalPrice;

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
  uint256 public minDepositPerUser;

  /// @notice is the minimum amount of assets needed at depositsStop, if not reached , sale failed.
  uint256 public softCap;
  /// @notice Max cap of the vault
  uint256 public hardCap;

  //// @notice Price raises artifically , following the interests, every update from the R.W.A.It's reajusted with the total refund.
  uint256 public tokenPrice;

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
  event InterestRefunded(uint256 expected, uint256 refunded);
  event CapitalRefunded(uint256 amount, uint256 collected);

  event TimesUpdated(uint256 depositsStart, uint256 depositsStop);
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
  error DecimalOverFlow();

  error WrongSaleTimeStamps();
  error WrongCaps();
  error WrongDatabase();
  error WrongTreasury(address treasury);
  error WrongVaultURI(string vaultURI_);
  error WrongMaxDepositPerUser(uint256 max, uint256 amountWanted);
  error WrongMinDepositPerUser(uint256 maxDeposit, uint256 minDeposit);
  error NegativeCapital(int256 capitalAndInterest);
  error InmpossibleInterest(int256 interest);

  error NotExpectedStep(SaleStep expected, SaleStep currentStep);
  error WrongStep(SaleStep currentStep);
  error MsgSenderUnauthorized(address msgSender);
  error ReceiverUnauthorized(address receiver);

  constructor() initializer {}

  /**
     *****************************Constructor (initializer)******************************************
     @param asset_ asset used to buy tokens
     @param name_ token name
     @param symbol_  token symbol
     @param multisig  Konkrete multisig ,used as Treasur for the moment
     @param dataBase_  Nft checking if msg.sender have made his kyc
     */
  function initialize(
    IERC20Upgradeable asset_,
    string memory name_,
    string memory symbol_,
    string memory vaultURI_,
    address multisig,
    address dataBase_,
    uint256 softCap_,
    uint256 depositsStart_,
    uint256 depositsStop_
  ) external initializer {
    __Pausable_init();
    __ERC4626_init(asset_);
    __ERC20_init(name_, symbol_);
    __ReentrancyGuard_init();
    if (!IDatabase(dataBase_).isDatabase()) revert WrongDatabase();

    (bool success, bytes memory encodedDecimals) = address(asset_).staticcall(
      abi.encodeWithSelector(IERC20MetadataUpgradeable.decimals.selector)
    );

    if (!(success && encodedDecimals.length >= 32)) revert DecimalOverFlow();

    uint256 assetDecimals = abi.decode(encodedDecimals, (uint256));
    if (assetDecimals != 18 && assetDecimals != 6)
      revert WrongDecimalNumber(18, 6, assetDecimals);

    _grantRole(KONKRETE, multisig);
    _grantRole(TREASURY, multisig);
    _grantRole(DEV, multisig);
    _grantRole(DEV, _msgSender());

    softCap = softCap_;
    hardCap = type(uint256).max;
    depositsStart = depositsStart_;
    depositsStop = depositsStop_;
    treasury = multisig;
    originalPrice = tokenPrice = 10 ** assetDecimals;
    dataBase = IDatabase(dataBase_);
    vaultURI = vaultURI_;
    maxDepositPerUser = softCap / 3;
    minDepositPerUser = 500 * (10 ** assetDecimals);
  }

  /**
   *****************************External Functions******************************************
   */
  /** External Write functions
   @notice accessControlled  functions
  /

  /**@dev Check if not address 0 or treasury is a contract (mutlisig , or other)*/
  function setTreasury(address treasury_) external onlyRole(KONKRETE) {
    if (treasury_ == address(0) || treasury_.code.length == 0)
      revert WrongTreasury(treasury_);

    grantRole(TREASURY, treasury_);
    revokeRole(TREASURY, treasury);

    emit TreasuryUpdated(treasury, treasury_);

    treasury = treasury_;
  }

  /**
  @notice Refund after maturity, reset price and activate withdraw
  @param capitalAndInterest is the total amount refunded at the end of maturity
 */
  function refundCapital(
    uint256 capitalAndInterest
  ) external onlyRole(TREASURY) {
    SaleStep step = getStep();
    if (step != SaleStep.SALE_COMPLETE) revert WrongStep(step);

    uint256 collectedCapital_ = collectedCapital;
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
      emit InterestRefunded(
        amountImpact(oldPrice - originalPrice),
        uint256(interest)
      );
    }
    uint256 newPrice = priceImpact(capitalAndInterest);
    tokenPrice = newPrice;
    emit PriceUpdated(oldPrice, newPrice);
    refunded = true;
  }

  // TIMELOCK functions

  /**@notice Reddeem unclaimed assets after a certain time (seedphrase lost, forgotten, asset sent by mistake etc...) */
  function collectUnclaimedFunds()
    external
    onlyRole(TIMELOCK)
    returns (uint256)
  {
    SaleStep step = getStep();
    if (step != SaleStep.CAPITAL_REFUNDED)
      revert NotExpectedStep(SaleStep.CAPITAL_REFUNDED, step);
    IERC20 stable = IERC20(asset());
    uint256 pendingFunds = stable.balanceOf(address(this));
    stable.safeTransfer(treasury, pendingFunds);

    emit UnclaimedFundsCollected(pendingFunds);

    return pendingFunds;
  }

  // DEV functions
  /** 
@notice  Collect capital 👍
@dev Use balanceOf instead of collectedCapital , for token sent by mistake (or wallet trying inflation attack)
 */
  function collectCapital() external onlyRole(TREASURY) returns (uint256) {
    SaleStep step = getStep();

    if (step != SaleStep.SALE_COMPLETE)
      revert NotExpectedStep(SaleStep.SALE_COMPLETE, step);

    IERC20 stable = IERC20(asset());
    uint256 collectedCapital_ = stable.balanceOf(address(this));
    stable.safeTransfer(treasury, collectedCapital_);

    emit CapitalCollected(collectedCapital_);

    return collectedCapital_;
  }

  /** 
@notice  This function just raise the price artificially with price impact of the theoric raw interest
@dev Use balanceOf instead of collectedCapital , for token sent by mistake (or wallet trying inflation attack)
 */

  function updateInterest(int256 interest) external onlyRole(DEV) {
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

  /** 
@notice  Set the database 👍
@dev Use a returning bool function  to check if the contract on address is made for that.
 */
  function setDatabase(address database_) external onlyRole(DEV) {
    if (!IDatabase(database_).isDatabase()) revert WrongDatabase();
    dataBase = IDatabase(database_);
  }

  /** 
@notice  Set times  of the start and the end of the Sale period 👍
@dev Check if start is not 0 and the order's respected
 */
  function setTimes(uint256 start, uint256 stop) external onlyRole(DEV) {
    if (start == 0 || start > stop) revert WrongSaleTimeStamps();
    emit TimesUpdated(start, stop);
    depositsStart = start;
    depositsStop = stop;
  }

  /** 
@notice  Set asset caps  👍
@dev Check if soft is not 0 and the order's respected
 */
  function setCaps(uint256 soft, uint256 hard) external onlyRole(DEV) {
    if (soft == 0 || soft > hard) revert WrongCaps();
    softCap = soft;
    hardCap = hard;
  }

  /** 
@notice  Set users' maximum deposit ( assets)  👍
@param minDeposit_ have to be less than maxDeposit_
@param maxDeposit_ have to be less than softCap
 */
  function setDepositLimitsPerUser(
    uint256 minDeposit_,
    uint256 maxDeposit_
  ) external onlyRole(DEV) {
    uint256 softCap_ = softCap;
    if (maxDeposit_ > softCap_)
      revert WrongMaxDepositPerUser(softCap_, maxDeposit_);
    if (minDeposit_ > minDeposit_)
      revert WrongMaxDepositPerUser(softCap_, minDeposit_);
    maxDepositPerUser = maxDeposit_;
    minDepositPerUser = minDeposit_;
  }

  /** 
@notice  Set vaults' URI  ( vaults information)  👍
@param vaultURI_ require to not be an empty string
 */
  function setVaultURI(string calldata vaultURI_) external onlyRole(KONKRETE) {
    if (bytes32(abi.encodePacked(vaultURI_)) == bytes32(0))
      revert WrongVaultURI(vaultURI_);

    emit VaultURIUpdated(vaultURI_);
    vaultURI = vaultURI_;
  }

  function pause() external onlyRole(DEV) {
    _pause();
  }

  function unpause() external onlyRole(KONKRETE) {
    _unpause();
  }

  /**@notice Just needed for fronts , return the symbole of the asset  */
  function assetSymbol() external view returns (string memory) {
    return IERC20MetadataUpgradeable(asset()).symbol();
  }

  /**
   *****************************Public Functions******************************************
   */

  //Public Write functions

  /** 
  @notice Deposit amount of @param assets in the vault and mint share to the @param receiver
  @dev See {IERC4626-deposit}. 
  Upgrades :
  - Some checks (is msg.sender is authorised and if we're in the sale period)
  - Using internal maxDeposit to avoid to recheck (and reuse getStep()) what is already checked up
  - iterate on mapping paid. 
  */
  function deposit(
    uint256 assets,
    address receiver
  ) public override nonReentrant whenNotPaused returns (uint256 shares) {
    address sender = _msgSender();
    if (!dataBase.canBuy(sender)) revert MsgSenderUnauthorized(sender);

    SaleStep step = getStep();
    if (step != SaleStep.SALE) revert NotExpectedStep(SaleStep.SALE, step);

    require(assets <= _maxDeposit(sender), "ERC4626: deposit more than max");
    require(
      assets >= minDeposit(sender),
      "KonkreteVault: deposit less than min"
    );

    shares = previewDeposit(assets);
    _deposit(sender, receiver, assets, shares);
    collectedCapital += assets;

    paid[sender] += assets;
  }

  /** 
  @notice Mint amount of @param shares in the vault and ask for the assets in return @param receiver
  @dev See {IERC4626-mint}. 
  Upgrades :
  - Minting is now a reverse deposit function (no freemint or etc...).
  - Some checks (is msg.sender is authorised and if we're in the sale period)
  -Using internal maxMint to avoid to recheck (and reuse getStep()) what is already checked up 
  */
  function mint(
    uint256 shares,
    address receiver
  ) public override nonReentrant whenNotPaused returns (uint256 assets) {
    address sender = _msgSender();
    if (!dataBase.canBuy(sender)) revert MsgSenderUnauthorized(sender);

    SaleStep step = getStep();
    if (step != SaleStep.SALE) revert NotExpectedStep(SaleStep.SALE, step);

    require(shares <= _maxMint(receiver), "ERC4626: mint more than max");
    require(shares >= minMint(sender), "KonkreteVault: deposit less than min");

    assets = previewMint(shares);
    collectedCapital += assets;
    _deposit(sender, receiver, assets, shares);

    paid[sender] += assets;
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
    require(
      assets <=
        _convertToAssets(balanceOf(owner), MathUpgradeable.Rounding.Down),
      "ERC4626: withdraw more than max"
    );

    shares = previewWithdraw(assets);
    _withdraw(_msgSender(), receiver, owner, assets, shares);
    if (step != SaleStep.CAPITAL_REFUNDED) collectedCapital -= assets;
  }

  /** @notice Withdraw asset for a given @param shares (token) amount 
  @dev See {IERC4626-redeem}. 
    Upgrades : 
    -Checking the sale periode
    -Reduce collected capital if it happens before refund 
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
    if (step != SaleStep.CAPITAL_REFUNDED) collectedCapital -= assets;
  }

  //Public View functions
  function minDeposit(address user) public view returns (uint256) {
    uint256 userPaid = paid[user];
    uint256 minDepositPerUser_ = minDepositPerUser;
    return userPaid >= minDepositPerUser_ ? 0 : minDepositPerUser_ - userPaid;
  }

  function minMint(address user) public view returns (uint256) {
    return _convertToAssets(minDeposit(user), MathUpgradeable.Rounding.Down);
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
    return getStep() != SaleStep.SALE ? 0 : _maxMint(user);
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
  @dev
  @return enum SaleStep {see ./interface/IKonkreteVault.sol}
 */
  function getStep() public view returns (SaleStep step) {
    if (block.timestamp < depositsStart) return SaleStep.PREAUCTION;
    if (block.timestamp < depositsStop) return SaleStep.SALE;
    if (collectedCapital < softCap) return SaleStep.SALE_FAILED;
    return refunded ? SaleStep.CAPITAL_REFUNDED : SaleStep.SALE_COMPLETE;
  }

  /**@notice Check the absolute impact on the token's price of an @param amountOfInteres
   * @dev  We multiplied by  the token mantissa before to have a real impact and not relative
   * (floating point, which is not existant in solidity)
   */
  function priceImpact(uint256 amountOfInterest) public view returns (uint256) {
    return amountOfInterest.mulDiv(originalPrice, totalSupply());
  }

  /**
  @notice Inverse of priceImpact
   */
  function amountImpact(
    uint256 priceRaiseOrLower
  ) public view returns (uint256) {
    return priceRaiseOrLower.mulDiv(totalSupply(), originalPrice);
  }

  /**
   *****************************Internal Functions******************************************
   */

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
      ? shares.mulDiv(tokenPrice, originalPrice, rounding)
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
      ? assets.mulDiv(originalPrice, tokenPrice, rounding)
      : 0;
  }

  /**

   * @notice Internal function to get maxDeposit() without the checks
   * @dev @return  the smallest amount between:
   -capedMax:  the hardcap & (converted in assets) totalSupply's difference
   -userMax:  the maxDepositPerUser & (converted in assets) already paid's difference
   */
  function _maxDeposit(address user) internal view returns (uint256) {
    uint256 hardCap_ = hardCap;

    uint256 tsInAssets = _convertToAssets(
      totalSupply(),
      MathUpgradeable.Rounding.Down
    );

    uint256 paidByUser = paid[user];
    if (hardCap_ <= tsInAssets || maxDepositPerUser <= paidByUser) return 0;

    uint256 userMax = maxDepositPerUser - paidByUser;
    uint256 capedMax = hardCap_ - tsInAssets;

    return userMax > capedMax ? capedMax : userMax;
  }

  /**
   * @notice Internal function to get maxDeposit() without the checks
   * @dev @return  the smallest amount between:
   -capedMax:  the (converted in shares) hardcap &  totalSupply's difference
   -userMax:  the maxDepositPerUser & (converted in assets) already paid's difference
   */
  function _maxMint(address user) internal view returns (uint256) {
    uint256 ts = totalSupply();

    uint256 hardCapInShares = _convertToShares(
      hardCap,
      MathUpgradeable.Rounding.Down
    );
    uint256 paidByUser = paid[user];
    if (hardCapInShares <= ts || maxDepositPerUser <= paidByUser) return 0;

    uint256 userMax = _convertToShares(
      maxDepositPerUser - paidByUser,
      MathUpgradeable.Rounding.Down
    );
    uint256 capedMax = hardCapInShares - ts;

    return userMax > capedMax ? capedMax : userMax;
  }
}
