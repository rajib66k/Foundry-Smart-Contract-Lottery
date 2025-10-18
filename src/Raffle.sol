// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle Contract
 * @author Rajib Kumar Pradhan
 * @notice This contract is for creating a raffle system
 * @dev Implements Chainlinks VRFv2.5
 */

// inheriting VRFConsumerBaseV2Plus
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__NotEnoughETH();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    // enum is a state type
    /* Type Declaration */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1

    }

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable I_ENTRANCE_FEE;
    uint256 private immutable I_INTERVAL;
    bytes32 private immutable I_KEY_HASH;
    uint256 private immutable I_SUBSCRIPTION_ID;
    uint32 private immutable I_CALL_BACK_GAS_LIMIT;
    address payable[] private s_players;
    uint256 private s_lastTimestamp;
    address private s_recentWinner;
    RaffleState public s_raffleState;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed reqestId);

    // inheriting cunstroctor from VRFConsumerBaseV2Plus
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        I_ENTRANCE_FEE = entranceFee;
        I_INTERVAL = interval;
        I_KEY_HASH = gasLane;
        I_SUBSCRIPTION_ID = subscriptionId;
        I_CALL_BACK_GAS_LIMIT = callbackGasLimit;

        s_lastTimestamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        // s_raffleState = RaffleState(0); // same
    }

    function enterRaffle() external payable {
        // require(msg.value >= I_ENTRANCE_FEE, Raffle__NotEnoughETH());  // only for latest solidity version

        if (msg.value < I_ENTRANCE_FEE) {
            revert Raffle__NotEnoughETH();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ ) public view returns (bool, bytes memory /* performData */ ) {
        bool timeHasPassed = ((block.timestamp - s_lastTimestamp) >= I_INTERVAL);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayer = s_players.length > 0;
        bool upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayer;
        return (upkeepNeeded, ""); // we have to return a empty bytes
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;

        // chainlink random number
        // import all the required dependencies
        // s_vrfCoordinator is a storage variable in our inherited VRFConsumerBaseV2Plus

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: I_KEY_HASH,
            subId: I_SUBSCRIPTION_ID,
            requestConfirmations: REQUEST_CONFIRMATION,
            callbackGasLimit: I_CALL_BACK_GAS_LIMIT,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effects, Interactions Pattern
    function fulfillRandomWords(
        uint256,
        /* requestId */
        uint256[] calldata randomWords
    ) internal override {
        // Checks
        // require, if else etc.
        // writing checks in start is more gas eff. bcz we just reverting if conditions are not favorable
        // if we revert after some stufs thease stufs wil cost some gas

        // Effects (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimestamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        // Interactions (External Contract Interaction)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter Functions */
    function getEntranceFee() external view returns (uint256) {
        return I_ENTRANCE_FEE;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimestamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}

// layout guides : follow solidity doc style guide
// https://docs.soliditylang.org/en/v0.8.19/style-guide.html#layout

// ChainLink Random Number
// ChainLink DOC >> VRF >> Get Random Number >> copy & paste request id section >> import dpendencies >> install chainlink-brownie-contracts >>
// >> inherit VRFConsumerBaseV2Plus (bcz. the actual contract in doc is inherits this) >> import cunstructor (as inherited contract has cuntroctor we have to import it to our contract) >>
// >> refactoring request id section (RandomWordsRequest has a sruct see VRFV2PlusClient) >> read all cunstuctos variables in doc >> then make variables acc. to cunstructor >>
// >> add a undefined virtul function present in VRFConsumerBaseV2Plus as this is a abstract contract and make it override (this function will take input requestId)

// ChainLink Automation
// ChainLink DOC >> ChainLink Automation >> Guides >> Create Automation Compatibel Contracts
