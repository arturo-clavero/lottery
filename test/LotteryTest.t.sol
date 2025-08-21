// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryMockTest} from "./mocks/LotteryMock.sol";
import {LotteryMockDeploy} from "../script/LotteryMockDeploy.s.sol";
import {LotteryConstants} from "../src/lib/LotteryConstants.sol";
import "forge-std/Vm.sol";

contract RejectEth {
    bool private rejects;

    error UnwantedMoney(bool rejects);

    constructor() {
        rejects = true;
    }

    function stopRejectionOfPayment() external {
        rejects = false;
    }

    fallback() external payable {
        if (rejects) {
            revert UnwantedMoney(rejects);
        }
    }
}

contract LotteryTest is Test {
    uint256 public constant MAX_PLAYERS = 500;
    uint256 public constant MIN_PLAYERS = 2;
    LotteryMockTest public lottery;
    address public user = vm.addr(1);
    address[] public players;
    RejectEth[] public rejectionPlayers;
    uint256[] public fakeRandomWords;
    uint256 price;
    address deployer;

    event WinnerWithdrawnPrice(address indexed winner, uint256 price);

    modifier enterLottery(uint256 total_players, bool playersAcceptTransfers) {
        players = new address[](0);
        rejectionPlayers = new RejectEth[](0);
        total_players = clampPlayerSize(total_players);
        for (uint256 i = 0; i < total_players; i++) {
            address player;
            if (playersAcceptTransfers) {
                player = vm.addr(i + 10);
            } else {
                RejectEth rejector = new RejectEth();
                rejectionPlayers.push(rejector);
                player = address(rejector);
            }
            players.push(player);
            vm.deal(player, lottery.getEntryPrice());
            vm.startPrank(player);
            lottery.enterLottery{value: lottery.getEntryPrice()}();
            vm.stopPrank();
            vm.deal(player, 0);
        }
        price = lottery.getTotalPlayers() * lottery.getEntryPrice();
        _;
    }

    function setUp() external {
        LotteryMockDeploy lotteryDeploy = new LotteryMockDeploy();
        setDeployer();
        lottery = lotteryDeploy.run(deployer);
        address lotteryAddress = address(lottery);
        address registerAddress = lotteryDeploy.deployRegister(lotteryAddress);
        deal(lotteryDeploy.getConfig(lotteryAddress).i_linkTokenAddress(), registerAddress, 1_000_000 ether);
        lotteryDeploy.setRegisterAfterFunding(lotteryAddress);
        vm.allowCheatcodes(lotteryAddress);
    }

    //constructor:
    function testConstructor() external view {
        assertEq(lottery.getEntryPrice(), LotteryConstants.ENTRY_PRICE);
        assertEq(lottery.getLength(), LotteryConstants.LENGTH);
        assertEq(lottery.getGracePeriod(), LotteryConstants.GRACE_PERIOD);
    }

    //enter lottery:
    function testEnterLotteryOverPaying() external {
        uint256 amount = LotteryConstants.ENTRY_PRICE + 1;
        hoax(user, amount);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__invalidPrice.selector, amount));
        lottery.enterLottery{value: amount}();
        assertEq(lottery.getTotalPlayers(), 0);
    }

    function testEnterLotteryUnderPaying() external {
        uint256 amount = LotteryConstants.ENTRY_PRICE - 1;
        hoax(user, amount);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__invalidPrice.selector, amount));
        lottery.enterLottery{value: amount}();
        assertEq(lottery.getTotalPlayers(), 0);
    }

    function testEnterLotteryAtDeadline() external {
        uint256 amount = LotteryConstants.ENTRY_PRICE;
        skip(lottery.getEntryDeadline() - block.timestamp);
        hoax(user, amount);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__alreadyEnded.selector));
        lottery.enterLottery{value: amount}();
        assertEq(lottery.getTotalPlayers(), 0);
    }

    function testEnterLotteryPlayerAdded(uint256 randomPlayers) public enterLottery(randomPlayers, true) {
        uint256 amount = LotteryConstants.ENTRY_PRICE;
        uint256 prevTotalPlayers = lottery.getTotalPlayers();
        hoax(user, amount);
        lottery.enterLottery{value: amount}();
        assertEq(lottery.getTotalPlayers(), prevTotalPlayers + 1);
    }

    //is lottery over:
    function testIsLotteryOverNoPlayers() external {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        (bool success, bytes memory data) = lottery.checkUpkeep("");
        assertFalse(success);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__notOver.selector));
        vm.prank(deployer);
        lottery.performUpkeep("");
        assertEq(lottery.getTotalPlayers(), 0);
    }

    function testIsLotteryOverTooSoon() external enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp - 1);
        (bool success, bytes memory data) = lottery.checkUpkeep("");
        assertFalse(success);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__notOver.selector));
        vm.prank(deployer);
        lottery.performUpkeep("");
    }

    function testIsLotteryOverTrue() public enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        (bool success, bytes memory data) = lottery.checkUpkeep("");
        assertTrue(success);
        vm.prank(deployer);
        lottery.performUpkeep("");
    }

    function testPerformUpkeepCanNotBeCalledByNonOwner() public enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.expectRevert(bytes("Only callable by owner"));
        lottery.performUpkeep("");
    }

    //test VFR

    function testRandomWinnerIsPlayer(uint256 randomNum, uint256 randomPlayers)
        public
        enterLottery(randomPlayers, true)
    {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(deployer);
        lottery.performUpkeep("");
        fakeRandomWords.push(randomNum);
        vm.recordLogs();
        lottery.testFulfillRandomWords(fakeRandomWords);
        address winner = find_winner_valid_payment();
        bool winnerIsPlayer;
        uint256 total_players = players.length;
        for (uint256 i = 0; i < total_players; i++) {
            if (players[i] == winner) {
                winnerIsPlayer = true;
                break;
            }
        }
        assertTrue(winnerIsPlayer);
    }

    //test winner default payment

    function testOnlyWinnerReceivePrice(uint256 randomNum, uint256 randomPlayers)
        public
        enterLottery(randomPlayers, true)
    {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(deployer);
        lottery.performUpkeep("");
        fakeRandomWords.push(randomNum);
        vm.recordLogs();
        lottery.testFulfillRandomWords(fakeRandomWords);
        address winner = find_winner_valid_payment();
        uint256 total_players = players.length;
        for (uint256 i = 0; i < total_players; i++) {
            if (players[i] == winner) {
                assertEq(winner.balance, price);
            } else {
                assertEq(players[i].balance, 0);
            }
        }
    }

    //test winner fallback payment

    function testWinnerFailedToReceivePrice(uint256 randomNum, uint256 randomPlayers)
        public
        enterLottery(randomPlayers, false)
    {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(deployer);
        lottery.performUpkeep("");
        fakeRandomWords.push(randomNum);
        vm.recordLogs();
        lottery.testFulfillRandomWords(fakeRandomWords);
        uint256 total_players = players.length;
        for (uint256 i = 0; i < total_players; i++) {
            assertEq(players[i].balance, 0);
        }
    }

    function testWinnedFailedTransferCanRefund(uint256 randomNum, uint256 randomPlayers) public {
        testWinnerFailedToReceivePrice(randomNum, randomPlayers);
        accept_all_payments();
        address winner = find_winner_invalid_payment();
        assertEq(winner.balance, 0);
        vm.prank(winner);
        lottery.winnerFallbackWithdrawal();
        assertEq(winner.balance, price);
    }

    function testWinnedCorrectTransferCanNotRefund(uint256 randomNum, uint256 randomPlayers)
        public
        enterLottery(randomPlayers, true)
    {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(deployer);
        lottery.performUpkeep("");
        fakeRandomWords.push(randomNum);
        vm.recordLogs();
        lottery.testFulfillRandomWords(fakeRandomWords);
        address winner = find_winner_valid_payment();
        uint256 winner_prev_balance = winner.balance;
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__noWinningsToWithdraw.selector));
        vm.prank(winner);
        lottery.winnerFallbackWithdrawal();
        assertEq(winner.balance, winner_prev_balance);
    }

    //test start lottery
    function testFundAndStartLotterySecondTime() external {
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__alreadyInitialized.selector));
        lottery.fundAndStartLottery(vm.addr(2), 1);
    }

    function testStartLotteryValues() external enterLottery(2, true) {
        uint256 randomNum = 1;
        uint256 prev_entry_deadline = lottery.getEntryDeadline();
        uint256 prev_pickWinner_deadline = lottery.getPickWinnerDeadline();
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(deployer);
        lottery.performUpkeep("");
        fakeRandomWords.push(randomNum);
        lottery.testFulfillRandomWords(fakeRandomWords);
        assertEq(lottery.getTotalPlayers(), 0);
        assertGt(lottery.getEntryDeadline(), prev_entry_deadline);
        assertGt(lottery.getPickWinnerDeadline(), prev_pickWinner_deadline);
    }

    //utils:
    function find_winner_valid_payment() public returns (address) {
        bytes32 eventValidPayment = keccak256("WinnerPaidPrice(address,uint256)");
        bytes32 eventInvalidPayment = keccak256("WinnerInvalidPayment(address,uint256)");
        bool eventInvalidPaymentEmitted;

        Vm.Log[] memory logs = vm.getRecordedLogs();
        address winner;
        for (uint256 i = 0; i < logs.length; i++) {
            console.log(uint256(logs[i].topics[0]));
            if ((logs[i].topics[0] == eventValidPayment) && logs[i].topics.length >= 2) {
                winner = address(uint160(uint256(logs[i].topics[1])));
                break;
            } else if (logs[i].topics[0] == eventInvalidPayment) {
                eventInvalidPaymentEmitted = true;
                break;
            }
        }
        assertNotEq(winner, address(0));
        assertFalse(eventInvalidPaymentEmitted);
        assertNotEq(winner, address(0));
        return winner;
    }

    function find_winner_invalid_payment() public returns (address) {
        bytes32 eventValidPayment = keccak256("WinnerPaidPrice(address,uint256)");
        bytes32 eventInvalidPayment = keccak256("WinnerInvalidPayment(address,uint256)");
        bool eventValidPaymentEmitted;
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address winner;
        for (uint256 i = 0; i < logs.length; i++) {
            console.log(uint256(logs[i].topics[0]));
            if ((logs[i].topics[0] == eventInvalidPayment) && logs[i].topics.length >= 2) {
                winner = address(uint160(uint256(logs[i].topics[1])));
                break;
            } else if (logs[i].topics[0] == eventValidPayment) {
                eventValidPaymentEmitted = true;
                break;
            }
        }
        assertNotEq(winner, address(0));
        assertFalse(eventValidPaymentEmitted);
        return winner;
    }

    function accept_all_payments() public {
        for (uint256 i = 0; i < rejectionPlayers.length; i++) {
            rejectionPlayers[i].stopRejectionOfPayment();
        }
    }

    function clampPlayerSize(uint256 nPlayers) private pure returns (uint256) {
        if (nPlayers > MAX_PLAYERS) {
            nPlayers = MAX_PLAYERS;
        } else if (nPlayers < MIN_PLAYERS) {
            nPlayers = MIN_PLAYERS;
        }
        return nPlayers;
    }

    function setDeployer() private {
        uint256 chainid = block.chainid;
        if (chainid == LotteryConstants.CHAIN_ID_SEPOLIA) {
            deployer = vm.addr(12);
            deal(LotteryConstants.LINK_TOKEN_ADDRESS_SEPOLIA, deployer, 1_000_000 ether);
        } else if (chainid == LotteryConstants.CHAIN_ID_ETHEREUM) {
            deployer = LotteryConstants.LINKWHALE_ETHEREUM;
        } else {
            deployer = vm.addr(12);
        }
    }
}
