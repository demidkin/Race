pragma solidity ^0.4.22; // solhint-disable-line

/*
    ContractStatus:
        Initializing - контракт создан, нет участников, дата аукциона не прошла, аукцион не начат
        Auction - дата аукциона не прошла, аукцион начат
        AuctionFault - дата аукциона прошла, не выполнены минимальные условия старта гонки
        (нужно определить) например количество участников, сумма сборов
        PreparationForTheRace - есть участники, дата аукциона прошла, дата гонки не прошла
        RaceIsOver - дата гонги прошла, есть победитель
        Stop - остановка контракта владельцем
*/

contract Race {
    using SafeMath for uint256;
//VARIABLES----------------------------------------------------------------------
    bool contractStoped; //остановка контракта владельцем
    bool auctionStarted; //признак что аукцион начат
    bool auctionEnded; // признак что аукцион завершен
    uint maxCar; //Максимальное количество автомобилей в гонке (от 2 до 32)
    address owner; //владелец контракта
    address beneficiary; //получатель выгоды
    uint auctionEndDate; //дата завершения аукциона
    uint raceStartDate; //дата завершения гонки
    uint256 reward; //награда победителя гонок
    address[] highestBidders; //адрес самого выского претендента для кадого автомобиля[порядковый номер автомобиля]
    uint256[] highestBids; //самая высокая ставка для кадого автомобиля [порядковый номер автомобиля]
    uint[] carsPower; // апгрейды автомобилей, до двух знаков после запятой, по умолчанию 10000
    mapping(address => uint256) pendingReturns; //возврат средств участникам аукциона   

    enum ContractStatus {
        Initsialising, 
        Auction,
        AuctionFault,
        PreparationForTheRace,
        RaceIsOver,
        Stop
    }
//EVENTS----------------------------------------------------------------------  
    event HighestBidIncreased(address sender, uint256 value, uint carIndex); // событие об увеличение максимальной ставки для тачки
    event AuctionEnded(); // событие об успешном завершении аукциона
    event AuctionStarted(uint256 reward); // событие о начале аукциона
//MODIFER---------------------------------------------------------------------  
    modifier auctionInProgress(){
        require(getContractStatus() == ContractStatus.Auction);
        _;
    }
    modifier auctionInInitsialising(){
        require(getContractStatus() == ContractStatus.Initsialising);
        _;
    }

//CONSTRUCTOR---------------------------------------------------------------------
    constructor(address _beneficiary, uint _auctionEndDate, uint _raceStartDate, uint _maxCar) public {
        require(_auctionEndDate > now);
        require(_raceStartDate > _auctionEndDate);
        require((_maxCar >= 2) && (_maxCar <= 32));
        auctionStarted = false;
        contractStoped = false;
        auctionEnded = false;
        auctionEndDate = _auctionEndDate;
        raceStartDate = _raceStartDate;
        maxCar = _maxCar;
        owner = msg.sender;
        beneficiary = _beneficiary;
        reward = 0;
        initCars(maxCar);
    }

    function initCars(uint carsCount) internal {
        for (uint i = 0; i < carsCount; i++){
            highestBidders.push(0);
            highestBids.push(0);
            carsPower.push(10000);
        }
    }

    function getContractStatus() public view returns(ContractStatus){
        if (contractStoped) return ContractStatus.Stop;
        //ContractStatus.Initsialising---------------------------------------------------------------------
        if ((now <= auctionEndDate) && !auctionStarted && !auctionEnded) return ContractStatus.Initsialising;
        
        //ContractStatus.Auction--------------------------------------------------------------------------
        if ((now <= auctionEndDate) && auctionStarted && !auctionEnded) return ContractStatus.Auction;

        //ContractStatus.AuctionFault--------------------------------------------------------------------------
        

        //ContractStatus.PreparationForTheRace--------------------------------------------------------------------------
        

        //ContractStatus.RaceIsOver--------------------------------------------------------------------------
        

        //состояние по умолчанию
        return ContractStatus.Stop;
    }

//FUNCTIONS AUCTION---------------------------------------------------------------------
    //ставка на машину с индексом carIndex
    function bid(uint carIndex)
        auctionInProgress
        public
        payable
    {
        require(carIndex < maxCar);
        require(msg.value > highestBids[carIndex]);
        if (highestBids[carIndex] != 0) {
            pendingReturns[highestBidders[carIndex]] = pendingReturns[highestBidders[carIndex]].add(highestBids[carIndex]);
        }
        highestBidders[carIndex] = msg.sender;
        highestBids[carIndex] = msg.value;
        emit HighestBidIncreased(msg.sender, msg.value, carIndex);
    }

    //запуск аукциона, перечесление награды
    function auctionStart()
        auctionInInitsialising
        public
        payable
    {
        reward = msg.value;
        auctionStarted = true;
        emit AuctionStarted(reward);
    }

    //возрат ставки в случае перекупа тачки
    function withdraw() public returns (bool) {
        uint256 amount = pendingReturns[msg.sender];
        if (amount > 0) {
            pendingReturns[msg.sender] = 0;
            if (!msg.sender.send(amount)) {
                pendingReturns[msg.sender] = amount;
                return false;
            }
        }
        return true;
    }

    //завершщение аукциона, забираем ставки
    function auctionEnd() public {
        require(now >= auctionEndDate);
        require(!auctionEnded);
        require(auctionStarted);
        auctionEnded = true;
        auctionStarted = false;
        emit AuctionEnded();
        uint256 amount;
        for (uint i = 0; i < maxCar; i++) amount = amount.add(highestBids[i]);
        beneficiary.transfer(amount);
    }
    
    //узнаем максимальную ставку для тачки с индексом carIndex
    function gethighestBid(uint carIndex) public view returns (uint256){
        require(carIndex < maxCar);
        return highestBids[carIndex];
    }

    //узнаем выиграла ли наша ставка для тачки с индексом carIndex
    function myBidIsWin(uint carIndex) public view returns (bool){
        require(carIndex < maxCar);
        if (highestBidders[carIndex] == msg.sender) return true;
        return false;
    }

}



//UTILITES==========================================================================================
    /**
    * @title SafeMath
    * @dev Math operations with safety checks that throw on error
    */
library SafeMath {

    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}
