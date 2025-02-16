// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Lottery {
    // -----------------------------------------------------
    // 상태 변수 (필요시 추가 가능)
    // -----------------------------------------------------
    uint256 public ticketPrice;       // 티켓 가격(0.1 eth)
    uint256 public saleStartTime;     // 티켓 판매 시작
    uint256 public saleDuration;      // 판매 기간(24hours)
    uint256 public vaultBalance;      // 티켓 판매로 모인 자금
    uint16 public winningNumber;      // 당첨번호
    uint256 public totalWinners;
    uint256 public payoutPerWinner;


    // 티켓 정보를 저장하기 위한 struct 사용
    struct Ticket {
        address buyer; //구매자
        uint16 guess; //추첨번호
    }
    Ticket[] public tickets;          // 구매된 모든 티켓을 저장할 배열

    // 복권 진행 단계 관리를 위한 enum
    enum LOTTERY_STATE { SELL, DRAW, CLAIM }
    LOTTERY_STATE public lotteryState;  // 현재 복권 진행 단계

    mapping(address => bool) public hasBought; //중복 구매 방지 
    mapping(address => bool) public hasClaimed; //중복 청구 방지

    // -----------------------------------------------------
    // 생성자: Lottery 파라미터 초기화
    // -----------------------------------------------------
    constructor() {
        ticketPrice = 0.1 ether;          
        saleDuration = 24 hours;          
        saleStartTime = block.timestamp;  
        lotteryState = LOTTERY_STATE.SELL; 
        vaultBalance = 0;              
    }


    // -----------------------------------------------------
    // 함수: buy -> 단계,시간,가격,중복 확인
    // -----------------------------------------------------
    function buy(uint16 _guess) external payable {//payble로 설정해야 이더 받기 가능
        require(lotteryState == LOTTERY_STATE.SELL, "Lottery is not in SELL phase");//단계확인
        require(block.timestamp < saleStartTime + saleDuration, "Sale phase ended");//시간확인
        require(msg.value == ticketPrice, "Incorrect ticket price"); //가격확인(0.1 eth 맞는지)
        require(!hasBought[msg.sender], "You have already bought a ticket"); //중복확인
        tickets.push(Ticket(msg.sender, _guess));
        vaultBalance += msg.value; //누적 판매 금액
        hasBought[msg.sender] = true; //중복 구매 방지
    }

    // -----------------------------------------------------
    // 함수: draw -> 판매기간 이후,SELL에서만,난수 생성(고민..)
    // -----------------------------------------------------
    function draw() external {
        require(block.timestamp >= saleStartTime + saleDuration, "Sale phase not ended");//판매 기간이 끝난 후
        require(lotteryState == LOTTERY_STATE.SELL, "Draw already executed or lottery closed");//SELL 단계
        winningNumber = uint16(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 1000);
        // chainlink VRF 고려해보기
        totalWinners = 0;
        for (uint i = 0; i < tickets.length; i++) {
            if (tickets[i].guess == winningNumber) {
                totalWinners++;
            }   
        }
        // 당첨자가 있다면 각 당첨자의 지급액을 미리 계산
        if (totalWinners > 0) {
            payoutPerWinner = vaultBalance / totalWinners;
        }
    
        lotteryState = LOTTERY_STATE.CLAIM;


    }

    // -----------------------------------------------------
    // 함수: claim -> 당첨번호 일치시 청구,중복 청구 방지,RollOver
    // -----------------------------------------------------
    function claim() external{
        require(lotteryState == LOTTERY_STATE.CLAIM, "Not in claim phase"); //CLAIM 단계인지 확인
        require(hasClaimed[msg.sender] == false, "You have already claimed your prize"); //중복 청구 방지
        if (totalWinners == 0) {
            resetLottery();
            return;
        }

        bool isWinner = false;
        
        // 호출자가 당첨자인지
        for (uint i = 0; i < tickets.length; i++) {
            if (tickets[i].buyer == msg.sender && tickets[i].guess == winningNumber) {
                isWinner = true;
                hasClaimed[msg.sender] = true; //중복 청구 방지
            }
        }

        
        if (isWinner) {
        vaultBalance -= payoutPerWinner;
        (bool success, ) = payable(msg.sender).call{value: payoutPerWinner}("");
        require(success, "Transfer failed");
        totalWinners--;
        }


        if (totalWinners == 0)
            resetLottery();

    }

    // -----------------------------------------------------
    // 보조 함수: resetLottery -> for RollOver, 초기화, 자금 이월, SELL 단계로 변경
    // -----------------------------------------------------
    function resetLottery() internal {
        delete tickets; //초기화                
        saleStartTime = block.timestamp; //시간 재설정

        //사용자 개개인별 초기화
        hasBought[msg.sender] = false;
        hasClaimed[msg.sender] = false;
        
        //모든 티켓에 대해 초기화
        for (uint i = 0; i < tickets.length; i++) {
            hasBought[tickets[i].buyer] = false;
            hasClaimed[tickets[i].buyer] = false;
        } 

        lotteryState = LOTTERY_STATE.SELL; // 상태전환 
        //자금 이월은 vaultBalance에 저장된 값이 그대로 유지
    }
}
