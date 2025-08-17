// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Lottery} from "../src/Lottery.sol";
import {LotteryMockTest} from "./mocks/LotteryMock.sol";
import {LotteryDeploy} from "../script/LotteryDeploy.s.sol";
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
    Lottery public lotteryReal;
    LotteryMockTest public lottery;
    address public owner = vm.addr(2);
    address public user = vm.addr(1);
    address[] public players;
    RejectEth[] public rejectionPlayers;
    uint256 [] public fakeRandomWords;
    uint256 price;

    event WinnerWithdrawnPrice(address indexed winner, uint256 price);

    modifier enterLottery(uint256 total_players, bool playersAcceptTransfers) {
        players = new address[](0);
        rejectionPlayers = new RejectEth[](0);
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
        LotteryDeploy lotteryDeploy = new LotteryDeploy();
        lottery = lotteryDeploy.runTest();
        lotteryReal = lotteryDeploy.run();
        // owner = msg.sender;
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

    function testEnterLotteryPlayerAdded() public {
        uint256 amount = LotteryConstants.ENTRY_PRICE;
        hoax(user, amount);
        lottery.enterLottery{value: amount}();
        assertEq(lottery.getTotalPlayers(), 1);
    }

    //is lottery over:

    function testIsLotteryOverNoPlayers() external {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        (bool success, bytes memory data) = lottery.checkUpkeep("");        
        assertFalse(success);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__notOver.selector));
        vm.prank(owner);
        lottery.performUpkeep("");
        assertEq(lottery.getTotalPlayers(), 0);
    }

    function testIsLotteryOverTooSoon() external enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp - 1);
         (bool success, bytes memory data) = lottery.checkUpkeep("");        
        assertFalse(success);
        vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__notOver.selector));
        vm.prank(owner);
        lottery.performUpkeep("");
    }

    function testIsLotteryOverTrue() public enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        (bool success, bytes memory data) = lottery.checkUpkeep("");        
        assertTrue(success);
        vm.prank(owner);
        lottery.performUpkeep("");
    }

    function testPerformUpkeepCanNotBeCalledByNonOwner() public enterLottery(2, true) {
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.expectRevert(bytes("Only callable by owner"));
        lottery.performUpkeep("");
    }

    function testRequestRandomWords() public enterLottery(2, true){
        skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
        vm.prank(owner);
        lottery.performUpkeep("");
        uint256 requestId = lottery.s_requestId();
        fakeRandomWords.push(1);
        lottery.testFulfillRandomWords(fakeRandomWords);
    // // 4️⃣ Simulate VRF callback
    // uint256 ;
    // randomWords[0] = 1; // pick winner index
    // vrfMock.callBackWithRandomWords(requestId, address(lottery), randomWords);
    }
    //test winner

    // function testWinner() public enterLottery(2, true) {
    //     skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
    //     bool success = lottery.checkUpkeep();
    //     assertTrue(success);
    //     lottery.performUpkeep(null);
    // }
    //get winner address:

    // function testGetWinnerAddress() external enterLottery(2, true) {
    //     address winner = lottery.get_winner_address(players.length);
    //     bool winnerIsPlayer = false;
    //     for (uint256 i = 0; i < players.length; i++) {
    //         if (players[i] == winner) {
    //             winnerIsPlayer = true;
    //             break;
    //         }
    //     }
    //     assertTrue(winnerIsPlayer);
    // }
    //pay winner:

    // function testPayWinnerTrue() public enterLottery(2, true) {
    //     skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
    //     vm.recordLogs();
    //     hoax(vm.addr(1), 10 ether);
    //     lottery.payWinner();
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     bytes32 winnerPaidPrice = keccak256("WinnerPaidPrice(address,uint256)");
    //     bool winnerPaidPriceEmitted = false;
    //     bytes32 WinnerInvalidPayment = keccak256("WinnerInvalidPayment(address,uint256)");
    //     bool WinnerInvalidPaymentEmitted = false;
    //     address winner;
    //     for (uint256 i = 0; i < logs.length; i++) {
    //         if (logs[i].topics[0] == winnerPaidPrice) {
    //             winnerPaidPriceEmitted = true;
    //             if (logs[i].topics.length >= 2) {
    //                 winner = address(uint160(uint256(logs[i].topics[1])));
    //                 break;
    //             }
    //         } else if (logs[i].topics[0] == WinnerInvalidPayment) {
    //             WinnerInvalidPaymentEmitted = true;
    //         }
    //     }
    //     assertTrue(winnerPaidPriceEmitted);
    //     //winner paid price event emited
    //     assertFalse(WinnerInvalidPaymentEmitted);
    //     //winner did not get price event NOT emited
    //     assertNotEq(winner, address(0));
    //     //we found winner!
    //     bool winnerIsPlayer = false;
    //     for (uint256 i = 0; i < players.length; i++) {
    //         if (players[i] == winner) {
    //             winnerIsPlayer = true;
    //             break;
    //         }
    //     }
    //     assertTrue(winnerIsPlayer);
    //     //winner is part of players!
    //     assertEq(winner.balance, price);
    //     //winner got price!
    // }

    // function testPayWinnerInvalidTransfer() external enterLottery(2, false) {
    //     skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
    //     vm.recordLogs();
    //     hoax(vm.addr(1), 10 ether);
    //     lottery.payWinner();
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     bytes32 winnerPaidPrice = keccak256("WinnerPaidPrice(address,uint256)");
    //     bool winnerPaidPriceEmitted = false;
    //     bytes32 WinnerInvalidPayment = keccak256("WinnerInvalidPayment(address,uint256)");
    //     bool WinnerInvalidPaymentEmitted = false;
    //     address winner;
    //     for (uint256 i = 0; i < logs.length; i++) {
    //         if (logs[i].topics[0] == WinnerInvalidPayment) {
    //             WinnerInvalidPaymentEmitted = true;
    //             if (logs[i].topics.length >= 2) {
    //                 winner = address(uint160(uint256(logs[i].topics[1])));
    //                 break;
    //             }
    //         } else if (logs[i].topics[0] == winnerPaidPrice) {
    //             winnerPaidPriceEmitted = true;
    //         }
    //     }
    //     assertTrue(WinnerInvalidPaymentEmitted);
    //     //winner did not get price event emited
    //     assertFalse(winnerPaidPriceEmitted);
    //     //winner paid price event NOT emited
    //     assertNotEq(winner, address(0));
    //     //we found winner!
    //     bool winnerIsPlayer = false;
    //     for (uint256 i = 0; i < players.length; i++) {
    //         if (players[i] == winner) {
    //             winnerIsPlayer = true;
    //             break;
    //         }
    //     }
    //     assertTrue(winnerIsPlayer);
    //     //winner is part of players!
    //     assertEq(winner.balance, 0);
    //     //winner did not get a price!
    // }

    // //start lottery:
    // function testStartLotteryValues() external {
    //     uint256 prev_entry_deadline = lottery.getEntryDeadline();
    //     uint256 prev_pickWinner_deadline = lottery.getPickWinnerDeadline();
    //     testPayWinnerTrue();
    //     assertEq(lottery.getTotalPlayers(), 0);
    //     assertGt(lottery.getEntryDeadline(), prev_entry_deadline);
    //     assertGt(lottery.getPickWinnerDeadline(), prev_pickWinner_deadline);
    // }

    //winner withdraws:
    // function find_winner() public returns (address) {
    //     skip(lottery.getPickWinnerDeadline() - block.timestamp + 1);
    //     vm.recordLogs();
    //     hoax(user, 10);
    //     lottery.payWinner();
    //     bytes32 eventInvalidPayment = keccak256("WinnerInvalidPayment(address,uint256)");
    //     bytes32 eventValidPayment = keccak256("WinnerPaidPrice(address,uint256)");
    //     Vm.Log[] memory logs = vm.getRecordedLogs();
    //     address winner;
    //     for (uint256 i = 0; i < logs.length; i++) {
    //         console.log(uint256(logs[i].topics[0]));
    //         if (
    //             (logs[i].topics[0] == eventValidPayment || logs[i].topics[0] == eventInvalidPayment)
    //                 && logs[i].topics.length >= 2
    //         ) {
    //             winner = address(uint160(uint256(logs[i].topics[1])));
    //             break;
    //         }
    //     }
    //     assertNotEq(winner, address(0));
    //     return winner;
    // }

    // function accept_all_payments() public {
    //     for (uint256 i = 0; i < rejectionPlayers.length; i++) {
    //         rejectionPlayers[i].stopRejectionOfPayment();
    //     }
    // }

    // function testWinnerFallbackWithdrawal() public enterLottery(2, false) {
    //     address winner = find_winner();
    //     accept_all_payments();
    //     vm.deal(winner, 10);
    //     uint256 prevBalance = winner.balance;
    //     vm.startPrank(winner);
    //     vm.expectEmit(true, false, false, true);
    //     emit WinnerWithdrawnPrice(winner, price);
    //     lottery.winnerFallbackWithdrawal();
    //     vm.stopPrank();
    //     assertEq(winner.balance, prevBalance + price);
    // }

    // function testWinnerFallbackWithdrawalAfterWithdraw() external enterLottery(2, false) {
    //     address winner = find_winner();
    //     accept_all_payments();
    //     vm.deal(winner, 10);
    //     uint256 prevBalance = winner.balance;
    //     vm.startPrank(winner);
    //     vm.expectEmit(true, false, false, true);
    //     emit WinnerWithdrawnPrice(winner, price);
    //     lottery.winnerFallbackWithdrawal();
    //     assertEq(winner.balance, prevBalance + price);
    //     //now we will try to withdraw a second time
    //     vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__noWinningsToWithdraw.selector));
    //     lottery.winnerFallbackWithdrawal();
    // }

    // function testWinnerFallbackWithdrawalbyNonWinner() external enterLottery(2, false) {
    //     address winner = find_winner();
    //     accept_all_payments();
    //     address looser;
    //     for (uint256 i = 0; i < players.length; i++) {
    //         if (players[i] != winner) {
    //             looser = players[i];
    //             break;
    //         }
    //     }
    //     assertNotEq(looser, address(0));
    //     //we found a looser
    //     vm.deal(looser, 10);
    //     uint256 prevBalance = looser.balance;
    //     vm.startPrank(looser);
    //     vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__noWinningsToWithdraw.selector));
    //     lottery.winnerFallbackWithdrawal();
    //     assertEq(looser.balance, prevBalance);
    // }

    // function testWinnerFallbackWithdrawalNoError() external enterLottery(2, true) {
    //     address winner = find_winner();
    //     accept_all_payments();
    //     vm.deal(winner, 10);
    //     uint256 prevBalance = winner.balance;
    //     vm.startPrank(winner);
    //     vm.expectRevert(abi.encodeWithSelector(Lottery.Lottery__noWinningsToWithdraw.selector));
    //     lottery.winnerFallbackWithdrawal();
    //     assertEq(winner.balance, prevBalance);
    // }
}
