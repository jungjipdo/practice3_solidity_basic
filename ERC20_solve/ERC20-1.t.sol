// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../src/ERC20.sol";

contract UpsideTokenTest is Test {
    address internal constant alice = address(1);
    address internal constant bob = address(2);

    // ERC20 토큰 인스턴스 변수
    ERC20 upside_token;

    function setUp() public {
        upside_token = new ERC20("UPSIDE", "UPS");
        // alice와 bob에게 각각 50 ether 상당의 토큰을 전송
        upside_token.transfer(alice, 50 ether);
        upside_token.transfer(bob, 50 ether);
    }
    
    // pause() 함수는 소유자만 호출할 수 있는데, alice가 호출하면 revert되어야 함을 테스트(1)
    function testFailPauseNotOwner() public {
        vm.prank(alice); // 다음 호출의 msg.sender를 alice로 변경
        upside_token.pause();
    } 
    // clear

    // 토큰이 pause 상태일 때 transfer()를 호출하면 revert되어야 함을 테스트(2)
    function testFailTransfer() public {
        upside_token.pause();
        vm.prank(alice);
        upside_token.transfer(bob, 10 ether); // revert
    }
    // clear
    

    // pause 상태에서 transferFrom 호출 시도 시 revert되어야 함을 테스트(3)
    function testFailTransferFrom() public {
        upside_token.pause();
        vm.prank(alice);
        upside_token.approve(msg.sender, 10 ether);
        upside_token.transferFrom(alice, bob, 10 ether);
    }
    // clear
}
