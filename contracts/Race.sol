pragma solidity >=0.4.1 <=0.4.20;
import "github.com/oraclize/ethereum-api/oraclizeAPI.sol";
/*
    ContractStatus:
        Initializing - контракт создан, нет участников, дата аукциона не прошла, аукцион не начат
        Auction - дата аукциона не прошла, аукцион начат
        AuctionFault - дата аукциона прошла, не выполнены минимальные условия старта гонки
        (нужно определить) например количество участников, сумма сборов
        PreparationForTheRace - есть участники, дата аукциона прошла, дата гонки не прошла
        RaceIsOver - дата гонги прошла, есть победитель
        Stop - остановка контракта владельцем
        AuctionEnded - аукцион завершен успешно
*/
contract Race is usingOraclize{
    using SafeMath for uint256;
//VARIABLES----------------------------------------------------------------------
    bool contractStoped; //остановка контракта
    bool auctionStarted; //признак что аукцион начат
    bool raceFinished;
    bool auctionEnded; // признак что аукцион завершен успешно
    uint maxCar; //Максимальное количество автомобилей в гонке (от 2 до 32)
    uint randomNumber;
    uint[] upgradesPower;
    uint256[] upgradesPrice;
    address owner; //владелец контракта
    address beneficiary; //получатель выгоды
    uint auctionEndDate; //дата завершения аукциона
    uint raceStartDate; //дата завершения гонки
    uint256 reward; //награда победителя гонок
    address[] highestBidders; //адрес самого выского претендента для кадого автомобиля[порядковый номер автомобиля]
    uint256[] highestBids; //самая высокая ставка для кадого автомобиля [порядковый номер автомобиля]
    uint[] carsPower; // апгрейды автомобилей, до двух знаков после запятой, по умолчанию 10000
    uint[] carUpgradePurchased;
    uint winner;
    uint allCarsPower;
    uint constant CUSTOM_GASLIMIT = 250000; // лимит газа для oriclize.io
    uint constant CUSTOM_GASPRICE = 4000000000; // цена за газ для oriclize.io
    mapping(address => uint256) pendingReturns; //возврат средств участникам аукциона   

    enum ContractStatus {
        Initialising, 
        Auction,
        AuctionFault,
        PreparationForTheRace,
        RaceIsOver,
        Stop,
        AuctionEnded
    }
//EVENTS----------------------------------------------------------------------  
    event HighestBidIncreased(address sender, uint256 value, uint carIndex); // событие об увеличение максимальной ставки для тачки
    event AuctionEnded(); // событие об успешном завершении аукциона
    event AuctionStarted(uint256 reward); // событие о начале аукциона
    event AuctionCanceled();
    event Winer(uint winner, uint random, string oricalize_random);
    event AllCarsPower(uint allCarsPower);
    event ProofError();
//MODIFER---------------------------------------------------------------------  
    modifier auctionInProgress(){
        require(getContractStatus() == ContractStatus.Auction);
        _;
    }
    modifier auctionInInitialising(){
        require(getContractStatus() == ContractStatus.Initialising);
        _;
    }
    // modifier auctionNotFault(){
    //     require(getContractStatus() != ContractStatus.AuctionFault);
    //     _;
    // }
    modifier auctionIsEnded(){
        require(getContractStatus() == ContractStatus.AuctionEnded);
        _;
    }
    modifier contractIsNormal(){
        require(getContractStatus() != ContractStatus.Stop);
        _;
    }
    modifier ContractInPreparationForTheRace(){
        require(getContractStatus() == ContractStatus.PreparationForTheRace);
        _;       
    }
    modifier ContractInRaceIsOver(){
        require(getContractStatus() == ContractStatus.RaceIsOver);
        _;       
    }

//CONSTRUCTOR---------------------------------------------------------------------
    function Race(address _beneficiary, uint _auctionEndDate, uint _raceStartDate, uint _maxCar) public {
        require(_auctionEndDate > now);
        require(_raceStartDate > _auctionEndDate);
        require((_maxCar >= 2) && (_maxCar <= 32));
        auctionStarted = false;
        contractStoped = false;
        auctionEnded = false;
        raceFinished = false;
        randomNumber = 0;
        auctionEndDate = _auctionEndDate;
        raceStartDate = _raceStartDate;
        maxCar = _maxCar;
        owner = msg.sender;
        beneficiary = _beneficiary;
        reward = 0;
        winner = 1000;
        initCars(maxCar);
        initUpgrades();
        oraclize_setCustomGasPrice(CUSTOM_GASPRICE);
        oraclize_setProof(proofType_Ledger);

    }

    function initCars(uint carsCount) internal {
        for (uint i = 0; i < carsCount; i++){
            highestBidders.push(0);
            highestBids.push(0);
            carsPower.push(10000);
            carUpgradePurchased.push(0);
        }
        allCarsPower = getAllCarsPower();
    }

    function initUpgrades() internal {
        //upgrade 1
        upgradesPower.push(1000);
        upgradesPrice.push(10 finney);

        //upgrade 2
        upgradesPower.push(4000);
        upgradesPrice.push(40 finney);

        //upgrade 3
        upgradesPower.push(5000);
        upgradesPrice.push(50 finney);
    }

    function getAuctionEndDate() public view returns(uint){
        return auctionEndDate;
    }

    function getRaceStartDate() public view returns(uint){
        return raceStartDate;
    }

    function getContractStatus() public view returns(ContractStatus){
        if (contractStoped) return ContractStatus.Stop;
        //ContractStatus.Initialising---------------------------------------------------------------------
        if ((now < auctionEndDate) && !auctionStarted && !auctionEnded) return ContractStatus.Initialising;

        //ContractStatus.AuctionFault--------------------------------------------------------------------------
        if ((now >= auctionEndDate) && auctionStarted && !auctionEnded)
        {
            uint256 amount;
            for (uint i = 0; i < maxCar; i++) amount = amount.add(highestBids[i]);
            //если сумма сборов не превышает награду, считаем аукцион не состоявшимся
            if (amount <= reward) return ContractStatus.AuctionFault;
            //если не задействованы все тачки, считаем аукцион не состоявшимся
            for (uint j = 0; j < maxCar; j++) if (highestBidders[j] == 0) return ContractStatus.AuctionFault;

            //Если все ок, то Auction Ended--------------------------------------------------------------------------
            return ContractStatus.AuctionEnded;
        }
        
        //ContractStatus.Auction--------------------------------------------------------------------------
        if ((now < auctionEndDate) && auctionStarted && !auctionEnded) return ContractStatus.Auction;


        //ContractStatus.PreparationForTheRace--------------------------------------------------------------------------
        if ((now >= auctionEndDate) && auctionEnded && (now < raceStartDate)) return ContractStatus.PreparationForTheRace;

        //ContractStatus.RaceIsOver--------------------------------------------------------------------------
        if (auctionEnded && (now >= raceStartDate)) return ContractStatus.RaceIsOver;

        //состояние по умолчанию
        return ContractStatus.Stop;
    }
    //какая награда за победу
    function getRewardValue() public view returns(uint256){
        return reward;
    }
    //какой не выплаченый баланс
    function getPandingReturnValue() public view returns(uint256){
        return pendingReturns[msg.sender];
    }

    //кто победитель, 1000 если победитель не определен
    function getWinner() public view returns(uint){
        return winner;
    }

    //Количество учасников
    function getMaxCarValue() public view returns(uint){
        return maxCar;
    }  
//FUNCTIONS AUCTION--------------------------------------------------------------------- 
    //ставка на машину с индексом carIndex
    function bid(uint carIndex)
        auctionInProgress
        contractIsNormal
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
        HighestBidIncreased(msg.sender, msg.value, carIndex);
    }

    //запуск аукциона, перечесление награды
    function auctionStart()
        auctionInInitialising
        contractIsNormal
        public
        payable
    {
        require(msg.value > 0);
        reward = msg.value;
        auctionStarted = true;
        AuctionStarted(reward);
    }

    //возрат ставки в случае перекупа тачки
    function withdraw()  
        public 
        returns (bool) 
    {
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
    function auctionEnd() 
        auctionIsEnded
        public 
    {
        require(now >= auctionEndDate);
        require(!auctionEnded);
        require(auctionStarted);
        auctionEnded = true;
        auctionStarted = false;
        AuctionEnded();
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

    //
    function auctionCancel()
        public
    {
        if ((getContractStatus() == ContractStatus.AuctionFault) || (getContractStatus() == ContractStatus.Stop)){
            for (uint i = 0; i < maxCar; i++){
                if (highestBidders[i] != 0){
                    pendingReturns[highestBidders[i]] = pendingReturns[highestBidders[i]].add(highestBids[i]);
                    highestBidders[i] = 0;
                    highestBids[i] = 0;
                }
            }
            pendingReturns[beneficiary] = pendingReturns[beneficiary].add(reward);
            reward = 0;
            auctionStarted = false;
            auctionEnded = false;
            contractStoped = true;
            AuctionCanceled();
        }
    }

//FUNCTIONS Preparation for the Race---------------------------------------------------------------------
    //узнаем сколько апгрейдов существует всего
    function getUpgradesCount() public view returns(uint){
        return upgradesPower.length;
    }
    //узнаем стоимость апгрейда с индексом index
    function getUpgradesPrice(uint index) public view returns(uint256){ 
        if (index < upgradesPrice.length) return upgradesPrice[index];
        return 0;
    }
    //узнаем мощьность автомобиля с индексом carIndex
    function getCarPower(uint carIndex) public view returns(uint){
        if (carIndex < maxCar) return carsPower[carIndex];
        return 0;
    }
    //узнаем сколько апгрейдов установлено на машину с индексом carIndex
    function getCarUpgrades(uint carIndex) public view returns(uint){
        if (carIndex < carUpgradePurchased.length) return carUpgradePurchased[carIndex];
        return 0;
    }

    //проверка что машина принадлежит "мне"
    function isMyCar(uint carIndex) public view returns(bool){
        if (carIndex >= highestBidders.length) return false;
        if ((highestBidders[carIndex] == msg.sender) && (getContractStatus() != ContractStatus.Auction)) return true;
        return false;
    }
    //покупка апгрейда тачки
    function upgradeCar(uint carIndex)
        ContractInPreparationForTheRace
        public
        payable
    {
        require(isMyCar(carIndex));
        require((getCarUpgrades(carIndex)) < getUpgradesCount());
        require(msg.value == (upgradesPrice[carUpgradePurchased[carIndex]]));
        carsPower[carIndex] = carsPower[carIndex].add(upgradesPower[carUpgradePurchased[carIndex]]);
        pendingReturns[beneficiary] = pendingReturns[beneficiary].add(msg.value);
        carUpgradePurchased[carIndex] += 1;
    }
//FUNCTIONS RACE---------------------------------------------------------------------
    function race()
        contractIsNormal
        ContractInRaceIsOver
        public
        payable
    {
        require(!raceFinished);
        require(msg.value == getOraclizePrice());
        uint N = 7;
        uint delay = 1;
        allCarsPower = getAllCarsPower();
        AllCarsPower(allCarsPower);
        oraclize_newRandomDSQuery(delay, N, CUSTOM_GASLIMIT);
    }

    function getOraclizePrice() public view returns (uint){
        return oraclize_getPrice("random", CUSTOM_GASLIMIT);
    }

    function __callback(bytes32 _queryId, string _result, bytes _proof) public
    { 
        require(raceFinished == false);
        require(msg.sender == oraclize_cbAddress());
        
        if (oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) != 0) {
            ProofError();
        } else {
            randomNumber = uint(sha3(_result)) % allCarsPower;
            winner = getWinnerCar(randomNumber);
            pendingReturns[highestBidders[winner]] = pendingReturns[highestBidders[winner]].add(reward);
            reward = 0;
            Winer(winner, randomNumber);
            raceFinished = true;
        }
    }

    function getAllCarsPower() public view returns(uint){
        uint power = 0;
        for (uint i = 0; i < maxCar; i++){
            power = power.add(carsPower[i]);
        }
        return power;
    }
    function getWinnerCar(uint random) internal view returns(uint){
        uint buf = 0;
        for (uint i = 0; i < maxCar; i++){
            buf = buf.add(carsPower[i]);
            if (random <= buf) return i;
        }
        return 1000;
    }

    function reset()
        public
    {
        require(raceFinished);
        require(msg.sender == owner);
        if (this.balance > 0) {
            if (msg.sender.send(this.balance)) {
                contractStoped = true;
            }
        }
        else contractStoped = true;
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
        assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        assert(a == b * c + a % b); // There is no case in which this doesn't hold
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
