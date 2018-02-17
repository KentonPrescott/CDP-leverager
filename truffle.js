// Allows us to use ES6 in our migrations and tests.
require('babel-register')
const secrets = require('./secrets.json');
const infura = require('./infura.json');
const HDWalletProvider = require('truffle-hdwallet-provider');

module.exports = {
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*' // Match any network id
    },
    kovan: {
      gas: 4712388,
      gasPrice: 10000000000,
      provider: function() {
        return new HDWalletProvider(secrets.mnemonic, 'https://kovan.infura.io/' + infura.token)
      },
      network_id: 42, // Official ID of the Kovan Network
    },
  }
}
