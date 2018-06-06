'use strict';

import expectThrow from './helpers/expectThrow';

const BreadCoin = artifacts.require('BreadCoin.sol');



contract('BreadCoin', function(accounts) {

    it('test constructor', async function() {
        const token1 = await BreadCoin.new();
    });
    // it('test getCoinName', async function() {
    //     const token2 = await BreadCoin.new();
    //     const name = await token2.getCoinName();
    //     console.log(name);
    // });
    // it('test mint not owner', async function() {
    //     const token4 = await BreadCoin.new();
    //     await expectThrow(token4.mint(accounts[1], 1000));
    // });
    // it('test get owner', async function() {
    //     const token5 = await BreadCoin.new();
    //     const owner = await token5.getTokenOwner();
    //     console.log(owner);
    // }); 
    // it('test balance', async function() {
    //     const token6 = await BreadCoin.new();
    //     const bal = await token6.balanceOf(accounts[0]);
    //     console.log(bal);
    // });
    // it('test mint owner', async function() {
    //     const token6 = await BreadCoin.new();
    //     await expectThrow(token6.mint(accounts[0], 1000));
    // });
    // it('test addToWhiteList and mint', async function() {
    //     const token = await BreadCoin.new();
    //     await token.addToWhiteList(accounts[0]);
    //     await token.mint(accounts[0], 1000);
    // });
    // it('test balance 2', async function() {
    //     const token = await BreadCoin.new();
    //     await token.addToWhiteList(accounts[0]);
    //     await token.mint(accounts[0], 1000);
    //     const bal = await token.balanceOf(accounts[0]);
    //     console.log(bal);
    // });

});
