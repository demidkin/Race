'use strict';


const BreadCoin = artifacts.require('./Race.sol');


module.exports = function(deployer, network) {
    deployer.deploy(BreadCoin);
};
