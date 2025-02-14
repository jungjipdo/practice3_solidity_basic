// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract Quiz{
    struct Quiz_item {
      uint id;
      string question;
      string answer;
      uint min_bet;
      uint max_bet;
   }
    //필요한 변수 선언
    address public owner;
    Quiz_item[] public quizs; //퀴즈 목록
    mapping(uint => mapping(address => uint)) public bets; // (quiz id - 1) → (user address → bet amount)
    mapping(address => uint) public winnings; 
    uint public vault_balance; //오답으로 인해 모아진 금액

    constructor () {
        owner = msg.sender;
        Quiz_item memory q;
        q.id = 1;
        q.question = "1+1=?";
        q.answer = "2";
        q.min_bet = 1 ether;
        q.max_bet = 2 ether;
        addQuiz(q);
    }

    receive() external payable {}

    
    //퀴즈 등록
    function addQuiz(Quiz_item memory q) public {
        require(msg.sender == owner, "Only owner can add quiz");
        q.id = quizs.length + 1;
        quizs.push(q);
    }
   
    //퀴즈 정답 반환
    function getAnswer(uint quizId) public view returns (string memory){
        require(quizId > 0 && quizId <= quizs.length, "Quiz not exist");
        Quiz_item memory q = quizs[quizId - 1];
        return quizs[quizId - 1].answer;
    }
    
    //퀴즈 정보 조회(정답은 숨김)
    function getQuiz(uint quizId) public view returns (Quiz_item memory) {
        require(quizId > 0 && quizId <= quizs.length, "Quiz not exist");
        Quiz_item memory q = quizs[quizId - 1];
        q.answer = "";
        return q;
    }

    //등록된 퀴즈 갯수 반환
    function getQuizNum() public view returns (uint){
        return quizs.length;
    }

    //퀴즈 배팅(최소,최대 금액제한)
    function betToPlay(uint quizId) public payable {
        require(quizId > 0 && quizId <= quizs.length, "Quiz not exist");
        Quiz_item memory q = quizs[quizId - 1];
        require(msg.value >= q.min_bet && msg.value <= q.max_bet);
        bets[quizId - 1][msg.sender] += msg.value;

    }

    //정답 맞추면 배팅 금액 2배, 오답이면 소멸
    function solveQuiz(uint quizId, string memory ans) public returns (bool) {
        require(quizId > 0 && quizId <= quizs.length, "Quiz not exist");
        require(bets[quizId - 1][msg.sender] > 0, "No bet placed");
        Quiz_item memory q = quizs[quizId - 1];
        uint bet = bets[quizId - 1][msg.sender];

        if(keccak256(abi.encodePacked(ans)) == keccak256(abi.encodePacked(q.answer))){
            winnings[msg.sender] += bet * 2;
            return true;
        }else{
            vault_balance += bet;
            bets[quizId - 1][msg.sender] = 0;
            return false;
        }
    }

    //정답자에게 보상 지급
    function claim() public {
        uint amount = winnings[msg.sender];
        require(winnings[msg.sender] > 0, "No winnings to claim");
        winnings[msg.sender] = 0; //effect
        payable(msg.sender).transfer(amount); //interaction
    }
   
}
