pragma solidity ^0.4.22; // solhint-disable-line

/*
    ContractStatus:
        Initializing - контракт создан, нет участников, дата аукциона не прошла
        Auction - есть участники, дата аукциона не прошла
        AuctionFault - дата аукциона прошла, не выполнены минимальные условия старта гонки
        (нужно определить) например количество участников, сумма сборов
        PreparationForTheRace - есть участники, дата аукциона прошла, дата гонки не прошла
        RaceIsOver - дата гонги прошла, есть победитель
        Stop - остановка контракта владельцем
*/

contract Race {
    using SafeMath for uint256;

    bool contractStoped; //остановка контракта владельцем
    bool auctionStarted; //
    bool auctionEnded; // признак что аукцион завершен
    uint maxCar; //Максимальное количество автомобилей в гонке (от 2 до 32)
    address owner; //владелец контракта
    address beneficiary; //получатель выгоды
    uint auctionEndDate; //дата завершения аукциона
    uint raceEndDate; //дата завершения гонки
    address[] public highestBidders; //адрес самого выского претендента для кадого автомобиля[порядковый номер автомобиля]
    uint256[] public highestBids; //самая высокая ставка для кадого автомобиля [порядковый номер автомобиля]
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
    event AuctionEnded(); // событие о завершении аукциона
//MODIFER---------------------------------------------------------------------  
    modifier auctionInProgress(){
        require(!auctionEnded);
        require((getContractStatus() == ContractStatus.Initsialising) || (getContractStatus() == ContractStatus.Auction));
        _;
    }

//CONSTRUCTOR---------------------------------------------------------------------
    constructor(address _beneficiary, uint _auctionEndDate, uint _raceEndDate, uint _maxCar) public {
        require(_auctionEndDate > now);
        require(_raceEndDate > _auctionEndDate);
        require((_maxCar >= 2) && (_maxCar <= 32));
        auctionStarted = false;
        contractStoped = false;
        auctionEnded = false;
        auctionEndDate = _auctionEndDate;
        raceEndDate = _raceEndDate;
        maxCar = _maxCar;
        owner = msg.sender;
        beneficiary = _beneficiary;
        initCars(maxCar);
    }

    function initCars(uint carsCount) internal {
        for (uint i = 0; i < carsCount; i++){
            highestBidders.push(0);
            highestBids.push(0);
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
        require((carIndex >= 2) && (carIndex <= 32));
        require(msg.value > highestBids[carIndex]);
        if (highestBids[carIndex] != 0) {
            pendingReturns[highestBidders[carIndex]] = pendingReturns[highestBidders[carIndex]].add(highestBids[carIndex]);
        }
        highestBidders[carIndex] = msg.sender;
        highestBids[carIndex] = msg.value;
        if (!auctionStarted) auctionStarted = true;
        emit HighestBidIncreased(msg.sender, msg.value, carIndex);
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
        auctionEnded = true;
        emit AuctionEnded();
        uint256 amount;
        for (uint i = 0; i < maxCar; i++) amount = amount.add(highestBids[i]);
        beneficiary.transfer(amount);
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
