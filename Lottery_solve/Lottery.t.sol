// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Lottery.sol";

contract LotteryTest is Test {
    Lottery public lottery;
    uint256 received_msg_value;

    // -----------------------------------------------------
    // 세팅 함수들
    // -----------------------------------------------------
    function setUp() public {
       lottery = new Lottery();
       received_msg_value = 0;
       // 현재 컨트랙트 및 테스트용 주소들에 각각 100 ether를 할당합니다.
       vm.deal(address(this), 100 ether);
       vm.deal(address(1), 100 ether);
       vm.deal(address(2), 100 ether);
       vm.deal(address(3), 100 ether);
    }

    // -----------------------------------------------------
    // 그룹 1: 구매 기능 테스트
    // -----------------------------------------------------
    // 유효한 티켓 구매 테스트(1) -> 단계,시간,가격,중복 확인
    function testGoodBuy() public {
        lottery.buy{value: 0.1 ether}(0);
    } 

    // 이더가 전송되지 않았을 때의 테스트(2)
    function testInsufficientFunds1() public {
        vm.expectRevert();
        lottery.buy(0); // value를 넣지않았기 때문에 revert
    } 

    // 전송된 이더가 요구되는 금액보다 약간 적을 때 테스트(3)
    function testInsufficientFunds2() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether - 1}(0); //정확하지 않기 때문에 revert
    }

    // 전송된 이더가 요구되는 금액보다 약간 더 많을 때 테스트(4)
    function testInsufficientFunds3() public {
        vm.expectRevert();
        lottery.buy{value: 0.1 ether + 1}(0);//정확하지 않기 때문에 revert
    }

    // 한 라운드 내에서 중복 구매가 불가능한지 테스트(5)
    function testNoDuplicate() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.expectRevert();
        lottery.buy{value: 0.1 ether}(0); //중복구매 -> revert
    }

    // -----------------------------------------------------
    // 그룹 2: 판매 단계 (시간 기반) 테스트
    // -----------------------------------------------------
    // 판매 종료 직전에 구매가 가능한지 테스트(6)
    function testSellPhaseFullLength() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1); // 판매기간 직전 구매 가능
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0);
    }  

    // 판매 기간이 종료된 후에는 구매가 불가능한지 테스트(7)
    function testNoBuyAfterPhaseEnd() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours); 
        vm.expectRevert();
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(0); //판매기간 종료 후 구매 -> revert
    }

    // -----------------------------------------------------
    // 그룹 3: 추첨 단계 테스트
    // -----------------------------------------------------
    // 판매 단계에서는 추첨이 불가능한지 테스트(8)
    function testNoDrawDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.draw(); // 판매기간 추첨 -> revert
    }

    // 판매 단계에서는 청구가 불가능한지 테스트(9)
    function testNoClaimDuringSellPhase() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours - 1);
        vm.expectRevert();
        lottery.claim(); // 판매기간 청구 -> revert
    }

    // 판매 기간이 끝난 후 추첨 함수가 정상적으로 동작하는지 테스트(10)
    function testDraw() public {
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw(); // 판매기간 종료 후 추첨
    }

    // -----------------------------------------------------
    // 보조 함수: 다음 당첨 번호 계산
    // -----------------------------------------------------
    // 상태를 스냅샷한 후 추첨을 실행하여 당첨 번호를 가져오고, 상태를 복구합니다.(11)
    function getNextWinningNumber() private returns (uint16) {
        uint256 snapshotId = vm.snapshot();
        lottery.buy{value: 0.1 ether}(0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        uint16 winningNumber = lottery.winningNumber();
        vm.revertTo(snapshotId);
        return winningNumber;
    } // vertTo(snapshotId)를 통해 상태를 복구하는건 cal+z라고 생각하면 될 거 같다.
    // 스냅샷은 찍어놓은 상태로 복구하는 것!

    // -----------------------------------------------------
    // 그룹 4: 청구 단계 테스트
    // -----------------------------------------------------
    // 정답(당첨 번호)일 경우 청구 시 지급액이 제대로 지급되는지 테스트(12)
    function testClaimOnWin() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); 
        vm.warp(block.timestamp + 24 hours);
        uint256 expectedPayout = address(lottery).balance;
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, expectedPayout);
    }

    // 오답일 경우 청구 시 지급액이 없는지 테스트(13)
    function testNoClaimOnLose() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); 
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0);
    }

    // 청구 단계가 끝난 후 다시 판매기간이 되면 draw가 불가능한지 테스트(14)
    function testNoDrawDuringClaimPhase() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); 
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim(); //여기에서 다시 SELL 단계로 돌아가기 때문에 revert
        vm.expectRevert();
        lottery.draw();
    }

    // -----------------------------------------------------
    // 그룹 5: 이월 테스트
    // -----------------------------------------------------
    // 연속적인 복권 라운드에서 이월 동작(자금의 이월)이 정상적으로 이루어지는지 테스트(15)
    function testRollover() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber + 1); 
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        winningNumber = getNextWinningNumber(); //draw()를 통해 winningNumber가 바뀌었기 때문에 다시 계산
        lottery.buy{value: 0.1 ether}(winningNumber); // 여기부터 문제발생
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();
        lottery.claim();
        assertEq(received_msg_value, 0.2 ether);
    }

    // -----------------------------------------------------
    // 그룹 6: 분할 지급 테스트
    // -----------------------------------------------------
    // 당첨자가 여러 명일 경우, 지급액이 올바르게 분할되어 지급되는지 테스트(16)
    function testSplit() public {
        uint16 winningNumber = getNextWinningNumber();
        lottery.buy{value: 0.1 ether}(winningNumber); //address(this)
        vm.prank(address(1));
        lottery.buy{value: 0.1 ether}(winningNumber);
        vm.deal(address(1), 0);
        vm.warp(block.timestamp + 24 hours);
        lottery.draw();

        lottery.claim(); // address(this)에게 0.1 ether 지급
        assertEq(received_msg_value, 0.1 ether);

        vm.prank(address(1));
        lottery.claim();
        assertEq(address(1).balance, 0.1 ether);
    }

    // -----------------------------------------------------
    // Fallback: 지급 추적용 receive 함수
    // -----------------------------------------------------
    // 이 함수는 컨트랙트가 이더를 받을 때 지급액을 추적합니다.(17)
    receive() external payable {
        received_msg_value = msg.value;
    }
}
