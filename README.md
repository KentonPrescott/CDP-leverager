# CDP-leverager

Smart contracts for [CDP-Leverager](https://leverager.now.sh/), a tool to streamline the process of reinvesting in one CDP, allowing you to increase your leverage and margin up to 3x. Please use caution, as the tool is still under development.

___________________________
This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
___________________________

## Setup

You will need two files if you want to get this thing running and deployed on a network. The first is the `secrets.json` file. This file contains the 12 word mnemonic phrase used by `HDWalletProvider`, and looks something like this:

```js
{
  "mnemonic": "soda secret valid ...",
  "hdPath": "m/44'/60'/0'/0/"
}
```

The mnemonic is a BIP39 mnemonic, which you can generate [here](https://iancoleman.io/bip39/). You'll need to make sure you're using 12 words, or else `HDWalletProvider` will complain. 


The next file is the `infura.json` file. This is where you can keep your [Infura](https://infura.io/) access key. That file looks something like this:

```js
{
  "token": "<YOUR INFURA TOKEN>"
}
```

By using this you don't need to run a local node when deploying. It's super convenient and saves a lot of headaches from trying to sync the networks on your computer.

Once you have that all set up you can deploy to the [Kovan](https://kovan.etherscan.io/) testnet (that's where the MakerDAO contracts live) by running:

``` 
truffle migrate --network kovan
```

## The Idea

![Recursive Collateralization](/recursive-collateralization.png)
