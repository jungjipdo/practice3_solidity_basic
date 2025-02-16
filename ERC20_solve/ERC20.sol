// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ERC20 {
    // 토큰 메타데이터
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply; // 총 발행량
    // pause 상태 변수 및 소유자 주소
    bool public paused;
    address public owner;
    
    // 각 주소별 잔액 매핑
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    // permit 관련 상태 변수: 각 주소별 nonce (EIP-2612)
    mapping(address => uint256) public nonces;
    
    // EIP-712 도메인 구분용 DOMAIN_SEPARATOR
    bytes32 public DOMAIN_SEPARATOR;
    
    // 이벤트 정의
    event Transfer(address indexed from, address indexed to, uint256 value); //transfer 이벤트 추가
    event Approval(address indexed owner, address indexed spender, uint256 value); //approve 이벤트 추가
    
    // 생성자: 토큰 메타데이터 초기화 및 도메인 구분자 설정
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        decimals = 18; // ERC20 표준 소수점 자리
        totalSupply = 1000000 ether; 
        balanceOf[msg.sender] = totalSupply; // 발행량을 생성자에게 할당
        owner = msg.sender;
        paused = false;
        
        // EIP-712 도메인 구분자 설정
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(_name)),
                keccak256(bytes("1")),
                block.chainid,
                address(this)
            )
        );
    }
    
    // transfer 함수 구현 (paused 상태일 때는 전송 불가)
    function transfer(address to, uint256 value) public virtual returns (bool) {
        require(!paused, "ERC20: token transfer while paused"); // test(2) 핵심
        require(balanceOf[msg.sender] >= value, "ERC20: insufficient balance");
        
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    // approve 함수 구현 (paused 상태일 때도 승인 가능)
    function approve(address spender, uint256 value) public virtual returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    // transferFrom 함수 구현 (paused 상태일 때는 전송 불가)(승인한도내에서만 전송 가능)
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool) {
        require(!paused, "ERC20: token transfer while paused"); // test(3) 핵심
        require(balanceOf[from] >= value, "ERC20: insufficient balance");
        require(allowance[from][msg.sender] >= value, "ERC20: allowance exceeded");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
    
    // pause 함수 구현
    function pause() public {
        require(msg.sender == owner, "ERC20: caller is not the owner"); // test(1) 핵심
        paused = true;
    }
    
    // EIP-712 규격에 따른 타입 데이터 해시 계산 함수(digest 계산)
    function _toTypedDataHash(bytes32 structHash) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }
    
    // permit 함수 구현 (EIP-2612) -> 토큰 소유자가 off-chain 서명을 통해 spender에게 토큰 사용을 승인함
    function permit(
        address owner_, 
        address spender, 
        uint256 value, 
        uint256 deadline, 
        uint8 v, 
        bytes32 r, 
        bytes32 s
    ) public {
        require(block.timestamp <= deadline, "Permit: expired deadline"); // test(5) 핵심
        
        // 현재 nonce를 가져옴
        uint256 currentNonce = nonces[owner_]; //test(8) 핵심
        
        // Permit 구조체에 대한 해시 계산 (EIP-2612)
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                owner_,
                spender,
                value,
                currentNonce,
                deadline
            )
        );
        // EIP-712 도메인 구분자와 결합한 digest 계산
        bytes32 digest = _toTypedDataHash(structHash); //test(7) 핵심
        // 서명 복구
        address recovered = ecrecover(digest, v, r, s);
        require(recovered != address(0) && recovered == owner_, "INVALID_SIGNER"); // test(6) 핵심
        
        // nonce 증가 및 allowance 설정(test(4) 핵심)
        nonces[owner_] = currentNonce + 1; //test2-56
        allowance[owner_][spender] = value; //test2-55
        emit Approval(owner_, spender, value); //이벤트 기록
    }
}