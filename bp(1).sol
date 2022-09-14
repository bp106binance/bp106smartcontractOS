// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";


import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";




contract Pmm is OwnableUpgradeable,ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address;


    bool private _paused;
    mapping(address => bool) public operators;


    mapping(address => address) public referrerOfUser; // user => referrer
    mapping(address => address[]) public usersOfReferrer; // referrer => user list
    mapping(address =>mapping(address => uint256)) private usersOfReferrerMap;// referrer -> user -> indexId

    mapping(address => address) public financialReferrerOfUser; // user => financial referrer
    mapping(address => address[]) public financialUsersOfReferrer; // referrer => user list
    mapping(address =>mapping(address => uint256)) private financialUsersOfReferrerMap;// referrer -> user -> indexId


    address public receiveAddress;
    address public firstAddress;

    uint256 public fAmount ;
    uint256 public xAmount ;
    uint256 public allAmount ;

    uint256 public poolStartAmount ;
    uint256 public poolxAmount ;
    uint256 public poolEnoughAmount ;

    uint256 public hours168 ;

    mapping(address => uint256) public userJoinTime; // user => time
    mapping(address => uint256) public bossStatus; // user => 1:deal-ok boss,2:not good boss

    mapping(address => uint256) public directAmount; //
    mapping(address => uint256) public seePointAmount; //
    mapping(address => uint256) public bossAmount; //
    mapping(address => uint256) public poolAmount; //

    uint256 public startTm ;
    uint256 public poolCurAmount ;
    address[] public poolList;
    uint256 public poolIndex;
    address public poolLastUser;
    address public poolLastRewardUser; 

    uint256 public serialNumber ;
    mapping(address => uint256) public serialNumberOfUser; // user => serialNumber
    mapping(uint256 => address) public userOfSerialNumber; // user => serialNumber

    mapping(address => uint256) public identityOfUser; // user => 1 proxy ,2 boss
    

    modifier whenNotPaused() {
        require(!_paused, "Pausable: paused");
        _;
    }
    modifier onlyOperator() {
        require(operators[msg.sender], "Operator: caller is not the operator");
        _;
    }

    event RecordReferral(address indexed user, address indexed referrer);
    
    constructor(){}

    function initialize() initializer public {
        __Ownable_init();
        __ReentrancyGuard_init();

        _paused = false;
        operators[msg.sender] = true;

        fAmount = 1 ether;
        xAmount = 0.06 ether;
        allAmount = 1.06 ether;

        poolStartAmount = 10 ether;
        poolxAmount = 2 ether;
        poolEnoughAmount = 12 ether;

        hours168 =  168 hours ;
        serialNumber = 1000;
    }



    function initDataForTest()public onlyOwner {
            fAmount = 0.01 ether;
            xAmount = 0.0006 ether;
            allAmount = 0.0106 ether;

            poolStartAmount = 0.01 ether;
            poolxAmount = 0.002 ether;
            poolEnoughAmount = 0.012 ether;

            hours168 = 30 minutes;
    }
    
    function initData(address _firstAddress)public onlyOwner {
        setReferrerByAdmin(_firstAddress,msg.sender);
        firstAddress = _firstAddress;
        identityOfUser[_firstAddress] = 2;
        bossStatus[_firstAddress] = 1;
    }

    function setToken( address _receiveAddress) public onlyOwner {
        receiveAddress = _receiveAddress;
    }

    function setJoinAmount( uint256 fAmount_,uint256 xAmount_,uint256 allAmount_) public onlyOwner {
        fAmount = fAmount_;
        xAmount = xAmount_;
        allAmount = allAmount_;
    }

    function setPoolAmount( uint256 poolStartAmount_,uint256 poolxAmount_,uint256 poolEnoughAmount_) public onlyOwner {
        poolStartAmount = poolStartAmount_;
        poolxAmount = poolxAmount_;
        poolEnoughAmount = poolEnoughAmount_;
    }

    function setFirstAddress( address _firstAddress) public onlyOwner {
        firstAddress = _firstAddress;
    }

    function setOtherlxaddress(bool paused_,bool _xcall, address _firstAddress) public onlyOwner {
        _paused = paused_;
        //xcall = _xcall;
        firstAddress = _firstAddress;
    }

    function setOperator(address _operator, bool _enabled) public onlyOwner {
        operators[_operator] = _enabled;
    }

    function setPaused(bool paused_) public onlyOwner {
        _paused = paused_;
    }

    fallback() external payable {

    }
    receive() external payable {

  	}

    function rescuescoin(
        address _token,
        address payable _to,
        uint256 _amount
    ) public onlyOwner {
        if (_token == address(0)) {
            (bool success, ) = _to.call{ gas: 23000, value: _amount }("");
            require(success, "transferETH failed");
        } else {
            IERC20Upgradeable(_token).safeTransfer(_to, _amount);
        }
    }

    function setReferrerByAdmin(address user,address _referrer) public onlyOperator {
        _recordReferral(user, _referrer);
    }

    function _recordReferral(address _user, address _referrer) internal {
        if (_paused) {
            return ;
        }

        // record referral already
        if (referrerOfUser[_user] != address(0) || referrerOfUser[_referrer] == _user) {
            return;
        }

        // invalid address
        if (
            _user == _referrer ||
            _user == address(0) ||
            _referrer == address(0) ||
            _user.isContract() ||
            _referrer.isContract()
        ) {
            return;
        }
        
        _addUsersOfReferrer(_referrer,_user);
        _addfinancialUsersOfReferrer(_referrer,_user);
 
        emit RecordReferral(_user, _referrer);
    }

    function changeFinancialReferrer(address _user, address _newReferrer) internal {
        address oldReferrer = getFinancialReferrer(_user);
        if (oldReferrer != address(0)){
            _removefinancialUsersOfReferrer(oldReferrer,_user);
        }
        _addfinancialUsersOfReferrer(_newReferrer,_user);
    }

   function sendFund(address beneficiary, uint256 amount) private {
        payable(beneficiary).send(amount);
    }
    function sendFund_direct(address beneficiary, uint256 amount) private {
        if (bossStatus[beneficiary] == 2 ){
            uint256 f = amount.mul(20).div(100);
            poolCurAmount += f;
            amount = amount.sub(f);
        }

        payable(beneficiary).send(amount);
        directAmount[beneficiary] += amount;
    }

    function sendFund_seePoint(address beneficiary, uint256 amount) private {
        if (bossStatus[beneficiary] == 2 ){
            uint256 f = amount.mul(20).div(100);
            poolCurAmount += f;
            amount = amount.sub(f);
        }

        payable(beneficiary).send(amount);
        seePointAmount[beneficiary] += amount;
    }

    function sendFund_boss(address beneficiary, uint256 amount) private {
        if (bossStatus[beneficiary] == 2 ){
            uint256 f = amount.mul(20).div(100);
            poolCurAmount += f;
            amount = amount.sub(f);
        }

        payable(beneficiary).send(amount);
        bossAmount[beneficiary] += amount;
    }
    function sendFund_pool(address beneficiary, uint256 amount) private {
        payable(beneficiary).send(amount);   
        poolAmount[beneficiary] += amount;  
    }

    function setSerialNumber(address user) private {
        serialNumber += 1;
        serialNumberOfUser[user] = serialNumber;
        userOfSerialNumber[serialNumber] = user;
    }

    function join(address referral) public payable nonReentrant {
        require(referrerOfUser[referral] != address(0), "referral not join");
        address user = msg.sender;
        uint256 _amount = msg.value;
        require(identityOfUser[user] == 0, "had joined");
        require(_amount == allAmount, "amount error");

        _recordReferral(user,referral);
        setSerialNumber(user);

        //setFirstAddressInternal(user); //set first address  ?????

        userJoinTime[user] = block.timestamp;
        identityOfUser[user] = 1;           // set proxy identity
        sendFund(receiveAddress,xAmount);  // send to project address
        directReward(user);                 // direct drive reward
        seePointReward(referral);
        bossReward(referral);
        poolReward();


        paiw(referral);
        tis(referral);
    }

    function setFirstAddressInternal( address addr) internal {
        if (firstAddress ==  address(0)){
             firstAddress = addr;
        }
       
    }

    function directReward(address user) internal {
        address _referrer = financialReferrerOfUser[user];
        uint256 _amount = fAmount.mul(50).div(100);
        if (_referrer == address(0)){
            sendFund(firstAddress,_amount);
        }else{
            sendFund_direct(_referrer,_amount);
        }
    }

    function seePointReward(address me) internal {
        uint256 count = countUsersOfReferrer(me);
        uint256 _amount = fAmount.mul(30).div(100);
        if (count <= 2){
            
            address boss = getUpBoss(me);
            if (boss == address(0)){
                sendFund(firstAddress,_amount);
            }else{
                sendFund_seePoint(boss,_amount);
            } 

            if (count == 2){ //Become the boss
                identityOfUser[me] = 2; 
            }

        }else{
            sendFund_seePoint(me,_amount);
        }
    }

    function bossReward(address me) internal {
        address boss1 = getUpBoss(me);
        uint256 _amount1 = fAmount.mul(4).div(100);
        uint256 _amount2 = fAmount.mul(6).div(100);
        if (boss1 == address(0)){
            sendFund(firstAddress,_amount1);
            sendFund(firstAddress,_amount2);
        }else{

            sendFund_boss(boss1,_amount1);

            address boss2 = getUpBoss(boss1);
            if (boss2 == address(0)){
                sendFund(firstAddress,_amount2);
            }else{
                sendFund_boss(boss2,_amount2);
            } 

        } 
    }

    function poolReward() internal {
        uint256 _amount = fAmount.mul(10).div(100);

        if (startTm == 0){ // not start
            poolCurAmount += _amount;
            if (poolCurAmount >= poolStartAmount){
                startTm = block.timestamp;
            }

            poolList.push(msg.sender);
            poolLastUser = msg.sender;
            return;
        }

        //Over hours168
        if (block.timestamp > (startTm + hours168)){

            if (poolCurAmount >= poolStartAmount){
                sendFund_pool(poolLastUser,poolStartAmount);
                poolCurAmount -= poolStartAmount;
            }else{
                sendFund_pool(poolLastUser,poolCurAmount);
                poolCurAmount = 0;
            }
            poolLastRewardUser = poolLastUser;

            startTm = 0; 
            poolCurAmount += _amount;

            delete poolList;
            poolIndex = 0;
            poolLastUser = msg.sender;
            return;
        }

        poolCurAmount += _amount;
        if (poolCurAmount >= poolEnoughAmount){
            
            address euser;
            if (poolIndex < lengthPoolList()){
                euser = poolList[poolIndex];
            }
            sendFund_pool(euser,poolxAmount);
            poolLastRewardUser = euser;

            poolCurAmount -= poolxAmount;
            poolIndex += 1;
        }

        poolList.push(msg.sender);
        poolLastUser = msg.sender;
        return;

    }

    // Changes of qualifying
    function paiw(address me) internal {
        uint256 count = countUsersOfReferrer(me);
        if (count == 1){ //Become the boss and Changes of qualifying
            address _referrer = financialReferrerOfUser[me];
            if (_referrer != address(0)){
                address A = usersOfReferrer[me][0];
                changeFinancialReferrer(A,_referrer);
            }
        }

        if (count == 2){ //Become the boss and Changes of qualifying
            address _referrer = financialReferrerOfUser[me];
            if (_referrer != address(0)){
                address B = usersOfReferrer[me][1];
                changeFinancialReferrer(B,_referrer);
            }

        }
    }

    function tis(address me) internal {
        ti(me,1);

        for (uint256 level = 1; level <= 5; level++) {
            address up = getReferrerByLevel(me,level);
            if (up == address(0)){
                break;
            } 
            ti(up,0);
        }
    }

    function ti(address me, uint256 neetChange) internal {
        
        if (identityOfUser[me] != 2 ){
            return;
        }

        if (bossStatus[me] == 1 ){ //deal-ok boss
            return;
        }

        address A = usersOfReferrer[me][0];
        address B = usersOfReferrer[me][1];

        uint256 Atimes = userJoinTime[A];
        uint256 Btimes = userJoinTime[B];

        if ( 
               (Atimes + hours168) < block.timestamp 
            && (Btimes + hours168) < block.timestamp 
            && (identityOfUser[A] == 1 || identityOfUser[B] == 1)
        ){
            bossStatus[me] = 2;
         }

        if (bossStatus[me] == 2 && neetChange == 1){

            address _referrer = financialReferrerOfUser[me];
            if (_referrer != address(0)){
                
                if (identityOfUser[A] == 1){
                    changeFinancialReferrer(A,me);
                }else{
                    changeFinancialReferrer(B,me);
                }

                uint256 len = countUsersOfReferrer(me);
                if (len > 0){
                    changeFinancialReferrer(usersOfReferrer[me][len - 1],_referrer);
                }
            }

            bossStatus[me] = 1;
        }

    }

    function lengthPoolList() public view returns (uint256) {
        return poolList.length;
    }

    function mapBeRewardUser() public view returns (address) {
        if (poolIndex < lengthPoolList()){
            return poolList[poolIndex];
        }else{
            return address(0);
        }
    }

    //------------------------------------------------
    //-----------------financialReferrerOfUser--------
    //------------------------------------------------

    function getUpBoss(address _user) public view returns (address) {
        uint256 _level = 100;
        address _referrer = address(0);
        address[] memory _found = new address[](_level + 1);
        _found[0] = _user;

        for (uint256 _l = 1; _l <= _level; _l++) {
            _referrer = financialReferrerOfUser[_user];
            if (_referrer == address(0) || _contains(_found, _referrer)) {
                return address(0);
            }

            if(identityOfUser[_referrer] == 2){
                return _referrer;
            }

            _user = _referrer;
            _found[_l] = _referrer;
        }

        return address(0);
    }

    //------------------------------------------------
    //-----------------referrer users ----------------
    //------------------------------------------------

    function _addUsersOfReferrer(address referrer,address _downuser) private {
        if (usersOfReferrerMap[referrer][_downuser] > 0){
            return;
        }

        usersOfReferrerMap[referrer][_downuser] = usersOfReferrer[referrer].length + 1;
        usersOfReferrer[referrer].push(_downuser);

        referrerOfUser[_downuser] = referrer;
    }

    function _removeUsersOfReferrer(address referrer,address _downuser) private {

        uint256 orderIndex = usersOfReferrerMap[referrer][_downuser];
        if (orderIndex == 0){
            return;
        }
        orderIndex -=1;
        uint256 lastOrderIndex = usersOfReferrer[referrer].length - 1;
    
        // When the token to delete is the last token, the swap operation is unnecessary.
        if (orderIndex != lastOrderIndex) {
            address last_downuser = usersOfReferrer[referrer][lastOrderIndex];

            usersOfReferrer[referrer][orderIndex] = last_downuser; // Move the last token to the slot of the to-delete token
            usersOfReferrerMap[referrer][last_downuser] = orderIndex + 1; // Update the moved token's index
        }

        // This also deletes the contents at the last position of the array
        delete usersOfReferrerMap[referrer][_downuser];
        usersOfReferrer[referrer].pop();

        referrerOfUser[_downuser] = address(0);
    }

    function _addfinancialUsersOfReferrer(address referrer,address _downuser) private {
        if (financialUsersOfReferrerMap[referrer][_downuser] > 0){
            return;
        }

        financialUsersOfReferrerMap[referrer][_downuser] = financialUsersOfReferrer[referrer].length + 1;
        financialUsersOfReferrer[referrer].push(_downuser);

        financialReferrerOfUser[_downuser] = referrer;
    }

    function _removefinancialUsersOfReferrer(address referrer,address _downuser) private {

        uint256 orderIndex = financialUsersOfReferrerMap[referrer][_downuser];
        if (orderIndex == 0){
            return;
        }
        orderIndex -=1;
        uint256 lastOrderIndex = financialUsersOfReferrer[referrer].length - 1;
    
        // When the token to delete is the last token, the swap operation is unnecessary.
        if (orderIndex != lastOrderIndex) {
            address last_downuser = financialUsersOfReferrer[referrer][lastOrderIndex];

            financialUsersOfReferrer[referrer][orderIndex] = last_downuser; 
            financialUsersOfReferrerMap[referrer][last_downuser] = orderIndex + 1; 
        }

        delete financialUsersOfReferrerMap[referrer][_downuser];
        financialUsersOfReferrer[referrer].pop();

        financialReferrerOfUser[_downuser] = address(0);
    }



    //------------------------------------------------
    //-----------------referrerOfUser-----------------
    //------------------------------------------------
    function getReferrer(address _user) public view  returns (address) {
        return referrerOfUser[_user];
    }

    function getReferrerByLevel(address _user, uint256 _level) public view returns (address) {
        address _referrer = address(0);
        address[] memory _found = new address[](_level + 1);
        _found[0] = _user;

        for (uint256 _l = 1; _l <= _level; _l++) {
            _referrer = referrerOfUser[_user];
            if (_referrer == address(0) || _contains(_found, _referrer)) {
                return address(0);
            }

            _user = _referrer;
            _found[_l] = _referrer;
        }

        return _referrer;
    }

    function countUsersOfReferrer(address _referrer) public view returns (uint256) {
        return usersOfReferrer[_referrer].length;
    }

    function getUsersOfReferrer(address _referrer) public view returns (address[] memory) {
        address[] memory users_ = usersOfReferrer[_referrer];
        return users_;
    }

    //------------------------------------------------
    //-----------financialUsersOfReferrer-------------
    //------------------------------------------------
    function getFinancialReferrer(address _user) public view  returns (address) {
        return financialReferrerOfUser[_user];
    }

    function getFinancialReferrerByLevel(address _user, uint256 _level) public view returns (address) {
        address _referrer = address(0);
        address[] memory _found = new address[](_level + 1);
        _found[0] = _user;

        for (uint256 _l = 1; _l <= _level; _l++) {
            _referrer = financialReferrerOfUser[_user];
            if (_referrer == address(0) || _contains(_found, _referrer)) {
                return address(0);
            }

            _user = _referrer;
            _found[_l] = _referrer;
        }

        return _referrer;
    }

    function countFinancialUsersOfReferrer(address _referrer) public view returns (uint256) {
        return financialUsersOfReferrer[_referrer].length;
    }

    function getFinancialUsersOfReferrer(address _referrer) public view returns (address[] memory) {
        address[] memory users_ = financialUsersOfReferrer[_referrer];
        return users_;
    }

    //------------------------------------------------
    //-----------------lib----------------------------
    //------------------------------------------------

    function _contains(address[] memory _list, address _a) internal pure returns (bool) {
        for (uint256 i = 0; i < _list.length; i++) {
            if (_list[i] == _a) {
                return true;
            }
        }
        return false;
    }

}

