pragma solidity ^0.4.22;


contract BreadCoin {
    using SafeMath for uint256;

    struct Member {
        bool memberStatus;
        uint256 Phone; // в будущем было бы интересно написать бота вайбер или телеграм, кторый будет отслеживат события и слать уведомелния
    }
    enum ContractStatus{ Initsialising, Normal }
    string name;
    string code;
    address[] memberList; //члены сообщества
    address[] candidats; //кандидаты на добавление в сообщество
    address[] candidatsToRemove; //кандидаты на удаление из сообщества
    address[] toMint; // кандидаты на выпуск токенов
    address[] toUnMint; // кандидаты на сжигание токенов
    address Owner;
    
    uint256 TotalSupply;
    mapping (address => Member) Members;
    mapping (address => uint256) balances;
    mapping (address => uint256) mintValue;
    mapping (address => uint256) unMintValue;
    //адрес кандидата, адрес голосующего, голос
    mapping (address => mapping (address => bool)) internal candidatVoting; //для голосования за доабвления нового члена сообщества
    //адрес кандидата, адрес голосующего, голос
    mapping (address => mapping (address => bool)) internal candidatRemoveVoting; //для голосования за удаление члена сообщества
    //кому минтим, адрес голосующего, голос
    mapping (address => mapping (address => bool)) internal mintVoting; //для голосования на выпуск токенов
    //у кого, адрес голосующего, голос
    mapping (address => mapping (address => bool)) internal unMintVoting; //для голосования на сжигание токенов
    // от кого, кому, сколько
    mapping (address => mapping (address => uint256)) internal payments; //для голосования на выплату токенов другому участнику

//EVENTS---_------------------------------------------------------------------  
    event NewCandidatVotingToAdd(address candidat); //о добавлении кандидата
    event MemberAdded(address member); //о добавлении нового члена
    event Rejectedcandidat(address candidat); // об отклонении кандидата
    event NewPayment(address from, address to, uint256 value); // Создан новый платеж
    event PaymentAccepted(address from, address to, uint256 value);// принятие входящего платежа
    event PaymentRejected(address from, address to, uint256 value);// отклонение входящего платежа
    event MemberRemoved(address member); //об удалении члена
    event NewCandidatVotingToRemove(address member); //о добавлении кандидата на удаление
    event MemberNotRemoved(address candidat); // Об отказе удаления члена
    event Minted(address toMember, uint256 value); // голосование на минтинг заверщено положительно
    event NotMinted(address toMember, uint256 value);// голосование на минтинг заверщено отрицательно
    event NotUnMinted(address toMember, uint256 value);// голосование на ан-минтинг заверщено отрицательно
    event NewMintVoting(address toMember, uint256 value); // голосования на минтинг начато
    event UnMinted(address toMember, uint256 value); // голосование на ан-минтинг заверщено положительно
    event NewUnMintVoting(address toMember, uint256 value);// голосования на ан-минтинг начато

//MODIFER---------------------------------------------------------------------  
    modifier isMember(address member){
        if (getContractStatus() == ContractStatus.Normal){
            require(Members[member].memberStatus == true);
        }
        else {
            require(msg.sender == Owner);
        }
        _;
    }

    modifier contractIsNormall(){
        require(getContractStatus() == ContractStatus.Normal);
        _;
    }

    modifier haveMoney(address member, uint256 value){
        require((balances[member] - value) >= 0);
        _;
    }



//CONSTRUCTOR------------------------------------------------------------------
    constructor()
        public 
       // DetailedERC20("BreadCoin", "BREAD", 18)
    {
        name = "BreadCoin";
        code = "BREAD";
        Owner = msg.sender;
        TotalSupply = 0;
    }


//BreadCoin Function
    function unMint(address toMember, uint256 value)
        public
        isMember(msg.sender)
        isMember(toMember)
        returns (bool)
    {
        require(toUnMint.length < 256);
        require(value > 0);
        require(unMintValue[toMember] == 0);
        require(balances[toMember] >= value);
        
        // если еще нет членов, то сразу ан-минтим без голосования
        if (getContractStatus() == ContractStatus.Initsialising){
            balances[toMember] = balances[toMember].sub(value);
            TotalSupply = TotalSupply.sub(value);      
            emit UnMinted(toMember, value);      
        }
        // если только один член то сразу ан-минтим без голосвания
        else if ((getContractStatus() == ContractStatus.Normal) && (memberList.length == 1)){
            balances[toMember] = balances[toMember].sub(value);
            TotalSupply = TotalSupply.sub(value);      
            emit UnMinted(toMember, value);  
        }
        // запуск голосования на минтинг
        else {
            resetUnMintVoting(toMember);
            toUnMint.push(toMember);
            unMintValue[toMember] = value; 
            unMintVoting[toMember][msg.sender] = true;
            unMintVoting[toMember][toMember] = true;
            emit NewUnMintVoting(toMember, value);
        }

        return true;
    }

    function mint(address toMember, uint256 value)
        public
        isMember(msg.sender)
        isMember(toMember)
        returns (bool)
    {
        require(toMint.length < 256);
        require(value > 0);
        require(mintValue[toMember] == 0);
        
        // если еще нет членов, то сразу минтим без голосования
        if (getContractStatus() == ContractStatus.Initsialising){
            balances[toMember] = balances[toMember].add(value);
            TotalSupply = TotalSupply.add(value);      
            emit Minted(toMember, value);      
        }
        // если только один член то сразу доабвялем без голосвания
        else if ((getContractStatus() == ContractStatus.Normal) && (memberList.length == 1)){
            balances[toMember] = balances[toMember].add(value);
            TotalSupply = TotalSupply.add(value);      
            emit Minted(toMember, value);  
        }
        // запуск голосования на минтинг
        else {
            resetMintVoting(toMember);
            toMint.push(toMember);
            mintValue[toMember] = value; 
            mintVoting[toMember][msg.sender] = true;
            mintVoting[toMember][toMember] = true;
            emit NewMintVoting(toMember, value);
        }

        return true;
    }

    function resetMintVoting(address toMember) internal{
        for (uint i = 0; i < memberList.length; i++) mintVoting[toMember][memberList[i]] = false;
    }

    function resetUnMintVoting(address toMember) internal{
        for (uint i = 0; i < memberList.length; i++) unMintVoting[toMember][memberList[i]] = false;
    }

    function acceptMint(address toMember) public isMember(msg.sender) returns (bool){
        // проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < toMint.length; i++){
            if (toMint[i] == toMember){
                mintVoting[toMember][msg.sender] = true;
                votingToMintIsEnd(toMember);
                return true;
            }
        } 

        return false;
    }

    function acceptUnMint(address toMember) public isMember(msg.sender) returns (bool){
        // проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < toUnMint.length; i++){
            if (toUnMint[i] == toMember){
                unMintVoting[toMember][msg.sender] = true;
                votingToUnMintIsEnd(toMember);
                return true;
            }
        } 

        return false;
    }

    function votingToMintIsEnd(address toMember) internal returns (bool){

        //если хоть один член сообщества не проголосовал выходим
        for (uint i = 0; i < memberList.length; i++){
            if (!mintVoting[toMember][memberList[i]]) return false;
        }
        //удаляем кандидата из кандидатов на минтинг и ...
        if(deleteMemberToMint(toMember)){
            uint256 value = mintValue[toMember];
            balances[toMember] = balances[toMember].add(value);
            TotalSupply = TotalSupply.add(value);
            mintValue[toMember] = 0;
            emit Minted(toMember, value);
            return true;
        }
        return false;
    }

    function votingToUnMintIsEnd(address toMember) internal returns (bool){

        //если хоть один член сообщества не проголосовал выходим
        for (uint i = 0; i < memberList.length; i++){
            if (!unMintVoting[toMember][memberList[i]]) return false;
        }
        //удаляем кандидата из кандидатов на минтинг и ...
        if(deleteMemberToUnMint(toMember)){
            uint256 value = unMintValue[toMember];
            balances[toMember] = balances[toMember].sub(value);
            TotalSupply = TotalSupply.sub(value);
            unMintValue[toMember] = 0;
            emit UnMinted(toMember, value);
            return true;
        }
        return false;
    }

    function getContractStatus() public view returns (ContractStatus){
        if (memberList.length == 0) return ContractStatus.Initsialising;
        if (memberList.length > 0){
            for (uint i = 0; i < memberList.length; i++) {
                if (Members[memberList[i]].memberStatus) return ContractStatus.Normal;
            }
        }
        return ContractStatus.Initsialising;
    }

    function addMember(address member, uint256 phone) 
        public 
        isMember(msg.sender)
        returns (bool)
    {
        require(memberList.length<256);
        require(candidats.length<256);
        require(member != address(0));
        require(candidatToAddIsNotCandidat(member));
        for (uint i = 0; i < memberList.length; i++) if (memberList[i] == member) return false;
        resetVotingAddMember(member);

        // если еще нет членов, то сразу добаввляем без голосования
        if (getContractStatus() == ContractStatus.Initsialising){
            Members[member].memberStatus = true;
            Members[member].Phone = phone;
            memberList.push(member);   
            emit MemberAdded(member);      
        }
        // если только один член то сразу доабвялем без голосвания, проверяем что есть на это досутп
        else if ((getContractStatus() == ContractStatus.Normal) && (memberList.length == 1)){
            Members[member].memberStatus = true;
            Members[member].Phone = phone;
            memberList.push(member);   
            emit MemberAdded(member);   
        }
        // запуск голосования на добавление новго члена
        else {
            candidats.push(member);
            Members[member].memberStatus = false;
            Members[member].Phone = phone;
            acceptcandidat(member);
            emit NewCandidatVotingToAdd(member);
        }
        return true;
    }

    function candidatToAddIsNotCandidat(address candidat) internal view returns (bool){
        if (candidats.length == 0) return true;
        for (uint i = 0; i < candidats.length; i++) if (candidats[i] == candidat) return false;
        return true;
    }

    function candidatToRemoveIsNotCandidat(address candidat) internal view returns (bool){
        if (candidatsToRemove.length == 0) return true;
        for (uint i = 0; i < candidatsToRemove.length; i++) if (candidatsToRemove[i] == candidat) return false;
        return true;
    }

    function removeMember(address candidat) 
        public 
        isMember(msg.sender)
        isMember(candidat)
        returns (bool)
    {
        require(candidatToRemoveIsNotCandidat(candidat));
        require(candidatsToRemove.length<256);
        resetVotingRemoveMember(candidat);
        if ((getContractStatus() == ContractStatus.Normal) && (memberList.length == 1) && (memberList[0] == msg.sender)){
            delete(Members[candidat].memberStatus);
            delete(Members[candidat].Phone);
            if (removeMemberToMemberList(candidat)) emit MemberRemoved(candidat);   
        }
        else {
            candidatRemoveVoting[candidat][msg.sender] = true;
            candidatRemoveVoting[candidat][candidat] = true;
            candidatsToRemove.push(candidat);
            emit NewCandidatVotingToRemove(candidat);
        }
        return true;
    }

    function getCandidatsToAdd() public view isMember(msg.sender) returns (address[]) {
        return candidats;
    }

    function getCandidatsToRemove() public view isMember(msg.sender) returns (address[]) {
        return candidatsToRemove;
    }

    function acceptcandidat(address candidat) public isMember(msg.sender) returns (bool){
        // проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < candidats.length; i++){
            if (candidats[i] == candidat){
                candidatVoting[candidat][msg.sender] = true;
                votingToAddMemberIsEnd(candidat);
                return true;
            }
        } 

        return false;
    }

    function acceptcandidatToRemove(address candidat) public isMember(msg.sender) returns (bool){
        require(msg.sender != candidat);
        require(!candidatRemoveVoting[candidat][msg.sender]);
        // проверяем есть ли такой кандидат, если есть то голосуем
        if (!candidatToRemoveIsNotCandidat(candidat)){
            candidatRemoveVoting[candidat][msg.sender] = true;
            votingToRemoveMemberIsEnd(candidat);
            return true;
        }
        return false;
    }

    function rejectcandidat(address candidat) public isMember(msg.sender) returns (bool){
        // проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < candidats.length; i++){
            if (candidats[i] == candidat){
                deletecandidatAddMember(candidat);
                emit Rejectedcandidat(candidat);
                return true;
            }
        }
        return false;
    }

    function rejectcandidatToRemove(address candidat) public isMember(msg.sender) returns (bool){
        require(msg.sender != candidat);
        // проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < candidats.length; i++){
            if (candidats[i] == candidat){

                if (deletecandidatRemoveMember(candidat))
                    emit MemberNotRemoved(candidat);
                return true;
            }
        }
        return false;
    }

    function rejectMintVoting(address toMember) public isMember(msg.sender) returns (bool){
        require(msg.sender != toMember);
        //проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < toMint.length; i++){
            if (toMint[i] == toMember){
                uint256 value = mintValue[toMember];
                mintValue[toMember] = 0;
                deleteMemberToMint(toMember);
                emit NotMinted(toMember,value);
                return true;
            }
        }
        return false;
    }

    function rejectUnMintVoting(address toMember) public isMember(msg.sender) returns (bool){
        require(msg.sender != toMember);
        //проверяем есть ли такой кандидат, если есть то голосуем
        for (uint i = 0; i < toUnMint.length; i++){
            if (toUnMint[i] == toMember){
                uint256 value = unMintValue[toMember];
                unMintValue[toMember] = 0;
                deleteMemberToUnMint(toMember);
                emit NotUnMinted(toMember,value);
                return true;
            }
        }
        return false;
    }

    function votingToAddMemberIsEnd(address candidat) internal returns (bool){

        //если хоть один член сообщества не проголосовал выходим
        for (uint i = 0; i < memberList.length; i++){
            if (!candidatVoting[candidat][memberList[i]]) return false;
        }
        //удаляем кандидата из кандидатов и ...
        if(deletecandidatAddMember(candidat)){
            //добавляем члена сообщества
            Members[candidat].memberStatus = true;
            memberList.push(candidat);   
            emit MemberAdded(candidat); 
            return true;
        }
        return false;
    }

    function votingToRemoveMemberIsEnd(address candidat) internal returns (bool){

        //если хоть один член сообщества не проголосовал выходим
        for (uint i = 0; i < memberList.length; i++){
            if (!candidatRemoveVoting[candidat][memberList[i]]) return false;
        }
        //удаляем кандидата из кандидатов и ...
        if(deletecandidatRemoveMember(candidat)){
            //удаляем члена сообщества
            delete(Members[candidat].memberStatus);
            delete(Members[candidat].Phone);
            if (removeMemberToMemberList(candidat)) 
            { 
                TotalSupply = TotalSupply.sub(balances[candidat]);
                balances[candidat] = 0;
                emit MemberRemoved(candidat); 
                return true;
            }
            
        }
        return false;
    }

    function resetVotingAddMember(address candidat) internal{
        for (uint i = 0; i < memberList.length; i++) candidatVoting[candidat][memberList[i]] = false;
    }

    function resetVotingRemoveMember(address candidat) internal{
        for (uint i = 0; i < memberList.length; i++) candidatRemoveVoting[candidat][memberList[i]] = false;
    }

    function removeMemberToMemberList(address member) internal returns (bool){
        require(memberList.length>0);
        //обунляем голосования для данного кондидата, на случай если вдруг его еще раз попробуют добавить
        resetVotingRemoveMember(member);
        //удаляем сразу если кандидат последний в списке
        if (memberList[memberList.length - 1] == member){
            delete memberList[memberList.length - 1];
            memberList.length--;
            return true;
		} 
		else 
		{
            bool shift = false;
            for (uint i = 0; i < memberList.length - 1; i++)
			{
                if (!shift && memberList[i] == member)
                {
                    shift = true;
                }
            
                if (shift == true) 
                {
                    memberList[i] = memberList[i+1];
                }
            }

            if (shift == true)
			{
                delete memberList[memberList.length-1];
                memberList.length--;
                return true;
			}	
		}	


        return false;
    }

    function deletecandidatAddMember(address candidat) internal returns (bool){
        require(candidats.length>0);
        //обунляем голосования для данного кондидата, на случай если вдруг его еще раз попробуют добавить
        resetVotingAddMember(candidat);
        //удаляем сразу если кандидат последний в списке
        if (candidats[candidats.length - 1] == candidat){
            delete candidats[candidats.length - 1];
            candidats.length--;
            return true;
		} 
		else 
		{
            bool shift = false;
            for (uint i = 0; i < candidats.length - 1; i++)
			{
                if (!shift && candidats[i] == candidat)
                {
                    shift = true;
                }
            
                if (shift == true) 
                {
                    candidats[i] = candidats[i+1];
                }
            }

            if (shift == true)
			{
                delete candidats[candidats.length-1];
                candidats.length--;
                return true;
			}	
		}	


        return false;
    }

    function deleteMemberToMint(address toMember) internal returns (bool){
        require(toMint.length > 0);
        //удаляем сразу если кандидат последний в списке
        if (toMint[toMint.length - 1] == toMember){
            delete toMint[toMint.length - 1];
            toMint.length--;
            return true;
		} 
		else 
		{
            bool shift = false;
            for (uint i = 0; i < toMint.length - 1; i++)
			{
                if (!shift && toMint[i] == toMember)
                {
                    shift = true;
                }
            
                if (shift == true) 
                {
                    toMint[i] = toMint[i+1];
                }
            }

            if (shift == true)
			{
                delete toMint[toMint.length-1];
                toMint.length--;
                return true;
			}	
		}	


        return false;
    }

    function deleteMemberToUnMint(address toMember) internal returns (bool){
        require(toUnMint.length > 0);
        //удаляем сразу если кандидат последний в списке
        if (toMint[toUnMint.length - 1] == toMember){
            delete toUnMint[toUnMint.length - 1];
            toUnMint.length--;
            return true;
		} 
		else 
		{
            bool shift = false;
            for (uint i = 0; i < toUnMint.length - 1; i++)
			{
                if (!shift && toUnMint[i] == toMember)
                {
                    shift = true;
                }
            
                if (shift == true) 
                {
                    toUnMint[i] = toUnMint[i+1];
                }
            }

            if (shift == true)
			{
                delete toUnMint[toUnMint.length-1];
                toUnMint.length--;
                return true;
			}	
		}	
        return false;
    }

    function deletecandidatRemoveMember(address candidat) internal returns (bool){
        //удаляем сразу если кандидат последний в списке
        if (candidatsToRemove[candidatsToRemove.length - 1] == candidat){
            delete candidatsToRemove[candidatsToRemove.length - 1];
            candidatsToRemove.length--;
            return true;
		} 
		else 
		{
            bool shift = false;
            for (uint i = 0; i < candidatsToRemove.length - 1; i++)
			{
                if (!shift && candidatsToRemove[i] == candidat)
                {
                    shift = true;
                }
            
                if (shift == true) 
                {
                    candidatsToRemove[i] = candidatsToRemove[i+1];
                }
            }

            if (shift == true)
			{
                delete candidatsToRemove[candidatsToRemove.length-1];
                candidatsToRemove.length--;
                return true;
			}	
		}	


        return false;
    }
    function getCoinName() public view returns (string){
        return name;
    }

    function payTo(address to, uint256 value)
        public
        isMember(msg.sender)
        isMember(to)
        haveMoney(msg.sender, value)
    {
        payments[msg.sender][to] = payments[msg.sender][to].add(value);
        balances[msg.sender] = balances[msg.sender].sub(value);
        emit NewPayment(msg.sender, to, value);
    }

    function acceptPayment(address from)
        public
        isMember(msg.sender)
    {
        require(payments[from][msg.sender] > 0);
        balances[msg.sender] = balances[msg.sender].add(payments[from][msg.sender]);
        uint256 pay = payments[from][msg.sender];
        payments[from][msg.sender] = 0;
        emit PaymentAccepted(from, msg.sender, pay);
    }  

    function rejectPayment(address from)
        public
        isMember(msg.sender)
    {
        require(payments[from][msg.sender] > 0);
        balances[from] = balances[from].add(payments[from][msg.sender]);
        uint256 pay = payments[from][msg.sender];
        payments[from][msg.sender] = 0;
        emit PaymentRejected(from, msg.sender, pay);
    }   

    function totalSupply() public view returns (uint256){
        return TotalSupply;
    }

    function balanceOf(address member) public view returns (uint256){
        return balances[member];
    }

    function incomingPaymants()
        public
        view
        isMember(msg.sender)
        returns (address[255])
    {
        address[255] memory IncomingPaymentsFrom;
        uint index = 0;
        for (uint i = 0; i < memberList.length; i++) {
            if (payments[memberList[i]][msg.sender] > 0) {
                IncomingPaymentsFrom[index] = memberList[i];
                index++;
            }
        }
        return IncomingPaymentsFrom;
    }

    function whereIsMyMoney()
        public
        view
        isMember(msg.sender)
        returns (address[255])
    {
        address[255] memory PaymentsTo;
        uint index = 0;
        for (uint i = 0; i < memberList.length; i++) {
            if (payments[msg.sender][memberList[i]] > 0) {
                PaymentsTo[index] = memberList[i];
                index++;
            }
        }
        return PaymentsTo;
    }

    function paymantValue(address from, address to)
        public
        view
        isMember(msg.sender)
        returns (uint256)
    {
        return payments[from][to];
    }
    function getMembers()
        public
        view
        returns (address[])
    {
        return memberList;
    }
}


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
