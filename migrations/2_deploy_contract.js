'use strict';


const Race = artifacts.require('./Race.sol');


module.exports = function(deployer, network) {
    //owner, auctionEndDate, raceEndDate, maxCars
    const auctionEndDate = new Date(2018, 6, 6, 20, 0);
    const raceEndDate = new Date(2018, 6, 7, 20, 0);

    deployer.deploy(Race, '0xe4Db8f75Fbe9FC52D31EF4e01b4437B9Aa3a309C', Math.round(auctionEndDate.getTime() / 1000), Math.round(raceEndDate.getTime() / 1000), 8);
};
