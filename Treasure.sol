
// File: @openzeppelin/contracts/utils/Context.sol


// OpenZeppelin Contracts (last updated v5.0.1) (utils/Context.sol)

pragma solidity ^0.8.20;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    function _contextSuffixLength() internal view virtual returns (uint256) {
        return 0;
    }
}

// File: @openzeppelin/contracts/access/Ownable.sol


// OpenZeppelin Contracts (last updated v5.0.0) (access/Ownable.sol)

pragma solidity ^0.8.20;


/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * The initial owner is set to the address provided by the deployer. This can
 * later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    /**
     * @dev The caller account is not authorized to perform an operation.
     */
    error OwnableUnauthorizedAccount(address account);

    /**
     * @dev The owner is not a valid owner account. (eg. `address(0)`)
     */
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the address provided by the deployer as the initial owner.
     */
    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(initialOwner);
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// File: contracts/TreasureHunt.sol



pragma solidity ^0.8.25;


/**
 * @title TreasureHuntGame
 * @dev A smart contract for organizing treasure hunt games on the blockchain.
 */
contract TreasureHuntGame is Ownable {

    /// @dev Error thrown when no clues are provided when creating a treasure hunt
    error CluesMustBeProvided();

    /// @dev Error thrown when an invalid hunt ID is provided
    error InvalidHuntId();

    /// @dev Error thrown when treasure has already been claimed
    error TreasureAlreadyClaimed();

    /// @dev Error thrown when an invalid clue fee is provided
    error InvalidClueFee();

    /// @dev Error thrown when an invalid answer is submitted
    error InvalidAnswer();

    /// @dev Error thrown when attempting to claim treasure by non winner
    error NotWinner();

    /// @dev Error thrown when the value sent for treasure creation does not match the specified treasure value
    error InvalidTreasureValue();

    /// @dev Error thrown when an invalid power-up fee is provided
    error InvalidPowerUpFee();

    /// @dev Error thrown when attempting to use a power-up without purchasing it
    error PowerUpNotPurchased();

    error InvalidKey();
    
    /// @dev Event emitted when a new treasure hunt is created
    event TreasureCreated(uint256 huntId, uint256 treasureValue);

    /// @dev Event emitted when a power-up is purchased
    event PowerUpPurchased(uint256 huntId, address player);

    /// @dev Event emitted when an answer is submitted
    event AnswerSubmitted(uint256 huntId, address player);

    /// @dev Event emitted when a player skips the current clue using a power-up
    event SkippedCurrentClue(uint256 huntId, address player);

    /// @dev Event emitted when a player claims the treasure
    event Claimed(uint256 huntId, address winner);

    /// @dev Struct to represent a treasure hunt
    struct TreasureHunt {
        uint256 treasureValue;                          // Value of the treasure
        string[] clues;                                 // Clues for the treasure hunt
        mapping (address => uint256) playerClueIndex;   // Mapping to track player's progress
        address winner;                                 // Address of the winner
        mapping(address => bool) powerUpHolders;        // Mapping to track players who purchased power-ups
        bool treasureClaimed;                           // Flag to indicate if the treasure is claimed
        uint256 trasureKey;
    }

    /// @dev Mapping to store treasure hunts
    mapping(uint256 => TreasureHunt) private treasureHunts;

    /// @dev Counter to track the current hunt ID
    uint256 public currentHuntId;

    /**
     * @dev Modifier to check if the treasure hunt id is valid and the winner is not yet declared.
     * @param _huntId The ID of the treasure hunt.
     */
    modifier isValidHunt(uint256 _huntId) {
        if(_huntId > currentHuntId){
            revert InvalidHuntId();
        }
        if(treasureHunts[_huntId].treasureClaimed){
            revert TreasureAlreadyClaimed();
        }
        _;
    }

    /**
     * @dev Constructor to initialize the contract.
     */
    constructor() Ownable(msg.sender) {}

    /**
     * @dev Creates a new treasure hunt.
     * @param _treasureValue Value of the treasure.
     * @param _clues Array of clues for the treasure hunt.
     */
    function createTreasureHunt(uint256 _treasureValue, string[] memory _clues, uint256 _trasureKey) public payable onlyOwner {
        if(_clues.length < 1){
            revert CluesMustBeProvided();
        }
        if(msg.value != _treasureValue){
            revert InvalidTreasureValue();
        }

        currentHuntId++;
        treasureHunts[currentHuntId].treasureValue = _treasureValue;
        treasureHunts[currentHuntId].clues = _clues;
        treasureHunts[currentHuntId].trasureKey = _trasureKey;

        emit TreasureCreated(currentHuntId, _treasureValue);
    }

    /**
     * @dev Retrieves the next clue for a player in a treasure hunt.
     * @param _huntId The ID of the treasure hunt.
     * @return The next clue.
     */
    function getNextClue(uint256 _huntId) public payable isValidHunt(_huntId) returns (string memory) {
        if(msg.value != 0.001 ether){
            revert InvalidClueFee();
        }

        return treasureHunts[_huntId].clues[treasureHunts[_huntId].playerClueIndex[msg.sender]];
    }
   
    /**
     * @dev Submits an answer for the current clue in the treasure hunt.
     * @param _huntId The ID of the treasure hunt.
     * @param _answer The answer submitted by the player.
     */
    function submitAnswer(uint256 _huntId, bytes32 _answer) public isValidHunt(_huntId) returns(uint256) {
        TreasureHunt storage hunt = treasureHunts[_huntId];
      
        if(keccak256(bytes(hunt.clues[hunt.playerClueIndex[msg.sender]])) != _answer){
            revert InvalidAnswer();
        }
        if (hunt.playerClueIndex[msg.sender] == hunt.clues.length - 1) {
            hunt.winner = msg.sender;
            return hunt.trasureKey;
        } else {
            hunt.playerClueIndex[msg.sender]++;
        }

        emit AnswerSubmitted(_huntId, msg.sender);
        return 0;
    }

    /**
     * @dev Skips the current clue in the treasure hunt using a power-up.
     * @param _huntId The ID of the treasure hunt.
     */
    function skipCurrentClue(uint256 _huntId) public isValidHunt(_huntId) returns(uint256){
        TreasureHunt storage hunt = treasureHunts[_huntId];

        if(!hunt.powerUpHolders[msg.sender]){
            revert PowerUpNotPurchased();
        }
        if (hunt.playerClueIndex[msg.sender] == hunt.clues.length - 1) {
            hunt.winner = msg.sender;
            return hunt.trasureKey;
        } else {
            hunt.playerClueIndex[msg.sender]++;
        }
        hunt.powerUpHolders[msg.sender] = false;

        emit SkippedCurrentClue(_huntId, msg.sender);
        return 0;
    }

    /**
     * @dev Claims the treasure for the winner of the treasure hunt.
     * @param _huntId The ID of the treasure hunt.
     */
    function claimTreasure(uint256 _huntId, uint256 _trasureKey) public isValidHunt(_huntId) payable {
        TreasureHunt storage hunt = treasureHunts[_huntId];
       
        if(hunt.winner != msg.sender){
            revert NotWinner();
        }
        if(_trasureKey != hunt.trasureKey){
            revert InvalidKey();
        }

        payable(msg.sender).transfer(hunt.treasureValue);
        hunt.treasureClaimed = true;

        emit Claimed(_huntId, msg.sender);
    }
    
    /**
     * @dev Allows a player to purchase a power-up for skipping a clue.
     * @param _huntId The ID of the treasure hunt.
     */
    function purchasePowerUp(uint256 _huntId) public isValidHunt(_huntId) payable {
        if(msg.value != 0.1 ether){
            revert InvalidPowerUpFee();
        }
        treasureHunts[_huntId].powerUpHolders[msg.sender] = true;

        emit PowerUpPurchased(_huntId, msg.sender);
    }
}
