// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Test.sol";
import "../src/ERC20.sol";

contract UpsideTokenTest is Test {
    address internal alice;
    address internal bob;
    // alice와 bob의 개인키 
    uint256 internal alicePK;
    uint256 internal bobPK;

    ERC20 upside_token;

    function setUp() public {
        upside_token = new ERC20("UPSIDE", "UPS");

        alicePK = 0xa11ce;
        // 개인키로부터 alice 주소 생성
        alice = vm.addr(alicePK);

        bobPK = 0xb0b;
        // 개인키로부터 bob 주소 생성
        bob = vm.addr(bobPK);

        // 생성된 주소들을 로그로 출력 (테스트 디버깅용)
        emit log_address(alice);
        emit log_address(bob);

        upside_token.transfer(alice, 50 ether);
        upside_token.transfer(bob, 50 ether);
    }
    
    // testPermit: permit() 함수의 정상 동작을 테스트하는 함수(4)
    function testPermit() public {
        // Permit 구조체 해시 계산
        bytes32 structHash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), 
            alice,         // owner
            address(this), // spender
            10 ether,      // value
            0,             // current nonce
            1 days         // deadline
            ));
        //digest 계산
        bytes32 hash = upside_token._toTypedDataHash(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, hash); // alicePK로 서명

        assertEq(upside_token.nonces(alice), 0); // alice의 nonce가 0인지 확인
        // permit() 호출: alice가 현재 컨트랙트에게 10 ether 사용을 승인하도록 서명값과 함께 호출
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);

        // permit 호출 후 업데이트 확인
        assertEq(upside_token.allowance(alice, address(this)), 10 ether);
        assertEq(upside_token.nonces(alice), 1);
    }

    // testFailExpiredPermit: 만료된 permit 호출 시 revert되는지 테스트(5)
    function testFailExpiredPermit() public {
        bytes32 hash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), 
            alice, 
            address(this), 
            10 ether, 
            0, 
            1 days
            ));
        bytes32 digest = upside_token._toTypedDataHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, digest);

        vm.warp(1 days + 1 seconds);//permit 만료 

        // 만료된 permit 호출 -> revert되어야 함 (testFail 계열 함수는 revert 시 테스트 통과)
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);
    }

    // testFailInvalidSigner: 잘못된 서명자가 서명하면 permit 호출이 revert되는지 테스트(6)
    function testFailInvalidSigner() public {
        bytes32 hash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), 
            alice, 
            address(this), 
            10 ether, 
            0, 
            1 days
            ));
        bytes32 digest = upside_token._toTypedDataHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(bobPK, digest); //잘못된 서명자(bob)

        // alice의 서명 대신 잘못된 서명자로 permit 호출 -> revert되어야 함
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);
    }

    // testFailInvalidNonce: 잘못된 nonce로 permit 호출 시 revert되는지 테스트(7)
    function testFailInvalidNonce() public {
        // Permit 데이터 해시 계산 (nonce를 1로 잘못 지정, 유효기간 1일)
        bytes32 hash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), 
            alice, 
            address(this), 
            10 ether, 
            1,    // nonce 값이 잘못됨 (올바른 nonce는 0이어야 함)
            1 days
            ));
        // EIP-712 규격에 따른 digest 계산
        bytes32 digest = upside_token._toTypedDataHash(hash);
        // alicePK로 서명하여 서명값 획득
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, digest);

        // 잘못된 nonce로 permit 호출 -> revert되어야 함
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);
    }

    // testReplay: 같은 permit 서명을 두 번 사용하면 두 번째 호출이 revert되는지 테스트)(8)
    function testReplay() public {
        // Permit 데이터 해시 계산 (nonce 0, 유효기간 1일)
        bytes32 hash = keccak256(abi.encode(
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"), 
            alice, 
            address(this), 
            10 ether, 
            0, 
            1 days
            ));
        // EIP-712 규격에 따른 digest 계산
        bytes32 digest = upside_token._toTypedDataHash(hash);
        // alicePK로 서명하여 서명값 획득
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePK, digest);

        // 첫 번째 permit 호출: 정상 실행되어 allowance와 nonce 업데이트
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);
        // 두 번째 동일한 permit 호출: 이미 사용된 nonce라서 revert되어야 함
        vm.expectRevert("INVALID_SIGNER");
        upside_token.permit(alice, address(this), 10 ether, 1 days, v, r, s);
    }
}